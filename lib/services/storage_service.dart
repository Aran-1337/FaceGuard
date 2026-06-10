import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../config/constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final extension = path.extension(imageFile.path).toLowerCase();
      final String fileName = '${userId}_profile${extension.isEmpty ? '.jpg' : extension}';
      final ref = _storage
          .ref()
          .child(AppConstants.profileImagesPath)
          .child(fileName);

      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(
        contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
      );

      final uploadTask = await ref.putData(bytes, metadata);

      // Add a small delay to ensure Firebase finishes propagating the file
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
           throw Exception('Firebase Storage is likely NOT initialized! Please go to your Firebase Console -> Build -> Storage -> Click "Get Started" to create your bucket. Then try again.');
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  // Upload attendance photo
  Future<String> uploadAttendancePhoto(
    String employeeId,
    String attendanceId,
    File imageFile,
  ) async {
    try {
      final extension = path.extension(imageFile.path).toLowerCase();
      final String fileName = '$attendanceId${extension.isEmpty ? '.jpg' : extension}';
      final ref = _storage
          .ref()
          .child(AppConstants.attendanceImagesPath)
          .child(employeeId)
          .child(fileName);

      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(
        contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
      );

      final uploadTask = await ref.putData(bytes, metadata);

      await Future.delayed(const Duration(milliseconds: 500));

      try {
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
           throw Exception('Firebase Storage is likely NOT initialized! Go to Firebase Console -> Storage -> Get Started.');
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  // Upload face data for recognition
  Future<String> uploadFaceData(String employeeId, File faceImage) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(faceImage.path).toLowerCase();
      final ref = _storage
          .ref()
          .child(AppConstants.faceDataPath)
          .child(employeeId)
          .child('$timestamp${extension.isEmpty ? '.jpg' : extension}');

      final bytes = await faceImage.readAsBytes();
      final metadata = SettableMetadata(
        contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
      );

      final uploadTask = await ref.putData(bytes, metadata);

      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        return await uploadTask.ref.getDownloadURL();
      } catch (e) {
        if (e.toString().contains('object-not-found')) {
           throw Exception('Firebase Storage is likely NOT initialized! Go to Firebase Console -> Storage -> Get Started.');
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  // Upload multiple training photos for face recognition
  Future<List<String>> uploadTrainingPhotos(
    String userId,
    List<File> photos,
  ) async {
    final urls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < photos.length; i++) {
      try {
        final extension = path.extension(photos[i].path).toLowerCase();
        final ref = _storage
            .ref()
            .child('face_training')
            .child(userId)
            .child('${timestamp}_$i${extension.isEmpty ? '.jpg' : extension}');

        final bytes = await photos[i].readAsBytes();
        final metadata = SettableMetadata(
          contentType: extension == '.png' ? 'image/png' : 'image/jpeg',
        );

        final uploadTask = await ref.putData(bytes, metadata);

        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        // Continue uploading remaining photos even if one fails
        continue;
      }
    }

    return urls;
  }

  // Delete file
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // File might not exist, ignore error
    }
  }

  // Get download URL
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
