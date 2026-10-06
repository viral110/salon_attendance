import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../controllers/staff_controller.dart';
import '../models/staff_model.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (Get.isRegistered<StaffController>()) {
        final controller = Get.find<StaffController>();
        if (controller.hasMorePages && !controller.isLoadingMore && !controller.isLoading) {
          controller.loadNextPage();
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StaffController>(
      init: Get.isRegistered<StaffController>()
          ? Get.find<StaffController>()
          : Get.put(StaffController()),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: CommonAppBar(
            title: 'Staff Directory',
            actions: [
              IconButton(
                tooltip: 'Refresh Staff',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                onPressed: () => controller.loadStaff(forceRefresh: true),
              ),
            ],
          ),
          body: ResponsiveCenter(
            maxWidth: 950,
            child: Column(
              children: [
                // Top Search & Filter Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Modern Search Input
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: controller.searchQuery.isNotEmpty
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: controller.setSearchQuery,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search staff by name, nickname, role...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      controller.setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All Staff',
                              count: controller.totalCount,
                              isSelected: controller.currentFilter == StaffFilter.all,
                              onTap: () => controller.setFilter(StaffFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Registered',
                              count: controller.registeredCount,
                              isSelected: controller.currentFilter == StaffFilter.registered,
                              activeColor: AppColors.success,
                              onTap: () => controller.setFilter(StaffFilter.registered),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Not Registered',
                              count: controller.notRegisteredCount,
                              isSelected: controller.currentFilter == StaffFilter.notRegistered,
                              activeColor: AppColors.warning,
                              onTap: () => controller.setFilter(StaffFilter.notRegistered),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Staff List
                Expanded(
                  child: controller.isLoading
                      ? ShimmerSkeleton.staffList(count: 5)
                      : controller.staffList.isEmpty
                          ? _buildEmptyState(controller)
                          : RefreshIndicator(
                              onRefresh: () => controller.loadStaff(forceRefresh: true),
                              color: AppColors.primary,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: controller.staffList.length +
                                    (controller.isLoadingMore ? 1 : 0),
                                itemBuilder: (ctx, index) {
                                  if (index == controller.staffList.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final staff = controller.staffList[index];
                                  return _buildStaffCard(context, staff, controller);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(BuildContext context, StaffModel staff, StaffController controller) {
    final isEnrolled = staff.faceEnrolled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Get.to(() => StaffDetailPage(staff: staff));
            controller.loadStaff();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Avatar with face registration badge dot
                Stack(
                  children: [
                    StaffAvatar(
                      imageUrl: staff.profilePicture,
                      name: staff.displayName,
                      radius: 26,
                      backgroundColor: isEnrolled
                          ? AppColors.primaryLight
                          : AppColors.surfaceVariant,
                      textColor: isEnrolled
                          ? AppColors.primary
                          : AppColors.textMuted,
                      fontSize: 18,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEnrolled
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: isEnrolled ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Staff Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Display Name (Nickname if available, otherwise Real Name)
                      Text(
                        staff.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Real Name (if Nickname is used)
                      if (staff.secondaryName != null) ...[
                        Text(
                          'Real: ${staff.secondaryName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Role & Staff ID
                      Row(
                        children: [
                          const Icon(
                            Icons.work_outline_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              staff.role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              staff.staffIdCode ?? 'ID: ${staff.id}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right side: Registration Badge & Chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge.faceStatus(isEnrolled),
                    const SizedBox(height: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(StaffController controller) {
    final query = controller.searchQuery.trim();
    final hasFilter = controller.currentFilter != StaffFilter.all || query.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              query.isNotEmpty
                  ? 'No staff found matching "$query"'
                  : 'No staff members found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'Try searching by full name, nickname, role, or staff ID.'
                  : 'There are currently no staff members registered in the system.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  controller.setSearchQuery('');
                  controller.setFilter(StaffFilter.all);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text(
                  'Clear Search & Filters',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
