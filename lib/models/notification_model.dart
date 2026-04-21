import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String senderId;
  final String senderName;
  final List<String> recipientIds; // empty = send to all
  final bool sendToAll;
  final DateTime createdAt;
  final List<String> readBy; // UIDs who read it

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.senderName,
    this.recipientIds = const [],
    this.sendToAll = false,
    required this.createdAt,
    this.readBy = const [],
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      recipientIds: List<String>.from(data['recipientIds'] ?? []),
      sendToAll: data['sendToAll'] ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'recipientIds': recipientIds,
      'sendToAll': sendToAll,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }

  bool isReadBy(String userId) => readBy.contains(userId);
}
