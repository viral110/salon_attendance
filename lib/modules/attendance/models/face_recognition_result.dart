enum FaceValidationStatus {
  valid,
  noFace,
  multipleFaces,
  tooFar,
  tooClose,
  notCentered,
  severeAngle,
  lowQuality,
}

class FaceRecognitionResult {
  final bool isMatch;
  final String? staffId;
  final double? confidence;
  final String? errorMessage;
  final FaceValidationStatus validationStatus;

  const FaceRecognitionResult({
    required this.isMatch,
    this.staffId,
    this.confidence,
    this.errorMessage,
    this.validationStatus = FaceValidationStatus.valid,
  });

  factory FaceRecognitionResult.unmatched({
    String? errorMessage,
    FaceValidationStatus validationStatus = FaceValidationStatus.valid,
  }) {
    return FaceRecognitionResult(
      isMatch: false,
      staffId: null,
      confidence: 0.0,
      errorMessage: errorMessage,
      validationStatus: validationStatus,
    );
  }

  factory FaceRecognitionResult.matched({
    required String staffId,
    required double confidence,
  }) {
    return FaceRecognitionResult(
      isMatch: true,
      staffId: staffId,
      confidence: confidence,
      errorMessage: null,
      validationStatus: FaceValidationStatus.valid,
    );
  }
}
