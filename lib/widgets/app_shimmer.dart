import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Animated Shimmer Effect container using a sliding LinearGradient mask
class AppShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const AppShimmer({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE2E4EB),
                Color(0xFFF8F9FE),
                Color(0xFFE2E4EB),
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.5 + (_controller.value * 3.5), -0.2),
              end: Alignment(1.5 + (_controller.value * 3.5), 0.2),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Helper container for drawing rounded skeleton shapes
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E4EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Presets for Shimmer Skeleton Views
class ShimmerSkeleton {
  /// 2x2 Grid of Stat Metric Cards (Dashboard & Staff Summary)
  static Widget statGrid({int count = 4, int crossAxisCount = 2, double childAspectRatio = 1.35}) {
    return AppShimmer(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
        children: List.generate(count, (_) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 38, height: 38, borderRadius: 10),
                    ShimmerBox(width: 48, height: 26, borderRadius: 6),
                  ],
                ),
                ShimmerBox(width: 90, height: 14, borderRadius: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Recent Activities List (Dashboard)
  static Widget activityList({int count = 4}) {
    return AppShimmer(
      child: Column(
        children: List.generate(count, (_) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                ShimmerBox(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 15, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 160, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 24, borderRadius: 12),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// History List Items (Attendance History Page)
  static Widget historyList({int count = 4}) {
    return AppShimmer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ShimmerBox(width: 36, height: 36, borderRadius: 18),
                        SizedBox(width: 10),
                        ShimmerBox(width: 110, height: 16, borderRadius: 4),
                      ],
                    ),
                    ShimmerBox(width: 80, height: 24, borderRadius: 12),
                  ],
                ),
                SizedBox(height: 8),
                ShimmerBox(width: 90, height: 12, borderRadius: 4),
                Divider(height: 20, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 50, height: 10, borderRadius: 3),
                        SizedBox(height: 4),
                        ShimmerBox(width: 65, height: 14, borderRadius: 4),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 50, height: 10, borderRadius: 3),
                        SizedBox(height: 4),
                        ShimmerBox(width: 65, height: 14, borderRadius: 4),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 50, height: 10, borderRadius: 3),
                        SizedBox(height: 4),
                        ShimmerBox(width: 65, height: 14, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Staff Directory Cards (Staff List Page)
  static Widget staffList({int count = 5}) {
    return AppShimmer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                ShimmerBox(width: 48, height: 48, borderRadius: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 110, height: 16, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBox(width: 70, height: 20, borderRadius: 10),
                        ],
                      ),
                      SizedBox(height: 6),
                      ShimmerBox(width: 140, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                ShimmerBox(width: 16, height: 16, borderRadius: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}
