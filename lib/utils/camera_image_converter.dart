import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraImageConverter {
  /// Converts a CameraImage frame into a properly formatted MLKit InputImage.
  static InputImage? convertToInputImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      // Single plane images (iOS BGRA / Android single plane)
      if (image.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }

      // Android YUV_420_888 (3 planes): Interleave Y, U, and V into proper NV21 format
      final nv21Bytes = _yuv420ToNv21(image);

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } catch (e) {
      debugPrint('Error converting camera image to InputImage: $e');
      return null;
    }
  }

  /// Converts Android YUV_420_888 3-plane CameraImage into interleaved NV21 Uint8List
  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    // 1. Copy Y channel
    final yRowStride = yPlane.bytesPerRow;
    if (yRowStride == width) {
      nv21.setRange(0, numPixels, yBuffer);
    } else {
      int idY = 0;
      for (int y = 0; y < height; y++) {
        final rowOffset = y * yRowStride;
        nv21.setRange(idY, idY + width, yBuffer, rowOffset);
        idY += width;
      }
    }

    // 2. Interleave V and U channels for NV21
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;
    int idUV = numPixels;

    for (int y = 0; y < height ~/ 2; y++) {
      final uvRowOffset = y * uvRowStride;
      for (int x = 0; x < width ~/ 2; x++) {
        final uvIndex = uvRowOffset + (x * uvPixelStride);
        if (uvIndex < vBuffer.length && uvIndex < uBuffer.length) {
          nv21[idUV++] = vBuffer[uvIndex]; // V channel
          nv21[idUV++] = uBuffer[uvIndex]; // U channel
        }
      }
    }

    return nv21;
  }
}
