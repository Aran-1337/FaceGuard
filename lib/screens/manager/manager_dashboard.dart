import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/attendance_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/stat_card.dart';
import '../employee/settings_screen.dart';
import '../common/notification_screen.dart';
import '../common/send_notification_screen.dart';
import 'attendance_config_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final DatabaseService _dbService = DatabaseService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final employeeProvider = context.read<EmployeeProvider>();
    if (authProvider.currentUser != null) {
      employeeProvider.loadEmployeesByManager(authProvider.currentUser!.uid);
      employeeProvider.loadUsersMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          _buildPlaceholder('Team'),
          _buildPlaceholder('Reports'),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1)
            Navigator.pushNamed(context, AppRoutes.employeeList);
          else if (index == 2)
            Navigator.pushNamed(context, AppRoutes.attendanceReports);
          else
            setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Team',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final authProvider = context.watch<AuthProvider>();
    final employeeProvider = context.watch<EmployeeProvider>();
    final user = authProvider.currentUser;
    final employees = employeeProvider.employees;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manager Dashboard',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'Manager',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                StreamBuilder<int>(
                  stream: _dbService.getUnreadNotificationCount(
                      authProvider.currentUser?.uid ?? ''),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationScreen(
                                    userId:
                                        authProvider.currentUser?.uid ?? ''),
                              ),
                            );
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
              style: TextStyle(color: AppTheme.greyColor),
            ),
            const SizedBox(height: 24),
            // Stats
            GradientStatCard(
              title: 'Team Members',
              value: '${employees.length}',
              icon: Icons.people,
              subtitle: 'Active employees',
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<AttendanceModel>>(
              stream: _dbService.getAttendanceByDate(DateTime.now()),
              builder: (context, snapshot) {
                final todayRecords = snapshot.data ?? [];
                // Filter only this manager's employees
                final employeeIds = employees.map((e) => e.id).toSet();
                final teamRecords = todayRecords
                    .where((a) => employeeIds.contains(a.employeeId))
                    .toList();

                final presentCount = teamRecords
                    .where((a) => a.status == AttendanceStatus.present)
                    .length;
                final lateCount = teamRecords
                    .where((a) => a.status == AttendanceStatus.late)
                    .length;
                final checkedInCount = presentCount + lateCount;
                final absentCount = employees.length - checkedInCount;

                return Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Present Today',
                        value: '$presentCount',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.successColor,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Absent',
                        value: '${absentCount < 0 ? 0 : absentCount}',
                        icon: Icons.cancel_outlined,
                        color: AppTheme.errorColor,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Late',
                        value: '$lateCount',
                        icon: Icons.schedule,
                        color: AppTheme.warningColor,
                        compact: true,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'View Team',
                    Icons.people,
                    () => Navigator.pushNamed(context, AppRoutes.employeeList),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Reports',
                    Icons.analytics,
                    () => Navigator.pushNamed(
                      context,
                      AppRoutes.attendanceReports,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Send Notification',
                    Icons.campaign,
                    () {
                      final user = authProvider.currentUser;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SendNotificationScreen(
                            senderId: user?.uid ?? '',
                            senderName: user?.name ?? 'Manager',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Settings',
                    Icons.settings,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttendanceConfigScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Today's Attendance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Attendance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(onPressed: () {}, child: Text('View All')),
              ],
            ),
            const SizedBox(height: 12),
            _buildTodayAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceList() {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _dbService.getAttendanceByDate(DateTime.now()),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        final attendance = snapshot.data!;
        if (attendance.isEmpty)
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No attendance records today'),
            ),
          );
        return Column(
          children: attendance
              .take(5)
              .map((a) => _buildAttendanceItem(a))
              .toList(),
        );
      },
    );
  }

  Widget _buildAttendanceItem(AttendanceModel attendance) {
    final employeeProvider = context.read<EmployeeProvider>();
    final employee = employeeProvider.getEmployeeById(attendance.employeeId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor = attendance.status == AttendanceStatus.present
        ? AppTheme.successColor
        : attendance.status == AttendanceStatus.late
        ? AppTheme.warningColor
        : AppTheme.errorColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              employee?.employeeCode.substring(0, 2) ?? 'E',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee?.position ?? 'Employee',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Check-in: ${attendance.hasCheckedIn ? DateFormat('HH:mm').format(attendance.checkIn!) : '--:--'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              attendance.status.name.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) => Center(child: Text(title));
}
