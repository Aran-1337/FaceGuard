import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/leave_request_model.dart';
import '../../services/database_service.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final managerId = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.greyColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<List<LeaveRequestModel>>(
        stream: _dbService.getManagerLeaveRequests(managerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final pending =
              all.where((r) => r.status == LeaveStatus.pending).toList();
          final approved =
              all.where((r) => r.status == LeaveStatus.approved).toList();
          final rejected =
              all.where((r) => r.status == LeaveStatus.rejected).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(pending, showActions: true, managerId: managerId),
              _buildList(approved, managerId: managerId),
              _buildList(rejected, managerId: managerId),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
    List<LeaveRequestModel> requests, {
    bool showActions = false,
    required String managerId,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              showActions ? 'No pending requests' : 'No requests here',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final r = requests[index];
        return _buildRequestCard(r, showActions: showActions, managerId: managerId);
      },
    );
  }

  Widget _buildRequestCard(
    LeaveRequestModel r, {
    required bool showActions,
    required String managerId,
  }) {
    Color typeColor;
    IconData typeIcon;
    switch (r.type) {
      case LeaveType.annual:
        typeColor = const Color(0xFF3B82F6);
        typeIcon = Icons.beach_access;
        break;
      case LeaveType.sick:
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.local_hospital;
        break;
      case LeaveType.emergency:
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.warning_amber;
        break;
      case LeaveType.unpaid:
        typeColor = const Color(0xFF6B7280);
        typeIcon = Icons.money_off;
        break;
      case LeaveType.other:
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.more_horiz;
        break;
    }

    Color statusColor;
    switch (r.status) {
      case LeaveStatus.pending:
        statusColor = AppTheme.warningColor;
        break;
      case LeaveStatus.approved:
        statusColor = AppTheme.successColor;
        break;
      case LeaveStatus.rejected:
        statusColor = AppTheme.errorColor;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.employeeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        r.typeLabel,
                        style: TextStyle(color: typeColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.statusLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dates row
                Row(
                  children: [
                    Icon(Icons.date_range, size: 16, color: AppTheme.greyColor),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('MMM d').format(r.fromDate)} → ${DateFormat('MMM d, yyyy').format(r.toDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${r.daysCount} day${r.daysCount > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: typeColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Reason
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(r.reason,
                      style: const TextStyle(fontSize: 13)),
                ),
                // Manager note if rejected/approved
                if (r.managerNote != null && r.managerNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: ${r.managerNote}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
                // Submitted date
                const SizedBox(height: 8),
                Text(
                  'Submitted ${DateFormat('MMM d, yyyy • h:mm a').format(r.createdAt)}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                // Action buttons for pending
                if (showActions) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _handleAction(r, false, managerId),
                          icon: const Icon(Icons.close,
                              size: 16, color: AppTheme.errorColor),
                          label: const Text('Reject',
                              style:
                                  TextStyle(color: AppTheme.errorColor)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppTheme.errorColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _handleAction(r, true, managerId),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(LeaveRequestModel r, bool approve, String managerId) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? '✅ Approve Leave' : '❌ Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.employeeName} – ${r.typeLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${DateFormat('MMM d').format(r.fromDate)} → ${DateFormat('MMM d').format(r.toDate)} (${r.daysCount} day${r.daysCount > 1 ? 's' : ''})',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: approve
                    ? 'Optional note to employee...'
                    : 'Reason for rejection...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await _dbService.updateLeaveRequestStatus(
                  r.id,
                  approve ? LeaveStatus.approved : LeaveStatus.rejected,
                  r.employeeId,
                  r.employeeName,
                  managerId,
                  note: noteController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(approve
                          ? '✅ Leave approved'
                          : '❌ Leave rejected'),
                      backgroundColor: approve
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppTheme.errorColor),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approve ? AppTheme.successColor : AppTheme.errorColor,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }
}
