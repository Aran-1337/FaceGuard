import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/database_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final DatabaseService _databaseService = DatabaseService();

  AttendanceModel? _todayAttendance;
  List<AttendanceModel> _attendanceHistory = [];
  Map<String, dynamic>? _monthlyStats;
  bool _isLoading = false;
  String? _error;

  // Getters
  AttendanceModel? get todayAttendance => _todayAttendance;
  List<AttendanceModel> get attendanceHistory => _attendanceHistory;
  Map<String, dynamic>? get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCheckedInToday => _todayAttendance?.hasCheckedIn ?? false;
  bool get hasCheckedOutToday => _todayAttendance?.hasCheckedOut ?? false;

  // Load today's attendance
  Future<void> loadTodayAttendance(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _todayAttendance = await _databaseService.getTodayAttendance(employeeId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load attendance history
  void loadAttendanceHistory(String employeeId) {
    _databaseService.getEmployeeAttendance(employeeId).listen((attendance) {
      _attendanceHistory = attendance;
      notifyListeners();
    });
  }

  // Load monthly statistics
  Future<void> loadMonthlyStats(String employeeId) async {
    try {
      _monthlyStats = await _attendanceService.getMonthlySummary(employeeId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      // Provide fallback empty stats to stop loading indicator
      _monthlyStats = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'excused': 0,
        'workingDays': 0,
        'daysRemaining': 0,
        'attendanceRate': 0.0,
        'totalHours': 0,
        'totalMinutes': 0,
      };
      notifyListeners();
    }
  }

  // Check in
  Future<bool> checkIn({
    required String employeeId,
    File? facePhoto,
    bool requireGeofence = true,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _todayAttendance = await _attendanceService.checkIn(
        employeeId: employeeId,
        facePhoto: facePhoto,
        requireGeofence: requireGeofence,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check out
  Future<bool> checkOut({
    required String employeeId,
    bool requireGeofence = true,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _todayAttendance = await _attendanceService.checkOut(
        employeeId: employeeId,
        requireGeofence: requireGeofence,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get attendance for specific month
  List<AttendanceModel> getAttendanceForMonth(int year, int month) {
    return _attendanceHistory.where((a) {
      return a.date.year == year && a.date.month == month;
    }).toList();
  }

  // Get absent days count for current month
  int get absentDaysThisMonth {
    final now = DateTime.now();
    return getAttendanceForMonth(
      now.year,
      now.month,
    ).where((a) => a.status == AttendanceStatus.absent).length;
  }

  // Get late days count for current month
  int get lateDaysThisMonth {
    final now = DateTime.now();
    return getAttendanceForMonth(
      now.year,
      now.month,
    ).where((a) => a.status == AttendanceStatus.late).length;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
