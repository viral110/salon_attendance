import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_endpoints.dart';
import '../modules/staff/controllers/staff_controller.dart';
import '../modules/staff/models/staff_model.dart';
import 'api_service.dart';
import 'attendance_service.dart';

/// WhatsApp Attendance Notification Service using WASender API
/// Syncs templates & settings dynamically with Victoria Salon Backend
class WASenderService extends GetxService {
  static WASenderService get to => Get.find<WASenderService>();

  static const String apiUrl = 'https://wasenderapi.com/api/send-message';
  static const String defaultBearerToken =
      '357868376634e987f696dc308850dcecb772d5003805ab751bf30029e767171e';

  final ApiService _apiService = ApiService();

  // Observable tokens and settings
  final bearerToken = defaultBearerToken.obs;
  final adminPhones = <String>['+918140954662', '+917201872515'].obs;
  final templates = <String, String>{}.obs;
  final salonName = 'Victoria Beauty Salon'.obs;

  final isLoadingSettings = false.obs;
  final isLoadingTemplates = false.obs;

  // Sequential message queue with rate-limiting to protect WASender account
  Future<void> _messageQueueChain = Future.value();
  DateTime? _lastMessageSentTime;
  static const int _minSecondsBetweenMessages = 5;

  @override
  void onInit() {
    super.onInit();
    fetchBackendSettings();
    fetchBackendTemplates();
  }

