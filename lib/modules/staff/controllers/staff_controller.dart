import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/staff_model.dart';
import '../../../services/database_service.dart';
import '../../../services/staff_service.dart';

enum StaffFilter { all, registered, notRegistered }

class StaffController extends GetxController {
  final StaffService _staffService = StaffService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  int _lastPage = 1;
  int get lastPage => _lastPage;

  bool _hasMorePages = true;
  bool get hasMorePages => _hasMorePages;

  int _totalServerCount = 0;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StaffFilter _currentFilter = StaffFilter.all;
  StaffFilter get currentFilter => _currentFilter;

  List<StaffModel> _allStaff = [];

  List<StaffModel> get activeStaff => _allStaff.where((s) => s.isActive).toList();

  int get totalCount => _totalServerCount > 0 ? _totalServerCount : activeStaff.length;
  int get registeredCount => activeStaff.where((s) => s.faceEnrolled).length;
  int get notRegisteredCount => activeStaff.where((s) => !s.faceEnrolled).length;

  List<StaffModel> get staffList {
    List<StaffModel> filtered = activeStaff;

    if (_currentFilter == StaffFilter.registered) {
      filtered = filtered.where((s) => s.faceEnrolled).toList();
    } else if (_currentFilter == StaffFilter.notRegistered) {
      filtered = filtered.where((s) => !s.faceEnrolled).toList();
    }

    if (_searchQuery.trim().isEmpty) {
      return filtered;
    }

    final q = _searchQuery.trim().toLowerCase();
    return filtered.where((staff) {
      final nameMatch = staff.name.toLowerCase().contains(q);
      final nicknameMatch = staff.nickname?.toLowerCase().contains(q) ?? false;
      final roleMatch = staff.role.toLowerCase().contains(q);
      final codeMatch = staff.staffIdCode?.toLowerCase().contains(q) ?? false;
      final idMatch = staff.id.toLowerCase().contains(q);
      final phoneMatch = staff.phone?.toLowerCase().contains(q) ?? false;

      return nameMatch || nicknameMatch || roleMatch || codeMatch || idMatch || phoneMatch;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadStaff();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    update();
  }

  void setFilter(StaffFilter filter) {
    _currentFilter = filter;
    update();
  }

  Future<void> loadStaff({bool forceRefresh = false}) async {
    _isLoading = true;
    _currentPage = 1;
    _hasMorePages = true;
    update();

    try {
      final res = await _staffService.fetchStaffPaginated(
        page: 1,
        status: 1,
        forceRefresh: forceRefresh,
      );
      _allStaff = res.staffList;
      _currentPage = res.currentPage;
      _lastPage = res.lastPage;
      _totalServerCount = res.total;
      _hasMorePages = res.hasMore;
    } catch (e, stack) {
      debugPrint('❌ Error in StaffController.loadStaff: $e\n$stack');
      _allStaff = [];
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMorePages || _isLoading) return;

    _isLoadingMore = true;
    update();

    try {
      final nextPage = _currentPage + 1;
      final res = await _staffService.fetchStaffPaginated(
        page: nextPage,
        status: 1,
      );

      final existingIds = _allStaff.map((s) => s.id).toSet();
      for (var item in res.staffList) {
        if (!existingIds.contains(item.id)) {
          _allStaff.add(item);
        }
      }

      _currentPage = res.currentPage;
      _lastPage = res.lastPage;
      _totalServerCount = res.total;
      _hasMorePages = res.hasMore;
    } catch (e, stack) {
      debugPrint('❌ Error in StaffController.loadNextPage: $e\n$stack');
      _hasMorePages = false;
    } finally {
      _isLoadingMore = false;
      update();
    }
  }
  Future<bool> removeFaceRegistration(StaffModel staff) async {
    _isLoading = true;
    update();

    try {
      final targetId = staff.dbId != 0 ? staff.dbId : staff.id;
      final success = await _staffService.removeStaffFace(targetId);
      await loadStaff(forceRefresh: true);
      return success;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<bool> deleteStaff(StaffModel staff) async {
    _isLoading = true;
    update();

    try {
      await _staffService.deleteStaff(staff.id);
      await DatabaseService.instance.deleteStaff(staff.id);
      await loadStaff(forceRefresh: true);
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }
}
