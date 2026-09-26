import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/attendance_summary_model.dart';
import '../../models/staff_model.dart';
import '../../services/attendance_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/staff_avatar.dart';

class StaffAttendanceSummaryPage extends StatefulWidget {
  final StaffModel staff;

  const StaffAttendanceSummaryPage({
    super.key,
    required this.staff,
  });

  @override
  State<StaffAttendanceSummaryPage> createState() => _StaffAttendanceSummaryPageState();
}

class _StaffAttendanceSummaryPageState extends State<StaffAttendanceSummaryPage> {
  final AttendanceService _attendanceService = AttendanceService();

  late int _selectedMonth;
  late int _selectedYear;
  bool _isLoading = true;
  StaffAttendanceSummaryResponse? _summaryResponse;

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  final List<int> _years = [2024, 2025, 2026, 2027, 2028];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
    });

    final targetId = widget.staff.dbId != 0 ? widget.staff.dbId : widget.staff.id;
    final res = await _attendanceService.fetchStaffAttendanceSummaryApi(
      staffId: targetId,
      month: _selectedMonth,
      year: _selectedYear,
    );

    setState(() {
      _summaryResponse = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: '${widget.staff.name} - Summary',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSummary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: ResponsiveCenter(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month & Year Filter Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, color: Color(0xFF4345E6), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(
                                    _months[index],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null && val != _selectedMonth) {
                                  setState(() {
                                    _selectedMonth = val;
                                  });
                                  _fetchSummary();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                            items: _years.map((year) {
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(
                                  year.toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedYear) {
                                setState(() {
                                  _selectedYear = val;
                                });
                                _fetchSummary();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Staff Header Card with Avatar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      StaffAvatar(
                        imageUrl: _summaryResponse?.profilePicture ?? widget.staff.profilePicture,
                        name: widget.staff.name,
                        radius: 26,
                        fontSize: 18,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _summaryResponse?.staffName.isNotEmpty == true
                                  ? _summaryResponse!.staffName
                                  : widget.staff.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.staff.role} • ${_months[_selectedMonth - 1]} $_selectedYear',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Summary Stats Grid (4 Cards)
                _isLoading
                    ? ShimmerSkeleton.statGrid(
                        crossAxisCount: Responsive.crossAxisCount(context, mobile: 2, tablet: 4),
                        childAspectRatio: Responsive.childAspectRatio(context, mobile: 1.35, tablet: 1.5),
                      )
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: Responsive.crossAxisCount(context, mobile: 2, tablet: 4),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: Responsive.childAspectRatio(context, mobile: 1.35, tablet: 1.5),
                        children: [
                          _buildStatCard(
                            title: 'Total Present',
                            value: _summaryResponse?.totalPresent ?? '0 Days',
                            icon: Icons.calendar_month_outlined,
                            iconColor: const Color(0xFF4345E6),
                            bgColor: const Color(0xFFEEEEFF),
                          ),
                          _buildStatCard(
                            title: 'Total Hours',
                            value: _summaryResponse?.totalHours ?? '0 hrs',
                            icon: Icons.access_time_filled,
                            iconColor: const Color(0xFF00A0FF),
                            bgColor: const Color(0xFFE6F5FF),
                          ),
                          _buildStatCard(
                            title: 'Avg Working Hours',
                            value: _summaryResponse?.avgWorkingHours ?? '0 hrs',
                            icon: Icons.timer_outlined,
                            iconColor: const Color(0xFF00C853),
                            bgColor: const Color(0xFFE8F9F1),
                          ),
                          _buildStatCard(
                            title: 'Late Check-Ins',
                            value: '${_summaryResponse?.lateCheckIns ?? 0}',
                            icon: Icons.notifications_off_outlined,
                            iconColor: const Color(0xFFFF9800),
                            bgColor: const Color(0xFFFFF6E5),
                          ),
                        ],
                      ),

              const SizedBox(height: 24),

              // Daily Logs Header
              const Text(
                'Daily Attendance Logs',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Daily Logs List
              if (_isLoading)
                ShimmerSkeleton.historyList(count: 3)
              else if (_summaryResponse == null || _summaryResponse!.dailyRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text(
                      'No attendance logs found for ${_months[_selectedMonth - 1]} $_selectedYear.',
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: _summaryResponse!.dailyRecords.map((record) {
                    final checkInStr = record.checkIn ?? '--';
                    final checkOutStr = record.checkOut ?? '--';
                    final durationStr = record.totalHours ?? '--';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${record.date} (${record.day})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: record.isLate
                                      ? const Color(0xFFFFF6E5)
                                      : const Color(0xFFE8F9F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record.isLate ? 'Late (${record.checkIn ?? ""})' : 'Present',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: record.isLate
                                        ? const Color(0xFFFF9800)
                                        : const Color(0xFF00C853),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricColumn('Check-In', checkInStr),
                              _buildMetricColumn('Check-Out', checkOutStr),
                              _buildMetricColumn('Duration', durationStr),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
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
}
