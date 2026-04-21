import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class SendNotificationScreen extends StatefulWidget {
  final String senderId;
  final String senderName;

  const SendNotificationScreen({
    super.key,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  String _title = '';
  String _message = '';
  bool _sendToAll = true;
  final Set<String> _selectedUserIds = {};
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Compose a notification to send to your team members.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                label: 'Title',
                hint: 'e.g. Team Meeting',
                onChanged: (v) => _title = v,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Message',
                hint: 'Enter your message here...',
                maxLines: 4,
                onChanged: (v) => _message = v,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Recipients toggle
              Text(
                'Recipients',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Send to All'),
                subtitle: const Text('Notify every user in the system'),
                value: _sendToAll,
                activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onChanged: (v) => setState(() => _sendToAll = v),
              ),

              // User selection (only if not sendToAll)
              if (!_sendToAll) ...[
                const SizedBox(height: 12),
                StreamBuilder<List<UserModel>>(
                  stream: _dbService.getUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!
                        .where((u) => u.uid != widget.senderId)
                        .toList();

                    return Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isSelected =
                              _selectedUserIds.contains(user.uid);
                          return CheckboxListTile(
                            title: Text(user.name),
                            subtitle: Text(user.email,
                                style: const TextStyle(fontSize: 12)),
                            value: isSelected,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedUserIds.add(user.uid);
                                } else {
                                  _selectedUserIds.remove(user.uid);
                                }
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                if (_selectedUserIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_selectedUserIds.length} user(s) selected',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],

              const SizedBox(height: 32),

              GradientButton(
                text: 'Send Notification',
                icon: Icons.send,
                isLoading: _isSending,
                onPressed: _sendNotification,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_sendToAll && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one recipient'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        title: _title,
        message: _message,
        senderId: widget.senderId,
        senderName: widget.senderName,
        sendToAll: _sendToAll,
        recipientIds: _sendToAll ? [] : _selectedUserIds.toList(),
        createdAt: DateTime.now(),
      );

      await _dbService.sendNotification(notification);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
