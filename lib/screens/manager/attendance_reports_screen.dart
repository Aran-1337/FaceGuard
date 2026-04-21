import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/employee_provider.dart';
import '../../models/attendance_model.dart';
import '../../services/database_service.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  final DatabaseService _dbService = DatabaseService();
  DateTime _selectedDate = DateTime.now();

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Reports')),
      body: Column(
        children: [
          // Date Picker
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(_selectedDate),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _dbService.getAttendanceByDate(_selectedDate),
              builder: (context, snapshot) {
                final data = snapshot.data ?? [];
                int present = data
                    .where((a) => a.status == AttendanceStatus.present)
                    .length;
                int late = data
                    .where((a) => a.status == AttendanceStatus.late)
                    .length;
                int absent = data
                    .where((a) => a.status == AttendanceStatus.absent)
                    .length;
                return Row(
                  children: [
                    Expanded(
                      child: _buildMiniCard(
                        'Present',
                        '$present',
                        AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniCard(
                        'Late',
                        '$late',
                        AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniCard(
                        'Absent',
                        '$absent',
                        AppTheme.errorColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Attendance List
          Expanded(
            child: StreamBuilder<List<AttendanceModel>>(
              stream: _dbService.getAttendanceByDate(_selectedDate),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final attendance = snapshot.data!;
                if (attendance.isEmpty)
                  return Center(
                    child: Text('No attendance records for this date'),
                  );
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: attendance.length,
                  itemBuilder: (context, index) {
                    final a = attendance[index];
                    final employeeProvider = context.read<EmployeeProvider>();
                    final employee = employeeProvider.getEmployeeById(
                      a.employeeId,
                    );
                    final user = employee != null
                        ? employeeProvider.userMap[employee.userId]
                        : null;
                    Color statusColor = a.status == AttendanceStatus.present
                        ? AppTheme.successColor
                        : a.status == AttendanceStatus.late
                        ? AppTheme.warningColor
                        : AppTheme.errorColor;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(
                            a.status == AttendanceStatus.present
                                ? Icons.check
                                : Icons.close,
                            color: statusColor,
                          ),
                        ),
                        title: Text(user?.name ?? 'Employee'),
                        subtitle: Text(
                          'In: ${a.hasCheckedIn ? DateFormat('HH:mm').format(a.checkIn!) : '--:--'} • Out: ${a.hasCheckedOut ? DateFormat('HH:mm').format(a.checkOut!) : '--:--'}',
                        ),
                        trailing: Text(
                          a.status.name,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
