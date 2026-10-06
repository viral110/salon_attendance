import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:salon_attendance/modules/staff/models/staff_model.dart';

import '../config/api_endpoints.dart';
import '../utils/camera_image_converter.dart';
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

class PaginatedStaffResponse {
  final List<StaffModel> staffList;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMore;

  PaginatedStaffResponse({
    required this.staffList,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.hasMore,
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

  /// Fetch paginated active staff list from GET /api/staff?page={page}&status={status}
  Future<PaginatedStaffResponse> fetchStaffPaginated({
    int page = 1,
    int status = 1, // Only active staff by default
    bool forceRefresh = false,
  }) async {
    try {
      final endpoint = '${ApiEndpoints.staff}?page=$page&status=$status';
      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final dataMap = body['data'];
          final List dynamicList = dataMap['data'] ?? [];

          final currentPage = dataMap['current_page'] is num ? (dataMap['current_page'] as num).toInt() : page;
          final lastPage = dataMap['last_page'] is num ? (dataMap['last_page'] as num).toInt() : page;
          final total = dataMap['total'] is num ? (dataMap['total'] as num).toInt() : dynamicList.length;

          List<StaffModel> items = [];
          for (var item in dynamicList) {
            if (item is Map) {
              try {
                items.add(StaffModel.fromApiJson(Map<String, dynamic>.from(item)));
              } catch (e, stack) {
                debugPrint('⚠️ Error parsing staff item: $e\n$stack');
              }
            }
          }

          // Sync with registered face templates
          items = await syncFaceTemplates(items);

          if (page == 1) {
            _cachedStaffList = List.from(items);
          } else {
            final existingIds = _cachedStaffList.map((e) => e.id).toSet();
            for (var item in items) {
              if (!existingIds.contains(item.id)) {
                _cachedStaffList.add(item);
              }
            }
          }

          return PaginatedStaffResponse(
            staffList: items,
            currentPage: currentPage,
            lastPage: lastPage,
            total: total,
            hasMore: currentPage < lastPage,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error in fetchStaffPaginated: $e\n$stack');
    }

    return PaginatedStaffResponse(
      staffList: page == 1 ? _cachedStaffList : [],
      currentPage: page,
      lastPage: page,
      total: _cachedStaffList.length,
      hasMore: false,
    );
  }

  /// Fetch staff list (compatibility method)
  Future<List<StaffModel>> getAllStaff({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStaffList.isNotEmpty) {
      return _cachedStaffList;
    }

    final res = await fetchStaffPaginated(page: 1, status: 1, forceRefresh: forceRefresh);
    return _cachedStaffList.isNotEmpty ? _cachedStaffList : res.staffList;
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

  /// Sync registered face templates into a list of StaffModel items
  Future<List<StaffModel>> syncFaceTemplates(List<StaffModel> targetList) async {
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

      return targetList.map((staff) {
        final tpls = dbIdTemplateMap[staff.dbId];

        final currentTmpls = staff.faceTemplates ?? (staff.faceEmbedding != null ? [staff.faceEmbedding!] : null);
        final validCurrentTmpls = currentTmpls?.where((t) => t.length >= 60).toList();

        final bool hasServerTpls = tpls != null && tpls.isNotEmpty && tpls.first.length >= 60;
        final bool hasCurrentTpls = validCurrentTmpls != null && validCurrentTmpls.isNotEmpty;

        if (hasCurrentTpls) {
          final combined = hasServerTpls ? [...validCurrentTmpls, ...tpls] : validCurrentTmpls;
          return staff.copyWith(
            isFaceRegistered: true,
            faceEmbedding: combined.first,
            faceTemplates: combined,
          );
        }

        if (hasServerTpls) {
          return staff.copyWith(
            isFaceRegistered: true,
            faceEmbedding: tpls.first,
            faceTemplates: tpls,
          );
        }

        return staff.copyWith(
          isFaceRegistered: staff.isFaceRegistered,
          faceEmbedding: null,
          faceTemplates: null,
        );
      }).toList();
    } catch (e, stack) {
      debugPrint('⚠️ Error syncing face templates: $e\n$stack');
      return targetList;
    }
  }

  /// Sync registered face templates into _cachedStaffList items
  Future<void> _syncFaceTemplatesToStaffList() async {
    _cachedStaffList = await syncFaceTemplates(_cachedStaffList);
  }

  /// Retrieve staff members who are active and have registered face embeddings
  Future<List<StaffModel>> getEnrolledActiveStaff() async {
    final staffList = await getAllStaff();
    await _syncFaceTemplatesToStaffList();

    return staffList.where((s) {
      final hasEmbedding = (s.faceEmbedding != null && s.faceEmbedding!.isNotEmpty) ||
          (s.faceTemplates != null && s.faceTemplates!.isNotEmpty);
      final hasAwsFace = s.awsFaceId != null && s.awsFaceId!.isNotEmpty;
      return s.isActive && (s.isFaceRegistered || s.faceEnrolled || hasEmbedding || hasAwsFace);
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

  /// Register or update staff face via POST /api/v1/staff/face-register
  Future<StaffFaceEnrollmentResponse> enrollStaffFace({
    required dynamic staffId,
    required String imageBase64,
    List<double>? faceEmbedding,
  }) async {
    final numericId = staffId is num ? staffId.toInt() : int.tryParse(staffId.toString()) ?? 0;
    final formattedImage = CameraImageConverter.ensureJpegDataUri(imageBase64);

    final bodyPayload = {
      'staffId': numericId,
      'image': formattedImage,
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
