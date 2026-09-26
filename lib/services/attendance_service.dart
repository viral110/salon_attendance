import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../utils/api_logger.dart';

import '../config/face_recognition_config.dart';
import '../models/attendance_model.dart';
import '../models/attendance_summary_model.dart';
import '../models/attendance_verification_model.dart';
import '../models/staff_model.dart';

enum SelectedAttendanceMode { auto, checkIn, checkOut }

enum AttendanceAction {
  checkIn,
  checkOut,
  alreadyCompleted,
  alreadyCheckedIn,
  notCheckedInYet,
}

class AttendanceActionResult {
  final bool success;
  final AttendanceAction action;
  final AttendanceModel? attendance;
  final StaffModel? staff;
  final String message;
  final String? errors;
  final bool isDuplicateProtection;

  AttendanceActionResult({
    required this.success,
    required this.action,
    this.attendance,
    this.staff,
    required this.message,
    this.errors,
    this.isDuplicateProtection = false,
  });
}

class AttendanceService {
  final _uuid = const Uuid();

  // In-memory store for attendance records & audit logs
  final List<AttendanceModel> _attendanceRecords = [];
  final List<AttendanceVerificationModel> _verificationLogs = [];

  /// Returns deterministic date key string "YYYY-MM-DD" for business local date.
  String getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Retrieves today's attendance for staff member using local timezone date key.
  Future<AttendanceModel?> getTodayAttendance(String staffId) async {
    final todayKey = getDateKey(DateTime.now());
    try {
      return _attendanceRecords.firstWhere(
        (r) => (r.staffId == staffId) && r.dateKey == todayKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// Central attendance decision logic based strictly on current state.
  Future<AttendanceAction> determineAttendanceAction(String staffId) async {
    final todayRecord = await getTodayAttendance(staffId);

    if (todayRecord == null || todayRecord.checkIn == null) {
      return AttendanceAction.checkIn;
    } else if (todayRecord.checkOut == null) {
      return AttendanceAction.checkOut;
    } else {
      return AttendanceAction.alreadyCompleted;
    }
  }

  /// Process face attendance attempt atomically with duplicate protection check.
  Future<AttendanceActionResult> processAttendance({
    required String staffId,
    required double confidence,
    SelectedAttendanceMode selectedMode = SelectedAttendanceMode.auto,
  }) async {
    final now = DateTime.now();
    final todayKey = getDateKey(now);
    final todayRecord = await getTodayAttendance(staffId);

    final bool hasCheckedIn = todayRecord != null && todayRecord.checkIn != null;
    final bool hasCheckedOut = todayRecord != null && todayRecord.checkOut != null;

    // 1. If today's attendance is already fully completed
    if (hasCheckedIn && hasCheckedOut) {
      final timeStr = DateFormat('hh:mm a').format(todayRecord.checkIn!);
      final checkOutStr = DateFormat('hh:mm a').format(todayRecord.checkOut!);
      return AttendanceActionResult(
        success: false,
        action: AttendanceAction.alreadyCompleted,
        attendance: todayRecord,
        message: 'You have already completed attendance for today.\nCheck-In: $timeStr | Check-Out: $checkOutStr',
      );
    }

    // 2. Explicit Mode Mismatch Checks
    if (selectedMode == SelectedAttendanceMode.checkIn && hasCheckedIn) {
      final timeStr = DateFormat('hh:mm a').format(todayRecord.checkIn!);
      return AttendanceActionResult(
        success: false,
        action: AttendanceAction.alreadyCheckedIn,
        attendance: todayRecord,
        message: 'You are already checked in for today at $timeStr.\nIf you want to check out, please switch to Check-Out mode.',
      );
    } else if (selectedMode == SelectedAttendanceMode.checkOut && !hasCheckedIn) {
      return AttendanceActionResult(
        success: false,
        action: AttendanceAction.notCheckedInYet,
        message: 'You have not checked in yet today.\nPlease switch to Check-In mode to check in first.',
      );
    }

    // 3. Determine target action
    final AttendanceAction targetAction;
    if (selectedMode == SelectedAttendanceMode.checkIn) {
      targetAction = AttendanceAction.checkIn;
    } else if (selectedMode == SelectedAttendanceMode.checkOut) {
      targetAction = AttendanceAction.checkOut;
    } else {
      targetAction = !hasCheckedIn ? AttendanceAction.checkIn : AttendanceAction.checkOut;
    }

    // --- DUPLICATE PROTECTION CHECK ---
    if (todayRecord != null) {
      final lastActionTime = todayRecord.checkOut ?? todayRecord.checkIn;
      if (lastActionTime != null) {
        final secondsSinceLast = now.difference(lastActionTime).inSeconds;
        if (secondsSinceLast < FaceRecognitionConfig.duplicateProtectionSeconds) {
          final timeStr = DateFormat('hh:mm a').format(todayRecord.checkIn!);
          return AttendanceActionResult(
            success: false,
            action: hasCheckedIn ? AttendanceAction.alreadyCheckedIn : targetAction,
            attendance: todayRecord,
            message: todayRecord.checkOut != null
                ? 'Already Checked Out\nCheck-Out: ${DateFormat('hh:mm a').format(todayRecord.checkOut!)}'
                : 'You are already checked in for today at $timeStr.',
            isDuplicateProtection: true,
          );
        }
      }
    }

    final verificationId = 'VER_${_uuid.v4().substring(0, 8)}';
    final attendanceId = todayRecord?.id ?? 'ATT_${_uuid.v4().substring(0, 8)}';

    // Call live backend attendance verification API: POST /api/v1/attendance/verify-face
    try {
      final numericId = int.tryParse(staffId) ?? 0;
      final actionStr = targetAction == AttendanceAction.checkIn ? 'check_in' : 'check_out';
      final url = 'https://testapi.victoriabeautysalon.in/api/v1/attendance/verify-face';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final bodyPayload = jsonEncode({
        'staff_id': numericId,
        'action': actionStr,
      });

      ApiLogger.logRequest(method: 'POST', url: url, headers: headers, body: bodyPayload);

      final apiResponse = await http.post(
        Uri.parse(url),
        headers: headers,
        body: bodyPayload,
      );

      ApiLogger.logResponse(
        method: 'POST',
        url: url,
        statusCode: apiResponse.statusCode,
        responseBody: apiResponse.body,
      );
    } catch (e) {
      ApiLogger.logError(
        method: 'POST',
        url: 'https://testapi.victoriabeautysalon.in/api/v1/attendance/verify-face',
        error: e,
      );
    }

    try {
      AttendanceModel updatedRecord;
      if (targetAction == AttendanceAction.checkIn) {
        updatedRecord = AttendanceModel(
          id: attendanceId,
          staffId: staffId,
          dateKey: todayKey,
          date: now,
          checkIn: now,
          status: AttendanceStatus.checkedIn,
          checkInVerificationId: verificationId,
          checkInConfidence: confidence,
          createdAt: now,
          updatedAt: now,
        );
        _attendanceRecords.removeWhere((r) => r.staffId == staffId && r.dateKey == todayKey);
        _attendanceRecords.add(updatedRecord);
      } else {
        if (todayRecord == null) {
          throw Exception('No check-in record found for check-out');
        }
        updatedRecord = todayRecord.copyWith(
          checkOut: now,
          status: AttendanceStatus.checkedOut,
          checkOutVerificationId: verificationId,
          checkOutConfidence: confidence,
          updatedAt: now,
        );
        final idx = _attendanceRecords.indexWhere((r) => r.id == todayRecord.id);
        if (idx != -1) {
          _attendanceRecords[idx] = updatedRecord;
        } else {
          _attendanceRecords.add(updatedRecord);
        }
      }

      _verificationLogs.add(
        AttendanceVerificationModel(
          verificationId: verificationId,
          staffId: staffId,
          action: targetAction == AttendanceAction.checkIn ? 'check_in' : 'check_out',
          timestamp: now,
          success: true,
          confidence: confidence,
        ),
      );

      return AttendanceActionResult(
        success: true,
        action: targetAction,
        attendance: updatedRecord,
        message: targetAction == AttendanceAction.checkIn ? 'Check-In Successful' : 'Check-Out Successful',
      );
    } catch (e) {
      _verificationLogs.add(
        AttendanceVerificationModel(
          verificationId: verificationId,
          staffId: staffId,
          action: targetAction == AttendanceAction.checkIn ? 'check_in' : 'check_out',
          timestamp: now,
          success: false,
          failureReason: e.toString(),
        ),
      );

      return AttendanceActionResult(
        success: false,
        action: targetAction,
        message: 'Attendance processing failed. Please try again.',
      );
    }
  }

  /// Direct Backend Face Verification & Attendance Submission via POST /api/v1/attendance/verify-face
  Future<AttendanceActionResult> verifyFaceWithBackend({
    required List<double> faceEmbedding,
    List<List<double>>? faceTemplates,
    SelectedAttendanceMode selectedMode = SelectedAttendanceMode.auto,
  }) async {
    final now = DateTime.now();
    final actionStr = selectedMode == SelectedAttendanceMode.checkOut ? 'check_out' : 'check_in';
    final targetAction = selectedMode == SelectedAttendanceMode.checkOut ? AttendanceAction.checkOut : AttendanceAction.checkIn;

    final url = 'https://testapi.victoriabeautysalon.in/api/v1/attendance/verify-face';
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final List<List<double>> templatesList = (faceTemplates != null && faceTemplates.isNotEmpty)
        ? faceTemplates
        : [faceEmbedding];

    final String faceTemplateJson = jsonEncode(templatesList);

    final bodyPayload = jsonEncode({
      'face_template': faceTemplateJson,
      'action': actionStr,
    });

    ApiLogger.logRequest(method: 'POST', url: url, headers: headers, body: bodyPayload);

    try {
      final apiResponse = await http.post(
        Uri.parse(url),
        headers: headers,
        body: bodyPayload,
      );

      ApiLogger.logResponse(
        method: 'POST',
        url: url,
        statusCode: apiResponse.statusCode,
        responseBody: apiResponse.body,
      );

      final Map<String, dynamic> responseData = jsonDecode(apiResponse.body);
      final bool isSuccess = responseData['success'] == true;
      final String message = responseData['message']?.toString() ?? (isSuccess ? 'Success' : 'Verification Failed');

      String? errorsMessage;
      if (responseData['errors'] != null) {
        final errs = responseData['errors'];
        if (errs is String) {
          errorsMessage = errs;
        } else if (errs is List) {
          errorsMessage = errs.join('\n');
        } else if (errs is Map) {
          errorsMessage = errs.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
        } else {
          errorsMessage = errs.toString();
        }
      }

      StaffModel? matchedStaff;
      final dataMap = responseData['data'] is Map<String, dynamic> ? responseData['data'] as Map<String, dynamic> : null;
      if (dataMap != null) {
        final rawStaffId = dataMap['staff_id'] ?? dataMap['staffId'] ?? dataMap['id'];
        final staffName = dataMap['staff_name'] ?? dataMap['name'] ?? dataMap['staff']?['name'] ?? 'Staff Member';
        if (rawStaffId != null) {
          matchedStaff = StaffModel(
            id: rawStaffId.toString(),
            name: staffName.toString(),
            role: dataMap['role']?.toString() ?? 'Staff',
            isFaceRegistered: true,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }

      // If staff name is mentioned in error string e.g. "Staff SELVI has already checked in today at 06:35 PM"
      if (matchedStaff == null && errorsMessage != null && errorsMessage.contains('Staff ')) {
        final match = RegExp(r'Staff\s+([A-Za-z0-9_\s]+?)\s+has').firstMatch(errorsMessage);
        if (match != null && match.group(1) != null) {
          matchedStaff = StaffModel(
            id: 'backend_staff',
            name: match.group(1)!.trim(),
            role: 'Staff',
            isFaceRegistered: true,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }

      AttendanceAction action = targetAction;
      final msgLower = message.toLowerCase();
      final errLower = (errorsMessage ?? '').toLowerCase();

      if (msgLower.contains('already checked in') || errLower.contains('already checked in')) {
        action = AttendanceAction.alreadyCheckedIn;
      } else if (msgLower.contains('already checked out') || errLower.contains('already checked out') || msgLower.contains('already completed')) {
        action = AttendanceAction.alreadyCompleted;
      }

      final verificationId = 'VER_${_uuid.v4().substring(0, 8)}';
      final attendanceId = dataMap?['id']?.toString() ?? 'ATT_${_uuid.v4().substring(0, 8)}';

      AttendanceModel? updatedRecord;
      if (isSuccess && matchedStaff != null) {
        final dateKeyStr = getDateKey(now);
        updatedRecord = AttendanceModel(
          id: attendanceId,
          staffId: matchedStaff.id,
          dateKey: dateKeyStr,
          date: now,
          checkIn: targetAction == AttendanceAction.checkIn ? now : null,
          checkOut: targetAction == AttendanceAction.checkOut ? now : null,
          status: targetAction == AttendanceAction.checkIn ? AttendanceStatus.checkedIn : AttendanceStatus.checkedOut,
          checkInVerificationId: targetAction == AttendanceAction.checkIn ? verificationId : null,
          checkOutVerificationId: targetAction == AttendanceAction.checkOut ? verificationId : null,
          createdAt: now,
          updatedAt: now,
        );
        _attendanceRecords.removeWhere((r) => r.staffId == matchedStaff!.id && r.dateKey == dateKeyStr);
        _attendanceRecords.add(updatedRecord);
      }

      return AttendanceActionResult(
        success: isSuccess,
        action: action,
        attendance: updatedRecord,
        staff: matchedStaff,
        message: message,
        errors: errorsMessage,
      );
    } catch (e) {
      ApiLogger.logError(
        method: 'POST',
        url: url,
        error: e,
      );

      return AttendanceActionResult(
        success: false,
        action: targetAction,
        message: 'Backend Connection Error',
        errors: 'Failed to verify face with backend: ${e.toString()}',
      );
    }
  }

  Future<List<AttendanceModel>> getAllAttendance({String? staffId, String? dateKey}) async {
    return _attendanceRecords.where((r) {
      if (staffId != null && r.staffId != staffId) return false;
      if (dateKey != null && r.dateKey != dateKey) return false;
      return true;
    }).toList();
  }

  Future<List<AttendanceModel>> getAttendanceHistory() async {
    return getAllAttendance();
  }

  Future<void> clearAllAttendance() async {
    _attendanceRecords.clear();
    _verificationLogs.clear();
  }

  Future<bool> clearAttendanceHistory() async {
    await clearAllAttendance();
    return true;
  }

  /// Get summary of today's attendance for dashboard stats.
  Future<Map<String, int>> getTodayStats(int totalStaffCount) async {
    final todayKey = getDateKey(DateTime.now());
    final records = _attendanceRecords.where((r) => r.dateKey == todayKey).toList();

    int checkedIn = 0;
    int checkedOut = 0;

    for (var r in records) {
      if (r.checkOut != null) {
        checkedOut++;
      } else if (r.checkIn != null) {
        checkedIn++;
      }
    }

    final presentTotal = checkedIn + checkedOut;
    final notYetPresent = (totalStaffCount - presentTotal).clamp(0, totalStaffCount);
    final incomplete = checkedIn;

    return {
      'total': totalStaffCount,
      'checkedIn': checkedIn,
      'checkedOut': checkedOut,
      'notYetPresent': notYetPresent,
      'incomplete': incomplete,
    };
  }

  /// Fetch today's attendance summary and recent activities from live API:
  /// GET /api/v1/attendance/today-summary?date=YYYY-MM-DD&limit=10
  Future<Map<String, dynamic>?> fetchTodaySummaryApi({String? date, int limit = 10}) async {
    final dateStr = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final url = 'https://testapi.victoriabeautysalon.in/api/v1/attendance/today-summary?date=$dateStr&limit=$limit';
    final headers = {'Accept': 'application/json'};

    ApiLogger.logRequest(method: 'GET', url: url, headers: headers);

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      ApiLogger.logResponse(
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      ApiLogger.logError(method: 'GET', url: url, error: e);
    }
    return null;
  }

  /// Fetch attendance history from live API:
  /// GET /api/v1/attendance/history?filter={filter}&start_date={start_date}&end_date={end_date}&date={date}
  Future<List<AttendanceHistoryItemModel>> fetchAttendanceHistoryApi({
    required String filter,
    String? startDate,
    String? endDate,
    String? date,
  }) async {
    final queryParams = <String, String>{
      'filter': filter,
    };
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }
    if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }

    final uri = Uri.https(
      'testapi.victoriabeautysalon.in',
      '/api/v1/attendance/history',
      queryParams,
    );

    final headers = {'Accept': 'application/json'};

    ApiLogger.logRequest(method: 'GET', url: uri.toString(), headers: headers);

    try {
      final response = await http.get(uri, headers: headers);

      ApiLogger.logResponse(
        method: 'GET',
        url: uri.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null && body['data']['history'] is List) {
          final List list = body['data']['history'];
          return list
              .map((item) => AttendanceHistoryItemModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      ApiLogger.logError(method: 'GET', url: uri.toString(), error: e);
    }
    return [];
  }

  /// Fetch staff attendance summary for specific month and year via live API:
  /// GET /api/v1/attendance-summary/{staff_id}?month={month}&year={year}
  Future<StaffAttendanceSummaryResponse?> fetchStaffAttendanceSummaryApi({
    required dynamic staffId,
    required int month,
    required int year,
  }) async {
    final sIdStr = staffId.toString();
    final url = 'https://testapi.victoriabeautysalon.in/api/v1/attendance-summary/$sIdStr?month=$month&year=$year';
    final headers = {'Accept': 'application/json'};

    ApiLogger.logRequest(method: 'GET', url: url, headers: headers);

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      ApiLogger.logResponse(
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return StaffAttendanceSummaryResponse.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      ApiLogger.logError(method: 'GET', url: url, error: e);
    }
    return null;
  }
}



