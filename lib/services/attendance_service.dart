import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/attendance_model.dart';
import 'database_service.dart';
import 'storage_service.dart';

class AttendanceService {
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final _uuid = const Uuid();



  // Get current location
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  // Check in
  Future<AttendanceModel> checkIn({
    required String employeeId,
    File? facePhoto,
    bool requireGeofence = true,
  }) async {
    final now = DateTime.now();

    // Check if already checked in today with a SUCCESSFUL record
    AttendanceModel? existingAttendance = await _databaseService.getTodayAttendance(
      employeeId,
    );
    
    if (existingAttendance != null && existingAttendance.hasCheckedIn) {
      throw Exception('You have already checked in today.');
    }

    // Get current location
    final location = await getCurrentLocation();
    if (location == null) {
      throw Exception('Unable to capture location. Please verify permissions.');
    }

    final config = await _databaseService.getAttendanceConfig();
    final startHour = config['workStartHour'] ?? AppConstants.workStartHour;
    final startMinute = config['workStartMinute'] ?? 0;
    final lateMinutes = config['lateThresholdMinutes'] ?? AppConstants.lateThresholdMinutes;

    final double lat = config['companyLatitude'] ?? AppConstants.companyLatitude;
    final double lng = config['companyLongitude'] ?? AppConstants.companyLongitude;
    final double radius = (config['geofenceRadiusMeters'] ?? AppConstants.geofenceRadiusMeters).toDouble();

    final workStart = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );
    final lateThreshold = workStart.add(
      Duration(minutes: lateMinutes),
    );

    AttendanceStatus status;
    if (now.isBefore(workStart) || now.isAtSameMomentAs(workStart)) {
      status = AttendanceStatus.present;
    } else if (now.isBefore(lateThreshold)) {
      status = AttendanceStatus.present;
    } else {
      status = AttendanceStatus.late;
    }

    final attendanceId = existingAttendance?.id ?? _uuid.v4();

