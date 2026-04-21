import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/employee/employee_dashboard.dart';
import '../screens/employee/camera_screen.dart';
import '../screens/employee/profile_screen.dart';
import '../screens/employee/settings_screen.dart';
import '../screens/employee/face_registration_screen.dart';
import '../screens/manager/manager_dashboard.dart';
import '../screens/manager/employee_list_screen.dart';
import '../screens/manager/employee_detail_screen.dart';
import '../screens/manager/attendance_reports_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/salary_management_screen.dart';
import '../screens/admin/punishment_management_screen.dart';
import '../screens/admin/department_management_screen.dart';

class AppRoutes {
  // Auth Routes
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // Employee Routes
  static const String employeeDashboard = '/employee/dashboard';
  static const String camera = '/employee/camera';
  static const String profile = '/employee/profile';
  static const String settings = '/employee/settings';
  static const String faceRegistration = '/employee/face-registration';

  // Manager Routes
  static const String managerDashboard = '/manager/dashboard';
  static const String employeeList = '/manager/employees';
  static const String employeeDetail = '/manager/employee-detail';
  static const String attendanceReports = '/manager/attendance-reports';

  // Admin Routes
  static const String adminDashboard = '/admin/dashboard';
  static const String userManagement = '/admin/users';
  static const String salaryManagement = '/admin/salaries';
  static const String punishmentManagement = '/admin/punishments';
  static const String departmentManagement = '/admin/departments';

  static Map<String, WidgetBuilder> get routes => {
    // Auth
    login: (context) => const LoginScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),

    // Employee
    employeeDashboard: (context) => const EmployeeDashboard(),
    camera: (context) => const CameraScreen(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    faceRegistration: (context) => const FaceRegistrationScreen(),

    // Manager
    managerDashboard: (context) => const ManagerDashboard(),
    employeeList: (context) => const EmployeeListScreen(),
    attendanceReports: (context) => const AttendanceReportsScreen(),

    // Admin
    adminDashboard: (context) => const AdminDashboard(),
    userManagement: (context) => const UserManagementScreen(),
    salaryManagement: (context) => const SalaryManagementScreen(),
    punishmentManagement: (context) => const PunishmentManagementScreen(),
    departmentManagement: (context) => const DepartmentManagementScreen(),
  };

  // Dynamic route for employee detail (requires argument)
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case employeeDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              EmployeeDetailScreen(employeeId: args?['employeeId'] ?? ''),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
