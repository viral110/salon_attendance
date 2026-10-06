import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_colors.dart';
import '../attendance/controllers/face_attendance_controller.dart';
import '../attendance/views/face_attendance_page.dart';
import '../staff/controllers/staff_controller.dart';
import '../staff/views/staff_list_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    StaffListPage(),
    FaceAttendancePage(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      if (Get.isRegistered<StaffController>()) {
        Get.find<StaffController>().loadStaff();
      }
      if (Get.isRegistered<FaceAttendanceController>()) {
        Get.find<FaceAttendanceController>().stopScanning();
      }
    } else if (index == 1) {
      if (Get.isRegistered<FaceAttendanceController>()) {
        final faceCtrl = Get.find<FaceAttendanceController>();
        faceCtrl.refreshStaffCache();
        faceCtrl.initializeCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.face_outlined),
              activeIcon: Icon(Icons.face),
              label: 'Staff Face',
            ),
          ],
        ),
      ),
    );
  }
}
