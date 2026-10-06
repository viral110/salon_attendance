import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../attendance/models/attendance_summary_model.dart';
import '../models/staff_model.dart';
import '../../../services/attendance_service.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/staff_avatar.dart';

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
    final nickname = _summaryResponse?.nickname ?? widget.staff.nickname;
    final realName = _summaryResponse?.staffName.isNotEmpty == true
        ? _summaryResponse!.staffName
        : widget.staff.name;

    final primaryName = (nickname != null && nickname.trim().isNotEmpty)
        ? nickname.trim()
        : realName;

    final secondaryName = (nickname != null &&
            nickname.trim().isNotEmpty &&
            nickname.trim().toLowerCase() != realName.trim().toLowerCase())
        ? realName
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: '$primaryName - Attendance Summary',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSummary,
        color: AppColors.primary,
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
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
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
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
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
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

                const SizedBox(height: 18),

                // Staff Header Card with Avatar & Nickname
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      StaffAvatar(
                        imageUrl: _summaryResponse?.profilePicture ?? widget.staff.profilePicture,
                        name: primaryName,
                        radius: 28,
                        fontSize: 20,
                        backgroundColor: AppColors.primaryLight,
                        textColor: AppColors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    primaryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (secondaryName != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      'Real: $secondaryName',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
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

                const SizedBox(height: 18),

                // Summary Stats Grid (4 Cards)
                _isLoading
                    ? ShimmerSkeleton.statGrid(
                        crossAxisCount: Responsive.crossAxisCount(context, mobile: 2, tablet: 4),
                        childAspectRatio: Responsive.childAspectRatio(context, mobile: 1.25, tablet: 1.5),
                      )
                    : GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: Responsive.crossAxisCount(context, mobile: 2, tablet: 4),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: Responsive.childAspectRatio(context, mobile: 1.25, tablet: 1.45),
                        children: [
                          _buildStatCard(
                            title: 'Total Present',
                            value: _summaryResponse?.totalPresent ?? '0 Days',
                            icon: Icons.calendar_today_rounded,
                            iconColor: AppColors.primary,
                            bgColor: AppColors.primaryLight,
                          ),
                          _buildStatCard(
                            title: 'Total Hours',
                            value: _summaryResponse?.totalHours ?? '0 hrs',
                            icon: Icons.access_time_rounded,
                            iconColor: const Color(0xFF0284C7),
                            bgColor: const Color(0xFFE0F2FE),
                          ),
                          _buildStatCard(
                            title: 'Avg Working Hours',
                            value: _summaryResponse?.avgWorkingHours ?? '0 hrs',
                            icon: Icons.timer_outlined,
                            iconColor: AppColors.success,
                            bgColor: AppColors.successBg,
                          ),
                          _buildStatCard(
                            title: 'Late Check-Ins',
                            value: '${_summaryResponse?.lateCheckIns ?? 0}',
                            subtitle: (_summaryResponse?.lateCheckIns ?? 0) > 0 ? 'Times Late' : 'On Time Record',
                            icon: Icons.alarm_off_rounded,
                            iconColor: (_summaryResponse?.lateCheckIns ?? 0) > 0
                                ? AppColors.danger
                                : AppColors.success,
                            bgColor: (_summaryResponse?.lateCheckIns ?? 0) > 0
                                ? AppColors.dangerBg
                                : AppColors.successBg,
                          ),
                        ],
                      ),

                const SizedBox(height: 24),

                // Daily Logs Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Attendance Logs',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_summaryResponse?.dailyRecords.isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_summaryResponse!.dailyRecords.length} Records',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Daily Logs List
                if (_isLoading)
                  ShimmerSkeleton.historyList(count: 3)
                else if (_summaryResponse == null || _summaryResponse!.dailyRecords.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_busy_rounded,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No attendance logs found for ${_months[_selectedMonth - 1]} $_selectedYear.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _summaryResponse!.dailyRecords.map((record) {
                      return _buildDailyRecordCard(record);
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
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor == AppColors.danger ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildDailyRecordCard(StaffDailyRecordModel record) {
    final checkInStr = record.checkIn ?? '--';
    final checkOutStr = record.checkOut ?? (record.checkIn != null ? 'In Progress' : '--');
    final durationStr = record.totalHours ?? (record.checkIn != null && record.checkOut == null ? 'Active' : '--');
    final expectedStart = record.expectedStartTime ?? '09:00 AM';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: record.isLate
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
          width: record.isLate ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Date & Late / Present Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${record.date} (${record.day})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: record.isLate
                        ? AppColors.dangerBg
                        : AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: record.isLate
                          ? AppColors.danger.withValues(alpha: 0.2)
                          : AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        record.isLate
                            ? Icons.alarm_on_rounded
                            : Icons.check_circle_rounded,
                        size: 13,
                        color: record.isLate ? AppColors.danger : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.isLate ? 'LATE' : 'ON TIME',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: record.isLate ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Late Warning Banner (If Late)
          if (record.isLate)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.warningBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Late Arrival: Checked in at $checkInStr (Shift Expected: $expectedStart)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309), // Warm amber dark
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppColors.border),

          // Timing Details Grid (4 Metrics: Expected, Check-In, Check-Out, Duration)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMetricColumn(
                    'Shift Expected',
                    expectedStart,
                    icon: Icons.schedule_rounded,
                    textColor: AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildMetricColumn(
                    'Check-In',
                    checkInStr,
                    icon: Icons.login_rounded,
                    textColor: record.isLate ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _buildMetricColumn(
                    'Check-Out',
                    checkOutStr,
                    icon: Icons.logout_rounded,
                    textColor: checkOutStr == 'In Progress' ? AppColors.info : AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _buildMetricColumn(
                    'Duration',
                    durationStr,
                    icon: Icons.timer_rounded,
                    textColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
    String label,
    String value, {
    IconData? icon,
    Color textColor = AppColors.textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
