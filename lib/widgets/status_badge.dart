import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../modules/attendance/models/attendance_model.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.fromAttendanceStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.checkedIn:
        return const StatusBadge(
          label: 'Checked In',
          backgroundColor: AppColors.infoBg,
          textColor: AppColors.info,
          icon: Icons.login,
        );
      case AttendanceStatus.checkedOut:
        return const StatusBadge(
          label: 'Checked Out',
          backgroundColor: AppColors.successBg,
          textColor: AppColors.success,
          icon: Icons.logout,
        );
      case AttendanceStatus.incomplete:
        return const StatusBadge(
          label: 'Incomplete',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
          icon: Icons.pending,
        );
    }
  }

  factory StatusBadge.faceStatus(bool isEnrolled) {
    return isEnrolled
        ? const StatusBadge(
            label: '✓ Registered',
            backgroundColor: AppColors.successBg,
            textColor: AppColors.success,
          )
        : const StatusBadge(
            label: 'Not Registered',
            backgroundColor: AppColors.dangerBg,
            textColor: AppColors.danger,
          );
  }

  factory StatusBadge.activeStatus(bool isActive) {
    return isActive
        ? const StatusBadge(
            label: 'Active',
            backgroundColor: AppColors.successBg,
            textColor: AppColors.success,
          )
        : const StatusBadge(
            label: 'Inactive',
            backgroundColor: AppColors.dangerBg,
            textColor: AppColors.danger,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
