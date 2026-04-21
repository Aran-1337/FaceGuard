import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// Service for communicating with the Python Face Recognition AI backend.
///
/// This service sends camera images to the backend server which runs
/// the FirebaseFaceModel (lib/ai/firebase_face_model.py) to perform
/// face recognition and registration using the face_recognition library.
class FaceAiService {
  static final FaceAiService _instance = FaceAiService._internal();
  factory FaceAiService() => _instance;
  FaceAiService._internal();

  /// Timeout for API requests
  static const Duration _timeout = Duration(seconds: 30);

  /// Get the server base URL
  String get _baseUrl => AppConstants.faceAiServerUrl;

  // ==================== HEALTH CHECK ====================

  /// Check if the AI backend server is running and accessible.
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'error': 'Server returned ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'error': 'Cannot connect to AI server: $e',
      };
    }
  }

  /// Check if the server is reachable.
  Future<bool> isServerAvailable() async {
    final result = await healthCheck();
    return result['status'] == 'ok';
  }

  // ==================== FACE RECOGNITION ====================

  /// Recognize a face from an image file.
  ///
  /// Takes a photo [imageFile], converts it to base64, and sends it to the
  /// AI backend for face recognition against all registered employees.
  ///
  /// Returns a [FaceRecognitionResult] with the match details.
  Future<FaceRecognitionResult> recognizeFace(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      return await recognizeFaceFromBase64(base64Image);
    } catch (e) {
      return FaceRecognitionResult(
        success: false,
        recognized: false,
        message: 'Error reading image: $e',
      );
    }
  }

  /// Recognize a face from a base64-encoded image string.
  Future<FaceRecognitionResult> recognizeFaceFromBase64(
    String base64Image,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/recognize'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'image': base64Image}),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return FaceRecognitionResult(
          success: data['success'] ?? false,
          recognized: data['recognized'] ?? false,
          name: data['name'],
          userId: data['user_id']?.toString(),
          message: data['message'] ?? 'Unknown',
          confidence: (data['confidence'] ?? 0.0).toDouble(),
        );
      } else {
        return FaceRecognitionResult(
          success: false,
          recognized: false,
          message: data['error'] ?? 'Server error ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('FaceAiService: Recognition error: $e');
      return FaceRecognitionResult(
        success: false,
        recognized: false,
        message: _getConnectionErrorMessage(e),
      );
    }
  }

  // ==================== FACE REGISTRATION ====================

  /// Register a face for an employee.
  ///
  /// Sends the face image to the AI backend which generates a 128-dimensional
  /// face encoding and stores it in Firebase.
  Future<FaceRegistrationResult> registerFace({
    required String name,
    required String numericId,
    required File imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      return await registerFaceFromBase64(
        name: name,
        numericId: numericId,
        base64Image: base64Image,
      );
    } catch (e) {
      return FaceRegistrationResult(
        success: false,
        message: 'Error reading image: $e',
      );
    }
  }

  /// Register a face from a base64-encoded image string.
  Future<FaceRegistrationResult> registerFaceFromBase64({
    required String name,
    required String numericId,
    required String base64Image,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'numeric_id': numericId,
              'image': base64Image,
            }),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      return FaceRegistrationResult(
        success: data['success'] ?? false,
        message: data['message'] ?? data['error'] ?? 'Unknown',
      );
    } catch (e) {
      debugPrint('FaceAiService: Registration error: $e');
      return FaceRegistrationResult(
        success: false,
        message: _getConnectionErrorMessage(e),
      );
    }
  }

  // ==================== MODEL MANAGEMENT ====================

  /// Reload face encodings from Firebase.
  Future<bool> reloadModel() async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/reload'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          'FaceAiService: Model reloaded. Known faces: ${data['known_faces']}',
        );
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('FaceAiService: Reload error: $e');
      return false;
    }
  }

  /// Generate a face encoding without registering.
  Future<FaceEncodingResult> generateEncoding(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/generate-encoding'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'image': base64Image}),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      return FaceEncodingResult(
        success: data['success'] ?? false,
        encoding: data['encoding'] != null
            ? List<double>.from(data['encoding'])
            : null,
        message: data['message'] ?? data['error'] ?? 'Unknown',
      );
    } catch (e) {
      return FaceEncodingResult(
        success: false,
        message: _getConnectionErrorMessage(e),
      );
    }
  }

  // ==================== FACE TRAINING ====================

  /// Train the face model with multiple images for a user.
  ///
  /// Sends multiple face photos to the AI backend which generates encodings
  /// from each, averages them, and stores in Firebase for robust recognition.
  Future<FaceTrainingResult> trainFace({
    required String name,
    required String userId,
    required List<String> base64Images,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/train'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'name': name,
              'images': base64Images,
            }),
          )
          .timeout(const Duration(seconds: 120)); // Training can take longer

      final data = json.decode(response.body);

      return FaceTrainingResult(
        success: data['success'] ?? false,
        message: data['message'] ?? data['error'] ?? 'Unknown',
        encodingsGenerated: data['encodings_generated'] ?? 0,
        totalImages: data['total_images'] ?? 0,
      );
    } catch (e) {
      debugPrint('FaceAiService: Training error: $e');
      return FaceTrainingResult(
        success: false,
        message: _getConnectionErrorMessage(e),
        encodingsGenerated: 0,
        totalImages: 0,
      );
    }
  }

  // ==================== FACE VERIFICATION ====================

  /// Verify a face against a specific user.
  ///
  /// Sends a single image + the expected userId. The backend checks:
  /// - Face count (0, 1, or 2+)
  /// - Whether the face matches the expected user
  ///
  /// Returns a [FaceVerifyResult] with detailed error info.
  Future<FaceVerifyResult> verifyFace({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/verify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'image': base64Image,
            }),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 400) {
        return FaceVerifyResult(
          success: data['success'] ?? false,
          faceCount: data['face_count'] ?? 0,
          match: data['match'] ?? false,
          matchedName: data['matched_name'],
          matchedUserId: data['matched_user_id']?.toString(),
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          errorType: data['error_type'],
          message: data['message'] ?? data['error'] ?? 'Unknown',
        );
      } else {
        return FaceVerifyResult(
          success: false,
          faceCount: 0,
          match: false,
          errorType: 'server_error',
          message: data['error'] ?? 'Server error ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('FaceAiService: Verify error: $e');
      return FaceVerifyResult(
        success: false,
        faceCount: 0,
        match: false,
        errorType: 'connection_error',
        message: _getConnectionErrorMessage(e),
      );
    }
  }

  // ==================== HELPERS ====================

  String _getConnectionErrorMessage(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      return 'Cannot connect to AI server. Make sure the backend is running on $_baseUrl';
    }
    if (error.toString().contains('TimeoutException')) {
      return 'AI server request timed out. The server may be busy processing.';
    }
    return 'AI server error: $error';
  }
}

