import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import '../models/attendance_model.dart';
import '../models/attendance_summary_model.dart';
import '../../staff/models/staff_model.dart';
import '../../../services/attendance_service.dart';
import '../../../services/staff_service.dart';

enum DateFilterMode {
  today,
  thisWeek,
  thisMonth,
  allTime,
  custom,
}

class AttendanceHistoryController extends GetxController {
  final AttendanceService _attendanceService = AttendanceService();
  final StaffService _staffService = StaffService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DateFilterMode _dateFilter = DateFilterMode.today;
  DateFilterMode get dateFilter => _dateFilter;

  DateTimeRange? _customDateRange;
  DateTimeRange? get customDateRange => _customDateRange;

  DateTime? _customSingleDate;
  DateTime? get customSingleDate => _customSingleDate;

  List<AttendanceModel> _allRecords = [];
  Map<String, StaffModel> _staffMap = {};
  Map<String, StaffModel> get staffMap => _staffMap;

  AttendanceSummaryModel? _apiSummary;
  List<RecentActivityModel> _recentActivities = [];
  List<RecentActivityModel> get recentActivities => _recentActivities;

  List<AttendanceHistoryItemModel> _historyItems = [];
  List<AttendanceHistoryItemModel> get historyItems => _historyItems;

  String get filterApiString {
    switch (_dateFilter) {
      case DateFilterMode.today:
        return 'today';
      case DateFilterMode.thisWeek:
        return 'this_week';
      case DateFilterMode.thisMonth:
        return 'this_month';
      case DateFilterMode.allTime:
        return 'all_time';
      case DateFilterMode.custom:
        return 'custom';
    }
  }

  List<AttendanceModel> get records {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    List<AttendanceModel> filtered;
    switch (_dateFilter) {
      case DateFilterMode.today:
        filtered = _allRecords.where((r) => r.date.isAfter(todayStart.subtract(const Duration(milliseconds: 1)))).toList();
        break;
      case DateFilterMode.thisWeek:
        final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        filtered = _allRecords.where((r) => r.date.isAfter(weekStart.subtract(const Duration(milliseconds: 1)))).toList();
        break;
      case DateFilterMode.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        filtered = _allRecords.where((r) => r.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1)))).toList();
        break;
      case DateFilterMode.allTime:
      case DateFilterMode.custom:
        filtered = List.from(_allRecords);
        break;
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  /// Returns attendance records for today (calendar day)
  List<AttendanceModel> get todayRecords {
    final now = DateTime.now();
    return _allRecords.where((r) {
      return r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day;
    }).toList();
  }

  /// Returns total count of check-ins today
  int get todayCheckedInCount {
    return todayRecords.where((r) => r.checkIn != null).length;
  }

  /// Returns total count of check-outs today
  int get todayCheckedOutCount {
    return todayRecords.where((r) => r.checkOut != null).length;
  }

  /// Returns overall summary model for dashboard stats
  AttendanceSummaryModel get summaryModel {
    if (_apiSummary != null) {
      return _apiSummary!;
    }

    final totalStaff = _staffMap.isNotEmpty ? _staffMap.values.toSet().length : 0;
    final checkedIn = todayCheckedInCount;
    final checkedOut = todayCheckedOutCount;
    final notPresent = (totalStaff - (checkedIn + checkedOut)).clamp(0, 9999);

    return AttendanceSummaryModel(
      totalStaff: totalStaff,
      presentToday: checkedIn + checkedOut,
      absentToday: notPresent,
      enrolledFaces: 0,
      date: DateTime.now(),
      checkedInCount: checkedIn,
      checkedOutCount: checkedOut,
      notYetPresentCount: notPresent,
    );
  }

  /// Returns summary statistics map for a specific staff member
  Map<String, dynamic> getSummaryStatsForStaff(String staffId) {
    final staffItems = _historyItems.where((h) => h.staffId.toString() == staffId || h.staffName.toLowerCase() == staffId.toLowerCase()).toList();
    final totalPresent = staffItems.where((h) => h.checkIn != '--' && h.checkIn.isNotEmpty).length;

    double totalMinutes = 0;
    int countWithDuration = 0;

    for (var item in staffItems) {
      if (item.duration != '--' && item.duration.isNotEmpty) {
        final match = RegExp(r'(\d+)h\s*(\d+)m').firstMatch(item.duration);
        if (match != null) {
          final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
          final mins = int.tryParse(match.group(2) ?? '0') ?? 0;
          totalMinutes += (hours * 60 + mins);
          countWithDuration++;
        }
      }
    }

    final totalHoursNum = totalMinutes / 60.0;
    final avgHoursNum = countWithDuration > 0 ? (totalMinutes / countWithDuration) / 60.0 : 0.0;

    return {
      'totalPresent': totalPresent,
      'totalWorkingHours': totalHoursNum.toStringAsFixed(1),
      'averageWorkingHours': avgHoursNum.toStringAsFixed(1),
      'lateCheckIns': 0,
    };
  }

  @override
  void onInit() {
    super.onInit();
    loadAttendanceData();
  }

  void setDateFilter(
    DateFilterMode mode, {
    DateTimeRange? customRange,
    DateTime? singleDate,
  }) {
    _dateFilter = mode;
    if (mode == DateFilterMode.custom) {
      _customDateRange = customRange;
      _customSingleDate = singleDate;
    } else {
      _customDateRange = null;
      _customSingleDate = null;
    }
    loadAttendanceData();
  }

  Future<void> loadAttendanceData() async {
    _isLoading = true;
    update();

    try {
      final staffList = await _staffService.getAllStaff();
      _staffMap = {for (var s in staffList) s.id: s};
      if (staffList.isNotEmpty) {
        _staffMap.addAll({for (var s in staffList) s.dbId.toString(): s});
      }

      // Fetch live today-summary API
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final summaryData = await _attendanceService.fetchTodaySummaryApi(date: todayStr, limit: 10);
      if (summaryData != null) {
        if (summaryData['summary'] is Map<String, dynamic>) {
          _apiSummary = AttendanceSummaryModel.fromApiSummary(
            summaryData['summary'] as Map<String, dynamic>,
            dateStr: summaryData['date']?.toString(),
          );
        }

        if (summaryData['recent_activities'] is List) {
          _recentActivities = (summaryData['recent_activities'] as List)
              .map((item) => RecentActivityModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      // Prepare custom date parameters
      String? startDateStr;
      String? endDateStr;
      String? singleDateStr;

      if (_dateFilter == DateFilterMode.custom) {
        if (_customDateRange != null) {
          startDateStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
          endDateStr = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
        } else if (_customSingleDate != null) {
          singleDateStr = DateFormat('yyyy-MM-dd').format(_customSingleDate!);
        }
      }

      // Fetch live history from API GET /api/v1/attendance/history
      _historyItems = await _attendanceService.fetchAttendanceHistoryApi(
        filter: filterApiString,
        startDate: startDateStr,
        endDate: endDateStr,
        date: singleDateStr,
      );

      _allRecords = await _attendanceService.getAttendanceHistory();
    } catch (e) {
      _historyItems = [];
      _allRecords = [];
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<bool> clearAttendanceHistory() async {
    _isLoading = true;
    update();

    try {
      final success = await _attendanceService.clearAttendanceHistory();
      if (success) {
        _allRecords = [];
        _historyItems = [];
        _recentActivities = [];
        _apiSummary = null;
      }
      return success;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }
}



