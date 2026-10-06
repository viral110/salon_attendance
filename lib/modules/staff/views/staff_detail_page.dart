import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_colors.dart';
import '../controllers/staff_controller.dart';
import '../models/staff_model.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/staff_avatar.dart';
import 'register_face_page.dart';
import 'staff_attendance_summary_page.dart';

class StaffDetailPage extends StatelessWidget {
  final StaffModel staff;

  const StaffDetailPage({
    super.key,
    required this.staff,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StaffController>(
      init: Get.isRegistered<StaffController>()
          ? Get.find<StaffController>()
          : Get.put(StaffController()),
      builder: (controller) {
        final currentStaff = controller.staffList.firstWhere(
          (s) => s.id == staff.id || s.dbId == staff.dbId,
          orElse: () => staff,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: CommonAppBar(
            title: currentStaff.displayName,
            showBackButton: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ResponsiveCenter(
              maxWidth: 850,
              child: Column(
                children: [
                  // Profile Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        StaffAvatar(
                          imageUrl: currentStaff.profilePicture,
                          name: currentStaff.displayName,
                          radius: 40,
                          backgroundColor: const Color(0xFFEFF2FE),
                          textColor: const Color(0xFF4F46E5),
                          fontSize: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentStaff.displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (currentStaff.secondaryName != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: Text(
                              'Real Name: ${currentStaff.secondaryName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${currentStaff.role} • ${currentStaff.staffIdCode ?? "STAFF_${currentStaff.id}"}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Face Status: ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (currentStaff.faceEnrolled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F8F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check,
                                        size: 14, color: Color(0xFF00A86B)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Registered',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF00A86B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDE8E8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Not Registered',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE53E3E),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Face Recognition Settings Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Face Recognition Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!currentStaff.faceEnrolled) ...[
                          // Register Face Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.badge_outlined,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                'Register Face',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () async {
                                await Get.to(() => RegisterFacePage(staff: currentStaff));
                                controller.loadStaff(forceRefresh: true);
                              },
                            ),
                          ),
                        ] else ...[
                          // Update Face Template & Remove Face Registration
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              icon: const Icon(Icons.refresh,
                                  color: AppColors.textPrimary, size: 20),
                              label: const Text(
                                'Update Face Template',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              onPressed: () async {
                                await Get.to(() => RegisterFacePage(staff: currentStaff));
                                controller.loadStaff(forceRefresh: true);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                'Remove Face Registration',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () =>
                                  _confirmRemoveFace(context, controller, currentStaff),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // View Staff Attendance Summary Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      icon: const Icon(Icons.insert_chart_outlined_rounded,
                          color: AppColors.textPrimary, size: 22),
                      label: const Text(
                        'View Staff Attendance Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onPressed: () {
                        Get.to(() => StaffAttendanceSummaryPage(staff: currentStaff));
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

  void _confirmRemoveFace(
      BuildContext context, StaffController controller, StaffModel staff) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Face Registration',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to remove face registration for ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Get.back();
              final success = await controller.removeFaceRegistration(staff);
              if (success) {
                Get.snackbar(
                  'Success',
                  'Face registration removed successfully',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.black87,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(16),
                );
              } else {
                Get.snackbar(
                  'Error',
                  'Failed to remove face registration',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(16),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