// ==================== RESULT MODELS ====================

/// Result of a face recognition attempt.
class FaceRecognitionResult {
  final bool success;
  final bool recognized;
  final String? name;
  final String? userId;
  final String message;
  final double confidence;

  FaceRecognitionResult({
    required this.success,
    required this.recognized,
    this.name,
    this.userId,
    required this.message,
    this.confidence = 0.0,
  });

  @override
  String toString() =>
      'FaceRecognitionResult(success: $success, recognized: $recognized, '
      'name: $name, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Result of a face registration attempt.
class FaceRegistrationResult {
  final bool success;
  final String message;

  FaceRegistrationResult({
    required this.success,
    required this.message,
  });
}

/// Result of a face encoding generation.
class FaceEncodingResult {
  final bool success;
  final List<double>? encoding;
  final String message;

  FaceEncodingResult({
    required this.success,
    this.encoding,
    required this.message,
  });
}

/// Result of face training with multiple images.
class FaceTrainingResult {
  final bool success;
  final String message;
  final int encodingsGenerated;
  final int totalImages;

  FaceTrainingResult({
    required this.success,
    required this.message,
    required this.encodingsGenerated,
    required this.totalImages,
  });

  @override
  String toString() =>
      'FaceTrainingResult(success: $success, '
      'encodings: $encodingsGenerated/$totalImages)';
}

/// Result of face verification against a specific user.
class FaceVerifyResult {
  final bool success;
  final int faceCount;
  final bool match;
  final String? matchedName;
  final String? matchedUserId;
  final double confidence;
  final String? errorType; // no_face, multiple_faces, mismatch, not_recognized, not_trained, connection_error
  final String message;

  FaceVerifyResult({
    required this.success,
    required this.faceCount,
    required this.match,
    this.matchedName,
    this.matchedUserId,
    this.confidence = 0.0,
    this.errorType,
    required this.message,
  });

  bool get isNoFace => errorType == 'no_face';
  bool get isMultipleFaces => errorType == 'multiple_faces';
  bool get isMismatch => errorType == 'mismatch';
  bool get isNotRecognized => errorType == 'not_recognized';
  bool get isNotTrained => errorType == 'not_trained';
  bool get isConnectionError => errorType == 'connection_error';

  @override
  String toString() =>
      'FaceVerifyResult(success: $success, match: $match, '
      'faceCount: $faceCount, errorType: $errorType)';
}

