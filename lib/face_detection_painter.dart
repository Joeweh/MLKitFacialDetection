import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionPainter extends CustomPainter {
  final Paint facePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = Colors.green;

  final Paint landmarkPaint = Paint()
    ..style = PaintingStyle.fill
    ..strokeWidth = 3.0
    ..color = Colors.blue;

  final Paint textBackgroundPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.black54;

  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  FaceDetectionPainter({super.repaint, required this.faces, required this.imageSize, required this.cameraLensDirection});

  String _formatFaceStatusText({
    required int faceNumber,
    required double smileProbability,
    required double leftEyeOpenProbability,
    required double rightEyeOpenProbability
  }) {
    String emotion = 'Neutral';

    if (smileProbability > 0.8) {
      emotion = 'Smiling';
    }

    else if (smileProbability < 0.1) {
      emotion = 'Serious';
    }

    String? eyeState;

    if (leftEyeOpenProbability < 0.2 && rightEyeOpenProbability < 0.2) {
      eyeState = 'Blinking';
    }

    if (cameraLensDirection == CameraLensDirection.front) {
      if (leftEyeOpenProbability < 0.2) {
        eyeState = 'Left Eye Closed';
      }

      else if (rightEyeOpenProbability < 0.2) {
        eyeState = 'Right Eye Closed';
      }
    }

    else {
      if (rightEyeOpenProbability < 0.2) {
        eyeState = 'Left Eye Closed';
      }

      else if (leftEyeOpenProbability < 0.2) {
        eyeState = 'Right Eye Closed';
      }
    }

    String text = 'Face $faceNumber\n$emotion';

    if (eyeState != null) {
      text += '\n$eyeState';
    }

    return text;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Scale image size to screen size coordinates
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (var i = 0; i < faces.length; i++) {
      final Face face = faces[i];

      double leftOffset = face.boundingBox.left;

      if (cameraLensDirection == CameraLensDirection.front) {
        leftOffset = imageSize.width - face.boundingBox.right;
      }

      final double left = leftOffset * scaleX;
      final double top = face.boundingBox.top * scaleY;
      final double right = (leftOffset + face.boundingBox.width) * scaleX;
      final double bottom = (face.boundingBox.top + face.boundingBox.height) * scaleY;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), facePaint);

      void drawFacialLandmark(FaceLandmarkType type) {
        if (face.landmarks[type] != null) {
          final point = face.landmarks[type]!.position;

          double pointX = point.x.toDouble();

          if (cameraLensDirection == CameraLensDirection.front) {
            pointX = imageSize.width - pointX;
          }

          canvas.drawCircle(
              Offset(pointX * scaleX, point.y * scaleY),
              4.0,
              landmarkPaint,
          );
        }
      }

      drawFacialLandmark(FaceLandmarkType.leftEye);
      drawFacialLandmark(FaceLandmarkType.rightEye);
      drawFacialLandmark(FaceLandmarkType.noseBase);
      drawFacialLandmark(FaceLandmarkType.leftMouth);
      drawFacialLandmark(FaceLandmarkType.rightMouth);
      drawFacialLandmark(FaceLandmarkType.bottomMouth);

      final TextSpan faceIdSpan = TextSpan(
        text: _formatFaceStatusText(
          faceNumber: i + 1,
          smileProbability: face.smilingProbability ?? 0.5,
          leftEyeOpenProbability: face.leftEyeOpenProbability ?? 0.5,
          rightEyeOpenProbability: face.rightEyeOpenProbability ?? 0.5,
        ),
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      final TextPainter textPainter = TextPainter(
        text: faceIdSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();

      final textRect = Rect.fromLTWH(
          left,
          top - textPainter.height - 8,
          textPainter.width + 16,
          textPainter.height + 8,
      );

      canvas.drawRRect(
          RRect.fromRectAndRadius(textRect, Radius.circular(10)),
          textBackgroundPaint,
      );

      textPainter.paint(canvas, Offset(left + 8, top - textPainter.height - 4));
    }
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}