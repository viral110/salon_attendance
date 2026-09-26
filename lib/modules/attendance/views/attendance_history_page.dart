import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../config/app_colors.dart';
import '../controllers/attendance_history_controller.dart';
import '../../staff/models/staff_model.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/staff_avatar.dart';
import '../../staff/views/staff_attendance_summary_page.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => AttendanceHistoryPageState();
}

class AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  void reload() {
    if (Get.isRegistered<AttendanceHistoryController>()) {
      Get.find<AttendanceHistoryController>().loadAttendanceData();
    }
  }

  Future<void> _selectCustomDateRange(BuildContext context, AttendanceHistoryController controller) async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: controller.customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4345E6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      controller.setDateFilter(DateFilterMode.custom, customRange: pickedRange);
    }
  }

  void _navigateToStaffSummary(AttendanceHistoryController controller, dynamic staffId, String staffName, String? nickname, String? profilePicture) {
    final sIdStr = staffId.toString();
    final staff = controller.staffMap[sIdStr] ??
        StaffModel(
          id: sIdStr,
          dbId: int.tryParse(sIdStr) ?? 0,
          name: staffName,
          nickname: nickname,
          profilePicture: profilePicture,
          role: 'Staff',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    Get.to(() => StaffAttendanceSummaryPage(staff: staff));
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceHistoryController>(
      init: Get.isRegistered<AttendanceHistoryController>()
          ? Get.find<AttendanceHistoryController>()
          : Get.put(AttendanceHistoryController()),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: CommonAppBar(
            title: 'Attendance History',
            showBackButton: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF4345E6), size: 24),
                tooltip: 'Refresh History',
                onPressed: () => controller.loadAttendanceData(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => controller.loadAttendanceData(),
            child: ResponsiveCenter(
              maxWidth: 950,
              child: Column(
                children: [
                  // Filter Chips Row
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(controller, 'Today', DateFilterMode.today),
                          const SizedBox(width: 8),
                          _buildFilterChip(controller, 'This Week', DateFilterMode.thisWeek),
                          const SizedBox(width: 8),
                          _buildFilterChip(controller, 'This Month', DateFilterMode.thisMonth),
                          const SizedBox(width: 8),
                          _buildFilterChip(controller, 'All Time', DateFilterMode.allTime),
                          const SizedBox(width: 8),
                          _buildCustomDateChip(context, controller),
                        ],
                      ),
                    ),
                  ),

                // Attendance Records List
                Expanded(
                  child: controller.isLoading
                      ? ShimmerSkeleton.historyList(count: 5)
                      : controller.historyItems.isEmpty && controller.records.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 140),
                                Center(
                                  child: Text(
                                    'No attendance records found.',
                                    style: TextStyle(
                                      color: Color(0xFF9E9E9E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : controller.historyItems.isNotEmpty
                              ? ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: controller.historyItems.length,
                                  itemBuilder: (ctx, index) {
                                    final item = controller.historyItems[index];
                                    final displayName = item.nickname != null && item.nickname!.isNotEmpty
                                        ? '${item.staffName} (${item.nickname})'
                                        : item.staffName;
                                    final isCheckedIn = item.badgeStatus == 'checked_in' || item.checkOut == '--';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _navigateToStaffSummary(
                                          controller,
                                          item.staffId,
                                          item.staffName,
                                          item.nickname,
                                          item.profilePicture,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        StaffAvatar(
                                                          imageUrl: item.profilePicture,
                                                          name: item.staffName,
                                                          radius: 18,
                                                          backgroundColor: const Color(0xFFEEEEFF),
                                                          textColor: const Color(0xFF4345E6),
                                                          fontSize: 14,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            displayName,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: isCheckedIn
                                                              ? const Color(0xFFE6F5FF)
                                                              : const Color(0xFFE8F9F1),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          item.badgeLabel,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: isCheckedIn
                                                                ? const Color(0xFF00A0FF)
                                                                : const Color(0xFF00C853),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item.formattedDate.isNotEmpty ? item.formattedDate : item.dateStr,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const Divider(height: 20, color: AppColors.border),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildMetricColumn('Check-In', item.checkIn),
                                                  _buildMetricColumn('Check-Out', item.checkOut),
                                                  _buildMetricColumn('Duration', item.duration),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: controller.records.length,
                                  itemBuilder: (ctx, index) {
                                    final record = controller.records[index];
                                    final staff = controller.staffMap[record.staffId];
                                    final staffName = staff?.name ?? 'Staff #${record.staffId}';

                                    final checkInStr = record.checkIn != null
                                        ? DateFormat('hh:mm a').format(record.checkIn!)
                                        : '--';
                                    final checkOutStr = record.checkOut != null
                                        ? DateFormat('hh:mm a').format(record.checkOut!)
                                        : '--';
                                    final dateStr = DateFormat('dd MMM yyyy').format(record.date);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _navigateToStaffSummary(
                                          controller,
                                          record.staffId,
                                          staffName,
                                          staff?.nickname,
                                          staff?.profilePicture,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    staffName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const Divider(height: 20, color: AppColors.border),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildMetricColumn('Check-In', checkInStr),
                                                  _buildMetricColumn('Check-Out', checkOutStr),
                                                  _buildMetricColumn('Duration', record.formattedWorkingDuration),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(AttendanceHistoryController controller, String label, DateFilterMode mode) {
    final isSelected = controller.dateFilter == mode;
    return InkWell(
      onTap: () => controller.setDateFilter(mode),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4345E6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4345E6) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(BuildContext context, AttendanceHistoryController controller) {
    final isSelected = controller.dateFilter == DateFilterMode.custom;
    String label = 'Custom Date';

    if (isSelected) {
      if (controller.customDateRange != null) {
        final start = DateFormat('dd MMM').format(controller.customDateRange!.start);
        final end = DateFormat('dd MMM').format(controller.customDateRange!.end);
        label = '$start - $end';
      } else if (controller.customSingleDate != null) {
        label = DateFormat('dd MMM yyyy').format(controller.customSingleDate!);
      }
    }

    return InkWell(
      onTap: () => _selectCustomDateRange(context, controller),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4345E6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4345E6) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

