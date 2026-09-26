import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../modules/staff/controllers/face_enrollment_controller.dart';
import '../modules/attendance/models/face_recognition_result.dart';

class FaceScannerOverlay extends StatelessWidget {
  final String statusMessage;
  final FaceValidationStatus validationStatus;
  final bool isProcessing;
  final String? instructionHeader;
  final double topOffset;
  final double scanProgress;
  final EnrollmentPoseStep? poseStep;
  final bool showFeatureGuides;

  const FaceScannerOverlay({
    super.key,
    required this.statusMessage,
    this.validationStatus = FaceValidationStatus.valid,
    this.isProcessing = false,
    this.instructionHeader,
    this.topOffset = 16.0,
    this.scanProgress = 0.0,
    this.poseStep,
    this.showFeatureGuides = false,
  });

  Color _getFrameColor() {
    switch (validationStatus) {
      case FaceValidationStatus.valid:
        return AppColors.scannerFrameValid;
      case FaceValidationStatus.tooFar:
      case FaceValidationStatus.tooClose:
      case FaceValidationStatus.notCentered:
        return AppColors.scannerFrameWarning;
      case FaceValidationStatus.noFace:
      case FaceValidationStatus.multipleFaces:
      case FaceValidationStatus.severeAngle:
      case FaceValidationStatus.lowQuality:
        return AppColors.scannerFrameInvalid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = _getFrameColor();

    return Stack(
      children: [
        // Semi-transparent cutout overlay painter with circular progress ring & dotted pose guides
        CustomPaint(
          size: Size.infinite,
          painter: ScannerCutoutPainter(
            borderColor: frameColor,
            scanProgress: scanProgress,
            poseStep: poseStep,
            showFeatureGuides: showFeatureGuides || poseStep != null,
          ),
        ),

        // Single Top Status & Instruction Banner (No duplicate bottom box)
        Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (instructionHeader != null) ...[
                Text(
                  instructionHeader!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(204),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: frameColor.withAlpha(180), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: frameColor.withAlpha(40),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isProcessing) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(frameColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      Icon(
                        validationStatus == FaceValidationStatus.valid
                            ? Icons.check_circle
                            : validationStatus == FaceValidationStatus.noFace
                                ? Icons.face_retouching_off
                                : Icons.info_outline,
                        color: frameColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: frameColor == AppColors.scannerFrameValid ? Colors.white : frameColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ScannerCutoutPainter extends CustomPainter {
  final Color borderColor;
  final double scanProgress;
  final EnrollmentPoseStep? poseStep;
  final bool showFeatureGuides;

  ScannerCutoutPainter({
    required this.borderColor,
    this.scanProgress = 0.0,
    this.poseStep,
    this.showFeatureGuides = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = size.width * 0.41;
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    final circlePath = Path()..addOval(circleRect);

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      circlePath,
    );

    final darkOverlayPaint = Paint()
      ..color = Colors.black.withAlpha(210)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, darkOverlayPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(center, radius, borderPaint);

    // Dotted Facial Feature Alignment Guides (Eyes, Nose, Mouth) - ONLY shown during Registration
    if (showFeatureGuides) {
      final featureDotPaint = Paint()
        ..color = borderColor.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final featureFillPaint = Paint()
        ..color = borderColor.withAlpha(180)
        ..style = PaintingStyle.fill;

      // Left Eye Dotted Target Circle (Accurate Y: center.dy - radius * 0.32)
      final leftEyeCenter = Offset(center.dx - radius * 0.28, center.dy - radius * 0.32);
      canvas.drawCircle(leftEyeCenter, radius * 0.11, featureDotPaint);
      canvas.drawCircle(leftEyeCenter, 3.5, featureFillPaint);

      // Right Eye Dotted Target Circle (Accurate Y: center.dy - radius * 0.32)
      final rightEyeCenter = Offset(center.dx + radius * 0.28, center.dy - radius * 0.32);
      canvas.drawCircle(rightEyeCenter, radius * 0.11, featureDotPaint);
      canvas.drawCircle(rightEyeCenter, 3.5, featureFillPaint);

      // Nose Bridge Line & Tip Target
      final noseTop = Offset(center.dx, center.dy - radius * 0.14);
      final noseTip = Offset(center.dx, center.dy + radius * 0.04);
      canvas.drawLine(noseTop, noseTip, featureDotPaint);
      canvas.drawCircle(noseTip, 3.5, featureFillPaint);

      // Mouth / Lip Curve Target
      final mouthRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.25),
        width: radius * 0.42,
        height: radius * 0.18,
      );
      canvas.drawArc(mouthRect, 0.2, pi - 0.4, false, featureDotPaint);
    }

    // Dotted Outer Ring for Step-wise Pose Alignment Guidance
    final outerRadius = radius + 12;
    final dashPaint = Paint()
      ..color = borderColor.withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const int totalDashes = 36;
    const double dashAngle = (2 * pi) / totalDashes;

    for (int i = 0; i < totalDashes; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        i * dashAngle,
        dashAngle,
        false,
        dashPaint,
      );
    }

    // Step-wise Target Position Indicators
    if (poseStep != null) {
      final activeDotPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;

      switch (poseStep!) {
        case EnrollmentPoseStep.lookFront:
          canvas.drawCircle(Offset(center.dx, center.dy - outerRadius), 8.0, activeDotPaint);
          break;
        case EnrollmentPoseStep.turnLeft:
          final leftArcPaint = Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: outerRadius),
            pi * 0.75,
            pi * 0.5,
            false,
            leftArcPaint,
          );
          canvas.drawCircle(Offset(center.dx - outerRadius, center.dy), 9.0, activeDotPaint);
          break;
        case EnrollmentPoseStep.turnRight:
          final rightArcPaint = Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: outerRadius),
            -pi * 0.25,
            pi * 0.5,
            false,
            rightArcPaint,
          );
          canvas.drawCircle(Offset(center.dx + outerRadius, center.dy), 9.0, activeDotPaint);
          break;
        case EnrollmentPoseStep.smile:
          final smileArcPaint = Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: outerRadius),
            pi * 0.25,
            pi * 0.5,
            false,
            smileArcPaint,
          );
          canvas.drawCircle(Offset(center.dx, center.dy + outerRadius), 9.0, activeDotPaint);
          break;
        case EnrollmentPoseStep.completed:
          final successRingPaint = Paint()
            ..color = AppColors.success
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0;
          canvas.drawCircle(center, outerRadius, successRingPaint);
          break;
      }
    }

    // 3-Second Progress Arc Overlay
    if (scanProgress > 0.0) {
      final progressPaint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * scanProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // Start at 12 o'clock
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScannerCutoutPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.scanProgress != scanProgress ||
        oldDelegate.poseStep != poseStep;
  }
}
