import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';
import '../modules/attendance/models/attendance_model.dart';
import '../modules/attendance/models/attendance_verification_model.dart';
import '../modules/staff/models/staff_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'salon_attendance.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Staff Table
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        role TEXT NOT NULL DEFAULT 'Staff',
        isActive INTEGER NOT NULL DEFAULT 1,
        faceEnrolled INTEGER NOT NULL DEFAULT 0,
        faceTemplateId TEXT,
        faceEmbedding TEXT,
        faceEnrolledAt TEXT,
        faceUpdatedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Attendance Table with unique index on staffId + dateKey to prevent duplicate records
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        staffId TEXT NOT NULL,
        dateKey TEXT NOT NULL,
        date TEXT NOT NULL,
        checkIn TEXT,
        checkOut TEXT,
        status TEXT NOT NULL,
        checkInVerificationId TEXT,
        checkOutVerificationId TEXT,
        checkInConfidence REAL,
        checkOutConfidence REAL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (staffId) REFERENCES staff (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_attendance_staff_date 
      ON attendance (staffId, dateKey)
    ''');

    // Attendance Verifications Audit Table
    await db.execute('''
      CREATE TABLE attendance_verifications (
        verificationId TEXT PRIMARY KEY,
        staffId TEXT,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        success INTEGER NOT NULL,
        confidence REAL,
        deviceId TEXT,
        failureReason TEXT
      )
    ''');
  }

  // --- STAFF DB METHODS ---

  Future<void> insertStaff(StaffModel staff) async {
    final db = await database;
    await db.insert('staff', staff.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStaff(StaffModel staff) async {
    final db = await database;
    await db.update(
      'staff',
      staff.toMap(),
      where: 'id = ?',
      whereArgs: [staff.id],
    );
  }

  Future<StaffModel?> getStaffById(String id) async {
    final db = await database;
    final maps = await db.query(
      'staff',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return StaffModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<StaffModel>> getAllStaff() async {
    final db = await database;
    final maps = await db.query('staff', orderBy: 'name ASC');
    return maps.map((m) => StaffModel.fromMap(m)).toList();
  }

  Future<List<StaffModel>> getEnrolledStaff() async {
    final db = await database;
    final maps = await db.query(
      'staff',
      where: 'isActive = 1 AND faceEnrolled = 1',
    );
    return maps.map((m) => StaffModel.fromMap(m)).toList();
  }

  Future<void> deleteStaff(String id) async {
    final db = await database;
    await db.delete('staff', where: 'id = ?', whereArgs: [id]);
  }

  // --- ATTENDANCE DB METHODS ---

  Future<AttendanceModel?> getAttendanceByStaffAndDateKey(String staffId, String dateKey) async {
    final db = await database;
    final maps = await db.query(
      'attendance',
      where: 'staffId = ? AND dateKey = ?',
      whereArgs: [staffId, dateKey],
    );
    if (maps.isNotEmpty) {
      return AttendanceModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<AttendanceModel>> getAttendanceByDateKey(String dateKey) async {
    final db = await database;
    final maps = await db.query(
      'attendance',
      where: 'dateKey = ?',
      whereArgs: [dateKey],
    );
    return maps.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  Future<List<AttendanceModel>> getAllAttendance({String? staffId, String? dateKey}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (staffId != null && dateKey != null) {
      where = 'staffId = ? AND dateKey = ?';
      whereArgs = [staffId, dateKey];
    } else if (staffId != null) {
      where = 'staffId = ?';
      whereArgs = [staffId];
    } else if (dateKey != null) {
      where = 'dateKey = ?';
      whereArgs = [dateKey];
    }

    final maps = await db.query(
      'attendance',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC, checkIn DESC',
    );
    return maps.map((m) => AttendanceModel.fromMap(m)).toList();
  }

  /// Clears all attendance records and audit logs
  Future<void> clearAllAttendance() async {
    final db = await database;
    await db.delete('attendance');
    await db.delete('attendance_verifications');
  }

  /// Atomic execution for Check-In or Check-Out
  Future<AttendanceModel> executeAttendanceTransaction({
    required String attendanceId,
    required String staffId,
    required String dateKey,
    required DateTime now,
    required String verificationId,
    required double confidence,
    required String targetAction, // 'checkIn' or 'checkOut'
  }) async {
    final db = await database;
    return await db.transaction<AttendanceModel>((txn) async {
      final existingMaps = await txn.query(
        'attendance',
        where: 'staffId = ? AND dateKey = ?',
        whereArgs: [staffId, dateKey],
      );

      if (targetAction == 'checkIn') {
        if (existingMaps.isNotEmpty) {
          final existing = AttendanceModel.fromMap(existingMaps.first);
          if (existing.checkIn != null) {
            return existing; // Already checked in
          }
        }

        final newRecord = AttendanceModel(
          id: attendanceId,
          staffId: staffId,
          dateKey: dateKey,
          date: now,
          checkIn: now,
          status: AttendanceStatus.checkedIn,
          checkInVerificationId: verificationId,
          checkInConfidence: confidence,
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert('attendance', newRecord.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        return newRecord;
      } else {
        // targetAction == 'checkOut'
        if (existingMaps.isEmpty) {
          throw Exception('No check-in record found for check-out');
        }

        final existing = AttendanceModel.fromMap(existingMaps.first);
        final updatedRecord = existing.copyWith(
          checkOut: now,
          status: AttendanceStatus.checkedOut,
          checkOutVerificationId: verificationId,
          checkOutConfidence: confidence,
          updatedAt: now,
        );

        await txn.update(
          'attendance',
          updatedRecord.toMap(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );

        return updatedRecord;
      }
    });
  }

  // --- VERIFICATION AUDIT LOGS ---

  Future<void> logVerification(AttendanceVerificationModel log) async {
    final db = await database;
    await db.insert('attendance_verifications', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
