import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../config/face_recognition_config.dart';
import '../../attendance/models/face_recognition_result.dart';
import '../models/staff_model.dart';
import '../../../services/face_recognition_service.dart';
import '../../../services/staff_service.dart';
import '../../../utils/camera_image_converter.dart';
import 'staff_controller.dart';

enum EnrollmentPoseStep {
  lookFront,
  turnLeft,
  turnRight,
  smile,
  completed,
}

class FaceEnrollmentController extends GetxController with WidgetsBindingObserver {
  final MLKitFaceRecognitionService _faceService = MLKitFaceRecognitionService();
  final StaffService _staffService = StaffService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = false;
  bool _isProcessing = false;
  bool _isEnrolledSuccess = false;
  bool _isDuplicateDetected = false;

  String _statusMessage = 'Initializing camera...';
  FaceValidationStatus _validationStatus = FaceValidationStatus.valid;
  EnrollmentPoseStep _currentStep = EnrollmentPoseStep.lookFront;

  StaffModel? _targetStaff;
  final List<List<double>> _collectedTemplates = [];

  // Pose template counters
  int _frontCount = 0;
  int _leftCount = 0;
  int _rightCount = 0;
  int _smileCount = 0;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isInitializing => _isInitializing;
  bool get isProcessing => _isProcessing;
  bool get isEnrolledSuccess => _isEnrolledSuccess;
  bool get isDuplicateDetected => _isDuplicateDetected;
  bool get canSave => !_isDuplicateDetected && _currentStep == EnrollmentPoseStep.completed;
  String get statusMessage => _statusMessage;
  FaceValidationStatus get validationStatus => _validationStatus;
  EnrollmentPoseStep get currentStep => _currentStep;
  StaffModel? get targetStaff => _targetStaff;
  List<List<double>> get collectedTemplates => _collectedTemplates;
  double get enrollmentProgress => (_collectedTemplates.length / 8.0).clamp(0.0, 1.0);
  List<double>? get capturedEmbedding => _collectedTemplates.isNotEmpty ? _collectedTemplates.first : null;

  FaceEnrollmentController() {
    WidgetsBinding.instance.addObserver(this);
  }

  void setStaff(StaffModel staff) {
    _targetStaff = staff;
    _isEnrolledSuccess = false;
    _isDuplicateDetected = false;
    _collectedTemplates.clear();
    _frontCount = 0;
    _leftCount = 0;
    _rightCount = 0;
    _smileCount = 0;
    _currentStep = EnrollmentPoseStep.lookFront;
    _statusMessage = 'Step 1/4: Look directly at camera';
    update();
  }

  void resetEnrollment() {
    _isEnrolledSuccess = false;
    _isDuplicateDetected = false;
    _collectedTemplates.clear();
    _frontCount = 0;
    _leftCount = 0;
    _rightCount = 0;
    _smileCount = 0;
    _currentStep = EnrollmentPoseStep.lookFront;
    _statusMessage = 'Step 1/4: Position face & look straight';
    update();
  }

  Future<void> initializeCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _statusMessage = 'Initializing camera...';
    update();

