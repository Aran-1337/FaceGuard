import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/employee_model.dart';
import '../models/attendance_model.dart';
import '../models/salary_model.dart';
import '../models/punishment_model.dart';
import '../models/department_model.dart';
import '../models/notification_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USER OPERATIONS ====================

  // Get all users
  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  // Get users by role
  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role.name)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }

  // Toggle user active status
  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
      'isActive': isActive,
    });
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toFirestore());
  }

  // Delete user (soft delete by setting isActive to false, or hard delete)
  Future<void> deleteUser(String uid, {bool hardDelete = false}) async {
    if (hardDelete) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .delete();
      // Also delete associated employee if exists
      final empQuery = await _firestore
          .collection(AppConstants.employeesCollection)
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in empQuery.docs) {
        await doc.reference.delete();
      }
    } else {
      await toggleUserStatus(uid, false);
    }
  }

  // ==================== EMPLOYEE OPERATIONS ====================

  // Create employee profile
  Future<void> createEmployee(EmployeeModel employee) async {
    await _firestore
        .collection(AppConstants.employeesCollection)
        .doc(employee.id)
        .set(employee.toFirestore());
  }

  // Generate next employee code (EMP-001, EMP-002, ...)
  Future<String> getNextEmployeeCode() async {
    final snapshot =
        await _firestore.collection(AppConstants.employeesCollection).get();

    int maxNumber = 0;
    for (final doc in snapshot.docs) {
      final code = (doc.data()['employeeCode'] ?? '') as String;
      // Parse "EMP-XXX" format
      final match = RegExp(r'EMP-(\d+)').firstMatch(code);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNumber) maxNumber = num;
      }
    }

    final nextNumber = maxNumber + 1;
    return 'EMP-${nextNumber.toString().padLeft(3, '0')}';
  }

  // Update employee profile
  Future<void> updateEmployee(EmployeeModel employee) async {
    await _firestore
        .collection(AppConstants.employeesCollection)
        .doc(employee.id)
        .update(employee.toFirestore());
  }

  // Get employee by user ID
  Future<EmployeeModel?> getEmployeeByUserId(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.employeesCollection)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return EmployeeModel.fromFirestore(snapshot.docs.first);
  }

  // Delete employee (removes from both employees and users collection)
  Future<void> deleteEmployee(String employeeId, String userId) async {
    // We cannot delete Firebase Auth accounts from client side without Admin SDK, 
    // but deleting their user document will prevent them from accessing the app.
    final batch = _firestore.batch();
    
    batch.delete(_firestore.collection(AppConstants.employeesCollection).doc(employeeId));
    batch.delete(_firestore.collection(AppConstants.usersCollection).doc(userId));
    
    await batch.commit();
  }

  // Get all employees
  Stream<List<EmployeeModel>> getEmployees() {
    return _firestore
        .collection(AppConstants.employeesCollection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmployeeModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get employees by manager
  Stream<List<EmployeeModel>> getEmployeesByManager(String managerId) {
    return _firestore
        .collection(AppConstants.employeesCollection)
        .where('managerId', isEqualTo: managerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmployeeModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Update face embeddings
  Future<void> updateFaceEmbeddings(
    String employeeId,
    List<String> embeddings,
  ) async {
    await _firestore
        .collection(AppConstants.employeesCollection)
        .doc(employeeId)
        .update({'faceEmbeddings': embeddings});
  }

  // ==================== ATTENDANCE OPERATIONS ====================

  // Record attendance (check-in or check-out)
  Future<void> recordAttendance(AttendanceModel attendance) async {
    await _firestore
        .collection(AppConstants.attendanceCollection)
        .doc(attendance.id)
        .set(attendance.toFirestore());
  }

  // Update attendance
  Future<void> updateAttendance(AttendanceModel attendance) async {
    await _firestore
        .collection(AppConstants.attendanceCollection)
        .doc(attendance.id)
        .update(attendance.toFirestore());
  }

  // Get monthly attendance stats for employee
  Future<Map<String, int>> getMonthlyAttendanceStats(
    String employeeId,
    int year,
    int month,
  ) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final snapshot = await _firestore
        .collection(AppConstants.attendanceCollection)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;
    int totalMinutes = 0;

    for (final doc in snapshot.docs) {
      final attendance = AttendanceModel.fromFirestore(doc);
      switch (attendance.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
      }
      // Calculate total work duration
      if (attendance.checkIn != null && attendance.checkOut != null) {
        final duration = attendance.checkOut!.difference(attendance.checkIn!);
        totalMinutes += duration.inMinutes;
      }
    }

    return {
      'present': present,
      'absent': absent,
      'late': late,
      'excused': excused,
      'totalHours': totalMinutes ~/ 60,
      'totalMinutes': totalMinutes % 60,
    };
  }

  // Get today's attendance for employee
  Future<AttendanceModel?> getTodayAttendance(String employeeId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(AppConstants.attendanceCollection)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AttendanceModel.fromFirestore(snapshot.docs.first);
  }

  // Get attendance history for employee
  Stream<List<AttendanceModel>> getEmployeeAttendance(String employeeId) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get attendance for date range
  Stream<List<AttendanceModel>> getAttendanceByDateRange(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all attendance for a specific date (for managers/admins)
  Stream<List<AttendanceModel>> getAttendanceByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ==================== SALARY OPERATIONS ====================

  // Create salary record
  Future<void> createSalary(SalaryModel salary) async {
    await _firestore
        .collection(AppConstants.salariesCollection)
        .doc(salary.id)
        .set(salary.toFirestore());
  }

  // Update salary
  Future<void> updateSalary(SalaryModel salary) async {
    await _firestore
        .collection(AppConstants.salariesCollection)
        .doc(salary.id)
        .update(salary.toFirestore());
  }

  // Get employee salaries
  Stream<List<SalaryModel>> getEmployeeSalaries(String employeeId) {
    return _firestore
        .collection(AppConstants.salariesCollection)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('month', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get latest salary for employee
  Future<SalaryModel?> getLatestSalary(String employeeId) async {
    final snapshot = await _firestore
        .collection(AppConstants.salariesCollection)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('month', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SalaryModel.fromFirestore(snapshot.docs.first);
  }

  // Get all salaries for a month (admin)
  Stream<List<SalaryModel>> getSalariesByMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return _firestore
        .collection(AppConstants.salariesCollection)
        .where(
          'month',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Mark salary as paid
  Future<void> markSalaryAsPaid(String salaryId) async {
    await _firestore
        .collection(AppConstants.salariesCollection)
        .doc(salaryId)
        .update({'status': SalaryStatus.paid.name, 'paidAt': Timestamp.now()});
  }

  // ==================== PUNISHMENT OPERATIONS ====================

  // Create punishment
  Future<void> createPunishment(PunishmentModel punishment) async {
    await _firestore
        .collection(AppConstants.punishmentsCollection)
        .doc(punishment.id)
        .set(punishment.toFirestore());
  }

  // Get employee punishments
  Stream<List<PunishmentModel>> getEmployeePunishments(String employeeId) {
    return _firestore
        .collection(AppConstants.punishmentsCollection)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PunishmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get active punishments for employee
  Stream<List<PunishmentModel>> getActivePunishments(String employeeId) {
    return _firestore
        .collection(AppConstants.punishmentsCollection)
        .where('employeeId', isEqualTo: employeeId)
        .where('isActive', isEqualTo: true)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PunishmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all punishments (admin)
  Stream<List<PunishmentModel>> getAllPunishments() {
    return _firestore
        .collection(AppConstants.punishmentsCollection)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PunishmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Deactivate punishment
  Future<void> deactivatePunishment(String punishmentId) async {
    await _firestore
        .collection(AppConstants.punishmentsCollection)
        .doc(punishmentId)
        .update({'isActive': false});
  }

  // ==================== DEPARTMENT OPERATIONS ====================

  // Get all departments
  Stream<List<DepartmentModel>> getDepartments() {
    return _firestore
        .collection(AppConstants.departmentsCollection)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DepartmentModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Create department
  Future<void> createDepartment(DepartmentModel department) async {
    await _firestore
        .collection(AppConstants.departmentsCollection)
        .doc(department.id)
        .set(department.toFirestore());
  }

  // Update department
  Future<void> updateDepartment(DepartmentModel department) async {
    await _firestore
        .collection(AppConstants.departmentsCollection)
        .doc(department.id)
        .update(department.toFirestore());
  }

  // Toggle department status
  Future<void> toggleDepartmentStatus(
    String departmentId,
    bool isActive,
  ) async {
    await _firestore
        .collection(AppConstants.departmentsCollection)
        .doc(departmentId)
        .update({'isActive': isActive});
  }

  // Assign manager to department
  Future<void> assignManagerToDepartment(
    String managerId,
    String departmentId,
  ) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(managerId)
        .update({'departmentId': departmentId});
  }

  // ==================== NOTIFICATION OPERATIONS ====================

  // Send notification
  Future<void> sendNotification(NotificationModel notification) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notification.id)
        .set(notification.toFirestore());
  }

  // Get notifications for a user (sent to them or to all)
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .where(
                (n) => n.sendToAll || n.recipientIds.contains(userId))
            .toList());
  }

  // Get unread count for a user
  Stream<int> getUnreadNotificationCount(String userId) {
    return getNotifications(userId).map(
      (notifications) =>
          notifications.where((n) => !n.isReadBy(userId)).length,
    );
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(
      String notificationId, String userId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  // ==================== SPOT CHECK OPERATIONS ====================

  // Create spot check request
  Future<void> createSpotCheck(Map<String, dynamic> spotCheck) async {
    await _firestore
        .collection(AppConstants.spotChecksCollection)
        .doc(spotCheck['id'])
        .set(spotCheck);
  }

  // Get pending spot checks for an employee
  Future<List<Map<String, dynamic>>> getPendingSpotChecks(
      String employeeId) async {
    final snapshot = await _firestore
        .collection(AppConstants.spotChecksCollection)
        .where('employeeId', isEqualTo: employeeId)
        .where('completed', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // Complete spot check
  Future<void> completeSpotCheck(
      String spotCheckId, GeoPoint? location, bool verified) async {
    await _firestore
        .collection(AppConstants.spotChecksCollection)
        .doc(spotCheckId)
        .update({
      'completed': true,
      'completedAt': Timestamp.now(),
      'location': location,
      'verified': verified,
    });
  }

  // ==================== ATTENDANCE CONFIGURATION ====================

  // Get attendance configuration
  Future<Map<String, dynamic>> getAttendanceConfig() async {
    final doc = await _firestore
        .collection('settings')
        .doc('attendance_config')
        .get();

    if (!doc.exists) {
      // Return defaults if no config exists
      return {
        'workStartHour': AppConstants.workStartHour,
        'workStartMinute': 0,
        'workEndHour': AppConstants.workEndHour,
        'workEndMinute': 0,
        'lateThresholdMinutes': AppConstants.lateThresholdMinutes,
        'companyLatitude': AppConstants.companyLatitude,
        'companyLongitude': AppConstants.companyLongitude,
        'geofenceRadiusMeters': AppConstants.geofenceRadiusMeters,
      };
    }

    return doc.data()!;
  }

  // Update attendance configuration
  Future<void> updateAttendanceConfig(Map<String, dynamic> config) async {
    await _firestore
        .collection('settings')
        .doc('attendance_config')
        .set(config, SetOptions(merge: true));
  }

  // Stream attendance configuration (for real-time updates)
  Stream<Map<String, dynamic>> streamAttendanceConfig() {
    return _firestore
        .collection('settings')
        .doc('attendance_config')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'workStartHour': AppConstants.workStartHour,
          'workStartMinute': 0,
          'workEndHour': AppConstants.workEndHour,
          'workEndMinute': 0,
          'lateThresholdMinutes': AppConstants.lateThresholdMinutes,
          'companyLatitude': AppConstants.companyLatitude,
          'companyLongitude': AppConstants.companyLongitude,
          'geofenceRadiusMeters': AppConstants.geofenceRadiusMeters,
        };
      }
      return doc.data()!;
    });
  }
}
