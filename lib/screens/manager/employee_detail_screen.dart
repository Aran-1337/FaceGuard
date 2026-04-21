import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/employee_provider.dart';
import '../../models/attendance_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/stat_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final employee = employeeProvider.getEmployeeById(widget.employeeId);
    final user = employee != null
        ? employeeProvider.userMap[employee.userId]
        : null;

    if (employee == null)
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Employee not found')),
      );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.photoUrl != null
                            ? NetworkImage(user!.photoUrl!)
                            : null,
                        child: user?.photoUrl == null
                            ? Text(
                                user?.name[0] ?? 'E',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? 'Employee',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${employee.position} • ${employee.employeeCode}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: MiniStatCard(
                          label: 'Department',
                          value: employee.department ?? 'N/A',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MiniStatCard(
                          label: 'Base Salary',
                          value: '\$${employee.baseSalary.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MiniStatCard(
                          label: 'Join Date',
                          value: DateFormat(
                            'MMM yyyy',
                          ).format(employee.joinDate),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MiniStatCard(
                          label: 'Employee Code',
                          value: employee.employeeCode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Recent Attendance
                  Text(
                    'Recent Attendance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildRecentAttendance(),
                  const SizedBox(height: 24),
                  // Actions
                  Text(
                    'Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.warning),
                          label: Text('Add Warning'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.calendar_today),
                          label: Text('Mark Absent'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendance() {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _dbService.getEmployeeAttendance(widget.employeeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final attendance = snapshot.data!.take(5).toList();
        if (attendance.isEmpty) {
          return const Center(child: Text('No attendance records'));
        }
        return Column(
          children: attendance.map((a) {
            Color statusColor = a.status == AttendanceStatus.present
                ? AppTheme.successColor
                : a.status == AttendanceStatus.late
                ? AppTheme.warningColor
                : AppTheme.errorColor;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAttendanceDetails(context, a, statusColor),
                child: ListTile(
                  leading: Icon(
                    a.status == AttendanceStatus.present
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: statusColor,
                  ),
                  title: Text(DateFormat('EEEE, MMM d').format(a.date)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (a.hasCheckedIn) ...[
                            Text('In: ${DateFormat('HH:mm').format(a.checkIn!)}'),
                            if (a.location != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.location_on, size: 14, color: AppTheme.primaryColor),
                              ),
                          ],
                          if (a.hasCheckedOut) ...[
                            const Text(' • '),
                            Text('Out: ${DateFormat('HH:mm').format(a.checkOut!)}'),
                            if (a.checkOutLocation != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.location_on, size: 14, color: AppTheme.errorColor),
                              ),
                          ],
                          if (!a.hasCheckedIn)
                            const Text('No check-in'),
                        ],
                      ),
                      if (a.location != null || a.checkOutLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Tap for location details',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.status.name.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAttendanceDetails(
      BuildContext context, AttendanceModel a, Color statusColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(a.date),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.status.name.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                icon: Icons.login,
                color: AppTheme.successColor,
                title: 'Check-In',
                time: a.hasCheckedIn
                    ? DateFormat('h:mm a').format(a.checkIn!)
                    : 'Not checked in',
                location: a.location,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.logout,
                color: AppTheme.errorColor,
                title: 'Check-Out',
                time: a.hasCheckedOut
                    ? DateFormat('h:mm a').format(a.checkOut!)
                    : 'Not checked out',
                location: a.checkOutLocation,
              ),
              if (a.hasCheckedIn && a.hasCheckedOut) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  color: AppTheme.primaryColor,
                  title: 'Duration',
                  time: a.formattedWorkDuration,
                  location: null,
                ),
              ],
              if (a.attempts.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Check-In Attempts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...a.attempts.map((attempt) {
                  final time = (attempt['time'] as Timestamp).toDate();
                  final loc = attempt['location'];
                  final status = attempt['status'] as String?;
                  final isSuccess = status == 'success';
                  final distance = attempt['distance'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDetailRow(
                      icon: isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isSuccess ? AppTheme.successColor : AppTheme.warningColor,
                      title: isSuccess ? 'Successful Check-in' : 'Out of Bounds (${distance.toStringAsFixed(0)}m away)',
                      time: DateFormat('h:mm a').format(time),
                      location: loc, // Dynamic based on attempt
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    required dynamic location,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                 final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
                 if (await canLaunchUrl(url)) {
                   await launchUrl(url);
                 }
              },
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)} (Tap to open Maps)',
                      style: const TextStyle(
                          color: AppTheme.primaryColor, 
                          fontSize: 12,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
