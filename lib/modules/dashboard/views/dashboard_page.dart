import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../config/app_colors.dart';
import '../../attendance/controllers/attendance_history_controller.dart';
import '../../attendance/controllers/face_attendance_controller.dart';
import '../../staff/controllers/staff_controller.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/staff_avatar.dart';
import '../../attendance/views/attendance_history_page.dart';
import '../../attendance/views/face_attendance_page.dart';
import '../../staff/views/staff_list_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardHomeView(),
    FaceAttendancePage(),
    StaffListPage(),
    AttendanceHistoryPage(),
  ];

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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 0) {
              if (Get.isRegistered<StaffController>()) {
                Get.find<StaffController>().loadStaff();
              }
              if (Get.isRegistered<AttendanceHistoryController>()) {
                Get.find<AttendanceHistoryController>().loadAttendanceData();
              }
            } else if (index == 1) {
              if (Get.isRegistered<FaceAttendanceController>()) {
                final faceCtrl = Get.find<FaceAttendanceController>();
                faceCtrl.refreshStaffCache();
                faceCtrl.initializeCamera();
              }
            } else if (index == 2) {
              if (Get.isRegistered<StaffController>()) {
                Get.find<StaffController>().loadStaff();
              }
            } else if (index == 3) {
              if (Get.isRegistered<AttendanceHistoryController>()) {
                Get.find<AttendanceHistoryController>().loadAttendanceData();
              }
            }

            if (index != 1 && Get.isRegistered<FaceAttendanceController>()) {
              Get.find<FaceAttendanceController>().stopScanning();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.center_focus_weak),
              activeIcon: Icon(Icons.center_focus_strong),
              label: 'Scan Face',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHomeView extends StatelessWidget {
  const DashboardHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (Get.isRegistered<StaffController>()) {
              await Get.find<StaffController>().loadStaff();
            }
            if (Get.isRegistered<AttendanceHistoryController>()) {
              await Get.find<AttendanceHistoryController>().loadAttendanceData();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: ResponsiveCenter(
              maxWidth: 1000,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header Bar (Title, Date, Refresh)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.primary, size: 24),
                      onPressed: () {
                        if (Get.isRegistered<StaffController>()) {
                          Get.find<StaffController>().loadStaff();
                        }
                        if (Get.isRegistered<AttendanceHistoryController>()) {
                          Get.find<AttendanceHistoryController>().loadAttendanceData();
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Purple Gradient Banner Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4345E6), Color(0xFF2F31BA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D4345E6),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0x33FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.face_retouching_natural,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Face Recognition Attendance',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan face to instantly record Check-In or Check-Out with real-time biometric verification.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xD9FFFFFF),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Get.to(() => const FaceAttendancePage());
                          },
                          icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E202C), size: 20),
                          label: const Text(
                            'Open Face Scanner',
                            style: TextStyle(
                              color: Color(0xFF1E202C),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Today's Attendance Summary Section
                const Text(
                  "Today's Attendance Summary",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                GetBuilder<StaffController>(
                  init: Get.isRegistered<StaffController>() ? Get.find<StaffController>() : Get.put(StaffController()),
                  builder: (staffCtrl) {
                    return GetBuilder<AttendanceHistoryController>(
                      init: Get.isRegistered<AttendanceHistoryController>()
                          ? Get.find<AttendanceHistoryController>()
                          : Get.put(AttendanceHistoryController()),
                      builder: (attCtrl) {
                        final summary = attCtrl.summaryModel;
                        final total = summary.totalStaff;
                        final checkedIn = summary.checkedInCount;
                        final checkedOut = summary.checkedOutCount;
                        final notPresent = summary.notYetPresentCount;

                        final gridCols = Responsive.crossAxisCount(context, mobile: 2, tablet: 4);
                        final gridRatio = Responsive.childAspectRatio(context, mobile: 1.35, tablet: 1.5);

                        if (attCtrl.isLoading) {
                          return ShimmerSkeleton.statGrid(
                            crossAxisCount: gridCols,
                            childAspectRatio: gridRatio,
                          );
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: gridCols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: gridRatio,
                          children: [
                            _buildStatCard(
                              title: 'Total Staff',
                              value: total.toString(),
                              icon: Icons.people_alt_outlined,
                              iconColor: const Color(0xFF4345E6),
                              bgColor: const Color(0xFFEEEEFF),
                            ),
                            _buildStatCard(
                              title: 'Checked In',
                              value: checkedIn.toString(),
                              icon: Icons.login,
                              iconColor: const Color(0xFF00A0FF),
                              bgColor: const Color(0xFFE6F5FF),
                            ),
                            _buildStatCard(
                              title: 'Checked Out',
                              value: checkedOut.toString(),
                              icon: Icons.logout,
                              iconColor: const Color(0xFF00C853),
                              bgColor: const Color(0xFFE8F9F1),
                            ),
                            _buildStatCard(
                              title: 'Not Yet Present',
                              value: notPresent.toString(),
                              icon: Icons.person_off_outlined,
                              iconColor: const Color(0xFFFF9800),
                              bgColor: const Color(0xFFFFF6E5),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Recent Attendance Activity Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Attendance Activity',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.to(() => const AttendanceHistoryPage());
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: Color(0xFF4345E6),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                GetBuilder<AttendanceHistoryController>(
                  builder: (attCtrl) {
                    if (attCtrl.isLoading) {
                      return ShimmerSkeleton.activityList(count: 4);
                    }

                    final recentActivities = attCtrl.recentActivities;
                    final todayRecords = attCtrl.todayRecords;

                    if (recentActivities.isEmpty && todayRecords.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'No attendance scans recorded today yet.',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }

                    if (recentActivities.isNotEmpty) {
                      return Column(
                        children: recentActivities.take(10).map((activity) {
                          final displayName = activity.nickname != null && activity.nickname!.isNotEmpty
                              ? '${activity.staffName} (${activity.nickname})'
                              : activity.staffName;
                          final isCheckIn = activity.actionPerformed == 'check_in';
                          final timeSubtitle = isCheckIn ? 'Check-In: ${activity.time}' : 'Check-Out: ${activity.time}';
                          final timeAgoStr = activity.timeAgo != null ? ' • ${activity.timeAgo}' : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                StaffAvatar(
                                  imageUrl: activity.profilePicture,
                                  name: activity.staffName,
                                  radius: 20,
                                  backgroundColor: const Color(0xFFEEEEFF),
                                  textColor: const Color(0xFF4345E6),
                                  fontSize: 14,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$timeSubtitle$timeAgoStr',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCheckIn ? const Color(0xFFE6F5FF) : const Color(0xFFE8F9F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCheckIn ? 'Checked In' : 'Checked Out',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCheckIn ? const Color(0xFF00A0FF) : const Color(0xFF00C853),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Column(
                      children: todayRecords.take(5).map((record) {
                        final staff = attCtrl.staffMap[record.staffId];
                        final staffName = staff?.name ?? 'Staff #${record.staffId}';
                        final checkInTime = record.checkIn != null
                            ? DateFormat('hh:mm a').format(record.checkIn!)
                            : '--';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFEEEEFF),
                                child: Text(
                                  staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4345E6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staffName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Check-In: $checkInTime',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: record.checkOut == null
                                      ? const Color(0xFFE6F5FF)
                                      : const Color(0xFFE8F9F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record.checkOut == null ? 'Checked In' : 'Checked Out',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: record.checkOut == null
                                        ? const Color(0xFF00A0FF)
                                        : const Color(0xFF00C853),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
