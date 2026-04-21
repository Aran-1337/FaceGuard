import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/face_ai_service.dart';
import '../../widgets/common/custom_button.dart';
import 'face_registration_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isDisposing = false;
  String _statusMessage = 'Initializing camera...';
  bool _faceRegistered = false;
  bool _hasError = false;

  // AI Verification
  final FaceAiService _faceAiService = FaceAiService();
  bool _isVerifying = false;
  bool _faceVerified = false;
  bool _serverAvailable = false;
  String? _verifiedName;
  double _verifiedConfidence = 0.0;

  // Error state
  String? _errorType;
  String? _errorTitle;
  String? _errorDetail;
  IconData? _errorIcon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRegisteredFace();
    _initializeCamera();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null) return;
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _loadRegisteredFace() {
    final authProvider = context.read<AuthProvider>();
    final employee = authProvider.currentEmployee;
    if (employee != null && employee.faceEmbeddings.isNotEmpty) {
      _faceRegistered = true;
    }
  }

  /// Check if the AI backend server is running
  Future<void> _checkServerStatus() async {
    final available = await _faceAiService.isServerAvailable();
    if (mounted) {
      setState(() {
        _serverAvailable = available;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposing) return;

    setState(() {
      _hasError = false;
      _isInitialized = false;
      _statusMessage = 'Initializing camera...';
      _clearError();
    });

    try {
      // Request camera permission at runtime
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _statusMessage = status.isPermanentlyDenied
                ? 'Camera permission denied. Please enable it in Settings.'
                : 'Camera permission required';
          });
        }
        return;
      }

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _statusMessage = 'No cameras available';
          });
        }
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      await _disposeCamera();

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted || _isDisposing) return;

      if (!_faceRegistered) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Face not registered';
        });
        _showRegistrationPrompt();
        return;
      }

      setState(() {
        _isInitialized = true;
        _statusMessage = _serverAvailable
            ? 'Tap capture to verify your face'
            : 'AI server is offline. Please start the backend server.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Camera error: $e';
        });
      }
    }
  }

  void _showRegistrationPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.face_retouching_natural, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Face Training Required')),
            ],
          ),
          content: const Text(
            'You need to train the face recognition model before you can check in.\n\n'
            'This process takes 5 photos from different angles.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaceRegistrationScreen(),
                  ),
                ).then((_) {
                  _loadRegisteredFace();
                  _checkServerStatus();
                  if (_faceRegistered && mounted) {
                    setState(() =>
                        _statusMessage = 'Tap capture to verify your face');
                  }
                });
              },
              icon: const Icon(Icons.smart_toy, size: 18),
              label: const Text('Train Face'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    });
  }

  void _clearError() {
    _errorType = null;
    _errorTitle = null;
    _errorDetail = null;
    _errorIcon = null;
  }

  /// Capture image and verify face with AI
  Future<void> _captureAndVerify() async {
    if (_cameraController == null || _isProcessing || !_serverAvailable) return;

    setState(() {
      _isProcessing = true;
      _isVerifying = true;
      _faceVerified = false;
      _verifiedName = null;
      _statusMessage = 'Capturing & verifying face...';
      _clearError();
    });

    // Read auth provider before async gap
    final authProvider = context.read<AuthProvider>();
    final employeeCode = authProvider.currentEmployee?.employeeCode ?? '';

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      setState(() => _statusMessage = 'AI is verifying your face...');

      // Send to AI backend for face verification
      final result = await _faceAiService.verifyFace(
        imageFile: imageFile,
        userId: employeeCode,
      );

      if (!mounted) return;

      if (result.success && result.match) {
        // ✅ Face verified successfully!
        setState(() {
          _verifiedName = result.matchedName;
          _verifiedConfidence = result.confidence;
          _faceVerified = true;
          _isVerifying = false;
          _statusMessage =
              'Verified ✓ ${result.matchedName} '
              '(${(result.confidence * 100).toStringAsFixed(0)}%)';
        });

        // Auto-submit attendance after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _submitAttendance(imageFile);
        }
      } else {
        // ❌ Verification failed — handle specific error types
        _handleVerifyError(result);

        // Clean up temp file
        try {
          await imageFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  /// Handle different verification error types
  void _handleVerifyError(FaceVerifyResult result) {
    setState(() {
      _isProcessing = false;
      _isVerifying = false;
      _faceVerified = false;
    });

    if (result.isNoFace) {
      setState(() {
        _errorType = 'no_face';
        _errorTitle = 'لم يتم اكتشاف وجه';
        _errorDetail =
            'No face detected. Please face the camera directly and ensure good lighting.';
        _errorIcon = Icons.face_retouching_off;
        _statusMessage = 'No face detected';
      });
    } else if (result.isMultipleFaces) {
      setState(() {
        _errorType = 'multiple_faces';
        _errorTitle = 'تم اكتشاف أكثر من وجه في الكاميرا';
        _errorDetail =
            '${result.faceCount} faces detected. Only one person should be in front of the camera.';
        _errorIcon = Icons.groups;
        _statusMessage = 'Multiple faces detected (${result.faceCount})';
      });
    } else if (result.isMismatch) {
      setState(() {
        _errorType = 'mismatch';
        _errorTitle = 'هذا الوجه لا يطابق صاحب الحساب';
        _errorDetail =
            'Detected: ${result.matchedName}\n'
            'This face belongs to a different account.';
        _errorIcon = Icons.person_off;
        _statusMessage = 'Face mismatch!';
      });
    } else if (result.isNotRecognized) {
      setState(() {
        _errorType = 'not_recognized';
        _errorTitle = 'الوجه غير معروف';
        _errorDetail =
            'Face not recognized. Please ensure good lighting and face the camera directly.';
        _errorIcon = Icons.help_outline;
        _statusMessage = 'Face not recognized';
      });
    } else if (result.isNotTrained) {
      setState(() {
        _errorType = 'not_trained';
        _errorTitle = 'لم يتم تدريب الوجه';
        _errorDetail = 'Please register your face first.';
        _errorIcon = Icons.model_training;
        _statusMessage = 'Face not trained';
      });
    } else if (result.isConnectionError) {
      setState(() {
        _errorType = 'connection';
        _errorTitle = 'خطأ في الاتصال';
        _errorDetail = result.message;
        _errorIcon = Icons.cloud_off;
        _statusMessage = 'AI server connection error';
      });
    } else {
      setState(() {
        _errorType = 'unknown';
        _errorTitle = 'خطأ';
        _errorDetail = result.message;
        _errorIcon = Icons.error_outline;
        _statusMessage = result.message;
      });
    }
  }

  /// Submit attendance record after face verification
  Future<void> _submitAttendance(File imageFile) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final attendanceProvider = context.read<AttendanceProvider>();
      final employeeId = authProvider.currentEmployee?.id;

      if (employeeId == null) {
        _showErrorSnackbar('Employee not found');
        return;
      }

      final hasCheckedIn = attendanceProvider.hasCheckedInToday;
      bool success;

      if (hasCheckedIn) {
        success = await attendanceProvider.checkOut(
          employeeId: employeeId,
          requireGeofence: true,
        );
      } else {
        success = await attendanceProvider.checkIn(
          employeeId: employeeId,
          facePhoto: imageFile,
          requireGeofence: true,
        );
      }

      try {
        await imageFile.delete();
      } catch (_) {}

      if (success && mounted) {
        _showSuccessDialog(hasCheckedIn);
      } else if (mounted && attendanceProvider.error != null) {
        final error = attendanceProvider.error!;
        if (error.contains('لا يمكن تسجيل حضورك')) {
          _showOutOfBoundsDialog(error.replaceAll('Exception: ', ''));
        } else {
          _showErrorSnackbar(error.replaceAll('Exception: ', ''));
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showOutOfBoundsDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Location Error', style: TextStyle(color: AppTheme.errorColor)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Also pop the camera screen
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(bool wasCheckOut) {
    // Refresh all attendance data after success
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final employeeId = authProvider.currentEmployee?.id;
    if (employeeId != null) {
      attendanceProvider.loadTodayAttendance(employeeId);
      attendanceProvider.loadMonthlyStats(employeeId);
      attendanceProvider.loadAttendanceHistory(employeeId);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                wasCheckOut ? 'Checked Out!' : 'Checked In!',
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_verifiedName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$_verifiedName '
                        '(${(_verifiedConfidence * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Done',
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    setState(() {
      _isProcessing = false;
      _isVerifying = false;
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final hasCheckedIn = attendanceProvider.hasCheckedInToday;
    final screenHeight = MediaQuery.of(context).size.height;
    final cameraHeight = screenHeight * 0.50;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          hasCheckedIn ? 'Check Out' : 'Check In',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Server status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _serverAvailable ? Icons.cloud_done : Icons.cloud_off,
              color: _serverAvailable ? AppTheme.successColor : Colors.redAccent,
              size: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            tooltip: 'Re-train face',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FaceRegistrationScreen(),
                ),
              ).then((_) {
                _loadRegisteredFace();
                _checkServerStatus();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),

          // Camera preview - 50% of screen height
          Container(
            height: cameraHeight,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _faceVerified
                    ? AppTheme.successColor
                    : _isVerifying
                        ? Colors.amber
                        : _errorType != null
                            ? Colors.redAccent
                            : Colors.white24,
                width: 3,
              ),
              color: Colors.black87,
            ),
            clipBehavior: Clip.hardEdge,
            child: _isInitialized &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Fix aspect ratio instead of randomly stretching
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? MediaQuery.of(context).size.width,
                          height: _cameraController!.value.previewSize?.width ?? MediaQuery.of(context).size.height,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      
                      // AI verifying overlay
                      if (_isVerifying)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.amber,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'AI Verifying...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Verified badge
                      if (_faceVerified && _verifiedName != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_verifiedName '
                                    '(${(_verifiedConfidence * 100).toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: _hasError
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off,
                                  color: Colors.white54, size: 48),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _initializeCamera,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          const SizedBox(height: 16),

          // Error card or status message
          if (_errorType != null)
            _buildErrorCard()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),

          const Spacer(),

          // Bottom area: Capture button + Retry
          if (_errorType != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _clearError();
                    _statusMessage = 'Tap capture to verify your face';
                  });
                },
                icon:
                    const Icon(Icons.refresh, color: Colors.white70, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),

          // Capture Button
          GestureDetector(
            onTap: !_isProcessing &&
                    _isInitialized &&
                    _faceRegistered &&
                    _serverAvailable
                ? _captureAndVerify
                : null,
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _faceRegistered &&
                          !_isProcessing &&
                          _serverAvailable
                      ? AppTheme.successColor
                      : Colors.white24,
                  width: 4,
                ),
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _faceRegistered &&
                            !_isProcessing &&
                            _serverAvailable
                        ? AppTheme.successColor
                        : Colors.white24,
                  ),
                  child: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    Color errorColor;
    switch (_errorType) {
      case 'multiple_faces':
        errorColor = Colors.orange;
        break;
      case 'mismatch':
        errorColor = Colors.redAccent;
        break;
      case 'no_face':
        errorColor = Colors.amber;
        break;
      default:
        errorColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_errorIcon ?? Icons.error_outline, color: errorColor, size: 36),
          const SizedBox(height: 10),
          Text(
            _errorTitle ?? 'Error',
            style: TextStyle(
              color: errorColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _errorDetail ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
