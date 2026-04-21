import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/employee_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  UserModel? _currentUser;
  EmployeeModel? _currentEmployee;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get currentUser => _currentUser;
  EmployeeModel? get currentEmployee => _currentEmployee;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmployee => _currentUser?.role == UserRole.employee;
  bool get isManager => _currentUser?.role == UserRole.manager;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        _currentEmployee = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await _authService.getUserData(uid);

      if (_currentUser != null) {
        // Load employee data if user is an employee
        if (_currentUser!.role == UserRole.employee) {
          _currentEmployee = await _databaseService.getEmployeeByUserId(uid);
        }
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signInWithEmailPassword(email, password);

      if (user != null) {
        _currentUser = user;

        // Load employee data if applicable
        if (user.role == UserRole.employee) {
          _currentEmployee = await _databaseService.getEmployeeByUserId(
            user.uid,
          );
        }

        return true;
      }

      _error = 'Failed to sign in';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;
      _currentEmployee = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new user (Admin only)
  Future<bool> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? departmentId,
  }) async {
    if (!isAdmin) {
      _error = 'Only admins can create users';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.createUser(
        email: email,
        password: password,
        name: name,
        role: role,
        departmentId: departmentId,
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

  // Update current user
  Future<bool> updateProfile({String? name, String? photoUrl}) async {
    if (_currentUser == null) return false;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
      );

      await _authService.updateUser(updatedUser);
      _currentUser = updatedUser;

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh current user data from database
  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    await _loadUserData(_currentUser!.uid);
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
