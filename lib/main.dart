import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/employee_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with explicit options
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => EmployeeProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const PigApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('FATAL INITIALIZATION ERROR: $e');
    debugPrint('$stackTrace');
    
    // If initialization fails, run a simple app showing the error so the user isn't stuck on splash screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initialization Error',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The application failed to initialize properly. Details below:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: SingleChildScrollView(
                        child: Text(
                          '$e\n\n$stackTrace',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
