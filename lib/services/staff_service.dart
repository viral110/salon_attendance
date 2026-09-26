import 'dart:convert';
import 'package:salon_attendance/modules/staff/models/staff_model.dart';

import '../config/api_endpoints.dart';
import 'api_service.dart';

class StaffFaceEnrollmentResponse {
  final bool success;
  final String message;
  final String? errors;

  StaffFaceEnrollmentResponse({
    required this.success,
    required this.message,
    this.errors,
  });
}

class StaffService {
  static String get baseUrl => ApiEndpoints.baseUrl;

  final ApiService _apiService;

  StaffService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // In-memory cache for fast scanning and offline resilience
  List<StaffModel> _cachedStaffList = [];
  List<StaffFaceTemplateModel> _cachedFaceTemplates = [];

  List<StaffModel> get cachedStaff => _cachedStaffList;

  /// Fetch staff list from GET /api/staff
  Future<List<StaffModel>> getAllStaff({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStaffList.isNotEmpty) {
      return _cachedStaffList;
    }

    try {
      final response = await _apiService.get(ApiEndpoints.staff);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List dynamicList = body['data']['data'] ?? [];
          _cachedStaffList = dynamicList
              .map((item) => StaffModel.fromApiJson(item as Map<String, dynamic>))
              .toList();

          // Sync with registered face templates if available
          await _syncFaceTemplatesToStaffList();

          return _cachedStaffList;
        }
      }
    } catch (_) {}

    return _cachedStaffList;
  }

  /// Fetch registered staff face templates from GET /api/v1/staff/face-templates
  Future<List<StaffFaceTemplateModel>> getFaceTemplates() async {
    try {
      final response = await _apiService.get(ApiEndpoints.staffFaceTemplates);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          _cachedFaceTemplates = list
              .map((item) => StaffFaceTemplateModel.fromJson(item as Map<String, dynamic>))
              .toList();
          return _cachedFaceTemplates;
        }
      }
    } catch (_) {}
    return _cachedFaceTemplates;
  }

  /// Sync registered face templates into _cachedStaffList items
  Future<void> _syncFaceTemplatesToStaffList() async {
    try {
      final templates = await getFaceTemplates();
      final Map<int, List<List<double>>> dbIdTemplateMap = {};

      for (var t in templates) {
        final list = t.faceTemplates.isNotEmpty
            ? t.faceTemplates
            : (t.faceTemplate.isNotEmpty ? [t.faceTemplate] : <List<double>>[]);
        if (list.isNotEmpty && list.first.length >= 60) {
          dbIdTemplateMap.putIfAbsent(t.staffId, () => []).addAll(list);
        }
      }

      _cachedStaffList = _cachedStaffList.map((staff) {
        final tpls = dbIdTemplateMap[staff.dbId];

        // 1. If staff already has valid MLKit face templates (e.g. from /api/staff JSON face_template)
        final currentTmpls = staff.faceTemplates ?? (staff.faceEmbedding != null ? [staff.faceEmbedding!] : null);
        final validCurrentTmpls = currentTmpls?.where((t) => t.length >= 60).toList();

        if (staff.isFaceRegistered && validCurrentTmpls != null && validCurrentTmpls.isNotEmpty) {
          final combined = (tpls != null && tpls.isNotEmpty)
              ? [...validCurrentTmpls, ...tpls]
              : validCurrentTmpls;
          return staff.copyWith(
            isFaceRegistered: true,
            faceEmbedding: combined.first,
            faceTemplates: combined,
          );
        }

        // 2. If /api/staff marked is_face_registered as true AND extra templates found for this dbId
        if (staff.isFaceRegistered && tpls != null && tpls.isNotEmpty && tpls.first.length >= 60) {
          return staff.copyWith(
            isFaceRegistered: true,
            faceEmbedding: tpls.first,
            faceTemplates: tpls,
          );
        }

        // 3. Unregistered staff member or no valid template -> clear face embedding
        return staff.copyWith(
          isFaceRegistered: false,
          faceEmbedding: null,
          faceTemplates: null,
        );
      }).toList();
    } catch (_) {}
  }

  /// Retrieve staff members who are active and have registered face embeddings
  Future<List<StaffModel>> getEnrolledActiveStaff() async {
    final staffList = await getAllStaff();
    await _syncFaceTemplatesToStaffList();

    return staffList.where((s) {
      final hasEmbedding = (s.faceEmbedding != null && s.faceEmbedding!.isNotEmpty) ||
          (s.faceTemplates != null && s.faceTemplates!.isNotEmpty);
      return s.isActive && s.faceEnrolled && hasEmbedding;
    }).toList();
  }

  /// Retrieve single staff by primary key ID
  Future<StaffModel?> getStaffById(String id) async {
    final staffList = await getAllStaff();
    try {
      return staffList.firstWhere(
        (s) => s.dbId.toString() == id || s.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  /// Register or update staff face template via POST /api/v1/staff/face-register
  Future<StaffFaceEnrollmentResponse> enrollStaffFace({
    required dynamic staffId,
    required List<double> faceEmbedding,
    List<List<double>>? faceTemplates,
  }) async {
    final numericId = staffId is num ? staffId.toInt() : int.tryParse(staffId.toString()) ?? 0;

    final String faceTemplateJson = (faceTemplates != null && faceTemplates.isNotEmpty)
        ? jsonEncode(faceTemplates)
        : jsonEncode(faceEmbedding);

    final String primaryEmbeddingJson = jsonEncode(faceEmbedding);

    final bodyPayload = {
      'staffId': numericId,
      'face_template': faceTemplateJson,
      'primaryEmbedding': primaryEmbeddingJson,
    };

    try {
      final response = await _apiService.post(
        ApiEndpoints.staffFaceRegister,
        body: bodyPayload,
      );

      final Map<String, dynamic> body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true || response.statusCode == 200) {
          // Update in-memory cache and re-sync
          _updateLocalStaffFaceState(numericId.toString(), faceEmbedding, true);
          await getAllStaff(forceRefresh: true);
          _updateLocalStaffFaceState(numericId.toString(), faceEmbedding, true);
          return StaffFaceEnrollmentResponse(
            success: true,
            message: body['message']?.toString() ?? 'Face enrolled successfully!',
          );
        }
      }

      // Handle 422 Unprocessable Entity or other error responses
      final String msg = body['message']?.toString() ?? 'Face Registration Failed';
      final String? errs = body['errors']?.toString();

      return StaffFaceEnrollmentResponse(
        success: false,
        message: msg,
        errors: errs,
      );
    } catch (e) {
      return StaffFaceEnrollmentResponse(
        success: false,
        message: 'Network Error',
        errors: e.toString(),
      );
    }
  }

  /// Delete staff face registration via GET /api/v1/staff/delete-face/{id}
  Future<bool> removeStaffFace(dynamic staffId) async {
    final sIdStr = staffId.toString();

    try {
      final response = await _apiService.get(ApiEndpoints.staffDeleteFace(sIdStr));

      if (response.statusCode == 200) {
        _updateLocalStaffFaceState(sIdStr, null, false);
        await getAllStaff(forceRefresh: true);
        return true;
      }
    } catch (_) {}

    // Fallback update in cache
    _updateLocalStaffFaceState(sIdStr, null, false);
    return true;
  }

  /// Helper to update local staff object face state
  void _updateLocalStaffFaceState(String staffIdStr, List<double>? embedding, bool isRegistered) {
    _cachedStaffList = _cachedStaffList.map((s) {
      if (s.id == staffIdStr || s.dbId.toString() == staffIdStr || s.staffIdCode == staffIdStr) {
        return s.copyWith(
          isFaceRegistered: isRegistered,
          faceEmbedding: isRegistered ? (embedding ?? s.faceEmbedding) : null,
          faceTemplates: isRegistered
              ? (embedding != null
                  ? [embedding]
                  : (s.faceTemplates ?? (s.faceEmbedding != null ? [s.faceEmbedding!] : null)))
              : null,
        );
      }
      return s;
    }).toList();
  }

  Future<void> updateStaffProfile(StaffModel staff) async {
    _cachedStaffList = _cachedStaffList.map((s) => s.id == staff.id ? staff : s).toList();
  }

  Future<void> deleteStaff(String staffId) async {
    _cachedStaffList.removeWhere((s) => s.id == staffId || s.dbId.toString() == staffId);
  }
}
