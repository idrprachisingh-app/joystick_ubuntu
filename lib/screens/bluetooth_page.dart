import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:joy_stickcontroller/ble_service.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final BleService ble = BleService.I;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanStateSub;

  List<ScanResult> results = [];
  bool scanning = false;
  bool connecting = false;

  @override
  void initState() {
    super.initState();

    ble.init();

    _scanSub = ble.scanResults.listen((list) {
      setState(() => results = list);
    });

    _scanStateSub = ble.isScanning.listen((v) {
      setState(() => scanning = v);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    try {
      await ble.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      _snack("Scan failed: $e");
    }
  }

  Future<void> _connect(ScanResult r) async {
    final deviceName =
    r.device.platformName.isNotEmpty ? r.device.platformName : "Unknown Device";

    setState(() => connecting = true);

    try {
      await ble.connect(r.device);
      if (!mounted) return;

      _snack("Connected: $deviceName");
      Navigator.pop(context, ble.connectedDevice);
    } catch (e) {
      _snack("Connection failed: $e");
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("Bluetooth (BLE)"),
        backgroundColor: const Color(0xFF0B0B0B),
        actions: [
          if (scanning == true)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: scanning ? null : _scan,
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    connecting
                        ? "Connecting..."
                        : scanning
                        ? "Scanning nearby devices..."
                        : "Tap Scan to find devices",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (ble.connectedDevice != null)
                  Text(
                    "CONNECTED",
                    style: TextStyle(
                      color: Colors.greenAccent.withOpacity(0.9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: results.isEmpty
                ? Center(
              child: Text(
                "No devices found.\nPress Scan.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) {
                final r = results[i];
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : "Unknown Device";

                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  iconColor: Colors.white.withOpacity(0.7),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    r.device.remoteId.toString(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  trailing: Text(
                    "${r.rssi} dBm",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: connecting ? null : () => _connect(r),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanning || connecting ? null : _scan,
        child: const Icon(Icons.search),
      ),
    );
  }
}
