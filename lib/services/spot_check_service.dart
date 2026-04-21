import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';

class SpotCheckService {
  final DatabaseService _dbService = DatabaseService();
  final _uuid = const Uuid();
  final _random = Random();
  Timer? _timer;
  String? _employeeId;
  String? _userId;

  // Start periodic random spot checks
  void startPeriodicChecks(String employeeId, String userId) {
    _employeeId = employeeId;
    _userId = userId;
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _timer?.cancel();
    // Random interval between 1-3 hours (3600 - 10800 seconds)
    final minSeconds = 60 * 60; // 1 hour
    final maxSeconds = 3 * 60 * 60; // 3 hours
    final delaySeconds =
        minSeconds + _random.nextInt(maxSeconds - minSeconds);

    _timer = Timer(Duration(seconds: delaySeconds), () {
      _triggerSpotCheck();
      _scheduleNextCheck(); // Schedule the next one
    });
  }

  Future<void> _triggerSpotCheck() async {
    if (_employeeId == null || _userId == null) return;

    final spotCheckId = _uuid.v4();

    // Create spot check record
    await _dbService.createSpotCheck({
      'id': spotCheckId,
      'employeeId': _employeeId,
      'userId': _userId,
      'requestedAt': Timestamp.now(),
      'completed': false,
      'completedAt': null,
      'location': null,
      'verified': false,
    });

    // Send notification to the employee
    final notification = NotificationModel(
      id: _uuid.v4(),
      title: '🔒 Face Verification Required',
      message:
          'A random security check has been triggered. Please verify your identity using face recognition now.',
      senderId: 'system',
      senderName: 'FaceGuard System',
      recipientIds: [_userId!],
      sendToAll: false,
      createdAt: DateTime.now(),
    );

    await _dbService.sendNotification(notification);
  }

  // Check if there are pending spot checks
  Future<List<Map<String, dynamic>>> checkPending(
      String employeeId) async {
    return await _dbService.getPendingSpotChecks(employeeId);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
