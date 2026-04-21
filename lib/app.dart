import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'models/user_model.dart';

class PigApp extends StatelessWidget {
  const PigApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'PIG Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      locale: settingsProvider.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show loading while checking auth state
    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Navigate based on auth state and user role
    if (authProvider.isAuthenticated) {
      final role = authProvider.currentUser!.role;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        String route;
        switch (role) {
          case UserRole.employee:
            route = AppRoutes.employeeDashboard;
            break;
          case UserRole.manager:
            route = AppRoutes.managerDashboard;
            break;
          case UserRole.admin:
            route = AppRoutes.adminDashboard;
            break;
        }
        Navigator.pushReplacementNamed(context, route);
      });

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Not authenticated - show login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
