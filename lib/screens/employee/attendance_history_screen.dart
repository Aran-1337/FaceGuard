import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Present', 'Late', 'Absent', 'Excused'];

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final history = _filterHistory(attendanceProvider.attendanceHistory);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : AppTheme.lightColor,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: isDark
                          ? const Color(0xFF374151)
                          : Colors.grey.shade200,
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total',
                  history.length,
                  Icons.calendar_today,
                ),
                _buildSummaryItem(
                  'Present',
                  history
                      .where((a) => a.status == AttendanceStatus.present)
                      .length,
                  Icons.check_circle,
                ),
                _buildSummaryItem(
                  'Late',
                  history
                      .where((a) => a.status == AttendanceStatus.late)
                      .length,
                  Icons.schedule,
                ),
                _buildSummaryItem(
                  'Absent',
                  history
                      .where((a) => a.status == AttendanceStatus.absent)
                      .length,
                  Icons.cancel,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // History List
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: AppTheme.greyColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter.toLowerCase()} records',
                          style: TextStyle(
                            color: AppTheme.greyColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final attendance = history[index];
                      return _buildHistoryCard(attendance, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<AttendanceModel> _filterHistory(List<AttendanceModel> history) {
    if (_selectedFilter == 'All') return history;
    return history.where((a) {
      switch (_selectedFilter) {
        case 'Present':
          return a.status == AttendanceStatus.present;
        case 'Late':
          return a.status == AttendanceStatus.late;
        case 'Absent':
          return a.status == AttendanceStatus.absent;
        case 'Excused':
          return a.status == AttendanceStatus.excused;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildSummaryItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(AttendanceModel attendance, bool isDark) {
    Color statusColor;
    IconData statusIcon;

    switch (attendance.status) {
      case AttendanceStatus.present:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case AttendanceStatus.late:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
        break;
      case AttendanceStatus.absent:
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      case AttendanceStatus.excused:
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date Column
          Container(
            width: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(attendance.date),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(attendance.date),
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(attendance.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.login, size: 14, color: AppTheme.greyColor),
                    const SizedBox(width: 4),
                    Text(
                      attendance.hasCheckedIn
                          ? DateFormat('h:mm a').format(attendance.checkIn!)
                          : '--:--',
                      style: TextStyle(color: AppTheme.greyColor, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.logout, size: 14, color: AppTheme.greyColor),
                    const SizedBox(width: 4),
                    Text(
                      attendance.hasCheckedOut
                          ? DateFormat('h:mm a').format(attendance.checkOut!)
                          : '--:--',
                      style: TextStyle(color: AppTheme.greyColor, fontSize: 13),
                    ),
                  ],
                ),
                if (attendance.hasCheckedIn && attendance.hasCheckedOut)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppTheme.greyColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Duration: ${attendance.formattedWorkDuration}',
                          style: TextStyle(
                            color: AppTheme.greyColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  attendance.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
