import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/app_colors.dart';
import '../../controllers/face_attendance_controller.dart';
import '../../models/staff_model.dart';
import '../../services/attendance_service.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/common_button.dart';
import '../../widgets/face_scanner_overlay.dart';
import 'check_in_success_dialog.dart';
import 'check_out_success_dialog.dart';

class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => FaceAttendancePageState();
}

class FaceAttendancePageState extends State<FaceAttendancePage> {
  bool _hasPermission = false;
  bool _isPermissionChecking = true;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission(requestIfNotGranted: false);
  }

  void resumeScanning() {
    _checkCameraPermission(requestIfNotGranted: false);
  }

  void pauseScanning() {
    if (Get.isRegistered<FaceAttendanceController>()) {
      Get.find<FaceAttendanceController>().stopScanning();
    }
  }

  Future<void> _checkCameraPermission({bool requestIfNotGranted = true}) async {
    if (mounted) {
      setState(() {
        _isPermissionChecking = true;
      });
    }

    var status = await Permission.camera.status;
    if (!status.isGranted && requestIfNotGranted) {
      status = await Permission.camera.request();
    }

    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isPermissionChecking = false;
      });

      if (_hasPermission && Get.isRegistered<FaceAttendanceController>()) {
        Get.find<FaceAttendanceController>().initializeCamera();
      }
    }
  }

  void _showAttendanceResultDialog(FaceAttendanceController controller) {
    final staff = controller.matchedStaff;
    final result = controller.lastActionResult!;

    // If failure, or notification like already checked in / face not recognized / already completed
    if (!result.success ||
        result.action == AttendanceAction.alreadyCheckedIn ||
        result.action == AttendanceAction.notCheckedInYet ||
        result.action == AttendanceAction.alreadyCompleted ||
        result.isDuplicateProtection) {
      
      final String title;
      final IconData icon;
      final Color iconColor;

      final msgLower = result.message.toLowerCase();
      final errLower = (result.errors ?? '').toLowerCase();

      if (result.action == AttendanceAction.alreadyCheckedIn || msgLower.contains('already checked in') || errLower.contains('already checked in')) {
        title = result.message.isNotEmpty ? result.message : 'Already Checked In';
        icon = Icons.info_outline;
        iconColor = AppColors.info;
      } else if (result.action == AttendanceAction.notCheckedInYet) {
        title = result.message.isNotEmpty ? result.message : 'Not Checked In Yet';
        icon = Icons.warning_amber_rounded;
        iconColor = AppColors.warning;
      } else if (result.action == AttendanceAction.alreadyCompleted || msgLower.contains('already checked out') || errLower.contains('already checked out')) {
        title = result.message.isNotEmpty ? result.message : 'Attendance Completed Today';
        icon = Icons.check_circle_outline;
        iconColor = AppColors.success;
      } else if (msgLower.contains('not recognized') || errLower.contains('not recognized')) {
        title = result.message.isNotEmpty ? result.message : 'Face Not Recognized';
        icon = Icons.no_accounts_outlined;
        iconColor = AppColors.danger;
      } else {
        title = result.message.isNotEmpty ? result.message : 'Attendance Notification';
        icon = Icons.error_outline;
        iconColor = AppColors.danger;
      }

      final bodyText = (result.errors != null && result.errors!.trim().isNotEmpty)
          ? result.errors!
          : result.message;

      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (staff != null && staff.name.isNotEmpty && staff.name != 'Unknown') ...[
                Text(
                  'Hello ${staff.name},',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                bodyText,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
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
      ).then((_) {
        _isShowingDialog = false;
        controller.resetScanner();
      });
      return;
    }

    Widget dialog;
    final staffObj = staff ?? StaffModel(
      id: '0',
      name: 'Staff',
      isFaceRegistered: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (result.action == AttendanceAction.checkOut) {
      dialog = CheckOutSuccessDialog(
        staff: staffObj,
        attendance: result.attendance!,
      );
    } else {
      dialog = CheckInSuccessDialog(
        staff: staffObj,
        attendance: result.attendance!,
      );
    }

    Get.dialog(
      dialog,
      barrierDismissible: false,
    ).then((_) {
      _isShowingDialog = false;
      controller.resetScanner();
    });

    // Dismiss dialog automatically after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FaceAttendanceController>(
      init: Get.isRegistered<FaceAttendanceController>()
          ? Get.find<FaceAttendanceController>()
          : Get.put(FaceAttendanceController()),
      builder: (controller) {
        if (controller.showSuccessDialog &&
            controller.lastActionResult != null &&
            !_isShowingDialog) {
          _isShowingDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAttendanceResultDialog(controller);
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: CommonAppBar(
            title: 'Face Attendance',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Restart Scanner',
                onPressed: () => controller.initializeCamera(),
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
            'Camera access is required to perform face detection and attendance verification.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          CommonButton(
            label: 'Grant Camera Permission',
            onPressed: () => _checkCameraPermission(requestIfNotGranted: true),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorBar(FaceAttendanceController controller) {
    final currentMode = controller.selectedMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(204),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildModeSegment(
            controller: controller,
            label: 'Check-In',
            icon: Icons.login,
            mode: SelectedAttendanceMode.checkIn,
            isSelected: currentMode == SelectedAttendanceMode.checkIn,
          ),
          _buildModeSegment(
            controller: controller,
            label: 'Check-Out',
            icon: Icons.logout,
            mode: SelectedAttendanceMode.checkOut,
            isSelected: currentMode == SelectedAttendanceMode.checkOut,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegment({
    required FaceAttendanceController controller,
    required String label,
    required IconData icon,
    required SelectedAttendanceMode mode,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setSelectedMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(FaceAttendanceController controller) {
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

        // Scanner overlay with target frame & message banner
        FaceScannerOverlay(
          statusMessage: controller.statusMessage,
          validationStatus: controller.validationStatus,
          isProcessing: controller.isProcessingFrame,
          topOffset: 70.0,
          scanProgress: controller.scanProgress,
        ),

        // Mode selector top overlay
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: SafeArea(
            child: _buildModeSelectorBar(controller),
          ),
        ),

        // Start / Resume Scanning Floating Button if scanner is inactive
        if (!controller.isScanning && !controller.showSuccessDialog)
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: CommonButton(
              label: 'Start Face Scan',
              icon: Icons.play_arrow,
              onPressed: () => controller.startScanning(),
            ),
          ),
      ],
    );
  }
}
