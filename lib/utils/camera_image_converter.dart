import 'dart:convert';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

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

  /// Converts a CameraImage into a JPEG base64 data URI string ("data:image/jpeg;base64,...")
  static String? convertToJpegDataUri({
    required CameraImage image,
    int sensorOrientation = 0,
    int quality = 85,
  }) {
    try {
      final img.Image? rgbImage = convertToRgbImage(
        image: image,
        sensorOrientation: sensorOrientation,
      );
      if (rgbImage == null) return null;

      final jpgBytes = img.encodeJpg(rgbImage, quality: quality);
      final base64String = base64Encode(jpgBytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Error converting camera image to JPEG data URI: $e');
      return null;
    }
  }

  /// Converts CameraImage to an Image object with rotation applied
  static img.Image? convertToRgbImage({
    required CameraImage image,
    int sensorOrientation = 0,
  }) {
    try {
      img.Image converted;

      if (image.format.group == ImageFormatGroup.bgra8888 || image.planes.length == 1) {
        converted = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      } else {
        // YUV420_888 / NV21 3 planes
        final int width = image.width;
        final int height = image.height;

        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final yBytes = yPlane.bytes;
        final uBytes = uPlane.bytes;
        final vBytes = vPlane.bytes;

        final yRowStride = yPlane.bytesPerRow;
        final uvRowStride = uPlane.bytesPerRow;
        final uvPixelStride = uPlane.bytesPerPixel ?? 2;

        converted = img.Image(width: width, height: height);

        for (int y = 0; y < height; y++) {
          final int uvRow = (y >> 1) * uvRowStride;
          final int yRow = y * yRowStride;

          for (int x = 0; x < width; x++) {
            final int uvCol = (x >> 1) * uvPixelStride;
            final int uvIndex = uvRow + uvCol;

            final int yVal = yBytes[yRow + x];
            final int uVal = uBytes[uvIndex] - 128;
            final int vVal = vBytes[uvIndex] - 128;

            final int r = (yVal + 1.402 * vVal).round().clamp(0, 255);
            final int g = (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
            final int b = (yVal + 1.772 * uVal).round().clamp(0, 255);

            converted.setPixelRgb(x, y, r, g, b);
          }
        }
      }

      if (sensorOrientation == 90 || sensorOrientation == 180 || sensorOrientation == 270) {
        return img.copyRotate(converted, angle: sensorOrientation);
      }
      return converted;
    } catch (e) {
      debugPrint('Error converting camera image to RGB: $e');
      return null;
    }
  }

  /// Converts an XFile (captured via cameraController.takePicture) into a JPEG base64 data URI string
  static Future<String> convertXFileToJpegDataUri(XFile file) async {
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Ensures any base64 image string is formatted as data:image/jpeg;base64,...
  static String ensureJpegDataUri(String base64OrDataUri) {
    final trimmed = base64OrDataUri.trim();
    if (trimmed.startsWith('data:image/')) {
      return trimmed;
    }
    return 'data:image/jpeg;base64,$trimmed';
  }
}
