import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../config/constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final extension = path.extension(imageFile.path);
      final ref = _storage
          .ref()
          .child(AppConstants.profileImagesPath)
          .child('$userId$extension');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/${extension.replaceAll('.', '')}'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Upload attendance photo
  Future<String> uploadAttendancePhoto(
    String employeeId,
    String attendanceId,
    File imageFile,
  ) async {
    try {
      final extension = path.extension(imageFile.path);
      final ref = _storage
          .ref()
          .child(AppConstants.attendanceImagesPath)
          .child(employeeId)
          .child('$attendanceId$extension');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/${extension.replaceAll('.', '')}'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload attendance photo: $e');
    }
  }

  // Upload face data for recognition
  Future<String> uploadFaceData(String employeeId, File faceImage) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(faceImage.path);
      final ref = _storage
          .ref()
          .child(AppConstants.faceDataPath)
          .child(employeeId)
          .child('$timestamp$extension');

      final uploadTask = await ref.putFile(
        faceImage,
        SettableMetadata(contentType: 'image/${extension.replaceAll('.', '')}'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload face data: $e');
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
        final extension = path.extension(photos[i].path);
        final ref = _storage
            .ref()
            .child('face_training')
            .child(userId)
            .child('${timestamp}_$i$extension');

        final uploadTask = await ref.putFile(
          photos[i],
          SettableMetadata(
            contentType: 'image/${extension.replaceAll('.', '')}',
          ),
        );

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
