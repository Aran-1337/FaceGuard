import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_text_field.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final navigator = Navigator.of(context);
    final dbService = DatabaseService();
    final storageService = StorageService();
    final imagePicker = ImagePicker();

    String name = user.name;
    String? photoUrl = user.photoUrl;
    File? selectedImage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (buildContext, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(buildContext).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Profile',
                        style: Theme.of(buildContext).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => navigator.pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Profile Image
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor,
                          backgroundImage: selectedImage != null
                              ? FileImage(selectedImage!)
                              : (photoUrl != null
                                    ? NetworkImage(photoUrl!) as ImageProvider
                                    : null),
                          child: selectedImage == null && photoUrl == null
                              ? Text(
                                  name[0],
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setModalState(
                                  () => selectedImage = File(picked.path),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: 'Name',
                    initialValue: name,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 16),
                  // Email (read-only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email, color: AppTheme.greyColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email',
                              style: TextStyle(
                                color: AppTheme.greyColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(user.email),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setModalState(() => isLoading = true);
                              try {
                                String? newPhotoUrl = photoUrl;

                                // Upload new image if selected
                                if (selectedImage != null) {
                                  newPhotoUrl = await storageService
                                      .uploadProfileImage(
                                        user.uid,
                                        selectedImage!,
                                      );
                                }

                                final updatedUser = user.copyWith(
                                  name: name,
                                  photoUrl: newPhotoUrl,
                                );
                                await dbService.updateUser(updatedUser);
                                await authProvider.refreshUser();
                                if (buildContext.mounted) {
                                  navigator.pop();
                                  ScaffoldMessenger.of(
                                    buildContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated!'),
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                if (buildContext.mounted) {
                                  ScaffoldMessenger.of(
                                    buildContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final user = authProvider.currentUser;
    final employee = authProvider.currentEmployee;

    return Scaffold(
      appBar: AppBar(
        title: Text(settingsProvider.isArabic ? 'الإعدادات' : 'Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Text(
                          user?.name[0] ?? 'E',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Employee',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user?.role.name.toUpperCase() ?? 'USER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (employee != null)
                            Text(
                              'Code: ${employee.employeeCode}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.greyColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditProfileDialog(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Preferences Section
          _buildSectionTitle(
            context,
            settingsProvider.isArabic ? 'التفضيلات' : 'Preferences',
          ),

          // Dark Mode
          SwitchListTile(
            title: Text(
              settingsProvider.isArabic ? 'الوضع الداكن' : 'Dark Mode',
            ),
            subtitle: Text(
              settingsProvider.isArabic
                  ? 'استخدام المظهر الداكن'
                  : 'Use dark theme',
            ),
            value: settingsProvider.isDarkMode,
            onChanged: (value) => settingsProvider.toggleDarkMode(value),
            secondary: Icon(
              settingsProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
          ),

          // Language
          SwitchListTile(
            title: Text(settingsProvider.isArabic ? 'اللغة' : 'Language'),
            subtitle: Text(
              settingsProvider.isArabic ? 'العربية (Arabic)' : 'English',
            ),
            value: settingsProvider.isArabic,
            onChanged: (value) =>
                settingsProvider.setLocale(Locale(value ? 'ar' : 'en')),
            secondary: const Icon(Icons.language),
          ),

          // Notifications
          SwitchListTile(
            title: Text(
              settingsProvider.isArabic ? 'الإشعارات' : 'Notifications',
            ),
            subtitle: Text(
              settingsProvider.isArabic
                  ? 'تلقي تذكيرات الحضور'
                  : 'Receive attendance reminders',
            ),
            value: true,
            onChanged: (value) {},
            secondary: const Icon(Icons.notifications_outlined),
          ),

          const Divider(),

          // About Section
          _buildSectionTitle(
            context,
            settingsProvider.isArabic ? 'حول التطبيق' : 'About',
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              settingsProvider.isArabic ? 'إصدار التطبيق' : 'App Version',
            ),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(
              settingsProvider.isArabic ? 'المساعدة والدعم' : 'Help & Support',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(
              settingsProvider.isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: Text(
              settingsProvider.isArabic ? 'تسجيل الخروج' : 'Logout',
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _handleLogout(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.greyColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
