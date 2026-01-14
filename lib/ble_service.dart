// lib/ble_service.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Abstract class defines the "contract" for our service.
abstract class BleService {
  Stream<List<ScanResult>> get scanResults;
  Stream<bool> get isScanning;
  Stream<BluetoothConnectionState> get connectionState;
  BluetoothDevice? get connectedDevice;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device);
  void disconnect();
  void sendControl(List<int> bytes);
}

// The real implementation that uses flutter_blue_plus.
class FlutterBlueBleService implements BleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _controlCharacteristic;

  // TODO: Replace with your actual Service and Characteristic UUIDs
  final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  final Guid characteristicUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  @override
  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    await device.connect();
    _connectedDevice = device;
    await _discoverServices();
  }

  @override
  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _controlCharacteristic = null;
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            _controlCharacteristic = characteristic;
          }
        }
      }
    }
  }

  @override
  void sendControl(List<int> bytes) {
    _controlCharacteristic?.write(bytes, withoutResponse: true);
  }

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      _connectedDevice?.connectionState ?? Stream.value(BluetoothConnectionState.disconnected);
      
  @override
  BluetoothDevice? get connectedDevice => _connectedDevice;
}