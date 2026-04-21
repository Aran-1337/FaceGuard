import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  late FaceDetector _faceDetector;
  bool _isInitialized = false;

  // Liveness tracking
  bool _hasBlinkDetected = false;
  bool _hasHeadMovement = false;
  double? _lastHeadAngleY;
  int _blinkCount = 0;
  double? _lastLeftEyeOpen;
  double? _lastRightEyeOpen;

  FaceRecognitionService() {
    _initializeDetector();
  }

  void _initializeDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      enableClassification: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;
  bool get hasBlinkDetected => _hasBlinkDetected;
  bool get hasHeadMovement => _hasHeadMovement;
  int get blinkCount => _blinkCount;

  // Reset liveness checks
  void resetLivenessCheck() {
    _hasBlinkDetected = false;
    _hasHeadMovement = false;
    _lastHeadAngleY = null;
    _blinkCount = 0;
    _lastLeftEyeOpen = null;
    _lastRightEyeOpen = null;
  }

  // Detect faces in camera image
  Future<List<Face>> detectFaces(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return [];

    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      return [];
    }
  }

  // Check liveness by detecting blink
  LivenessResult checkLiveness(Face face) {
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    final headAngleY = face.headEulerAngleY ?? 0;

    // Blink detection: eyes were open, now closed
    if (_lastLeftEyeOpen != null && _lastRightEyeOpen != null) {
      final wasOpen = _lastLeftEyeOpen! > 0.6 && _lastRightEyeOpen! > 0.6;
      final nowClosed = leftEyeOpen < 0.3 && rightEyeOpen < 0.3;

      if (wasOpen && nowClosed) {
        _blinkCount++;
        _hasBlinkDetected = true;
      }
    }

    _lastLeftEyeOpen = leftEyeOpen;
    _lastRightEyeOpen = rightEyeOpen;

    // Head movement detection
    if (_lastHeadAngleY != null) {
      final headMovement = (headAngleY - _lastHeadAngleY!).abs();
      if (headMovement > 10) {
        _hasHeadMovement = true;
      }
    }
    _lastHeadAngleY = headAngleY;

    // Determine liveness status
    if (_hasBlinkDetected) {
      return LivenessResult(
        isLive: true,
        message: 'Liveness verified!',
        confidence: 1.0,
      );
    } else if (_blinkCount == 0) {
      return LivenessResult(
        isLive: false,
        message: 'Please blink to verify you are real',
        confidence: 0.3,
      );
    }

    return LivenessResult(
      isLive: false,
      message: 'Verifying liveness...',
      confidence: 0.5,
    );
  }

  // Generate face embedding from landmarks
  List<double> generateFaceEmbedding(Face face) {
    final landmarks = <double>[];

    // Get key facial landmarks
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    final leftEar = face.landmarks[FaceLandmarkType.leftEar];
    final rightEar = face.landmarks[FaceLandmarkType.rightEar];
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek];
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek];

    // Calculate distances between landmarks (normalized)
    final bbox = face.boundingBox;
    final faceWidth = bbox.width;
    final faceHeight = bbox.height;

    // Eye distance ratio
    if (leftEye != null && rightEye != null) {
      final eyeDistance = _distance(leftEye.position, rightEye.position);
      landmarks.add(eyeDistance / faceWidth);
    }

    // Nose to eye ratio
    if (noseBase != null && leftEye != null) {
      final noseToLeftEye = _distance(noseBase.position, leftEye.position);
      landmarks.add(noseToLeftEye / faceHeight);
    }
    if (noseBase != null && rightEye != null) {
      final noseToRightEye = _distance(noseBase.position, rightEye.position);
      landmarks.add(noseToRightEye / faceHeight);
    }

    // Mouth width ratio
    if (leftMouth != null && rightMouth != null) {
      final mouthWidth = _distance(leftMouth.position, rightMouth.position);
      landmarks.add(mouthWidth / faceWidth);
    }

    // Nose to mouth ratio
    if (noseBase != null && bottomMouth != null) {
      final noseToMouth = _distance(noseBase.position, bottomMouth.position);
      landmarks.add(noseToMouth / faceHeight);
    }

    // Face proportions
    landmarks.add(faceWidth / faceHeight);

    // Ear positions (if visible)
    if (leftEar != null && rightEar != null) {
      final earDistance = _distance(leftEar.position, rightEar.position);
      landmarks.add(earDistance / faceWidth);
    }

    // Cheek positions
    if (leftCheek != null && rightCheek != null) {
      final cheekDistance = _distance(leftCheek.position, rightCheek.position);
      landmarks.add(cheekDistance / faceWidth);
    }

    // Eye-Mouth triangle ratios
    if (leftEye != null && rightEye != null && bottomMouth != null) {
      final leftEyeToMouth = _distance(leftEye.position, bottomMouth.position);
      final rightEyeToMouth = _distance(
        rightEye.position,
        bottomMouth.position,
      );
      landmarks.add(leftEyeToMouth / faceHeight);
      landmarks.add(rightEyeToMouth / faceHeight);
    }

    // Add contour-based features if available
    final faceContour = face.contours[FaceContourType.face];
    if (faceContour != null && faceContour.points.length >= 10) {
      // Sample points from face contour
      for (int i = 0; i < faceContour.points.length; i += 5) {
        final point = faceContour.points[i];
        landmarks.add((point.x - bbox.left) / faceWidth);
        landmarks.add((point.y - bbox.top) / faceHeight);
      }
    }

    // Pad or truncate to fixed size (64 features)
    while (landmarks.length < 64) {
      landmarks.add(0.0);
    }

    return landmarks.take(64).toList();
  }

  double _distance(dynamic p1, dynamic p2) {
    // Handle both Point<int> from ML Kit and Offset types
    final x1 = p1 is ui.Offset ? p1.dx : (p1.x as num).toDouble();
    final y1 = p1 is ui.Offset ? p1.dy : (p1.y as num).toDouble();
    final x2 = p2 is ui.Offset ? p2.dx : (p2.x as num).toDouble();
    final y2 = p2 is ui.Offset ? p2.dy : (p2.y as num).toDouble();
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
  }

  // Compare two face embeddings (cosine similarity)
  double compareFaces(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length || embedding1.isEmpty) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0 || norm2 == 0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  // Check if face matches registered face
  FaceMatchResult matchFace(
    Face detectedFace,
    List<List<double>> registeredEmbeddings,
  ) {
    if (registeredEmbeddings.isEmpty) {
      return FaceMatchResult(
        isMatch: false,
        confidence: 0,
        message: 'No registered face found. Please register your face first.',
      );
    }

    final detectedEmbedding = generateFaceEmbedding(detectedFace);
    double maxSimilarity = 0.0;

    for (final registered in registeredEmbeddings) {
      final similarity = compareFaces(detectedEmbedding, registered);
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
      }
    }

    // Threshold for match (0.75 = 75% similarity)
    const threshold = 0.75;

    if (maxSimilarity >= threshold) {
      return FaceMatchResult(
        isMatch: true,
        confidence: maxSimilarity,
        message: 'Face verified successfully!',
      );
    } else if (maxSimilarity >= 0.5) {
      return FaceMatchResult(
        isMatch: false,
        confidence: maxSimilarity,
        message: 'Face does not match. Please try again.',
      );
    } else {
      return FaceMatchResult(
        isMatch: false,
        confidence: maxSimilarity,
        message: 'This face does not match your registered account.',
      );
    }
  }

  // Convert CameraImage to InputImage
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final rotation = _rotationIntToImageRotation(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final bytes = _concatenatePlanes(image.planes);
    final size = ui.Size(image.width.toDouble(), image.height.toDouble());

    final metadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = planes.fold<List<int>>(
      [],
      (buffer, plane) => buffer..addAll(plane.bytes),
    );
    return Uint8List.fromList(allBytes);
  }

  InputImageRotation? _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  // Check if face is centered and suitable for capture
  bool isFaceSuitable(Face face, double imageWidth, double imageHeight) {
    final boundingBox = face.boundingBox;

    final minFaceSize = imageWidth * 0.2;
    if (boundingBox.width < minFaceSize || boundingBox.height < minFaceSize) {
      return false;
    }

    final maxFaceSize = imageWidth * 0.8;
    if (boundingBox.width > maxFaceSize || boundingBox.height > maxFaceSize) {
      return false;
    }

    final centerX = boundingBox.center.dx;
    final centerY = boundingBox.center.dy;
    final imageCenterX = imageWidth / 2;
    final imageCenterY = imageHeight / 2;

    final xOffset = (centerX - imageCenterX).abs() / imageWidth;
    final yOffset = (centerY - imageCenterY).abs() / imageHeight;

    if (xOffset > 0.3 || yOffset > 0.3) {
      return false;
    }

    final headEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0;

    if (headEulerAngleY.abs() > 30 || headEulerAngleZ.abs() > 30) {
      return false;
    }

    return true;
  }

  double getFaceQualityScore(Face face) {
    double score = 100;

    if (face.leftEyeOpenProbability != null &&
        face.leftEyeOpenProbability! < 0.5) {
      score -= 20;
    }
    if (face.rightEyeOpenProbability != null &&
        face.rightEyeOpenProbability! < 0.5) {
      score -= 20;
    }

    final headEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0;

    score -= headEulerAngleY.abs() * 0.5;
    score -= headEulerAngleZ.abs() * 0.5;

    if (face.smilingProbability != null && face.smilingProbability! > 0.5) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  void dispose() {
    _faceDetector.close();
    _isInitialized = false;
  }
}

