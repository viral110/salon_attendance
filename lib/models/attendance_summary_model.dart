class AttendanceSummaryModel {
  final int totalStaff;
  final int presentToday;
  final int absentToday;
  final int enrolledFaces;
  final DateTime date;
  final int checkedInCount;
  final int checkedOutCount;
  final int notYetPresentCount;

  const AttendanceSummaryModel({
    required this.totalStaff,
    required this.presentToday,
    required this.absentToday,
    required this.enrolledFaces,
    required this.date,
    int? checkedInCount,
    int? checkedOutCount,
    int? notYetPresentCount,
  })  : checkedInCount = checkedInCount ?? presentToday,
        checkedOutCount = checkedOutCount ?? 0,
        notYetPresentCount = notYetPresentCount ?? absentToday;

  factory AttendanceSummaryModel.fromApiSummary(Map<String, dynamic> summaryMap, {String? dateStr}) {
    final total = summaryMap['total_staff'] is num ? (summaryMap['total_staff'] as num).toInt() : 0;
    final checkedIn = summaryMap['checked_in'] is num ? (summaryMap['checked_in'] as num).toInt() : 0;
    final checkedOut = summaryMap['checked_out'] is num ? (summaryMap['checked_out'] as num).toInt() : 0;
    final notPresent = summaryMap['not_yet_present'] is num ? (summaryMap['not_yet_present'] as num).toInt() : 0;

    DateTime parsedDate = DateTime.now();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {}
    }

    return AttendanceSummaryModel(
      totalStaff: total,
      presentToday: checkedIn + checkedOut,
      absentToday: notPresent,
      enrolledFaces: 0,
      date: parsedDate,
      checkedInCount: checkedIn,
      checkedOutCount: checkedOut,
      notYetPresentCount: notPresent,
    );
  }

  factory AttendanceSummaryModel.fromMap(Map<String, dynamic> map) {
    final total = map['totalStaff'] as int? ?? 0;
    final present = map['presentToday'] as int? ?? 0;
    final absent = map['absentToday'] as int? ?? 0;
    return AttendanceSummaryModel(
      totalStaff: total,
      presentToday: present,
      absentToday: absent,
      enrolledFaces: map['enrolledFaces'] as int? ?? 0,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      checkedInCount: map['checkedInCount'] as int? ?? present,
      checkedOutCount: map['checkedOutCount'] as int? ?? 0,
      notYetPresentCount: map['notYetPresentCount'] as int? ?? absent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalStaff': totalStaff,
      'presentToday': presentToday,
      'absentToday': absentToday,
      'enrolledFaces': enrolledFaces,
      'date': date.toIso8601String(),
      'checkedInCount': checkedInCount,
      'checkedOutCount': checkedOutCount,
      'notYetPresentCount': notYetPresentCount,
    };
  }
}

class RecentActivityModel {
  final int attendanceId;
  final int staffId;
  final String staffName;
  final String? nickname;
  final String? profilePicture;
  final String actionPerformed;
  final String time;
  final String? timeAgo;
  final String? checkIn;
  final String? checkOut;
  final String? totalHours;
  final String status;

  RecentActivityModel({
    required this.attendanceId,
    required this.staffId,
    required this.staffName,
    this.nickname,
    this.profilePicture,
    required this.actionPerformed,
    required this.time,
    this.timeAgo,
    this.checkIn,
    this.checkOut,
    this.totalHours,
    required this.status,
  });

  factory RecentActivityModel.fromJson(Map<String, dynamic> json) {
    return RecentActivityModel(
      attendanceId: json['attendance_id'] is num
          ? (json['attendance_id'] as num).toInt()
          : int.tryParse(json['attendance_id']?.toString() ?? '') ?? 0,
      staffId: json['staff_id'] is num
          ? (json['staff_id'] as num).toInt()
          : int.tryParse(json['staff_id']?.toString() ?? '') ?? 0,
      staffName: json['staff_name']?.toString() ?? 'Staff',
      nickname: json['nickname']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      actionPerformed: json['action_performed']?.toString() ?? 'check_in',
      time: json['time']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString(),
      checkIn: json['check_in']?.toString(),
      checkOut: json['check_out']?.toString(),
      totalHours: json['total_hours']?.toString(),
      status: json['status']?.toString() ?? 'present',
    );
  }
}

class AttendanceHistoryItemModel {
  final int attendanceId;
  final int staffId;
  final String staffName;
  final String? nickname;
  final String? profilePicture;
  final String dateStr;
  final String formattedDate;
  final String badgeStatus;
  final String badgeLabel;
  final String checkIn;
  final String checkOut;
  final String duration;
  final String status;

  AttendanceHistoryItemModel({
    required this.attendanceId,
    required this.staffId,
    required this.staffName,
    this.nickname,
    this.profilePicture,
    required this.dateStr,
    required this.formattedDate,
    required this.badgeStatus,
    required this.badgeLabel,
    required this.checkIn,
    required this.checkOut,
    required this.duration,
    required this.status,
  });

