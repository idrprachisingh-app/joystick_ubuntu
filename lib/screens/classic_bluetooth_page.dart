import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ClassicBluetoothPage extends StatefulWidget {
  const ClassicBluetoothPage({super.key});

  @override
  State<ClassicBluetoothPage> createState() => _ClassicBluetoothPageState();
}

class _ClassicBluetoothPageState extends State<ClassicBluetoothPage> {
  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;

  StreamSubscription<BluetoothDiscoveryResult>? _discSub;

  bool discovering = false;
  bool connecting = false;

  List<BluetoothDevice> bonded = [];
  final Map<String, BluetoothDiscoveryResult> discovered = {};

  BluetoothConnection? connection;
  BluetoothDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    _initBt();
  }

  Future<void> _initBt() async {
    final enabled = await _bt.isEnabled ?? false;
    if (!enabled) {
      await _bt.requestEnable();
    }

    bonded = await _bt.getBondedDevices();
    if (mounted) setState(() {});
  }

  Future<void> refreshPaired() async {
    bonded = await _bt.getBondedDevices();
    if (mounted) setState(() {});
  }

  Future<void> startDiscovery() async {
    discovered.clear();
    setState(() => discovering = true);

    await _discSub?.cancel();
    _discSub = _bt.startDiscovery().listen((r) {
      if (r.device.name?.isNotEmpty == true) {
        discovered[r.device.address] = r;
        if (mounted) setState(() {});
      }
    });

    _discSub?.onDone(() {
      if (mounted) setState(() => discovering = false);
    });
  }

  Future<void> stopDiscovery() async {
    await _discSub?.cancel();
    _discSub = null;
    if (mounted) setState(() => discovering = false);
  }

  Future<void> connectTo(BluetoothDevice device) async {
    if (connecting) return;

    setState(() => connecting = true);

    try {
      await stopDiscovery();

      if (connection != null) {
        await connection!.close();
        connection = null;
      }

      final conn = await BluetoothConnection.toAddress(device.address);

      connection = conn;
      connectedDevice = device;

      if (mounted) setState(() {});

      conn.input?.listen((data) {
        // If needed: receive bytes from device here
      }).onDone(() {
        if (mounted) {
          setState(() {
            connection = null;
            connectedDevice = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connect failed: $e")),
      );
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> disconnect() async {
    try {
      await connection?.close();
    } catch (_) {}
    connection = null;
    connectedDevice = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    stopDiscovery();
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveredList = discovered.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text("Bluetooth Classic"),
        actions: [
          IconButton(
            onPressed: refreshPaired,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            icon: Icon(discovering ? Icons.stop : Icons.search),
            onPressed: () => discovering ? stopDiscovery() : startDiscovery(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connectedDevice != null)
              _connectedTile(connectedDevice!)
            else
              _statusTile(title: "Connected", value: "None"),
            const SizedBox(height: 12),
            if (connecting)
              Text(
                "Connecting...",
                style: TextStyle(color: Colors.white.withOpacity(0.60)),
              ),
            const SizedBox(height: 10),
            Text(
              "Paired Devices",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: bonded.isEmpty
                  ? Center(
                      child: Text(
                        "No paired devices",
                        style: TextStyle(color: Colors.white.withOpacity(0.55)),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: bonded.length,
                      itemBuilder: (context, i) {
                        final d = bonded[i];
                        return _btCard(
                          title: d.name ?? "Unknown",
                          sub: d.address,
                          onTap: () => connectTo(d),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  "Nearby Devices",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  discovering ? "Scanning..." : "${discoveredList.length}",
                  style: TextStyle(color: Colors.white.withOpacity(0.55)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: discoveredList.isEmpty
                  ? Center(
                      child: Text(
                        discovering ? "Searching nearby devices..." : "Tap 🔍 to scan devices",
                        style: TextStyle(color: Colors.white.withOpacity(0.55)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: discoveredList.length,
                      itemBuilder: (context, i) {
                        final r = discoveredList[i];
                        final d = r.device;

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
                              d.name ?? "Unknown",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              "${d.address}\nRSSI: ${r.rssi}",
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            isThreeLine: true,
                            trailing: ElevatedButton(
                              onPressed: () => connectTo(d),
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
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w900),
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
              "Connected: ${d.name ?? d.address}",
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(onPressed: disconnect, child: const Text("Disconnect")),
        ],
      ),
    );
  }

  Widget _btCard({required String title, required String sub, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.link, color: Color(0xFF35F6A3), size: 18),
                const SizedBox(width: 8),
                Text("Tap to connect", style: TextStyle(color: Colors.white.withOpacity(0.60))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
