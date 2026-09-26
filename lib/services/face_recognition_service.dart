import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:salon_attendance/models/staff_model.dart';

import '../config/face_recognition_config.dart';
import '../models/face_recognition_result.dart';

abstract class FaceRecognitionService {
  Future<void> initialize();
  Future<FaceRecognitionResult> recognizeFace({
    required Face face,
    required CameraImage image,
    required List<StaffModel> enrolledStaff,
  });
  List<double> extractFaceEmbedding({
    required Face face,
    required CameraImage image,
  });
  double computeCosineSimilarity(List<double> v1, List<double> v2);
  FaceValidationStatus validateFaceQuality(Face face, int frameWidth, int frameHeight);
  Future<void> dispose();
}

class MLKitFaceRecognitionService implements FaceRecognitionService {
  late final FaceDetector _faceDetector;
  bool _isInitialized = false;

  MLKitFaceRecognitionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Eye open & smile probabilities
        enableLandmarks: true, // Eye, nose, mouth landmarks
        enableContours: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: FaceRecognitionConfig.minFaceSizeRatio,
      ),
    );
  }

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  /// Processes camera frame with ML Kit face detector.
  Future<List<Face>> detectFacesFromInputImage(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  @override
  FaceValidationStatus validateFaceQuality(Face face, int rawWidth, int rawHeight) {
    final boundingBox = face.boundingBox;

    // 1. Minimum face dimension check
    if (boundingBox.width < 45 || boundingBox.height < 45) {
      return FaceValidationStatus.tooFar;
    }

    // 2. Head Rotation Angle Validation (Bug 2: Reject faces turned sideways or tilted)
    final rotY = (face.headEulerAngleY ?? 0.0).abs(); // Yaw (sideways turn)
    final rotZ = (face.headEulerAngleZ ?? 0.0).abs(); // Roll (head tilt)
    final rotX = (face.headEulerAngleX ?? 0.0).abs(); // Pitch (up/down)

    if (rotY > 18.0 || rotZ > 18.0 || rotX > 15.0) {
      return FaceValidationStatus.severeAngle;
    }

    // 3. Border Clipping Check (Reject faces cut off at camera frame borders)
    if (boundingBox.left < 8 ||
        boundingBox.top < 8 ||
        boundingBox.right > rawWidth - 8 ||
        boundingBox.bottom > rawHeight - 8) {
      return FaceValidationStatus.notCentered;
    }

    // 4. Require actual MLKit Eye & Nose landmarks/contours (prevent forehead/partial face extraction)
    final hasLeftEye = face.landmarks[FaceLandmarkType.leftEye] != null ||
        (face.contours[FaceContourType.leftEye]?.points.isNotEmpty ?? false);
    final hasRightEye = face.landmarks[FaceLandmarkType.rightEye] != null ||
        (face.contours[FaceContourType.rightEye]?.points.isNotEmpty ?? false);
    final hasNose = face.landmarks[FaceLandmarkType.noseBase] != null ||
        (face.contours[FaceContourType.noseBridge]?.points.isNotEmpty ?? false);

    if (!hasLeftEye || !hasRightEye || !hasNose) {
      return FaceValidationStatus.lowQuality;
    }

    // 5. Calculate face center in portrait coordinate space & target containment
    final int frameW = rawWidth > rawHeight ? rawHeight : rawWidth;
    final int frameH = rawWidth > rawHeight ? rawWidth : rawWidth;

    final normX = boundingBox.center.dx / frameW;
    final normY = boundingBox.center.dy / frameH;

    // Center target is at (0.50, 0.44). Containment radius tolerance 0.32
    final dx = normX - 0.50;
    final dy = normY - 0.44;
    final distFromCenter = sqrt(dx * dx + dy * dy);

    if (distFromCenter > 0.32) {
      return FaceValidationStatus.notCentered;
    }

    return FaceValidationStatus.valid;
  }

  Point<double> _getLandmarkOrFallback(Face face, FaceLandmarkType type, double relX, double relY) {
    final landmark = face.landmarks[type]?.position;
    if (landmark != null) {
      return Point<double>(landmark.x.toDouble(), landmark.y.toDouble());
    }
    final box = face.boundingBox;
    return Point<double>(box.left + box.width * relX, box.top + box.height * relY);
  }

  List<Point<double>> _getContourOrFallback(Face face, FaceContourType type, int targetCount, List<Point<double>> fallbackPoints) {
    final contour = face.contours[type];
    if (contour != null && contour.points.isNotEmpty) {
      final pts = contour.points;
      final result = <Point<double>>[];
      if (pts.length <= targetCount) {
        for (var p in pts) {
          result.add(Point<double>(p.x.toDouble(), p.y.toDouble()));
        }
        while (result.length < targetCount) {
          result.add(result.last);
        }
      } else {
        final step = (pts.length - 1) / (targetCount - 1);
        for (int i = 0; i < targetCount; i++) {
          final idx = (i * step).round().clamp(0, pts.length - 1);
          final p = pts[idx];
          result.add(Point<double>(p.x.toDouble(), p.y.toDouble()));
        }
      }
      return result;
    }
    return fallbackPoints;
  }

  /// Extracts a canonical, pose-aligned and scale-invariant geometric face embedding.
  /// Fixed vector length: 70 doubles (60 canonical coordinates + 10 facial geometry ratios).
  @override
  List<double> extractFaceEmbedding({
    required Face face,
    required CameraImage image,
  }) {
    final box = face.boundingBox;
    final boxWidth = box.width > 0 ? box.width.toDouble() : 100.0;
    final boxHeight = box.height > 0 ? box.height.toDouble() : 100.0;

    // Retrieve Eye landmarks/contours
    final leftEyeLandmark = _getLandmarkOrFallback(face, FaceLandmarkType.leftEye, 0.65, 0.35);
    final rightEyeLandmark = _getLandmarkOrFallback(face, FaceLandmarkType.rightEye, 0.35, 0.35);

    // Standardize ordering in image space: eyeImageLeft has smaller X, eyeImageRight has larger X
    final Point<double> eyeImageLeft;
    final Point<double> eyeImageRight;
    if (leftEyeLandmark.x < rightEyeLandmark.x) {
      eyeImageLeft = leftEyeLandmark;
      eyeImageRight = rightEyeLandmark;
    } else {
      eyeImageLeft = rightEyeLandmark;
      eyeImageRight = leftEyeLandmark;
    }

    final eyeDx = eyeImageRight.x - eyeImageLeft.x;
    final eyeDy = eyeImageRight.y - eyeImageLeft.y;
    double interEyeDist = sqrt(eyeDx * eyeDx + eyeDy * eyeDy);
    if (interEyeDist <= 0) {
      interEyeDist = boxWidth * 0.35;
    }

    final eyeCenterX = (eyeImageLeft.x + eyeImageRight.x) / 2.0;
    final eyeCenterY = (eyeImageLeft.y + eyeImageRight.y) / 2.0;

    final angle = atan2(eyeDy, eyeDx);
    final cosA = cos(-angle);
    final sinA = sin(-angle);

    Point<double> toCanonical(Point<double> p) {
      final dx = p.x - eyeCenterX;
      final dy = p.y - eyeCenterY;
      final rotX = (dx * cosA - dy * sinA) / interEyeDist;
      final rotY = (dx * sinA + dy * cosA) / interEyeDist;
      return Point<double>(rotX, rotY);
    }

    // Build fixed 30-point landmark schema
    final points = <Point<double>>[];

    // 0: Nose Base
    final noseBase = _getLandmarkOrFallback(face, FaceLandmarkType.noseBase, 0.50, 0.55);
    points.add(noseBase);

    // 1: Nose Bridge Top
    points.add(Point<double>(box.left + boxWidth * 0.50, box.top + boxHeight * 0.40));

    // 2: Left Mouth Corner
    final leftMouth = _getLandmarkOrFallback(face, FaceLandmarkType.leftMouth, 0.65, 0.72);
    points.add(leftMouth);

    // 3: Right Mouth Corner
    final rightMouth = _getLandmarkOrFallback(face, FaceLandmarkType.rightMouth, 0.35, 0.72);
    points.add(rightMouth);

    // 4: Bottom Mouth / Lower Lip
    final bottomMouth = _getLandmarkOrFallback(face, FaceLandmarkType.bottomMouth, 0.50, 0.78);
    points.add(bottomMouth);

    // 5: Top Lip Center
    points.add(Point<double>(box.left + boxWidth * 0.50, box.top + boxHeight * 0.68));

    // 6: Left Cheek
    final leftCheek = _getLandmarkOrFallback(face, FaceLandmarkType.leftCheek, 0.75, 0.55);
    points.add(leftCheek);

    // 7: Right Cheek
    final rightCheek = _getLandmarkOrFallback(face, FaceLandmarkType.rightCheek, 0.25, 0.55);
    points.add(rightCheek);

    // 8-10: Left Eyebrow (3 points)
    final leftEyebrowFallback = [
      Point<double>(box.left + boxWidth * 0.60, box.top + boxHeight * 0.25),
      Point<double>(box.left + boxWidth * 0.70, box.top + boxHeight * 0.23),
      Point<double>(box.left + boxWidth * 0.80, box.top + boxHeight * 0.26),
    ];
    points.addAll(_getContourOrFallback(face, FaceContourType.leftEyebrowTop, 3, leftEyebrowFallback));

    // 11-13: Right Eyebrow (3 points)
    final rightEyebrowFallback = [
      Point<double>(box.left + boxWidth * 0.40, box.top + boxHeight * 0.25),
      Point<double>(box.left + boxWidth * 0.30, box.top + boxHeight * 0.23),
      Point<double>(box.left + boxWidth * 0.20, box.top + boxHeight * 0.26),
    ];
    points.addAll(_getContourOrFallback(face, FaceContourType.rightEyebrowTop, 3, rightEyebrowFallback));

    // 14-17: Left Eye Contour (4 points)
    final leftEyeFallback = [
      Point<double>(box.left + boxWidth * 0.60, box.top + boxHeight * 0.35),
      Point<double>(box.left + boxWidth * 0.70, box.top + boxHeight * 0.33),
      Point<double>(box.left + boxWidth * 0.80, box.top + boxHeight * 0.35),
      Point<double>(box.left + boxWidth * 0.70, box.top + boxHeight * 0.37),
    ];
    points.addAll(_getContourOrFallback(face, FaceContourType.leftEye, 4, leftEyeFallback));

    // 18-21: Right Eye Contour (4 points)
    final rightEyeFallback = [
      Point<double>(box.left + boxWidth * 0.40, box.top + boxHeight * 0.35),
      Point<double>(box.left + boxWidth * 0.30, box.top + boxHeight * 0.33),
      Point<double>(box.left + boxWidth * 0.20, box.top + boxHeight * 0.35),
      Point<double>(box.left + boxWidth * 0.30, box.top + boxHeight * 0.37),
    ];
    points.addAll(_getContourOrFallback(face, FaceContourType.rightEye, 4, rightEyeFallback));

    // 22-29: Face Oval Contour (8 points)
    final faceOvalFallback = List.generate(8, (i) {
      final t = i / 7.0;
      final angleRad = pi * 0.1 + t * pi * 0.8;
      final cx = box.left + boxWidth * (0.5 + 0.45 * cos(angleRad));
      final cy = box.top + boxHeight * (0.5 + 0.45 * sin(angleRad));
      return Point<double>(cx, cy);
    });
    points.addAll(_getContourOrFallback(face, FaceContourType.face, 8, faceOvalFallback));

    // Ensure points list length is strictly 30 points
    while (points.length < 30) {
      points.add(Point<double>(box.left + boxWidth * 0.5, box.top + boxHeight * 0.5));
    }
    if (points.length > 30) {
      points.removeRange(30, points.length);
    }

    final vector = <double>[];
    for (var p in points) {
      final cp = toCanonical(p);
      vector.add(cp.x);
      vector.add(cp.y);
    }

    // Append 10 invariant geometric facial ratio descriptors (indices 60..69)
    double dist(Point<double> p1, Point<double> p2) {
      final dx = p1.x - p2.x;
      final dy = p1.y - p2.y;
      return sqrt(dx * dx + dy * dy);
    }

    final mouthCenter = Point<double>((leftMouth.x + rightMouth.x) / 2.0, (leftMouth.y + rightMouth.y) / 2.0);

    vector.add(interEyeDist / boxWidth);
    vector.add(dist(Point<double>(eyeCenterX, eyeCenterY), noseBase) / interEyeDist);
    vector.add(dist(noseBase, mouthCenter) / interEyeDist);
    vector.add(dist(mouthCenter, bottomMouth) / interEyeDist);
    vector.add(dist(leftMouth, rightMouth) / interEyeDist);
    vector.add(dist(leftCheek, rightCheek) / interEyeDist);
    vector.add(dist(eyeImageLeft, leftEyebrowFallback.first) / interEyeDist);
    vector.add(dist(eyeImageRight, rightEyebrowFallback.first) / interEyeDist);
    vector.add(boxHeight / boxWidth);
    vector.add(dist(leftMouth, noseBase) / interEyeDist);

    // Append 10 scale-invariant facial triangle angles in radians (indices 70..79)
    double angleBetween(Point<double> p1, Point<double> vertex, Point<double> p2) {
      final v1x = p1.x - vertex.x;
      final v1y = p1.y - vertex.y;
      final v2x = p2.x - vertex.x;
      final v2y = p2.y - vertex.y;
      final dot = v1x * v2x + v1y * v2y;
      final mag1 = sqrt(v1x * v1x + v1y * v1y);
      final mag2 = sqrt(v2x * v2x + v2y * v2y);
      if (mag1 <= 0 || mag2 <= 0) return 0.0;
      final cosTheta = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
      return acos(cosTheta);
    }

    vector.add(angleBetween(eyeImageLeft, noseBase, eyeImageRight));
    vector.add(angleBetween(eyeImageLeft, noseBase, leftMouth));
    vector.add(angleBetween(eyeImageRight, noseBase, rightMouth));
    vector.add(angleBetween(leftMouth, noseBase, rightMouth));
    vector.add(angleBetween(eyeImageLeft, leftMouth, rightMouth));
    vector.add(angleBetween(eyeImageRight, rightMouth, leftMouth));
    vector.add(angleBetween(leftEyebrowFallback.first, eyeImageLeft, noseBase));
    vector.add(angleBetween(rightEyebrowFallback.first, eyeImageRight, noseBase));
    vector.add(angleBetween(leftCheek, noseBase, rightCheek));
    vector.add(angleBetween(eyeImageLeft, mouthCenter, eyeImageRight));

    return vector;
  }

  /// Computes hybrid similarity score between candidate vector and enrolled template vector.
  @override
  double computeCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0.0;

    // Vector length mismatch guard (e.g. 80D MLKit landmark vector vs 16D/4D legacy string template)
    if ((v1.length >= 60 && v2.length < 60) || (v1.length < 60 && v2.length >= 60)) {
      return 0.0;
    }

    final minLen = min(v1.length, v2.length);
    if (minLen < 2) return 0.0;

    // 1. Mean Landmark Distance over 30 canonical 2D points (indices 0..59)
    double landmarkDist = 0.0;
    final pointCount = min(30, minLen ~/ 2);
    if (pointCount > 0) {
      double totalDist = 0.0;
      for (int i = 0; i < pointCount * 2; i += 2) {
        final dx = v1[i] - v2[i];
        final dy = v1[i + 1] - v2[i + 1];
        totalDist += sqrt(dx * dx + dy * dy);
      }
      landmarkDist = totalDist / pointCount.toDouble();
    }

    // 2. Mean Geometric Ratio & Angle Difference (indices 60..minLen-1)
    double geometryDist = 0.0;
    if (minLen > 60) {
      double totalGeoDiff = 0.0;
      int geoCount = 0;
      for (int i = 60; i < minLen; i++) {
        totalGeoDiff += (v1[i] - v2[i]).abs();
        geoCount++;
      }
      if (geoCount > 0) {
        geometryDist = totalGeoDiff / geoCount.toDouble();
      }
    } else {
      geometryDist = landmarkDist;
    }

    // 3. Combined Facial Distance Metric (Lower = More Similar)
    final double combinedDist = (0.50 * landmarkDist) + (0.50 * geometryDist);

    // 4. Distance to Similarity Score Transformation [0.0, 1.0]
    // Tolerance scale: 0.0 distance => 1.0 similarity, >= 0.10 distance => 0.0 similarity
    final double similarityScore = (1.0 - (combinedDist / 0.10)).clamp(0.0, 1.0);

    return similarityScore;
  }

  @override
  Future<FaceRecognitionResult> recognizeFace({
    required Face face,
    required CameraImage image,
    required List<StaffModel> enrolledStaff,
  }) async {
    final candidateVector = extractFaceEmbedding(face: face, image: image);

    StaffModel? bestMatchStaff;
    double highestSimilarity = 0.0;
    double secondHighestSimilarity = 0.0;

    for (var staff in enrolledStaff) {
      if (!staff.isActive || !staff.faceEnrolled) {
        continue;
      }

      final templates = staff.faceTemplates ?? (staff.faceEmbedding != null ? [staff.faceEmbedding!] : []);
      if (templates.isEmpty) continue;

      double staffBestSimilarity = 0.0;
      for (final tmpl in templates) {
        final similarity = computeCosineSimilarity(candidateVector, tmpl);
        if (similarity > staffBestSimilarity) {
          staffBestSimilarity = similarity;
        }
      }

      if (staffBestSimilarity > highestSimilarity) {
        secondHighestSimilarity = highestSimilarity;
        highestSimilarity = staffBestSimilarity;
        bestMatchStaff = staff;
      } else if (staffBestSimilarity > secondHighestSimilarity) {
        secondHighestSimilarity = staffBestSimilarity;
      }
    }

    final bool isMarginValid = (enrolledStaff.length <= 1) ||
        ((highestSimilarity - secondHighestSimilarity) >= FaceRecognitionConfig.confidenceMargin);

    if (bestMatchStaff != null &&
        highestSimilarity >= FaceRecognitionConfig.recognitionThreshold &&
        isMarginValid) {
      return FaceRecognitionResult.matched(
        staffId: bestMatchStaff.id,
        confidence: highestSimilarity,
      );
    } else {
      return FaceRecognitionResult.unmatched(
        errorMessage: 'No matching enrolled staff face found.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_isInitialized) {
      await _faceDetector.close();
      _isInitialized = false;
    }
  }
}