  factory AttendanceHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final statusBadge = json['status_badge'] is Map<String, dynamic>
        ? json['status_badge'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AttendanceHistoryItemModel(
      attendanceId: json['attendance_id'] is num
          ? (json['attendance_id'] as num).toInt()
          : int.tryParse(json['attendance_id']?.toString() ?? '') ?? 0,
      staffId: json['staff_id'] is num
          ? (json['staff_id'] as num).toInt()
          : int.tryParse(json['staff_id']?.toString() ?? '') ?? 0,
      staffName: json['staff_name']?.toString() ?? 'Staff',
      nickname: json['nickname']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      dateStr: json['date']?.toString() ?? '',
      formattedDate: json['formatted_date']?.toString() ?? '',
      badgeStatus: statusBadge['status']?.toString() ?? json['status']?.toString() ?? 'checked_in',
      badgeLabel: statusBadge['label']?.toString() ?? 'Checked In',
      checkIn: json['check_in']?.toString() ?? '--',
      checkOut: json['check_out']?.toString() ?? '--',
      duration: json['duration']?.toString() ?? '--',
      status: json['status']?.toString() ?? 'present',
    );
  }
}

class StaffAttendanceSummaryResponse {
  final int staffId;
  final String staffName;
  final String? nickname;
  final String? profilePicture;
  final int month;
  final int year;
  final String totalPresent;
  final int totalPresentDays;
  final String totalHours;
  final String avgWorkingHours;
  final int lateCheckIns;
  final List<StaffDailyRecordModel> dailyRecords;

  StaffAttendanceSummaryResponse({
    required this.staffId,
    required this.staffName,
    this.nickname,
    this.profilePicture,
    required this.month,
    required this.year,
    required this.totalPresent,
    required this.totalPresentDays,
    required this.totalHours,
    required this.avgWorkingHours,
    required this.lateCheckIns,
    required this.dailyRecords,
  });

  factory StaffAttendanceSummaryResponse.fromJson(Map<String, dynamic> json) {
    final filter = json['filter'] is Map<String, dynamic> ? json['filter'] as Map<String, dynamic> : <String, dynamic>{};
    final summary = json['summary'] is Map<String, dynamic> ? json['summary'] as Map<String, dynamic> : <String, dynamic>{};

    List<StaffDailyRecordModel> records = [];
    if (json['daily_records'] is List) {
      records = (json['daily_records'] as List)
          .map((r) => StaffDailyRecordModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return StaffAttendanceSummaryResponse(
      staffId: json['staff_id'] is num ? (json['staff_id'] as num).toInt() : int.tryParse(json['staff_id']?.toString() ?? '') ?? 0,
      staffName: json['staff_name']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      month: filter['month'] is num ? (filter['month'] as num).toInt() : DateTime.now().month,
      year: filter['year'] is num ? (filter['year'] as num).toInt() : DateTime.now().year,
      totalPresent: summary['total_present']?.toString() ?? '0 Days',
      totalPresentDays: summary['total_present_days'] is num ? (summary['total_present_days'] as num).toInt() : 0,
      totalHours: summary['total_hours']?.toString() ?? '0 hrs',
      avgWorkingHours: summary['avg_working_hours']?.toString() ?? '0 hrs',
      lateCheckIns: summary['late_check_ins'] is num ? (summary['late_check_ins'] as num).toInt() : 0,
      dailyRecords: records,
    );
  }
}

class StaffDailyRecordModel {
  final int attendanceId;
  final String date;
  final String day;
  final String? checkIn;
  final String? checkOut;
  final String? totalHours;
  final double minutesWorked;
  final String? expectedStartTime;
  final bool isLate;
  final String status;

  StaffDailyRecordModel({
    required this.attendanceId,
    required this.date,
    required this.day,
    this.checkIn,
    this.checkOut,
    this.totalHours,
    required this.minutesWorked,
    this.expectedStartTime,
    required this.isLate,
    required this.status,
  });

  factory StaffDailyRecordModel.fromJson(Map<String, dynamic> json) {
    return StaffDailyRecordModel(
      attendanceId: json['attendance_id'] is num ? (json['attendance_id'] as num).toInt() : int.tryParse(json['attendance_id']?.toString() ?? '') ?? 0,
      date: json['date']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      checkIn: json['check_in']?.toString(),
      checkOut: json['check_out']?.toString(),
      totalHours: json['total_hours']?.toString(),
      minutesWorked: json['minutes_worked'] is num ? (json['minutes_worked'] as num).toDouble() : 0.0,
      expectedStartTime: json['expected_start_time']?.toString(),
      isLate: json['is_late'] == true || json['is_late'] == 1,
      status: json['status']?.toString() ?? 'present',
    );
  }
}