    try {
      if (_cameraController != null) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
        await _cameraController!.dispose();
        _cameraController = null;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _statusMessage = 'No camera available on device.';
        _isInitializing = false;
        update();
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      await _faceService.initialize();

      _isInitializing = false;
      _statusMessage = 'Step 1/4: Position face & look straight';
      update();

      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessing || _isEnrolledSuccess || _currentStep == EnrollmentPoseStep.completed) return;
        _processEnrollmentFrame(image);
      });
    } catch (e) {
      _isInitializing = false;
      _statusMessage = 'Camera error: ${e.toString()}';
      update();
    }
  }

  Future<void> _processEnrollmentFrame(CameraImage image) async {
    if (_isProcessing || _isEnrolledSuccess || _currentStep == EnrollmentPoseStep.completed) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceService.detectFacesFromInputImage(inputImage);

      if (faces.isEmpty) {
        _statusMessage = 'No face detected.\nPosition your face in the circle.';
        _validationStatus = FaceValidationStatus.noFace;
        update();
        _isProcessing = false;
        return;
      }

      if (faces.length > 1) {
        _statusMessage = 'Multiple faces detected.\nEnsure only one person is visible.';
        _validationStatus = FaceValidationStatus.multipleFaces;
        update();
        _isProcessing = false;
        return;
      }

      final face = faces.first;
      final quality = _faceService.validateFaceQuality(
        face,
        image.width,
        image.height,
      );

      _validationStatus = quality;

      if (quality != FaceValidationStatus.valid && _currentStep == EnrollmentPoseStep.lookFront) {
        _updateStatusForQuality(quality);
        _isProcessing = false;
        return;
      }

      // Extract 80D facial geometry vector
      final candidateEmbedding = _faceService.extractFaceEmbedding(face: face, image: image);

      // Live Duplicate Check against other enrolled staff members
      final enrolledStaff = await _staffService.getEnrolledActiveStaff();
      bool foundDuplicate = false;
      for (final existing in enrolledStaff) {
        final isSelf = _targetStaff != null &&
            (existing.id == _targetStaff!.id ||
                existing.dbId == _targetStaff!.dbId ||
                (existing.dbId > 0 && _targetStaff!.dbId > 0 && existing.dbId == _targetStaff!.dbId) ||
                (existing.staffIdCode != null && _targetStaff!.staffIdCode != null && existing.staffIdCode == _targetStaff!.staffIdCode) ||
                existing.name.trim().toLowerCase() == _targetStaff!.name.trim().toLowerCase());
        if (isSelf) continue;

        final templates = existing.faceTemplates ??
            (existing.faceEmbedding != null ? [existing.faceEmbedding!] : []);
        for (final tmpl in templates) {
          // Ignore legacy short test vectors (< 60D) from API test data
          if (tmpl.length < 60) continue;

          final similarity = _faceService.computeCosineSimilarity(candidateEmbedding, tmpl);
          if (similarity >= FaceRecognitionConfig.duplicateThreshold) {
            foundDuplicate = true;
            _isDuplicateDetected = true;
            _validationStatus = FaceValidationStatus.lowQuality;
            _statusMessage = '⚠️ Duplicate Face Detected!\nThis face is already registered to "${existing.name}".';
            update();
            _isProcessing = false;
            return;
          }
        }
      }

      if (!foundDuplicate) {
        _isDuplicateDetected = false;
      }

      // Smartphone Pose Angle Setup Pipeline
      final rotY = face.headEulerAngleY ?? 0.0; // Positive = Left, Negative = Right

      switch (_currentStep) {
        case EnrollmentPoseStep.lookFront:
          if (rotY.abs() <= 10.0) {
            _collectedTemplates.add(candidateEmbedding);
            _frontCount++;
            if (_frontCount >= 2) {
              _currentStep = EnrollmentPoseStep.turnLeft;
              _statusMessage = 'Step 1/4 Complete ✓\nNow turn head slightly to LEFT';
            } else {
              _statusMessage = 'Step 1/4: Look straight at camera';
            }
          } else {
            _statusMessage = 'Step 1/4: Look straight at camera';
          }
          break;

        case EnrollmentPoseStep.turnLeft:
          if (rotY >= 8.0 && rotY <= 30.0) {
            _collectedTemplates.add(candidateEmbedding);
            _leftCount++;
            if (_leftCount >= 2) {
              _currentStep = EnrollmentPoseStep.turnRight;
              _statusMessage = 'Step 2/4 Complete ✓\nNow turn head slightly to RIGHT';
            } else {
              _statusMessage = 'Step 2/4: Hold left angle...';
            }
          } else {
            _statusMessage = 'Step 2/4: Turn head slightly to LEFT';
          }
          break;

        case EnrollmentPoseStep.turnRight:
          if (rotY <= -8.0 && rotY >= -30.0) {
            _collectedTemplates.add(candidateEmbedding);
            _rightCount++;
            if (_rightCount >= 2) {
              _currentStep = EnrollmentPoseStep.smile;
              _statusMessage = 'Step 3/4 Complete ✓\nNow look straight and SMILE';
            } else {
              _statusMessage = 'Step 3/4: Hold right angle...';
            }
          } else {
            _statusMessage = 'Step 3/4: Turn head slightly to RIGHT';
          }
          break;

        case EnrollmentPoseStep.smile:
          if (rotY.abs() <= 12.0) {
            _collectedTemplates.add(candidateEmbedding);
            _smileCount++;
            if (_smileCount >= 2) {
              _currentStep = EnrollmentPoseStep.completed;
              _statusMessage = '🎉 All Face Poses Captured!\nTap "Save Face Registration" below.';
            } else {
              _statusMessage = 'Step 4/4: Look straight & smile...';
            }
          } else {
            _statusMessage = 'Step 4/4: Look straight & SMILE';
          }
          break;

        case EnrollmentPoseStep.completed:
          _statusMessage = '🎉 All Face Poses Captured!\nTap "Save Face Registration" below.';
          break;
      }

      update();
    } catch (e) {
      _statusMessage = 'Processing error: ${e.toString()}';
      update();
    } finally {
      _isProcessing = false;
    }
  }

  void _updateStatusForQuality(FaceValidationStatus quality) {
    switch (quality) {
      case FaceValidationStatus.tooFar:
        _statusMessage = 'Move closer to the camera.';
        break;
      case FaceValidationStatus.tooClose:
        _statusMessage = 'Move slightly away from camera.';
        break;
      case FaceValidationStatus.notCentered:
        _statusMessage = 'Center your face in the circle.';
        break;
      case FaceValidationStatus.severeAngle:
        _statusMessage = 'Look directly at the camera.';
        break;
      case FaceValidationStatus.lowQuality:
        _statusMessage = 'Full face & eyes must be visible in circle.';
        break;
      default:
        break;
    }
    update();
  }

  /// Finalize staff face enrollment with multi-template duplicate detection
  Future<StaffFaceEnrollmentResponse> registerFace() async {
    if (_targetStaff == null) {
      return StaffFaceEnrollmentResponse(
        success: false,
        message: 'No target staff selected for enrollment.',
      );
    }

    if (_isDuplicateDetected) {
      return StaffFaceEnrollmentResponse(
        success: false,
        message: 'Duplicate Face Detected',
        errors: _statusMessage,
      );
    }

    if (_collectedTemplates.isEmpty) {
      return StaffFaceEnrollmentResponse(
        success: false,
        message: 'Scan Incomplete',
        errors: 'Please complete face pose scanning before saving.',
      );
    }

    try {
      // Check duplicate face against existing enrolled staff members
      final enrolledStaff = await _staffService.getEnrolledActiveStaff();
      for (final existing in enrolledStaff) {
        final isSelf = existing.id == _targetStaff!.id ||
            existing.dbId == _targetStaff!.dbId ||
            (existing.dbId > 0 && _targetStaff!.dbId > 0 && existing.dbId == _targetStaff!.dbId) ||
            (existing.staffIdCode != null && _targetStaff!.staffIdCode != null && existing.staffIdCode == _targetStaff!.staffIdCode) ||
            existing.name.trim().toLowerCase() == _targetStaff!.name.trim().toLowerCase();
        if (isSelf) continue;

        final templates = existing.faceTemplates ??
            (existing.faceEmbedding != null ? [existing.faceEmbedding!] : []);

        for (final myTmpl in _collectedTemplates) {
          for (final existingTmpl in templates) {
            if (existingTmpl.length < 60) continue;

            final similarity = _faceService.computeCosineSimilarity(myTmpl, existingTmpl);
            if (similarity >= FaceRecognitionConfig.duplicateThreshold) {
              _statusMessage = 'This face is already registered to "${existing.name}".\nEach staff member must register their own face.';
              update();
              return StaffFaceEnrollmentResponse(
                success: false,
                message: 'Duplicate Face Detected',
                errors: 'This face is already registered to "${existing.name}". Each staff member must register their own face.',
              );
            }
          }
        }
      }

      // Save multi-pose template list
      final primaryEmbedding = _collectedTemplates.first;
      final updatedStaff = _targetStaff!.copyWith(
        faceEnrolled: true,
        faceEmbedding: primaryEmbedding,
        faceTemplates: _collectedTemplates,
      );

      final apiRes = await _staffService.enrollStaffFace(
        staffId: updatedStaff.dbId > 0 ? updatedStaff.dbId : updatedStaff.id,
        faceEmbedding: primaryEmbedding,
        faceTemplates: _collectedTemplates,
      );

      if (apiRes.success) {
        // Update full profile with templates
        await _staffService.updateStaffProfile(updatedStaff);

        if (Get.isRegistered<StaffController>()) {
          await Get.find<StaffController>().loadStaff(forceRefresh: true);
        }

        _isEnrolledSuccess = true;
        _statusMessage = 'Face Enrolled Successfully!';
        update();
      } else {
        _isDuplicateDetected = true;
        _statusMessage = apiRes.errors ?? apiRes.message;
        update();
      }

      return apiRes;
    } catch (e) {
      _statusMessage = 'Enrollment failed: ${e.toString()}';
      update();
      return StaffFaceEnrollmentResponse(
        success: false,
        message: 'Enrollment Failed',
        errors: e.toString(),
      );
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    return CameraImageConverter.convertToInputImage(
      image: image,
      camera: _cameraController!.description,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }
}
