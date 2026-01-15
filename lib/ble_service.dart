import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE service wrapper (FlutterBluePlus)
class BleService {
  BleService._();
  static final BleService I = BleService._();

  BluetoothDevice? connectedDevice;

  final StreamController<List<ScanResult>> _resultsCtrl =
  StreamController<List<ScanResult>>.broadcast();

  final Map<DeviceIdentifier, ScanResult> _resultsMap = {};

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  Stream<List<ScanResult>> get scanResults => _resultsCtrl.stream;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  BluetoothAdapterState get adapterState => FlutterBluePlus.adapterStateNow;

  /// ✅ Call once at app start (optional but good)
  Future<void> init() async {
    _adapterSub ??= FlutterBluePlus.adapterState.listen((state) async {
      if (state != BluetoothAdapterState.on) {
        await stopScan();
      }
    });
  }

  /// ✅ Android permissions (very important)
  Future<void> ensurePermissions() async {
    // NOTE: On Android 12+ (API 31+)
    // Scan + connect permissions required.
    // Location still needed by many devices during scan.

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  /// ✅ Start BLE Scan
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    await ensurePermissions();

    _resultsMap.clear();
    _resultsCtrl.add([]);

    // cancel old listener
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        _resultsMap[r.device.remoteId] = r;
      }

      final merged = _resultsMap.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      _resultsCtrl.add(merged);
    });

    // reset scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );
  }

  /// ✅ Stop BLE scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// ✅ Connect to device reliably
  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    await ensurePermissions();

    // Disconnect previous device
    if (connectedDevice != null) {
      await disconnect();
    }

    // Some devices throw if already connected
    try {
      await device.disconnect();
    } catch (_) {}

    // ✅ Connect
    await device.connect(timeout: const Duration(seconds: 15));
    connectedDevice = device;

    // ✅ Drone-style stable communication improvements
    try {
      await device.requestMtu(247);
    } catch (_) {}

    try {
      await device.discoverServices();
    } catch (_) {}
  }

  /// ✅ Disconnect
  Future<void> disconnect() async {
    if (connectedDevice == null) return;

    try {
      await connectedDevice!.disconnect();
    } catch (_) {}

    connectedDevice = null;
  }

  /// ✅ Connection state stream
  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device) {
    return device.connectionState;
  }

  void dispose() {
    stopScan();
    _adapterSub?.cancel();
    _adapterSub = null;
    _resultsCtrl.close();
  }
}
