import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/face_recognition_result.dart';
import '../../staff/models/staff_model.dart';
import '../../../services/attendance_service.dart';
import '../../../services/face_recognition_service.dart';
import '../../../services/staff_service.dart';
import '../../../utils/camera_image_converter.dart';

class FaceAttendanceController extends GetxController with WidgetsBindingObserver {
  final MLKitFaceRecognitionService _faceService = MLKitFaceRecognitionService();
  final AttendanceService _attendanceService = AttendanceService();
  final StaffService _staffService = StaffService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = false;
  bool _isScanning = false;
  bool _isProcessingFrame = false;

  String _statusMessage = 'Initializing camera...';
  FaceValidationStatus _validationStatus = FaceValidationStatus.valid;
  SelectedAttendanceMode _selectedMode = SelectedAttendanceMode.checkIn;

  StaffModel? _matchedStaff;
  AttendanceActionResult? _lastActionResult;
  bool _showSuccessDialog = false;

  DateTime? _lastScanTime;
  DateTime? _holdStartTime;
  double _scanProgress = 0.0;

  // Liveness anti-spoofing state
  bool _eyeBlinkVerified = false;
  bool _eyeClosedDetected = false;
  double? _lastLeftEyeProb;
  double? _lastRightEyeProb;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isInitializing => _isInitializing;
  bool get isScanning => _isScanning;
  bool get isProcessingFrame => _isProcessingFrame;
  String get statusMessage => _statusMessage;
  FaceValidationStatus get validationStatus => _validationStatus;
  SelectedAttendanceMode get selectedMode => _selectedMode;
  double get scanProgress => _scanProgress;
  StaffModel? get matchedStaff => _matchedStaff;
  AttendanceActionResult? get lastActionResult => _lastActionResult;
  bool get showSuccessDialog => _showSuccessDialog;
  bool get eyeBlinkVerified => _eyeBlinkVerified;

  void setSelectedMode(SelectedAttendanceMode mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    update();
  }

