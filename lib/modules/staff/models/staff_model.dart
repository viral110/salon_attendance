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
  final String? awsFaceId;
  final String? type;
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
  final String? referenceName;
  final String? referenceContact;
  final String? emergencyContactNumber;
  final String? emergencyContactName;
  final String? relationship;
  final String? experience;
  final String? reasonForLeaving;
  final String? lastWorkPlace;
  final bool housekeepingTip;
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
    this.awsFaceId,
    this.type,
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
    this.referenceName,
    this.referenceContact,
    this.emergencyContactNumber,
    this.emergencyContactName,
    this.relationship,
    this.experience,
    this.reasonForLeaving,
    this.lastWorkPlace,
    this.housekeepingTip = false,
    this.commissionType,
    this.services = const [],
    this.workingHours = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : isFaceRegistered = isFaceRegistered ?? faceEnrolled ?? false;

  /// Alias getter for faceEnrolled for backward compatibility
  bool get faceEnrolled =>
      isFaceRegistered ||
      (awsFaceId != null && awsFaceId!.isNotEmpty) ||
      (faceEmbedding != null && faceEmbedding!.isNotEmpty) ||
      (faceTemplates != null && faceTemplates!.isNotEmpty);
  String? get faceTemplateId => faceEnrolled ? (awsFaceId ?? 'TMP_$id') : null;
  DateTime? get faceEnrolledAt => faceRegisteredAt;
  DateTime? get faceUpdatedAt => updatedAt;

  /// Formatted list of weekly off days
  List<String> get weeklyOffDaysList {
    if (weeklyOffDay == null || weeklyOffDay!.trim().isEmpty) return [];
    return weeklyOffDay!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Primary display name: Nickname if available, otherwise real Name.
  String get displayName {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      return nickname!.trim();
    }
    return name;
  }

  /// Secondary name: Real name if nickname is used and different from real name.
  String? get secondaryName {
    if (nickname != null &&
        nickname!.trim().isNotEmpty &&
        nickname!.trim().toLowerCase() != name.trim().toLowerCase()) {
      return name.trim();
    }
    return null;
  }

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
    String? awsFaceId,
    String? type,
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
    String? referenceName,
    String? referenceContact,
    String? emergencyContactNumber,
    String? emergencyContactName,
    String? relationship,
    String? experience,
    String? reasonForLeaving,
    String? lastWorkPlace,
    bool? housekeepingTip,
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
      awsFaceId: awsFaceId ?? this.awsFaceId,
      type: type ?? this.type,
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
      referenceName: referenceName ?? this.referenceName,
      referenceContact: referenceContact ?? this.referenceContact,
      emergencyContactNumber: emergencyContactNumber ?? this.emergencyContactNumber,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      relationship: relationship ?? this.relationship,
      experience: experience ?? this.experience,
      reasonForLeaving: reasonForLeaving ?? this.reasonForLeaving,
      lastWorkPlace: lastWorkPlace ?? this.lastWorkPlace,
      housekeepingTip: housekeepingTip ?? this.housekeepingTip,
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

    // Helper for safe string parsing
    String? parseString(dynamic val) {
      if (val == null) return null;
      if (val is String) {
        final trimmed = val.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (val is List) {
        final items = val
            .map((e) => e?.toString().trim())
            .where((e) => e != null && e.isNotEmpty && e.toLowerCase() != 'none')
            .toList();
        return items.isEmpty ? null : items.join(', ');
      }
      return val.toString();
    }

    final p1 = parseString(json['phone_1']);
    final p2 = parseString(json['phone_2']);
    final phoneNum = (p1 != null && p1.isNotEmpty) ? p1 : (p2 ?? parseString(json['phone']));

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
      for (var s in (json['services'] as List)) {
        if (s is Map) {
          try {
            parsedServices.add(StaffServiceItem.fromJson(Map<String, dynamic>.from(s)));
          } catch (_) {}
        }
      }
    }

    // Working hours parsing
    List<StaffWorkingHour> parsedWorkingHours = [];
    if (json['working_hours'] is List) {
      for (var w in (json['working_hours'] as List)) {
        if (w is Map) {
          try {
            parsedWorkingHours.add(StaffWorkingHour.fromJson(Map<String, dynamic>.from(w)));
          } catch (_) {}
        }
      }
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

    final awsFaceId = parseString(json['aws_face_id']);

    final isReg = parseBool(
      json['is_face_registered'],
      (awsFaceId != null && awsFaceId.isNotEmpty) ||
          (primaryEmbedding != null && primaryEmbedding.isNotEmpty) ||
          (json['face_template'] != null &&
              json['face_template'].toString().trim().isNotEmpty &&
              json['face_template'].toString().trim() != 'null'),
    );

    // Weekly off days parsing
    String? parsedWeeklyOffDay;
    final rawOff = json['weekly_off_day'];
    if (rawOff is List) {
      final items = rawOff
          .map((e) => e?.toString().replaceAll(RegExp(r'[\[\]"]'), '').trim())
          .where((e) => e != null && e.isNotEmpty && e.toLowerCase() != 'none')
          .map((e) => e!.length > 1 ? (e[0].toUpperCase() + e.substring(1).toLowerCase()) : e)
          .toList();
      parsedWeeklyOffDay = items.isEmpty ? null : items.join(', ');
    } else {
      parsedWeeklyOffDay = parseString(rawOff);
    }

    bool parsedIsActive = true;
    if (json.containsKey('is_active')) {
      parsedIsActive = parseBool(json['is_active'], true);
    } else if (json.containsKey('active')) {
      parsedIsActive = parseBool(json['active'], true);
    } else if (json['status'] != null) {
      final st = json['status'].toString().toLowerCase().trim();
      if (st == 'active' || st == '1' || st == 'true') {
        parsedIsActive = true;
      } else if (st == 'inactive' || st == '0' || st == 'false' || st == 'disabled' || st == 'deactive') {
        parsedIsActive = false;
      }
    }

    return StaffModel(
      id: staffIdStr,
      dbId: dbIdVal,
      name: parseString(json['name']) ?? 'Staff #$dbIdVal',
      nickname: parseString(json['nickname']),
      email: parseString(json['email']),
      phone: phoneNum,
      phone1: p1,
      phone2: p2,
      role: parsedRole,
      profilePicture: parseString(json['profile_picture']),
      isActive: parsedIsActive,
      isFaceRegistered: isReg,
      faceRegisteredAt: parsedFaceRegAt,
      rawFaceTemplate: faceTpl,
      faceEmbedding: primaryEmbedding,
      faceTemplates: templates,
      awsFaceId: awsFaceId,
      type: parseString(json['type']),
      idProofFront: parseString(json['id_proof_front']),
      idProofBack: parseString(json['id_proof_back']),
      aadharCardNumber: parseString(json['aadhar_card_number']),
      staffIdCode: parseString(json['staff_id']),
      lockerNumber: parseString(json['locker_number']),
      dob: parseString(json['dob']),
      gender: parseString(json['gender']),
      address: parseString(json['address']),
      dateOfJoining: parseString(json['date_of_joining']),
      weeklyOffDay: parsedWeeklyOffDay,
      referenceName: parseString(json['reference_name']),
      referenceContact: parseString(json['reference_contact']),
      emergencyContactNumber: parseString(json['emergency_contact_number']),
      emergencyContactName: parseString(json['emergency_contact_name']),
      relationship: parseString(json['relationship']),
      experience: parseString(json['experience']),
      reasonForLeaving: parseString(json['reason_for_leaving']),
      lastWorkPlace: parseString(json['last_work_place']),
      housekeepingTip: parseBool(json['housekeeping_tip'], false),
      commissionType: parseString(json['commission_type']),
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
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      price: json['price']?.toString() ?? '0.00',
      serviceTime: json['service_time']?.toString(),
      processingTime: json['processing_time']?.toString(),
      isVisibleOnline: json['is_visible_online'] == true || json['is_visible_online'] == 1 || json['is_visible_online'] == '1',
      status: json['status'] == true || json['status'] == 1 || json['status'] == '1',
      staffPricingModule: json['staff_pricing_module'] == true || json['staff_pricing_module'] == 1 || json['staff_pricing_module'] == '1',
      position: json['position'] is num ? (json['position'] as num).toInt() : int.tryParse(json['position']?.toString() ?? ''),
      pivot: json['pivot'] is Map ? StaffServicePivot.fromJson(Map<String, dynamic>.from(json['pivot'] as Map)) : null,
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
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is num ? (json['user_id'] as num).toInt() : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      day: json['day']?.toString() ?? '',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
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
      name: json['name']?.toString() ?? 'Staff #$sId',
      nickname: json['nickname']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      faceTemplate: primaryVector,
      faceTemplates: templatesList,
      faceRegisteredAt: json['face_registered_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