  /// Helper to format phone number to international standard (e.g. +919876543210)
  String formatPhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return '';
    if (!cleaned.startsWith('+')) {
      if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else if (cleaned.startsWith('91') && cleaned.length == 12) {
        cleaned = '+$cleaned';
      } else {
        cleaned = '+$cleaned';
      }
    }
    return cleaned;
  }

  /// Fetch settings from backend API endpoint: /api/settings
  Future<void> fetchBackendSettings() async {
    isLoadingSettings.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.settings);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic>? dataMap;
        if (decoded is Map) {
          if (decoded['data'] is Map) {
            dataMap = Map<String, dynamic>.from(decoded['data']);
          } else {
            dataMap = Map<String, dynamic>.from(decoded);
          }
        }

        if (dataMap != null) {
          // 1. Extract Bearer Token
          final token = dataMap['bearer_token'] ??
              dataMap['bearerToken'] ??
              dataMap['personal_access_token'];
          if (token != null && token.toString().trim().isNotEmpty) {
            bearerToken.value = token.toString().trim();
          }

          // 2. Extract Salon Name
          final name = dataMap['salon_name'] ?? dataMap['business_name'] ?? dataMap['name'];
          if (name != null && name.toString().trim().isNotEmpty) {
            salonName.value = name.toString().trim();
          }

          // 3. Extract Admin Mobile Numbers
          final Set<String> adminList = {};
          if (dataMap['admin_mobile_numbers'] is List) {
            for (final item in (dataMap['admin_mobile_numbers'] as List)) {
              if (item is Map) {
                final phone = item['phone'] ?? item['mobile'];
                final isSelected = item['is_selected'] == true || item['isSelected'] == true;
                if (isSelected && phone != null) {
                  final formatted = formatPhone(phone.toString());
                  if (formatted.isNotEmpty) adminList.add(formatted);
                }
              } else if (item is String) {
                final formatted = formatPhone(item);
                if (formatted.isNotEmpty) adminList.add(formatted);
              }
            }
          }

          if (dataMap['selected_admin_mobiles'] is List) {
            for (final phone in (dataMap['selected_admin_mobiles'] as List)) {
              final formatted = formatPhone(phone.toString());
              if (formatted.isNotEmpty) adminList.add(formatted);
            }
          }

          final singleAdmin = dataMap['selected_admin_mobile'] ?? dataMap['admin_phone'];
          if (singleAdmin != null && singleAdmin.toString().trim().isNotEmpty) {
            final formatted = formatPhone(singleAdmin.toString());
            if (formatted.isNotEmpty) adminList.add(formatted);
          }

          if (adminList.isNotEmpty) {
            adminPhones.assignAll(adminList.toList());
          }
        }
      }
    } catch (e) {
      debugPrint('WASenderService fetchBackendSettings error: $e');
    } finally {
      isLoadingSettings.value = false;
    }
  }

  /// Fetch templates from backend API endpoint: /api/v1/templates
  Future<void> fetchBackendTemplates() async {
    isLoadingTemplates.value = true;
    try {
      final response = await _apiService.get(ApiEndpoints.templates);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            items = decoded['data'];
          } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
            items = decoded['data']['data'];
          }
        }

        final Map<String, String> loaded = {};
        for (final item in items) {
          if (item is Map) {
            final eventKey = (item['event_key'] ?? item['eventKey'] ?? '').toString().trim();
            final body = (item['template_body'] ?? item['body'] ?? '').toString().trim();
            final isActive = item['is_active'] == true ||
                item['is_active'] == 1 ||
                item['is_active'] == '1';

            if (eventKey.isNotEmpty && body.isNotEmpty && isActive) {
              loaded[eventKey] = body;
              loaded[eventKey.toLowerCase()] = body;
              loaded[eventKey.toUpperCase()] = body;
            }
          }
        }

        templates.assignAll(loaded);
        debugPrint('WASenderService: Loaded ${loaded.length ~/ 3} active templates from backend');
      }
    } catch (e) {
      debugPrint('WASenderService fetchBackendTemplates error: $e');
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  /// Fetch template body by event key (case-insensitive)
  String getTemplate(String key) {
    return templates[key] ??
        templates[key.toUpperCase()] ??
        templates[key.toLowerCase()] ??
        '';
  }

  /// Core Send Message method enqueued in sequential rate-limited chain
  Future<bool> sendMessage({
    required String toPhone,
    required String messageText,
  }) {
    final completer = Completer<bool>();
    _messageQueueChain = _messageQueueChain.then((_) async {
      try {
        final result = await _executeSendMessageWithRetry(
          toPhone: toPhone,
          messageText: messageText,
        );
        completer.complete(result);
      } catch (e) {
        debugPrint('WASenderService Queue Exception: $e');
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<bool> _executeSendMessageWithRetry({
    required String toPhone,
    required String messageText,
    int maxRetries = 3,
  }) async {
    final formattedTo = formatPhone(toPhone);
    if (formattedTo.isEmpty) {
      debugPrint('WASenderService: Cannot send message, phone is empty.');
      return false;
    }

    final activeToken = bearerToken.value.trim().isNotEmpty
        ? bearerToken.value.trim()
        : defaultBearerToken;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      // Enforce at least 5.5s delay between consecutive messages
      if (_lastMessageSentTime != null) {
        final elapsed = DateTime.now().difference(_lastMessageSentTime!);
        final minIntervalMs = (_minSecondsBetweenMessages * 1000) + 500;
        if (elapsed.inMilliseconds < minIntervalMs) {
          final waitMs = minIntervalMs - elapsed.inMilliseconds;
          debugPrint('WASenderService Rate-Limit: Waiting ${waitMs}ms before sending to $formattedTo...');
          await Future.delayed(Duration(milliseconds: waitMs));
        }
      }

      try {
        final headers = {
          'Authorization': 'Bearer $activeToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        final body = jsonEncode({
          'to': formattedTo,
          'text': messageText,
        });

        debugPrint('WASenderService: Sending message to $formattedTo (Attempt $attempt/$maxRetries)');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: headers,
          body: body,
        );

        _lastMessageSentTime = DateTime.now();

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('WASenderService Success [$formattedTo]: ${response.body}');
          return true;
        }

        if (response.statusCode == 429) {
          int retryAfter = _minSecondsBetweenMessages;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['retry_after'] != null) {
              retryAfter = int.tryParse(decoded['retry_after'].toString()) ?? _minSecondsBetweenMessages;
            }
          } catch (_) {}

          final waitSeconds = retryAfter + 2;
          debugPrint('WASenderService 429 Rate Limit: Waiting ${waitSeconds}s...');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: waitSeconds));
            _lastMessageSentTime = DateTime.now();
            continue;
          }
        }

        debugPrint('WASenderService Error [${response.statusCode}]: ${response.body}');
        return false;
      } catch (e) {
        debugPrint('WASenderService Exception: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return false;
      }
    }
    return false;
  }

  /// Sends Admin notification to all active admin numbers
  Future<void> sendAdminAlert(String messageText) async {
    final mobiles = adminPhones.toList();
    debugPrint('WASenderService: Sending admin alert to ${mobiles.length} number(s): $mobiles');
    for (final phone in mobiles) {
      sendMessage(toPhone: phone, messageText: messageText);
    }
  }

  /// Resolves staff model phone from controller if missing in matched staff
  StaffModel _resolveStaffDetails(StaffModel staff) {
    if (staff.phone != null && staff.phone!.trim().isNotEmpty) {
      return staff;
    }

    if (Get.isRegistered<StaffController>()) {
      final staffList = Get.find<StaffController>().staffList;
      for (final s in staffList) {
        if (s.id == staff.id ||
            (s.dbId != 0 && s.dbId == staff.dbId) ||
            s.name.trim().toLowerCase() == staff.name.trim().toLowerCase()) {
          return s;
        }
      }
    }
    return staff;
  }

  /// Central trigger: Sends WhatsApp message for Attendance Check-In and Check-Out
  /// Dispatched asynchronously so UI is never blocked.
  void notifyAttendanceAction({
    required StaffModel staff,
    required AttendanceAction action,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    Duration? workingDuration,
    String? checkInTimeStr,
    String? checkOutTimeStr,
    String? totalHoursStr,
    String? dateStr,
    String? statusStr,
  }) {
    // Run asynchronously in background
    Future.microtask(() async {
      try {
        final resolvedStaff = _resolveStaffDetails(staff);
        final staffPhone = resolvedStaff.phone ?? resolvedStaff.phone1 ?? resolvedStaff.phone2 ?? '';
        final staffName = resolvedStaff.name.isNotEmpty ? resolvedStaff.name : 'Staff Member';
        final now = DateTime.now();

        // 1. Resolve date string (e.g. backend "2026-10-06" -> "06-10-2026")
        String dateFormatted = DateFormat('dd-MM-yyyy').format(now);
        if (dateStr != null && dateStr.trim().isNotEmpty) {
          try {
            final parsedDate = DateTime.tryParse(dateStr.trim());
            if (parsedDate != null) {
              dateFormatted = DateFormat('dd-MM-yyyy').format(parsedDate);
            } else {
              dateFormatted = dateStr.trim();
            }
          } catch (_) {
            dateFormatted = dateStr.trim();
          }
        }

        // 2. Resolve times directly from backend response e.g. "02:36 PM" / "03:53 PM"
        final inTimeFormatted = (checkInTimeStr != null && checkInTimeStr.trim().isNotEmpty)
            ? checkInTimeStr.trim()
            : DateFormat('hh:mm a').format(checkInTime ?? now);

        final outTimeFormatted = (checkOutTimeStr != null && checkOutTimeStr.trim().isNotEmpty)
            ? checkOutTimeStr.trim()
            : DateFormat('hh:mm a').format(checkOutTime ?? now);

        // 3. Resolve duration e.g. "1h 17m" from backend total_hours
        String durationFormatted = '--';
        if (totalHoursStr != null && totalHoursStr.trim().isNotEmpty) {
          durationFormatted = totalHoursStr.trim();
        } else if (workingDuration != null) {
          final hours = workingDuration.inHours;
          final mins = workingDuration.inMinutes.remainder(60);
          durationFormatted = '${hours}h ${mins}m';
        } else if (checkInTime != null && checkOutTime != null) {
          final diff = checkOutTime.difference(checkInTime);
          final hours = diff.inHours;
          final mins = diff.inMinutes.remainder(60);
          durationFormatted = '${hours}h ${mins}m';
        }

        final statusFormatted = (statusStr != null && statusStr.trim().isNotEmpty)
            ? (statusStr.trim().toLowerCase() == 'present' ? 'Present' : statusStr.trim())
            : (action == AttendanceAction.checkIn ? 'Checked In' : 'Checked Out');

        if (action == AttendanceAction.checkIn) {
          // -------------------------------------------------------------
          // 1. STAFF CHECK-IN MESSAGE
          // -------------------------------------------------------------
          String staffTpl = getTemplate('STAFF_CHECK_IN');
          if (staffTpl.isEmpty) {
            staffTpl = 'Hello {{staff_name}},\n'
                'Your attendance *Check-In* has been recorded successfully at *{{time}}* on *{{date}}*.\n\n'
                'Have a wonderful and productive day at {{salon_name}}! 🌸';
          }

          final staffMsg = _replacePlaceholders(
            template: staffTpl,
            staffName: staffName,
            date: dateFormatted,
            time: inTimeFormatted,
            checkInTime: inTimeFormatted,
            checkOutTime: '--',
            duration: '--',
            status: statusFormatted,
            salon: salonName.value,
          );

          if (staffPhone.isNotEmpty) {
            debugPrint('WASenderService: Sending Check-In message to staff: $staffPhone');
            sendMessage(toPhone: staffPhone, messageText: staffMsg);
          } else {
            debugPrint('WASenderService: Staff phone is empty for $staffName, skipping staff WhatsApp.');
          }

          // -------------------------------------------------------------
          // 2. ADMIN CHECK-IN NOTIFICATION
          // -------------------------------------------------------------
          String adminTpl = getTemplate('ADMIN_STAFF_CHECK_IN');
          if (adminTpl.isEmpty) {
            adminTpl = '🔔 *Attendance Alert (Check-In)*\n\n'
                '• Staff: *{{staff_name}}*\n'
                '• Status: *{{status}}*\n'
                '• Check-In: *{{time}}*\n'
                '• Date: *{{date}}*\n'
                '• Salon: *{{salon_name}}*';
          }

          final adminMsg = _replacePlaceholders(
            template: adminTpl,
            staffName: staffName,
            date: dateFormatted,
            time: inTimeFormatted,
            checkInTime: inTimeFormatted,
            checkOutTime: '--',
            duration: '--',
            status: statusFormatted,
            salon: salonName.value,
          );

          sendAdminAlert(adminMsg);
        } else if (action == AttendanceAction.checkOut) {
          // -------------------------------------------------------------
          // 1. STAFF CHECK-OUT MESSAGE
          // -------------------------------------------------------------
          String staffTpl = getTemplate('STAFF_CHECK_OUT');
          if (staffTpl.isEmpty) {
            staffTpl = 'Hello {{staff_name}},\n'
                'Your attendance *Check-Out* has been recorded successfully on {{date}}.\n\n'
                '• Check-In Time: *{{check_in_time}}*\n'
                '• Check-Out Time: *{{check_out_time}}*\n'
                '• Total Working Hours: *{{duration}}*\n\n'
                'Thank you for your hard work today at {{salon_name}}! ✨';
          }

          final staffMsg = _replacePlaceholders(
            template: staffTpl,
            staffName: staffName,
            date: dateFormatted,
            time: outTimeFormatted,
            checkInTime: inTimeFormatted,
            checkOutTime: outTimeFormatted,
            duration: durationFormatted,
            status: statusFormatted,
            salon: salonName.value,
          );

          if (staffPhone.isNotEmpty) {
            debugPrint('WASenderService: Sending Check-Out message to staff: $staffPhone');
            sendMessage(toPhone: staffPhone, messageText: staffMsg);
          } else {
            debugPrint('WASenderService: Staff phone is empty for $staffName, skipping staff WhatsApp.');
          }

          // -------------------------------------------------------------
          // 2. ADMIN CHECK-OUT NOTIFICATION
          // -------------------------------------------------------------
          String adminTpl = getTemplate('ADMIN_STAFF_CHECK_OUT');
          if (adminTpl.isEmpty) {
            adminTpl = '🔔 *Attendance Alert (Check-Out)*\n\n'
                '• Staff: *{{staff_name}}*\n'
                '• Status: *{{status}}*\n'
                '• Check-In: *{{check_in_time}}*\n'
                '• Check-Out: *{{time}}*\n'
                '• Working Hours: *{{duration}}*\n'
                '• Date: *{{date}}*\n'
                '• Salon: *{{salon_name}}*';
          }

          final adminMsg = _replacePlaceholders(
            template: adminTpl,
            staffName: staffName,
            date: dateFormatted,
            time: outTimeFormatted,
            checkInTime: inTimeFormatted,
            checkOutTime: outTimeFormatted,
            duration: durationFormatted,
            status: statusFormatted,
            salon: salonName.value,
          );

          sendAdminAlert(adminMsg);
        }
      } catch (e) {
        debugPrint('WASenderService notifyAttendanceAction exception: $e');
      }
    });
  }

  String _replacePlaceholders({
    required String template,
    required String staffName,
    required String date,
    required String time,
    required String checkInTime,
    required String checkOutTime,
    required String duration,
    required String status,
    required String salon,
  }) {
    return template
        .replaceAll('{{staff_name}}', staffName)
        .replaceAll('{staff_name}', staffName)
        .replaceAll('{{name}}', staffName)
        .replaceAll('{name}', staffName)
        .replaceAll('{{date}}', date)
        .replaceAll('{date}', date)
        .replaceAll('{{time}}', time)
        .replaceAll('{time}', time)
        .replaceAll('{{check_in_time}}', checkInTime)
        .replaceAll('{check_in_time}', checkInTime)
        .replaceAll('{{check_out_time}}', checkOutTime)
        .replaceAll('{check_out_time}', checkOutTime)
        .replaceAll('{{duration}}', duration)
        .replaceAll('{duration}', duration)
        .replaceAll('{{working_hours}}', duration)
        .replaceAll('{working_hours}', duration)
        .replaceAll('{{status}}', status)
        .replaceAll('{status}', status)
        .replaceAll('{{salon_name}}', salon)
        .replaceAll('{salon_name}', salon);
  }
}