    // Verify geofence if required
    if (requireGeofence) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        lat,
        lng,
      );

      if (distance > radius) {
        // Employee is OUT OF BOUNDS => Log Failed Attempt & Mark Absent
        final attempt = {
          'time': Timestamp.fromDate(now),
          'location': location,
          'status': 'out_of_zone',
          'distance': distance,
        };

        if (existingAttendance == null) {
          existingAttendance = AttendanceModel(
            id: attendanceId,
            employeeId: employeeId,
            date: DateTime(now.year, now.month, now.day),
            status: AttendanceStatus.absent,
            isApproved: true,
            attempts: [attempt],
          );
          await _databaseService.recordAttendance(existingAttendance);
        } else {
          final updatedAttempts = List<Map<String, dynamic>>.from(existingAttendance.attempts)..add(attempt);
          existingAttendance = existingAttendance.copyWith(attempts: updatedAttempts);
          await _databaseService.updateAttendance(existingAttendance);
        }
        throw Exception('لا يمكن تسجيل حضورك لأنك بعيد عن الشركة، وسيتم تسجيل غيابك حتى تصبح في نطاق الشركة.');
      }
    }

    // Check-In SUCCESSFUL
    // Photo upload skipped to avoid Firebase Storage costs
    String? photoUrl; // null - no photo stored

    final successAttempt = {
      'time': Timestamp.fromDate(now),
      'location': location,
      'status': 'success',
      'distance': requireGeofence ? Geolocator.distanceBetween(location.latitude, location.longitude, lat, lng) : 0,
    };

    if (existingAttendance == null) {
      existingAttendance = AttendanceModel(
        id: attendanceId,
        employeeId: employeeId,
        date: DateTime(now.year, now.month, now.day),
        checkIn: now,
        status: status,
        photoUrl: photoUrl,
        location: location,
        isApproved: true,
        attempts: [successAttempt],
      );
      await _databaseService.recordAttendance(existingAttendance);
    } else {
      final updatedAttempts = List<Map<String, dynamic>>.from(existingAttendance.attempts)..add(successAttempt);
      existingAttendance = existingAttendance.copyWith(
        checkIn: now,
        status: status,
        location: location,
        attempts: updatedAttempts,
      );
      await _databaseService.updateAttendance(existingAttendance);
    }

    return existingAttendance;
  }

  // Check out
  Future<AttendanceModel> checkOut({
    required String employeeId,
    bool requireGeofence = true,
  }) async {
    // Get today's attendance
    final attendance = await _databaseService.getTodayAttendance(employeeId);
    if (attendance == null) {
      throw Exception('You have not checked in today.');
    }

    if (attendance.hasCheckedOut) {
      throw Exception('You have already checked out today.');
    }

    final checkOutLocation = await getCurrentLocation();
    if (checkOutLocation == null) {
      throw Exception('Unable to capture location. Please verify permissions.');
    }

    // Verify geofence if required
    if (requireGeofence) {
      final config = await _databaseService.getAttendanceConfig();
      final double lat = config['companyLatitude'] ?? AppConstants.companyLatitude;
      final double lng = config['companyLongitude'] ?? AppConstants.companyLongitude;
      final double radius = (config['geofenceRadiusMeters'] ?? AppConstants.geofenceRadiusMeters).toDouble();

      final distance = Geolocator.distanceBetween(
        checkOutLocation.latitude,
        checkOutLocation.longitude,
        lat,
        lng,
      );

      if (distance > radius) {
        throw Exception('لا يمكن تسجيل الانصراف لأنك بعيد عن الشركة.');
      }
    }

    // Update with checkout time and location
    final updatedAttendance = attendance.copyWith(
      checkOut: DateTime.now(),
      checkOutLocation: checkOutLocation,
    );

    await _databaseService.updateAttendance(updatedAttendance);
    return updatedAttendance;
  }

  // Get attendance summary for current month
  Future<Map<String, dynamic>> getMonthlySummary(String employeeId) async {
    final now = DateTime.now();
    final stats = await _databaseService.getMonthlyAttendanceStats(
      employeeId,
      now.year,
      now.month,
    );

    // Calculate working days in month (excluding weekends)
    int workingDays = 0;
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    for (
      var day = firstDay;
      day.isBefore(lastDay) || day.isAtSameMomentAs(lastDay);
      day = day.add(const Duration(days: 1))
    ) {
      if (day.weekday != DateTime.friday && day.weekday != DateTime.saturday) {
        workingDays++;
      }
    }

    final totalRecorded = stats.values.fold<int>(0, (sum, val) => sum + val);
    final daysRemaining = workingDays - totalRecorded;

    return {
      'present': stats['present'] ?? 0,
      'absent': stats['absent'] ?? 0,
      'late': stats['late'] ?? 0,
      'excused': stats['excused'] ?? 0,
      'workingDays': workingDays,
      'daysRemaining': daysRemaining > 0 ? daysRemaining : 0,
      'attendanceRate': workingDays > 0
          ? ((stats['present'] ?? 0) + (stats['late'] ?? 0)) / workingDays * 100
          : 0,
      'totalHours': stats['totalHours'] ?? 0,
      'totalMinutes': stats['totalMinutes'] ?? 0,
    };
  }

  // Mark absent (Admin/Manager)
  Future<void> markAbsent({
    required String employeeId,
    required DateTime date,
    String? notes,
  }) async {
    final attendanceId = _uuid.v4();
    final attendance = AttendanceModel(
      id: attendanceId,
      employeeId: employeeId,
      date: date,
      status: AttendanceStatus.absent,
      isApproved: true,
      notes: notes,
    );

    await _databaseService.recordAttendance(attendance);
  }

  // Mark excused (Admin/Manager)
  Future<void> markExcused({
    required String employeeId,
    required DateTime date,
    required String reason,
  }) async {
    final attendanceId = _uuid.v4();
    final attendance = AttendanceModel(
      id: attendanceId,
      employeeId: employeeId,
      date: date,
      status: AttendanceStatus.excused,
      isApproved: true,
      notes: reason,
    );

    await _databaseService.recordAttendance(attendance);
  }
}