  FaceAttendanceController() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      stopScanning();
    } else if (state == AppLifecycleState.resumed) {
      ensureScanning();
    }
  }

  Future<void> initializeCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _statusMessage = 'Initializing camera...';
    update();

    try {
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
          await _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _statusMessage = 'No camera available on device.';
        _isInitializing = false;
        update();
        return;
      }

      // Select front camera if available
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
      _statusMessage = 'Searching for face...';
      startScanning();
    } catch (e) {
      _isInitializing = false;
      _statusMessage = 'Camera initialization failed: ${e.toString()}';
      update();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> refreshStaffCache() async {
    try {
      await _staffService.getAllStaff(forceRefresh: true);
      update();
    } catch (_) {}
  }

  void startScanning() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      initializeCamera();
      return;
    }

    _showSuccessDialog = false;
    _matchedStaff = null;
    _lastActionResult = null;
    _holdStartTime = null;
    _scanProgress = 0.0;
    _eyeBlinkVerified = false;
    _eyeClosedDetected = false;
    _lastLeftEyeProb = null;
    _lastRightEyeProb = null;
    _statusMessage = 'Searching for face...';
    _validationStatus = FaceValidationStatus.valid;

    // Refresh staff cache on scanner start
    refreshStaffCache();

    if (_cameraController!.value.isStreamingImages) {
      _isScanning = true;
      update();
      return;
    }

    _isScanning = true;
    update();

    try {
      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || !_isScanning || _showSuccessDialog) return;
        _processCameraFrame(image);
      });
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
      _isScanning = false;
      _statusMessage = 'Camera stream error. Tap to restart scanner.';
      update();
    }
  }

  void stopScanning() {
    if (!_isScanning && (_cameraController == null || !_cameraController!.value.isStreamingImages)) {
      return;
    }
    _isScanning = false;
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
    } catch (_) {}
    update();
  }

  /// Restarts or ensures scanning is actively running
  void ensureScanning() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      initializeCamera();
    } else if (!_isScanning || !_cameraController!.value.isStreamingImages) {
      startScanning();
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || !_isScanning || _showSuccessDialog) return;

    // Throttle frame processing (max 1 frame per 350ms)
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inMilliseconds < 350) {
      return;
    }
    _lastScanTime = now;
    _isProcessingFrame = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceService.detectFacesFromInputImage(inputImage);

      if (faces.isEmpty) {
        _statusMessage = 'No face detected.\nPlease position your face inside the frame.';
        _validationStatus = FaceValidationStatus.noFace;
        update();
        _isProcessingFrame = false;
        return;
      }

      if (faces.length > 1) {
        _statusMessage = 'Multiple faces detected.\nPlease make sure only one person is visible.';
        _validationStatus = FaceValidationStatus.multipleFaces;
        update();
        _isProcessingFrame = false;
        return;
      }

      final face = faces.first;
      final quality = _faceService.validateFaceQuality(
        face,
        image.width,
        image.height,
      );

      _validationStatus = quality;

      switch (quality) {
        case FaceValidationStatus.tooFar:
          _holdStartTime = null;
          _scanProgress = 0.0;
          _statusMessage = 'Move closer to the camera.';
          update();
          _isProcessingFrame = false;
          return;
        case FaceValidationStatus.tooClose:
          _holdStartTime = null;
          _scanProgress = 0.0;
          _statusMessage = 'Move slightly away from the camera.';
          update();
          _isProcessingFrame = false;
          return;
        case FaceValidationStatus.notCentered:
          _holdStartTime = null;
          _scanProgress = 0.0;
          _statusMessage = 'Please center your face inside the circle.';
          update();
          _isProcessingFrame = false;
          return;
        case FaceValidationStatus.severeAngle:
          _holdStartTime = null;
          _scanProgress = 0.0;
          _statusMessage = 'Look directly at the camera.';
          update();
          _isProcessingFrame = false;
          return;
        case FaceValidationStatus.lowQuality:
          _holdStartTime = null;
          _scanProgress = 0.0;
          _statusMessage = 'Full face & eyes must be visible in the circle.';
          update();
          _isProcessingFrame = false;
          return;
        default:
          break;
      }

      // Liveness / Eye Blink Anti-Spoofing Check
      final leftEyeProb = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeProb = face.rightEyeOpenProbability ?? 1.0;

      if (leftEyeProb < 0.40 || rightEyeProb < 0.40) {
        _eyeClosedDetected = true;
      }
      if (_eyeClosedDetected && leftEyeProb > 0.60 && rightEyeProb > 0.60) {
        _eyeBlinkVerified = true;
      }
      if ((_lastLeftEyeProb != null && (leftEyeProb - _lastLeftEyeProb!).abs() > 0.18) ||
          (_lastRightEyeProb != null && (rightEyeProb - _lastRightEyeProb!).abs() > 0.18)) {
        _eyeBlinkVerified = true;
      }
      _lastLeftEyeProb = leftEyeProb;
      _lastRightEyeProb = rightEyeProb;

      // Fast 0.25-Second Hold-to-Verify Logic (Reduced from 800ms for fast attendance)
      if (_holdStartTime == null) {
        _holdStartTime = DateTime.now();
        _scanProgress = 0.0;
        _eyeBlinkVerified = false;
        _eyeClosedDetected = false;
      }

      const double holdDurationMs = 250.0;
      final elapsedMs = now.difference(_holdStartTime!).inMilliseconds;
      _scanProgress = (elapsedMs / holdDurationMs).clamp(0.0, 1.0);

      if (_scanProgress < 1.0) {
        final percent = (_scanProgress * 100).toInt();
        _statusMessage = 'Face Detected! $percent%';
        update();
        _isProcessingFrame = false;
        return;
      }

      // Convert verified frame to JPEG base64
      final orientation = _cameraController?.description.sensorOrientation ?? 0;
      String? base64Image = CameraImageConverter.convertToJpegDataUri(
        image: image,
        sensorOrientation: orientation,
      );

      // Verification Completed -> Stop scanning & submit image directly to backend
      stopScanning();
      _statusMessage = 'Verifying face with backend server...';
      update();

      if ((base64Image == null || base64Image.isEmpty) && _cameraController != null && _cameraController!.value.isInitialized) {
        try {
          final file = await _cameraController!.takePicture();
          base64Image = await CameraImageConverter.convertXFileToJpegDataUri(file);
        } catch (_) {}
      }

      final faceEmbedding = _faceService.extractFaceEmbedding(
        face: face,
        image: image,
      );

      final actionResult = await _attendanceService.verifyFaceWithBackend(
        imageBase64: base64Image ?? '',
        faceEmbedding: faceEmbedding,
        selectedMode: _selectedMode,
      );

      _lastActionResult = actionResult;
      _matchedStaff = actionResult.staff;
      _showSuccessDialog = true;
      _statusMessage = actionResult.message;
      update();

      // Automatically reset scanner after 1.5 seconds delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        resetScanner();
      });
    } catch (e) {
      _statusMessage = 'Verification error: ${e.toString()}';
      update();
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    return CameraImageConverter.convertToInputImage(
      image: image,
      camera: _cameraController!.description,
    );
  }

  void resetScanner() {
    _showSuccessDialog = false;
    _matchedStaff = null;
    _lastActionResult = null;
    _holdStartTime = null;
    _scanProgress = 0.0;
    _validationStatus = FaceValidationStatus.valid;
    startScanning();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopScanning();
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }
}
