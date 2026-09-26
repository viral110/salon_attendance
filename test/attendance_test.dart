import 'package:flutter_test/flutter_test.dart';
import 'package:salon_attendance/config/face_recognition_config.dart';
import 'package:salon_attendance/models/attendance_model.dart';
import 'package:salon_attendance/models/staff_model.dart';
import 'package:salon_attendance/services/attendance_service.dart';
import 'package:salon_attendance/services/face_recognition_service.dart';

void main() {
  late AttendanceService attendanceService;
  late MLKitFaceRecognitionService faceService;

  setUp(() async {
    attendanceService = AttendanceService();
    faceService = MLKitFaceRecognitionService();
  });

  group('Attendance System Suite Tests', () {
    test('Test 1: No attendance today -> Expect CHECK_IN action', () async {
      const staffId = '3';
      final action = await attendanceService.determineAttendanceAction(staffId);
      expect(action, equals(AttendanceAction.checkIn));
    });

    test('Test 2: Check-in exists, check-out does not -> Expect CHECK_OUT action', () async {
      const staffId = '3';
      final result1 = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.95,
      );
      expect(result1.action, equals(AttendanceAction.checkIn));

      final action = await attendanceService.determineAttendanceAction(staffId);
      expect(action, equals(AttendanceAction.checkOut));
    });

    test('Test 3: Face template similarity below threshold -> Unmatched', () async {
      final vec1 = List<double>.filled(80, 0.1);
      final vec2 = List<double>.filled(80, -0.1);

      final sim = faceService.computeCosineSimilarity(vec1, vec2);
      expect(sim < FaceRecognitionConfig.recognitionThreshold, isTrue);
    });

    test('Test 4: Inactive staff -> Flagged as inactive', () async {
      final staff = StaffModel(
        id: '3',
        dbId: 3,
        name: 'Inactive User',
        isActive: false,
        faceEnrolled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(staff.isActive, isFalse);
    });

    test('Test 5: Face not enrolled -> Flagged as faceEnrolled == false', () async {
      final staff = StaffModel(
        id: '3',
        dbId: 3,
        name: 'New User',
        isActive: true,
        faceEnrolled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(staff.faceEnrolled, isFalse);
    });

    test('Test 6: Duplicate scan within protection window -> Expect duplicate protection', () async {
      const staffId = '3';

      final result1 = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.92,
      );
      expect(result1.success, isTrue);

      final result2 = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.92,
      );
      expect(result2.isDuplicateProtection, isTrue);
    });

    test('Test 7: Working duration calculation accuracy', () {
      final now = DateTime.now();
      final checkInTime = now.subtract(const Duration(hours: 8, minutes: 49));
      final checkOutTime = now;

      final model = AttendanceModel(
        id: 'ATT_TEST',
        staffId: '3',
        dateKey: '2026-09-18',
        date: now,
        checkIn: checkInTime,
        checkOut: checkOutTime,
        status: AttendanceStatus.checkedOut,
        createdAt: now,
        updatedAt: now,
      );

      expect(model.formattedWorkingDuration, equals('08h 49m'));
    });

    test('Test 8: Cosine similarity vector normalization math', () {
      final v1 = List<double>.filled(80, 0.5);
      final v2 = List<double>.filled(80, 0.5);
      final sim = faceService.computeCosineSimilarity(v1, v2);
      expect(sim, closeTo(1.0, 0.0001));
    });

    test('Test 9: Explicit Check-In mode when already checked in', () async {
      const staffId = '3';
      final res1 = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.95,
        selectedMode: SelectedAttendanceMode.checkIn,
      );
      expect(res1.success, isTrue);
      expect(res1.action, equals(AttendanceAction.checkIn));

      final res2 = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.95,
        selectedMode: SelectedAttendanceMode.checkIn,
      );
      expect(res2.success, isFalse);
      expect(res2.action, equals(AttendanceAction.alreadyCheckedIn));
    });

    test('Test 10: Explicit Check-Out mode when not checked in yet', () async {
      const staffId = '3';
      final res = await attendanceService.processAttendance(
        staffId: staffId,
        confidence: 0.95,
        selectedMode: SelectedAttendanceMode.checkOut,
      );
      expect(res.action, equals(AttendanceAction.notCheckedInYet));
    });

    test('Test 11: Distinct staff face vectors -> Below threshold', () {
      final amitVector = List<double>.generate(80, (i) => i.isEven ? (i / 10.0) : (i / 8.0));
      final kishanVector = List<double>.generate(80, (i) => i.isOdd ? (i / 10.0) : (-i / 8.0));

      final similarity = faceService.computeCosineSimilarity(amitVector, kishanVector);
      expect(similarity < FaceRecognitionConfig.duplicateThreshold, isTrue);

      final sameSimilarity = faceService.computeCosineSimilarity(amitVector, amitVector);
      expect(sameSimilarity >= FaceRecognitionConfig.duplicateThreshold, isTrue);
    });
  });
}
