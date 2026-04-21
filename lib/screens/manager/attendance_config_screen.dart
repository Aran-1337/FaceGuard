import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_button.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceConfigScreen extends StatefulWidget {
  const AttendanceConfigScreen({super.key});

  @override
  State<AttendanceConfigScreen> createState() => _AttendanceConfigScreenState();
}

class _AttendanceConfigScreenState extends State<AttendanceConfigScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  bool _isSaving = false;

  TimeOfDay _workStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEndTime = const TimeOfDay(hour: 17, minute: 0);
  int _lateThreshold = 15;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final MapController _mapController = MapController();
  double _radius = 100.0;
  LatLng _mapCenter = const LatLng(30.0444, 31.2357);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _dbService.getAttendanceConfig();
      setState(() {
        _workStartTime = TimeOfDay(
          hour: config['workStartHour'] ?? 9,
          minute: config['workStartMinute'] ?? 0,
        );
        _workEndTime = TimeOfDay(
          hour: config['workEndHour'] ?? 17,
          minute: config['workEndMinute'] ?? 0,
        );
        _lateThreshold = config['lateThresholdMinutes'] ?? 15;
        
        final lat = (config['companyLatitude'] ?? 30.0444).toDouble();
        final lng = (config['companyLongitude'] ?? 31.2357).toDouble();
        
        _latController.text = lat.toString();
        _lngController.text = lng.toString();
        _mapCenter = LatLng(lat, lng);
        _radius = (config['geofenceRadiusMeters'] ?? 100.0).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
        _mapCenter = LatLng(position.latitude, position.longitude);
        _mapController.move(_mapCenter, 16);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Work Schedule & Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Configure check-in times and company area',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Company Location Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Company Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Use My Location'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Map Preview
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _mapCenter,
                            initialZoom: 16,
                            onTap: (tapPosition, point) {
                              setState(() {
                                _latController.text = point.latitude.toStringAsFixed(6);
                                _lngController.text = point.longitude.toStringAsFixed(6);
                                _mapCenter = point;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.pig',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _mapCenter,
                                  width: 80,
                                  height: 80,
                                  child: const Icon(Icons.location_on, color: AppTheme.errorColor, size: 40),
                                ),
                              ],
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _mapCenter,
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderStrokeWidth: 2,
                                  borderColor: AppTheme.primaryColor,
                                  useRadiusInMeter: true,
                                  radius: _radius, // dynamic radius!
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Overlay instruction
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Tap anywhere to place property pin',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final v = double.tryParse(val);
                            if (v != null) {
                              setState(() => _mapCenter = LatLng(v, _mapCenter.longitude));
                              _mapController.move(_mapCenter, _mapController.camera.zoom);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.public, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final v = double.tryParse(val);
                            if (v != null) {
                              setState(() => _mapCenter = LatLng(_mapCenter.latitude, v));
                              _mapController.move(_mapCenter, _mapController.camera.zoom);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.public, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Geofence Radius (Meters)',
                    style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _radius,
                          min: 50,
                          max: 1000,
                          divisions: 19,
                          label: '${_radius.round()} m',
                          onChanged: (v) => setState(() => _radius = v),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${_radius.round()} m', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                    ],
                  ),
                  const Divider(height: 48),

                  // Work Start Time
                  Text(
                    'Work Start Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Employees checking in after this time + threshold will be marked as Late',
                    style: TextStyle(
                        color: AppTheme.greyColor, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildTimePicker(
                    icon: Icons.login,
                    label: 'Check-In Time',
                    time: _workStartTime,
                    color: AppTheme.successColor,
                    isDark: isDark,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _workStartTime,
                      );
                      if (picked != null) {
                        setState(() => _workStartTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Work End Time
                  Text(
                    'Work End Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected check-out time for employees',
                    style: TextStyle(
                        color: AppTheme.greyColor, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildTimePicker(
                    icon: Icons.logout,
                    label: 'Check-Out Time',
                    time: _workEndTime,
                    color: AppTheme.errorColor,
                    isDark: isDark,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _workEndTime,
                      );
                      if (picked != null) {
                        setState(() => _workEndTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 28),

                  // Late Threshold
                  Text(
                    'Late Threshold',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minutes after work start time before marking as late',
                    style: TextStyle(
                        color: AppTheme.greyColor, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.timer,
                                  color: AppTheme.warningColor),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$_lateThreshold minutes',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _lateThreshold.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 12,
                          label: '$_lateThreshold min',
                          activeColor: AppTheme.warningColor,
                          onChanged: (v) {
                            setState(
                                () => _lateThreshold = v.round());
                          },
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0 min',
                                style: TextStyle(
                                    color: AppTheme.greyColor,
                                    fontSize: 12)),
                            Text('60 min',
                                style: TextStyle(
                                    color: AppTheme.greyColor,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppTheme.infoColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.infoColor, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.infoColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Company Area: ${_radius.round()}m from ${_latController.text}, ${_lngController.text}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• On Time: Check-in before ${_formatTime(_workStartTime)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• Grace Period: ${_formatTime(_workStartTime)} – ${_formatTime(TimeOfDay(hour: _workStartTime.hour + (_workStartTime.minute + _lateThreshold) ~/ 60, minute: (_workStartTime.minute + _lateThreshold) % 60))}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• Late: After ${_formatTime(TimeOfDay(hour: _workStartTime.hour + (_workStartTime.minute + _lateThreshold) ~/ 60, minute: (_workStartTime.minute + _lateThreshold) % 60))}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '• Work ends at: ${_formatTime(_workEndTime)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  GradientButton(
                    text: 'Save Configuration',
                    icon: Icons.save,
                    isLoading: _isSaving,
                    onPressed: _saveConfig,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimePicker({
    required IconData icon,
    required String label,
    required TimeOfDay time,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: AppTheme.greyColor, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(time),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit, color: AppTheme.greyColor),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      await _dbService.updateAttendanceConfig({
        'workStartHour': _workStartTime.hour,
        'workStartMinute': _workStartTime.minute,
        'workEndHour': _workEndTime.hour,
        'workEndMinute': _workEndTime.minute,
        'lateThresholdMinutes': _lateThreshold,
        'companyLatitude': double.tryParse(_latController.text) ?? 30.0444,
        'companyLongitude': double.tryParse(_lngController.text) ?? 31.2357,
        'geofenceRadiusMeters': _radius,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
