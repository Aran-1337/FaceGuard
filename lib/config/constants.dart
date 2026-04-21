import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // App Info
  static const String appName = 'FaceGuard Attendance';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String employeesCollection = 'employees';
  static const String attendanceCollection = 'attendance';
  static const String salariesCollection = 'salaries';
  static const String punishmentsCollection = 'punishments';
  static const String departmentsCollection = 'departments';
  static const String notificationsCollection = 'notifications';
  static const String spotChecksCollection = 'spot_checks';

  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String attendanceImagesPath = 'attendance_images';
  static const String faceDataPath = 'face_data';

  // Work Hours
  static const int workStartHour = 9; // 9 AM
  static const int workEndHour = 17; // 5 PM
  static const int lateThresholdMinutes = 15; // Late after 15 minutes

  // Geofencing (Company Location)
  static const double companyLatitude = 30.0444; // Cairo, Egypt (example)
  static const double companyLongitude = 31.2357;
  static const double geofenceRadiusMeters = 100; // 100 meters radius

  // Face Detection
  static const double faceDetectionMinConfidence = 0.7;
  static const double faceMatchThreshold = 0.6;

  // Face AI Backend Server
  static String get faceAiServerUrl {
    // TODO: Paste your Railway URL here once deployed, for example: 'https://your-app.up.railway.app'
    const String productionServerUrl = ''; 

    if (productionServerUrl.isNotEmpty) {
      return productionServerUrl;
    }

    if (kIsWeb) return 'http://127.0.0.1:5000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    } catch (_) {}
    return 'http://127.0.0.1:5000';
  }
  // Shared Preferences Keys
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String notificationsKey = 'notifications_enabled';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Pagination
  static const int defaultPageSize = 20;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String authError = 'Authentication failed. Please login again.';
  static const String permissionError =
      'You do not have permission to perform this action.';

  // Department-based Positions Mapping
  static const Map<String, List<String>> positionsByDepartment = {
    'Software Development': [
      'Software Engineer',
      'Software Developer',
      'Frontend Developer',
      'Backend Developer',
      'Full Stack Developer',
      'Mobile App Developer',
      'Android Developer',
      'iOS Developer',
      'Flutter Developer',
      'React Native Developer',
      'Game Developer',
      'Technical Lead',
    ],
    'Data & Artificial Intelligence': [
      'Data Analyst',
      'Data Scientist',
      'Machine Learning Engineer',
      'AI Engineer',
      'Business Intelligence Analyst',
      'Data Engineer',
    ],
    'Cybersecurity': [
      'Cyber Security Analyst',
      'SOC Analyst',
      'Penetration Tester',
      'Incident Response Engineer',
      'Digital Forensics Analyst',
      'GRC Specialist',
      'Security Engineer',
    ],
    'UI/UX & Design': [
      'UI Designer',
      'UX Designer',
      'Product Designer',
      'Graphic Designer',
      'Motion Designer',
      'Visual Designer',
    ],
    'Infrastructure & Cloud': [
      'DevOps Engineer',
      'Cloud Engineer',
      'System Administrator',
      'Network Engineer',
      'Site Reliability Engineer',
      'Platform Engineer',
    ],
    'Quality Assurance (QA)': [
      'Software Tester',
      'QA Engineer',
      'Automation Test Engineer',
      'Test Lead',
      'Performance Tester',
    ],
    'Project & Product Management': [
      'Project Manager',
      'Product Manager',
      'Scrum Master',
      'Program Manager',
      'Agile Coach',
    ],
    'IT Support & Operations': [
      'IT Support',
      'Help Desk Technician',
      'Technical Support Engineer',
      'Customer Success Engineer',
      'IT Administrator',
    ],
  };

  // Get positions for a specific department
  static List<String> getPositionsForDepartment(String? department) {
    if (department == null || department.isEmpty) {
      // Return all positions if no department selected
      return positionsByDepartment.values.expand((list) => list).toList();
    }
    return positionsByDepartment[department] ?? [];
  }

  // All positions (flattened list)
  static List<String> get allPositions =>
      positionsByDepartment.values.expand((list) => list).toList();

  // Predefined Departments
  static const List<String> departments = [
    'Software Development',
    'Data & Artificial Intelligence',
    'Cybersecurity',
    'UI/UX & Design',
    'Infrastructure & Cloud',
    'Quality Assurance (QA)',
    'Project & Product Management',
    'IT Support & Operations',
  ];

  // Job Levels
  static const List<String> jobLevels = [
    'Intern',
    'Junior',
    'Mid-Level',
    'Senior',
    'Lead',
    'Principal',
    'Manager',
    'Director',
    'VP',
    'C-Level',
  ];
}
