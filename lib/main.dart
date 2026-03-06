import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00B8D4),
          surface: Color(0xFF161B22),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const TrackerPage(),
    );
  }
}

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  String _status = 'Disconnected';
  bool _isTracking = false;
  Position? _currentPosition;
  String _deviceId = '';
  final TextEditingController _serverIpController = TextEditingController();
  StreamSubscription<Position>? _positionStream;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    const uuid = Uuid();
    _deviceId = 'phone_${uuid.v4().substring(0, 8)}';
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    final serverIp = _serverIpController.text.trim();
    if (serverIp.isEmpty) {
      _showSnackBar('Please enter Server IP');
      return;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied');
      return;
    }

    setState(() {
      _isTracking = true;
      _status = 'Connecting...';
    });

    try {
      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _status = 'Live Tracking';
      });

      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });

      // Start periodic updates to server
      _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _sendUpdateToServer();
      });

      // Send first update immediately
      _sendUpdateToServer();

    } catch (e) {
      _stopTracking();
      _showSnackBar('Error: $e');
    }
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _updateTimer?.cancel();
    setState(() {
      _isTracking = false;
      _status = 'Disconnected';
    });
  }

  Future<void> _sendUpdateToServer() async {
    if (_currentPosition == null) return;
    
    final serverIp = _serverIpController.text.trim();
    final url = Uri.parse('http://$serverIp:5000/api/mobile/update');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'name': 'Android Device',
          'lat': _currentPosition!.latitude,
          'lng': _currentPosition!.longitude,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        debugPrint('Update sent successfully');
      } else {
        debugPrint('Failed to send update: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending update: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E14), Color(0xFF1A1F2B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildStatusCard(),
                const SizedBox(height: 30),
                _buildInputSection(),
                const Spacer(),
                _buildTrackingButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.location_searching,
            color: Color(0xFF00E5FF),
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'TRACKER PRO',
          style: GoogleFonts.orbitron(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: Colors.white,
          ),
        ),
        Text(
          'SECURE REAL-TIME LINK',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SYSTEM STATUS', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isTracking ? const Color(0xFF00FF9D) : Colors.redAccent,
                          boxShadow: [
                            if (_isTracking)
                              BoxShadow(color: const Color(0xFF00FF9D).withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _status.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isTracking ? const Color(0xFF00FF9D) : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.security, color: Colors.white12, size: 24),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildDataRow('DEVICE ID', _deviceId.toUpperCase()),
          const SizedBox(height: 12),
          _buildDataRow(
            'GPS COORDS',
            _currentPosition != null
                ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                : 'WAITING FOR SIGNAL...',
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white30, letterSpacing: 1)),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, color: Colors.white)),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CENTRAL CONSOLE IP', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _serverIpController,
          enabled: !_isTracking,
          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '0.0.0.0',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            prefixIcon: const Icon(Icons.lan, color: Colors.white24, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildTrackingButton() {
    return GestureDetector(
      onTap: _toggleTracking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: _isTracking
                ? [const Color(0xFFCF6679), const Color(0xFFB00020)]
                : [const Color(0xFF00E5FF), const Color(0xFF00B8D4)],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isTracking ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isTracking ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                _isTracking ? 'STOP TRACKING' : 'START TRACKING',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopTracking();
    _serverIpController.dispose();
    super.dispose();
  }
}