import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/staff_controller.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/staff_avatar.dart';
import 'staff_detail_page.dart';

class StaffListPage extends StatefulWidget {
  const StaffListPage({super.key});

  @override
  State<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StaffController>(
      init: Get.isRegistered<StaffController>() ? Get.find<StaffController>() : Get.put(StaffController()),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const CommonAppBar(
            title: 'Staff Directory',
          ),
          body: ResponsiveCenter(
            maxWidth: 950,
            child: Column(
              children: [
              // Search Input
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or role...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Staff List
              Expanded(
                child: controller.isLoading
                    ? ShimmerSkeleton.staffList(count: 5)
                    : controller.staffList.isEmpty
                        ? const Center(
                            child: Text(
                              'No staff members found.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: controller.staffList.length,
                            itemBuilder: (ctx, index) {
                              final staff = controller.staffList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  leading: StaffAvatar(
                                    imageUrl: staff.profilePicture,
                                    name: staff.name,
                                    radius: 24,
                                    backgroundColor: staff.faceEnrolled
                                        ? AppColors.primaryLight
                                        : AppColors.surfaceVariant,
                                    textColor: staff.faceEnrolled
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    fontSize: 16,
                                  ),
                                  title: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          staff.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge.faceStatus(staff.faceEnrolled),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${staff.role} • ${staff.staffIdCode ?? staff.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMuted,
                                  ),
                                  onTap: () async {
                                    await Get.to(() => StaffDetailPage(staff: staff));
                                    controller.loadStaff();
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}
