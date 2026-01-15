import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final Map<DeviceIdentifier, ScanResult> results = {};
  StreamSubscription<List<ScanResult>>? _scanSub;

  BluetoothDevice? connectedDevice;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    await FlutterBluePlus.turnOn();

    FlutterBluePlus.adapterState.listen((s) {
      if (mounted) setState(() {});
    });
  }

  Future<void> startScan() async {
    results.clear();
    setState(() => scanning = true);

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      androidUsesFineLocation: true,
    );

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        results[r.device.remoteId] = r;
      }
      if (mounted) setState(() {});
    });

    Future.delayed(const Duration(seconds: 12), () async {
      await stopScan();
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => scanning = false);
  }

  Future<void> connect(BluetoothDevice d) async {
    try {
      await stopScan();
      if (connectedDevice != null) {
        await connectedDevice!.disconnect();
      }

      await d.connect(timeout: const Duration(seconds: 15));
      connectedDevice = d;

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connect failed: $e")),
      );
    }
  }

  Future<void> disconnect() async {
    if (connectedDevice == null) return;
    try {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adapterState = FlutterBluePlus.adapterStateNow;

    final list = results.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text("Bluetooth Devices"),
        actions: [
          IconButton(
            icon: Icon(scanning ? Icons.stop : Icons.search),
            onPressed: () => scanning ? stopScan() : startScan(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusTile(
              title: "Adapter",
              value: adapterState.toString().replaceAll("BluetoothAdapterState.", ""),
            ),
            const SizedBox(height: 10),

            if (connectedDevice != null)
              _connectedTile(connectedDevice!)
            else
              _statusTile(title: "Connected", value: "None"),

            const SizedBox(height: 14),
            Text(
              "Nearby Devices (${list.length})",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: list.isEmpty
                  ? Center(
                child: Text(
                  scanning ? "Scanning..." : "No devices found.\nTap search to scan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.55)),
                ),
              )
                  : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final d = r.device;

                  final name = (r.advertisementData.advName.isNotEmpty)
                      ? r.advertisementData.advName
                      : (d.platformName.isNotEmpty ? d.platformName : "Unknown");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth, color: Color(0xFF35F6A3)),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        "${d.remoteId.str}\nRSSI: ${r.rssi}",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        onPressed: () => connect(d),
                        child: const Text("Connect"),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTile({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.white.withOpacity(0.55))),
        ],
      ),
    );
  }

  Widget _connectedTile(BluetoothDevice d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF35F6A3).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF35F6A3).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF35F6A3)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Connected: ${d.platformName.isNotEmpty ? d.platformName : d.remoteId.str}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: disconnect,
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
  }
}
