import 'dart:convert';

/// Represents a staff member fetched from the live API (/api/staff).
class StaffModel {
  final String id; // String representation of database ID or staff_id
  final int dbId; // Integer primary key from backend
  final String name;
  final String? nickname;
  final String? email;
  final String? phone;
  final String? phone1;
  final String? phone2;
  final String role;
  final String? profilePicture;
  final bool isActive;
  final bool isFaceRegistered;
  final DateTime? faceRegisteredAt;
  final dynamic rawFaceTemplate; // Can be String, List<num>, or List<List<num>>
  final List<double>? faceEmbedding;
  final List<List<double>>? faceTemplates;
  final String? idProofFront;
  final String? idProofBack;
  final String? aadharCardNumber;
  final String? staffIdCode;
  final String? lockerNumber;
  final String? dob;
  final String? gender;
  final String? address;
  final String? dateOfJoining;
  final String? weeklyOffDay;
  final String? experience;
  final String? commissionType;
  final List<StaffServiceItem> services;
  final List<StaffWorkingHour> workingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffModel({
    required this.id,
    this.dbId = 0,
    required this.name,
    this.nickname,
    this.email,
    this.phone,
    this.phone1,
    this.phone2,
    this.role = 'Staff',
    this.profilePicture,
    this.isActive = true,
    bool? isFaceRegistered,
    bool? faceEnrolled,
    this.faceRegisteredAt,
    this.rawFaceTemplate,
    this.faceEmbedding,
    this.faceTemplates,
    this.idProofFront,
    this.idProofBack,
    this.aadharCardNumber,
    this.staffIdCode,
    this.lockerNumber,
    this.dob,
    this.gender,
    this.address,
    this.dateOfJoining,
    this.weeklyOffDay,
    this.experience,
    this.commissionType,
    this.services = const [],
    this.workingHours = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : isFaceRegistered = isFaceRegistered ?? faceEnrolled ?? false;

  /// Alias getter for faceEnrolled for backward compatibility
  bool get faceEnrolled =>
      isFaceRegistered ||
      (faceEmbedding != null && faceEmbedding!.isNotEmpty) ||
      (faceTemplates != null && faceTemplates!.isNotEmpty);
  String? get faceTemplateId => faceEnrolled ? 'TMP_$id' : null;
  DateTime? get faceEnrolledAt => faceRegisteredAt;
  DateTime? get faceUpdatedAt => updatedAt;

  StaffModel copyWith({
    String? id,
    int? dbId,
    String? name,
    String? nickname,
    String? email,
    String? phone,
    String? phone1,
    String? phone2,
    String? role,
    String? profilePicture,
    bool? isActive,
    bool? isFaceRegistered,
    bool? faceEnrolled,
    DateTime? faceRegisteredAt,
    dynamic rawFaceTemplate,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    String? idProofFront,
    String? idProofBack,
    String? aadharCardNumber,
    String? staffIdCode,
    String? lockerNumber,
    String? dob,
    String? gender,
    String? address,
    String? dateOfJoining,
    String? weeklyOffDay,
    String? experience,
    String? commissionType,
    List<StaffServiceItem>? services,
    List<StaffWorkingHour>? workingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      dbId: dbId ?? this.dbId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      isActive: isActive ?? this.isActive,
      isFaceRegistered: isFaceRegistered ?? faceEnrolled ?? this.isFaceRegistered,
      faceRegisteredAt: faceRegisteredAt ?? this.faceRegisteredAt,
      rawFaceTemplate: rawFaceTemplate ?? this.rawFaceTemplate,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      faceTemplates: faceTemplates ?? this.faceTemplates,
      idProofFront: idProofFront ?? this.idProofFront,
      idProofBack: idProofBack ?? this.idProofBack,
      aadharCardNumber: aadharCardNumber ?? this.aadharCardNumber,
      staffIdCode: staffIdCode ?? this.staffIdCode,
      lockerNumber: lockerNumber ?? this.lockerNumber,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      weeklyOffDay: weeklyOffDay ?? this.weeklyOffDay,
      experience: experience ?? this.experience,
      commissionType: commissionType ?? this.commissionType,
      services: services ?? this.services,
      workingHours: workingHours ?? this.workingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Factory constructor to parse Staff object from live API (/api/staff)
  factory StaffModel.fromApiJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final dbIdVal = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final staffIdStr = dbIdVal.toString();

    // Helper for boolean parsing
    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is num) return val == 1;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return defaultVal;
    }

    final p1 = json['phone_1'] as String?;
    final p2 = json['phone_2'] as String?;
    final phoneNum = (p1 != null && p1.isNotEmpty) ? p1 : (p2 ?? json['phone'] as String?);

    // Extract face embedding & templates if present
    List<double>? primaryEmbedding;
    List<List<double>>? templates;
    final faceTpl = json['face_template'];

    if (faceTpl != null) {
      try {
        dynamic decoded = faceTpl;
        if (faceTpl is String && faceTpl.trim().isNotEmpty) {
          decoded = jsonDecode(faceTpl);
        }
        if (decoded is List && decoded.isNotEmpty) {
          if (decoded.first is List) {
            templates = decoded
                .map((t) => (t as List).map((e) => (e as num).toDouble()).toList())
                .toList();
            primaryEmbedding = templates.first;
          } else {
            primaryEmbedding = decoded.map((e) => (e as num).toDouble()).toList();
            templates = [primaryEmbedding];
          }
        }
      } catch (_) {}
    }

    // Role handling
    String parsedRole = 'Staff';
    if (json['role'] != null) {
      if (json['role'] is Map && json['role']['name'] != null) {
        parsedRole = json['role']['name'].toString();
      } else if (json['role'] is String && (json['role'] as String).isNotEmpty) {
        parsedRole = json['role'] as String;
      }
    }

    // Services parsing
    List<StaffServiceItem> parsedServices = [];
    if (json['services'] is List) {
      parsedServices = (json['services'] as List)
          .map((s) => StaffServiceItem.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    // Working hours parsing
    List<StaffWorkingHour> parsedWorkingHours = [];
    if (json['working_hours'] is List) {
      parsedWorkingHours = (json['working_hours'] as List)
          .map((w) => StaffWorkingHour.fromJson(w as Map<String, dynamic>))
          .toList();
    }

    DateTime parsedCreated = DateTime.now();
    if (json['created_at'] != null) {
      try {
        parsedCreated = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    DateTime parsedUpdated = DateTime.now();
    if (json['updated_at'] != null) {
      try {
        parsedUpdated = DateTime.parse(json['updated_at'].toString());
      } catch (_) {}
    }

    DateTime? parsedFaceRegAt;
    if (json['face_registered_at'] != null) {
      try {
        parsedFaceRegAt = DateTime.parse(json['face_registered_at'].toString());
      } catch (_) {}
    }

    final isReg = parseBool(
      json['is_face_registered'],
      (primaryEmbedding != null && primaryEmbedding.isNotEmpty) ||
          (json['face_template'] != null &&
              json['face_template'].toString().trim().isNotEmpty &&
              json['face_template'].toString().trim() != 'null'),
    );

    return StaffModel(
      id: staffIdStr,
      dbId: dbIdVal,
      name: (json['name'] as String?) ?? 'Staff #$dbIdVal',
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
      phone: phoneNum,
      phone1: p1,
      phone2: p2,
      role: parsedRole,
      profilePicture: json['profile_picture'] as String?,
      isActive: parseBool(json['is_active'], true),
      isFaceRegistered: isReg,
      faceRegisteredAt: parsedFaceRegAt,
      rawFaceTemplate: faceTpl,
      faceEmbedding: primaryEmbedding,
      faceTemplates: templates,
      idProofFront: json['id_proof_front'] as String?,
      idProofBack: json['id_proof_back'] as String?,
      aadharCardNumber: json['aadhar_card_number'] as String?,
      staffIdCode: json['staff_id']?.toString(),
      lockerNumber: json['locker_number'] as String?,
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      dateOfJoining: json['date_of_joining'] as String?,
      weeklyOffDay: json['weekly_off_day'] as String?,
      experience: json['experience'] as String?,
      commissionType: json['commission_type'] as String?,
      services: parsedServices,
      workingHours: parsedWorkingHours,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  /// Legacy local map conversion for backward compatibility
  Map<String, dynamic> toMap() {
    dynamic encodedData;
    if (faceTemplates != null && faceTemplates!.isNotEmpty) {
      encodedData = jsonEncode(faceTemplates);
    } else if (faceEmbedding != null) {
      encodedData = jsonEncode(faceEmbedding);
    }

    return {
      'id': id,
      'dbId': dbId,
      'name': name,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'role': role,
      'profile_picture': profilePicture,
      'isActive': isActive ? 1 : 0,
      'faceEnrolled': isFaceRegistered ? 1 : 0,
      'faceTemplateId': faceTemplateId,
      'faceEmbedding': encodedData,
      'faceEnrolledAt': faceRegisteredAt?.toIso8601String(),
      'faceUpdatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel.fromApiJson(map);
  }
}

/// Service Item assigned to staff member
class StaffServiceItem {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final String price;
  final String? serviceTime;
  final String? processingTime;
  final bool isVisibleOnline;
  final bool status;
  final bool staffPricingModule;
  final int? position;
  final StaffServicePivot? pivot;

  StaffServiceItem({
    required this.id,
    required this.name,
    this.description,
    this.image,
    required this.price,
    this.serviceTime,
    this.processingTime,
    this.isVisibleOnline = true,
    this.status = true,
    this.staffPricingModule = false,
    this.position,
    this.pivot,
  });

  factory StaffServiceItem.fromJson(Map<String, dynamic> json) {
    return StaffServiceItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      image: json['image'] as String?,
      price: json['price']?.toString() ?? '0.00',
      serviceTime: json['service_time'] as String?,
      processingTime: json['processing_time'] as String?,
      isVisibleOnline: json['is_visible_online'] == true || json['is_visible_online'] == 1,
      status: json['status'] == true || json['status'] == 1,
      staffPricingModule: json['staff_pricing_module'] == true || json['staff_pricing_module'] == 1,
      position: json['position'] is num ? (json['position'] as num).toInt() : null,
      pivot: json['pivot'] is Map<String, dynamic> ? StaffServicePivot.fromJson(json['pivot']) : null,
    );
  }
}

/// Pivot details for Staff <-> Service relationship
class StaffServicePivot {
  final int staffId;
  final int serviceId;
  final String? price;

  StaffServicePivot({
    required this.staffId,
    required this.serviceId,
    this.price,
  });

  factory StaffServicePivot.fromJson(Map<String, dynamic> json) {
    return StaffServicePivot(
      staffId: json['staff_id'] is num ? (json['staff_id'] as num).toInt() : int.tryParse(json['staff_id'].toString()) ?? 0,
      serviceId: json['service_id'] is num ? (json['service_id'] as num).toInt() : int.tryParse(json['service_id'].toString()) ?? 0,
      price: json['price']?.toString(),
    );
  }
}

/// Staff Working Hour schedule entry
class StaffWorkingHour {
  final int id;
  final int userId;
  final String day;
  final String? startTime;
  final String? endTime;
  final bool isActive;

  StaffWorkingHour({
    required this.id,
    required this.userId,
    required this.day,
    this.startTime,
    this.endTime,
    this.isActive = true,
  });

  factory StaffWorkingHour.fromJson(Map<String, dynamic> json) {
    return StaffWorkingHour(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is num ? (json['user_id'] as num).toInt() : int.tryParse(json['user_id'].toString()) ?? 0,
      day: (json['day'] as String?) ?? '',
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

/// Registered Staff Face Template Model from (/api/v1/staff/face-templates)
class StaffFaceTemplateModel {
  final int staffId;
  final String name;
  final String? nickname;
  final String? profilePicture;
  final List<double> faceTemplate;
  final List<List<double>> faceTemplates;
  final String? faceRegisteredAt;
  final String? updatedAt;

  StaffFaceTemplateModel({
    required this.staffId,
    required this.name,
    this.nickname,
    this.profilePicture,
    required this.faceTemplate,
    this.faceTemplates = const [],
    this.faceRegisteredAt,
    this.updatedAt,
  });

  factory StaffFaceTemplateModel.fromJson(Map<String, dynamic> json) {
    List<double> primaryVector = [];
    List<List<double>> templatesList = [];

    final tpl = json['face_template'];
    if (tpl is List) {
      if (tpl.isNotEmpty && tpl.first is List) {
        templatesList = tpl
            .map((t) => (t as List).map((e) => (e as num).toDouble()).toList())
            .toList();
        primaryVector = templatesList.isNotEmpty ? templatesList.first : [];
      } else {
        primaryVector = tpl.map((e) => (e as num).toDouble()).toList();
        templatesList = [primaryVector];
      }
    } else if (tpl is String && tpl.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(tpl);
        if (decoded is List && decoded.isNotEmpty) {
          if (decoded.first is List) {
            templatesList = decoded
                .map((t) => (t as List).map((e) => (e as num).toDouble()).toList())
                .toList();
            primaryVector = templatesList.isNotEmpty ? templatesList.first : [];
          } else {
            primaryVector = decoded.map((e) => (e as num).toDouble()).toList();
            templatesList = [primaryVector];
          }
        }
      } catch (_) {}
    }

    final sId = json['staff_id'] is num
        ? (json['staff_id'] as num).toInt()
        : int.tryParse(json['staff_id']?.toString() ?? '') ?? 0;

    return StaffFaceTemplateModel(
      staffId: sId,
      name: (json['name'] as String?) ?? 'Staff #$sId',
      nickname: json['nickname'] as String?,
      profilePicture: json['profile_picture'] as String?,
      faceTemplate: primaryVector,
      faceTemplates: templatesList,
      faceRegisteredAt: json['face_registered_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

