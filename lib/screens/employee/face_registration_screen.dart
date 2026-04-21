import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/face_ai_service.dart';
import '../../services/storage_service.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isDisposing = false;
  bool _isTraining = false;
  String _statusMessage = 'Initializing camera...';
  bool _hasError = false;
  String _instruction = 'Look straight at the camera';
  int _capturedAngles = 0;
  final DatabaseService _dbService = DatabaseService();
  final FaceAiService _faceAiService = FaceAiService();
  final StorageService _storageService = StorageService();
  bool _serverAvailable = false;

  // Training state
  double _trainingProgress = 0.0;
  String _trainingStep = '';

  // Store captured images for training
  final List<File> _capturedImages = [];

  static const int _requiredPhotos = 5;

  final List<String> _stages = [
    'Look straight at the camera',
    'Turn your head slightly left',
    'Turn your head slightly right',
    'Tilt your head slightly up',
    'Tilt your head slightly down',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    // Clean up all captured images
    for (final img in _capturedImages) {
      img.delete().catchError((_) => File(''));
    }
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

  /// Check if the AI backend server is running
  Future<void> _checkServerStatus() async {
    final available = await _faceAiService.isServerAvailable();
    if (mounted) {
      setState(() {
        _serverAvailable = available;
        if (!available) {
          _hasError = true;
          _statusMessage =
              'AI server is offline. Cannot register face.\n'
              'Please make sure the backend server is running.';
        }
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposing) return;

    setState(() {
      _hasError = false;
      _isInitialized = false;
      _statusMessage = 'Initializing camera...';
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

      // Re-check server status
      if (!_serverAvailable) {
        await _checkServerStatus();
      }

      setState(() {
        _isInitialized = true;
        _statusMessage = _serverAvailable
            ? 'Capture $_requiredPhotos photos to train face recognition'
            : 'AI server offline. Please start the backend server.';
        _instruction = _stages[_capturedAngles];
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

  Future<void> _pickFromGallery() async {
    if (_isProcessing || !_serverAvailable) return;

    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Processing images...';
      });

      int needed = _requiredPhotos - _capturedAngles;
      int toAdd = pickedFiles.length > needed ? needed : pickedFiles.length;

      for (int i = 0; i < toAdd; i++) {
        _capturedImages.add(File(pickedFiles[i].path));
      }

      setState(() {
        _capturedAngles += toAdd;
        if (_capturedAngles < _requiredPhotos) {
          _instruction = _stages[_capturedAngles];
          _statusMessage = 'Photo $_capturedAngles/$_requiredPhotos added ✓';
          _isProcessing = false;
        }
      });

      if (_capturedAngles >= _requiredPhotos) {
        await _trainFaceModel();
      }
    } catch (e) {
      _showError('Error picking images: $e');
    } finally {
      if (mounted && _capturedAngles < _requiredPhotos) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _captureAngle() async {
    if (_cameraController == null || _isProcessing || !_serverAvailable) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      _capturedImages.add(imageFile);

      setState(() {
        _capturedAngles++;
        if (_capturedAngles < _requiredPhotos) {
          _instruction = _stages[_capturedAngles];
          _statusMessage =
              'Photo $_capturedAngles/$_requiredPhotos captured ✓';
          _isProcessing = false;
        }
      });

      if (_capturedAngles >= _requiredPhotos) {
        await _trainFaceModel();
      }
    } catch (e) {
      _showError('Error capturing photo: $e');
    }
  }

  /// Train the face model using captured images
  Future<void> _trainFaceModel() async {
    if (!mounted) return;

    setState(() {
      _isTraining = true;
      _trainingProgress = 0.0;
      _trainingStep = 'Preparing training photos...';
      _statusMessage = 'Training in progress...';
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final employee = authProvider.currentEmployee;
      final user = authProvider.currentUser;

      if (employee == null || user == null) {
        _showError('Employee not found');
        return;
      }

      // Step 1: Convert images to base64
      setState(() {
        _trainingProgress = 0.1;
        _trainingStep = 'Encoding images...';
      });

      final List<String> base64Images = [];
      for (final img in _capturedImages) {
        final bytes = await img.readAsBytes();
        base64Images.add(base64Encode(bytes));
      }

      // Step 2: Upload training photos to Firebase Storage
      setState(() {
        _trainingProgress = 0.3;
        _trainingStep = 'Uploading photos to cloud...';
      });

      List<String> photoUrls = [];
      try {
        photoUrls = await _storageService.uploadTrainingPhotos(
          user.uid,
          _capturedImages,
        );
        debugPrint(
          'FaceRegistration: Uploaded ${photoUrls.length} training photos',
        );
      } catch (e) {
        debugPrint('FaceRegistration: Photo upload failed (non-fatal): $e');
        // Non-fatal: continue with AI training even if storage upload fails
      }

      // Step 3: Send all photos to AI backend for training
      setState(() {
        _trainingProgress = 0.5;
        _trainingStep = 'AI is learning your face...';
      });

      final trainResult = await _faceAiService.trainFace(
        name: user.name,
        userId: employee.employeeCode,
        base64Images: base64Images,
      );

      if (!trainResult.success) {
        _showError('Training failed: ${trainResult.message}');
        return;
      }

      // Step 4: Update employee record
      setState(() {
        _trainingProgress = 0.8;
        _trainingStep = 'Saving registration...';
      });

      final registrationTimestamp = DateTime.now().toIso8601String();
      final updatedEmployee = employee.copyWith(
        faceEmbeddings: ['trained:$registrationTimestamp'],
        trainingPhotoUrls: photoUrls,
      );
      await _dbService.updateEmployee(updatedEmployee);
      await authProvider.refreshUser();

      // Step 5: Done!
      setState(() {
        _trainingProgress = 1.0;
        _trainingStep = 'Training complete!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      // Clean up captured images
      for (final img in _capturedImages) {
        try {
          await img.delete();
        } catch (_) {}
      }
      _capturedImages.clear();

      if (mounted) {
        _showSuccessDialog(
          trainResult.encodingsGenerated,
          trainResult.totalImages,
          photoUrls.length,
        );
      }
    } catch (e) {
      _showError('Training failed: $e');
    }
  }

  void _showSuccessDialog(
    int encodingsGenerated,
    int totalImages,
    int photosUploaded,
  ) {
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
                'Face Trained Successfully!',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      Icons.smart_toy,
                      'AI Encodings',
                      '$encodingsGenerated / $totalImages',
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      Icons.cloud_upload,
                      'Photos Saved',
                      '$photosUploaded uploaded',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can now use face-verified check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.greyColor, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    setState(() {
      _isProcessing = false;
      _isTraining = false;
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cameraHeight = screenHeight * 0.50;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Train Face Recognition',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // AI server status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _serverAvailable ? Icons.smart_toy : Icons.smart_toy_outlined,
                  color: _serverAvailable
                      ? AppTheme.successColor
                      : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _serverAvailable ? 'AI' : 'OFF',
                  style: TextStyle(
                    color: _serverAvailable
                        ? AppTheme.successColor
                        : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isTraining ? _buildTrainingView() : _buildCaptureView(cameraHeight),
    );
  }

  /// Training progress view
  Widget _buildTrainingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
              child: Icon(
                _trainingProgress >= 1.0
                    ? Icons.check_circle
                    : Icons.smart_toy,
                color: _trainingProgress >= 1.0
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 32),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _trainingProgress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _trainingProgress >= 1.0
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress percentage
            Text(
              '${(_trainingProgress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Step description
            Text(
              _trainingStep,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Camera capture view
  Widget _buildCaptureView(double cameraHeight) {
    return Column(
      children: [
        // Progress dots
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_requiredPhotos, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 50,
                height: 8,
                decoration: BoxDecoration(
                  color: index < _capturedAngles
                      ? AppTheme.successColor
                      : index == _capturedAngles
                          ? AppTheme.primaryColor
                          : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),

        // Counter
        Text(
          '$_capturedAngles / $_requiredPhotos',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        const Spacer(flex: 1),

        // Instruction banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Camera preview
        Container(
          height: cameraHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _capturedAngles > 0
                  ? AppTheme.successColor.withValues(alpha: 0.6)
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
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? MediaQuery.of(context).size.width,
                        height: _cameraController!.value.previewSize?.width ?? MediaQuery.of(context).size.height,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: _hasError
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _serverAvailable
                                  ? Icons.videocam_off
                                  : Icons.cloud_off,
                              color: Colors.white54,
                              size: 48,
                            ),
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
                              onPressed: () {
                                _checkServerStatus();
                                _initializeCamera();
                              },
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

        // Status message
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),

        const Spacer(),

        // Capture Buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery Button
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.photo_library),
                  color: Colors.white,
                  iconSize: 28,
                  tooltip: 'Pick from Gallery',
                  onPressed: !_isProcessing && _serverAvailable
                      ? _pickFromGallery
                      : null,
                ),
              ),

              // Camera Capture Button
              GestureDetector(
                onTap: !_isProcessing && _isInitialized && _serverAvailable
                    ? _captureAngle
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isProcessing || !_serverAvailable
                          ? Colors.white24
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing || !_serverAvailable
                            ? Colors.white24
                            : Colors.white,
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: _serverAvailable
                                  ? AppTheme.primaryColor
                                  : Colors.grey,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ),

              // Placeholder for symmetry
              const SizedBox(width: 60),
            ],
          ),
        ),
      ],
    );
  }
}
