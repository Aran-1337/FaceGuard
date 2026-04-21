import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class EmployeeProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<EmployeeModel> _employees = [];
  Map<String, UserModel> _userMap = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<EmployeeModel> get employees => _employees;
  Map<String, UserModel> get userMap => _userMap;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all employees (Admin)
  Future<void> loadAllEmployees() async {
    try {
      _isLoading = true;
      notifyListeners();

      _databaseService.getEmployees().listen((employees) {
        _employees = employees;
        notifyListeners();
      });

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load employees by manager
  Future<void> loadEmployeesByManager(String managerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _databaseService.getEmployeesByManager(managerId).listen((employees) {
        _employees = employees;
        notifyListeners();
      });

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete employee
  Future<void> deleteEmployee(String employeeId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _databaseService.deleteEmployee(employeeId, userId);
      // Because we use streams for the employee list, it will auto-update.
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get employee by ID
  EmployeeModel? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get user for employee
  Future<UserModel?> getUserForEmployee(String userId) async {
    if (_userMap.containsKey(userId)) {
      return _userMap[userId];
    }

    try {
      final users = await _databaseService
          .getUsersByRole(UserRole.employee)
          .first;
      for (final user in users) {
        _userMap[user.uid] = user;
      }
      return _userMap[userId];
    } catch (e) {
      return null;
    }
  }

  // Load users map
  Future<void> loadUsersMap() async {
    try {
      _databaseService.getUsers().listen((users) {
        for (final user in users) {
          _userMap[user.uid] = user;
        }
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Create employee profile
  Future<bool> createEmployee(EmployeeModel employee) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.createEmployee(employee);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update employee
  Future<bool> updateEmployee(EmployeeModel employee) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateEmployee(employee);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
