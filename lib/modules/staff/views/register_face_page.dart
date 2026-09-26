import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/app_colors.dart';
import '../controllers/face_enrollment_controller.dart';
import '../models/staff_model.dart';
import '../../../services/staff_service.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/face_scanner_overlay.dart';

class RegisterFacePage extends StatefulWidget {
  final StaffModel? staff;

  const RegisterFacePage({
    super.key,
    this.staff,
  });

  @override
  State<RegisterFacePage> createState() => _RegisterFacePageState();
}

class _RegisterFacePageState extends State<RegisterFacePage> {
  bool _hasPermission = false;
  bool _isPermissionChecking = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final controller = Get.isRegistered<FaceEnrollmentController>()
        ? Get.find<FaceEnrollmentController>()
        : Get.put(FaceEnrollmentController());

    if (widget.staff != null) {
      controller.setStaff(widget.staff!);
    }

    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    if (mounted) {
      setState(() {
        _isPermissionChecking = true;
      });
    }

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isPermissionChecking = false;
      });

      if (_hasPermission && Get.isRegistered<FaceEnrollmentController>()) {
        final controller = Get.find<FaceEnrollmentController>();
        controller.initializeCamera();
      }
    }
  }

  Future<void> _handleSaveRegistration(FaceEnrollmentController controller) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final StaffFaceEnrollmentResponse response = await controller.registerFace();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (response.success) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text(
                'Face Enrolled!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Face enrollment for ${widget.staff?.name ?? "staff"} has been saved successfully.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Get.back(); // close dialog
                Get.back(); // return to previous screen
              },
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  response.message,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            response.errors ?? response.message,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.back(),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        barrierDismissible: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FaceEnrollmentController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: CommonAppBar(
            title: widget.staff != null
                ? 'Enroll Face (${widget.staff!.name})'
                : 'Enroll Staff Face',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Reset Scan',
                onPressed: () {
                  controller.resetEnrollment();
                  controller.initializeCamera();
                },
              ),
            ],
          ),
          body: _isPermissionChecking
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : !_hasPermission
                  ? _buildPermissionDeniedView()
                  : _buildCameraView(controller),
        );
      },
    );
  }

  Widget _buildPermissionDeniedView() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera Permission Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Camera access is required to perform 3D multi-pose face enrollment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          CommonButton(
            label: 'Grant Camera Permission',
            onPressed: _checkCameraPermission,
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressBar(FaceEnrollmentController controller) {
    final currentStep = controller.currentStep;

    final steps = [
      {'step': EnrollmentPoseStep.lookFront, 'title': '1. Front'},
      {'step': EnrollmentPoseStep.turnLeft, 'title': '2. Left'},
      {'step': EnrollmentPoseStep.turnRight, 'title': '3. Right'},
      {'step': EnrollmentPoseStep.smile, 'title': '4. Smile'},
    ];

    int stepIndex(EnrollmentPoseStep step) {
      switch (step) {
        case EnrollmentPoseStep.lookFront:
          return 0;
        case EnrollmentPoseStep.turnLeft:
          return 1;
        case EnrollmentPoseStep.turnRight:
          return 2;
        case EnrollmentPoseStep.smile:
          return 3;
        case EnrollmentPoseStep.completed:
          return 4;
      }
    }

    final activeIndex = stepIndex(currentStep);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isDone = activeIndex > idx;
          final isCurrent = activeIndex == idx;

          final Color bgColor = isDone
              ? AppColors.success
              : isCurrent
                  ? AppColors.primary
                  : Colors.white12;

          final Color textColor = isDone || isCurrent ? Colors.white : Colors.white60;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone) ...[
                  const Icon(Icons.check, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraView(FaceEnrollmentController controller) {
    if (controller.isInitializing || controller.cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (!controller.cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              controller.statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            CommonButton(
              label: 'Retry Camera',
              icon: Icons.refresh,
              onPressed: () => controller.initializeCamera(),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        CameraPreview(controller.cameraController!),

        // Scanner overlay with facial feature guides & posture targets
        FaceScannerOverlay(
          statusMessage: controller.statusMessage,
          validationStatus: controller.validationStatus,
          isProcessing: controller.isProcessing,
          topOffset: 75.0,
          scanProgress: controller.enrollmentProgress,
          poseStep: controller.currentStep,
          showFeatureGuides: true,
        ),

        // Step progress header overlay
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: SafeArea(
            child: _buildStepProgressBar(controller),
          ),
        ),

        // Bottom Action Area
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.isDuplicateDetected) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(220),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Duplicate face detected!\nThis face is already registered.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.resetEnrollment(),
                          child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (controller.currentStep == EnrollmentPoseStep.completed || controller.canSave) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSaving ? null : () => _handleSaveRegistration(controller),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                      label: Text(
                        _isSaving ? 'Saving Registration...' : 'Save Face Registration',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Enrollment progress bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Face Scan Progress',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${(controller.enrollmentProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: controller.enrollmentProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