// Liveness detection result
class LivenessResult {
  final bool isLive;
  final String message;
  final double confidence;

  LivenessResult({
    required this.isLive,
    required this.message,
    required this.confidence,
  });
}

// Face match result
class FaceMatchResult {
  final bool isMatch;
  final double confidence;
  final String message;

  FaceMatchResult({
    required this.isMatch,
    required this.confidence,
    required this.message,
  });
}

// Face detection result
class FaceDetectionResult {
  final bool faceDetected;
  final bool isSuitable;
  final double qualityScore;
  final String? message;
  final Face? face;

  FaceDetectionResult({
    required this.faceDetected,
    required this.isSuitable,
    required this.qualityScore,
    this.message,
    this.face,
  });

  factory FaceDetectionResult.noFace() => FaceDetectionResult(
    faceDetected: false,
    isSuitable: false,
    qualityScore: 0,
    message: 'No face detected. Please position your face in the frame.',
  );

  factory FaceDetectionResult.multipleFaces() => FaceDetectionResult(
    faceDetected: true,
    isSuitable: false,
    qualityScore: 0,
    message: 'Multiple faces detected. Please ensure only one face is visible.',
  );

  factory FaceDetectionResult.notCentered() => FaceDetectionResult(
    faceDetected: true,
    isSuitable: false,
    qualityScore: 0,
    message: 'Please center your face in the frame.',
  );

  factory FaceDetectionResult.success(Face face, double score) =>
      FaceDetectionResult(
        faceDetected: true,
        isSuitable: true,
        qualityScore: score,
        message: 'Face detected. Ready to capture.',
        face: face,
      );
}
