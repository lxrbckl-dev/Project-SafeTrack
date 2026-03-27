import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityTestPage extends StatefulWidget {
  const ConnectivityTestPage({super.key});

  @override
  State<ConnectivityTestPage> createState() => _ConnectivityTestPageState();
}

class _ConnectivityTestPageState extends State<ConnectivityTestPage> {
  List<ConnectivityResult> _connectivityResult = [];
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _connectivityResult = result);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _connectivityResult = result);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _connectivityResult.isNotEmpty &&
        !_connectivityResult.contains(ConnectivityResult.none);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectivity Test'),
        backgroundColor: const Color(0xFF000000),
        foregroundColor: const Color(0xFFFFD100),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              size: 80,
              color: isOnline
                  ? const Color(0xFF1E6B38)
                  : const Color(0xFFAB2D24),
            ),
            const SizedBox(height: 24),
            Text(
              isOnline ? 'ONLINE' : 'OFFLINE',
              style: const TextStyle(
                fontFamily: 'Oswald',
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connection types: ${_connectivityResult.map((r) => r.name).join(", ")}',
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Color(0xFF58595B),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1ECF1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Toggle WiFi/airplane mode to test real-time detection',
                style: TextStyle(color: Color(0xFF086670)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
