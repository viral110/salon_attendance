class ApiEndpoints {
  /// Base API URL for the Victoria Beauty Salon API
  static const String baseUrl = 'https://testapi.victoriabeautysalon.in/api';

  // Staff endpoints
  static const String staff = '/staff';
  static const String staffFaceTemplates = '/v1/staff/face-templates';
  static const String staffFaceRegister = '/v1/staff/face-register';
  static String staffDeleteFace(String id) => '/v1/staff/delete-face/$id';

  // Attendance endpoints
  static const String attendanceVerifyFace = '/v1/attendance/verify-face';
  static const String attendanceTodaySummary = '/v1/attendance/today-summary';
  static const String attendanceHistory = '/v1/attendance/history';
  static String staffAttendanceSummary(String staffId) => '/v1/attendance-summary/$staffId';
}
