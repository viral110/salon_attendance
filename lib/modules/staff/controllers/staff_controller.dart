import 'package:get/get.dart';

import '../models/staff_model.dart';
import '../../../services/database_service.dart';
import '../../../services/staff_service.dart';

class StaffController extends GetxController {
  final StaffService _staffService = StaffService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<StaffModel> _allStaff = [];

  List<StaffModel> get staffList {
    if (_searchQuery.trim().isEmpty) {
      return _allStaff;
    }
    final q = _searchQuery.toLowerCase();
    return _allStaff.where((staff) {
      final nameMatch = staff.name.toLowerCase().contains(q);
      final roleMatch = staff.role.toLowerCase().contains(q);
      final codeMatch = staff.staffIdCode?.toLowerCase().contains(q) ?? false;
      final idMatch = staff.id.toLowerCase().contains(q);
      return nameMatch || roleMatch || codeMatch || idMatch;
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

  Future<void> loadStaff({bool forceRefresh = false}) async {
    _isLoading = true;
    update();

    try {
      _allStaff = await _staffService.getAllStaff(forceRefresh: forceRefresh);
    } catch (e) {
      _allStaff = [];
    } finally {
      _isLoading = false;
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
