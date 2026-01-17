import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/* ============================================================
    GLOBAL BLE & DATA MANAGER
   ============================================================ */
class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeChar;

  bool get isReady => connectedDevice != null && writeChar != null;

  Future<void> sendRcCsv(String csv) async {
    if (isReady) {
      try {
        await writeChar!.write(utf8.encode(csv), withoutResponse: true);
      } catch (_) {}
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF050505)),
      home: const ControllerUI(),
    );
  }
}

/* ============================================================
    MODELS
   ============================================================ */
class HudItem {
  final String id;
  final Offset posPct;
  final double scale;
  const HudItem({required this.id, required this.posPct, this.scale = 1.0});

  HudItem copyWith({Offset? posPct, double? scale}) =>
      HudItem(id: id, posPct: posPct ?? this.posPct, scale: scale ?? this.scale);
}

/* ============================================================
    MAIN UI
   ============================================================ */
class ControllerUI extends StatefulWidget {
  const ControllerUI({super.key});
  @override
  State<ControllerUI> createState() => _ControllerUIState();
}

class _ControllerUIState extends State<ControllerUI> {
  bool powerOn = true;
  bool hudEditMode = false;
  bool hudMoveEnabled = true;
  bool hudResizeEnabled = true;

  // Controller Inputs
  Offset leftJoy = Offset.zero;
  Offset rightJoy = Offset.zero;

  // 2-Option Switches (0 or 1)
  int sw1 = 0, sw2 = 0;
  // 3-Option Switches (0, 1, or 2)
  int sw3 = 0, sw4 = 0;

  late Map<String, HudItem> hud;
  Timer? _txTimer;

  @override
  void initState() {
    super.initState();
    _resetHud();
    _txTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (powerOn && BleManager().isReady) {
        BleManager().sendRcCsv(_getFormattedData());
      }
    });
  }

  @override
  void dispose() {
    _txTimer?.cancel();
    super.dispose();
  }

  void _resetHud() {
    setState(() {
      hud = {
        "bt": const HudItem(id: "bt", posPct: Offset(0.04, 0.05)),
        "power": const HudItem(id: "power", posPct: Offset(0.47, 0.02)),
        "topRight": const HudItem(id: "topRight", posPct: Offset(0.85, 0.05)),
        "swLeft": const HudItem(id: "swLeft", posPct: Offset(0.18, 0.15)),
        "swRight": const HudItem(id: "swRight", posPct: Offset(0.72, 0.15)),
        "joyLeft": const HudItem(id: "joyLeft", posPct: Offset(0.16, 0.48)),
        "joyRight": const HudItem(id: "joyRight", posPct: Offset(0.70, 0.48)),
        "dpadLeft": const HudItem(id: "dpadLeft", posPct: Offset(0.06, 0.72)),
        "dpadRight": const HudItem(id: "dpadRight", posPct: Offset(0.88, 0.72)),
        "ab": const HudItem(id: "ab", posPct: Offset(0.43, 0.72)),
        "debug": const HudItem(id: "debug", posPct: Offset(0.02, 0.82)),
      };
    });
  }

  String _getFormattedData() {
    int map(double v) => (1500 + (v.clamp(-1.0, 1.0) * 500)).round();
    // Format: THR,YAW,PIT,ROL,SW1,SW2,SW3,SW4
    return "${map(-leftJoy.dy)},${map(leftJoy.dx)},${map(-rightJoy.dy)},${map(rightJoy.dx)},$sw1,$sw2,$sw3,$sw4\n";
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("HUD EDIT SETTINGS"),
              SwitchListTile(
                title: const Text("Edit Mode"),
                value: hudEditMode,
                onChanged: (v) { setState(() => hudEditMode = v); setMState(() {}); },
              ),
              if (hudEditMode) ...[
                CheckboxListTile(title: const Text("Move"), value: hudMoveEnabled, onChanged: (v) => setState(() => hudMoveEnabled = v!)),
                CheckboxListTile(title: const Text("Scale"), value: hudResizeEnabled, onChanged: (v) => setState(() => hudResizeEnabled = v!)),
                ElevatedButton(onPressed: _resetHud, child: const Text("Reset Layout")),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Bluetooth Chip
          HudWrapper(
            item: hud["bt"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["bt"] = ni),
            child: _ActionChip(
              label: BleManager().isReady ? "LINKED" : "BT UART",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BluetoothPage())),
            ),
          ),
          // Power Button
          HudWrapper(
            item: hud["power"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["power"] = ni),
            child: _PowerBtn(isOn: powerOn, onTap: () => setState(() => powerOn = !powerOn)),
          ),
          // Link & Settings
          HudWrapper(
            item: hud["topRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["topRight"] = ni),
            child: Row(children: [
              const Icon(Icons.link, color: Colors.white54, size: 30),
              const SizedBox(width: 15),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white54, size: 30), onPressed: _openSettings),
            ]),
          ),
          // 2-Position Switches (SW1, SW2)
          HudWrapper(
            item: hud["swLeft"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["swLeft"] = ni),
            child: Row(children: [
              _MultiSwitch(label: "SW1", options: 2, current: sw1, onToggle: (v) => setState(() => sw1 = v), enabled: powerOn),
              const SizedBox(width: 15),
              _MultiSwitch(label: "SW2", options: 2, current: sw2, onToggle: (v) => setState(() => sw2 = v), enabled: powerOn),
            ]),
          ),
          // 3-Position Switches (SW3, SW4)
          HudWrapper(
            item: hud["swRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["swRight"] = ni),
            child: Row(children: [
              _MultiSwitch(label: "SW3", options: 3, current: sw3, onToggle: (v) => setState(() => sw3 = v), enabled: powerOn),
              const SizedBox(width: 15),
              _MultiSwitch(label: "SW4", options: 3, current: sw4, onToggle: (v) => setState(() => sw4 = v), enabled: powerOn),
            ]),
          ),
          // Joysticks
          HudWrapper(
            item: hud["joyLeft"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["joyLeft"] = ni),
            child: _Joystick(enabled: powerOn && !hudEditMode, onMove: (v) => setState(() => leftJoy = v)),
          ),
          HudWrapper(
            item: hud["joyRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["joyRight"] = ni),
            child: _Joystick(enabled: powerOn && !hudEditMode, onMove: (v) => setState(() => rightJoy = v)),
          ),
          // D-Pads
          HudWrapper(
            item: hud["dpadLeft"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["dpadLeft"] = ni),
            child: const _DPad(),
          ),
          HudWrapper(
            item: hud["dpadRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["dpadRight"] = ni),
            child: const _DPad(),
          ),
          // AB Buttons
          HudWrapper(
            item: hud["ab"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["ab"] = ni),
            child: Row(children: [
              _RoundBtn(label: "A", enabled: powerOn),
              const SizedBox(width: 25),
              _RoundBtn(label: "B", enabled: powerOn),
            ]),
          ),
          // LIVE MONITORING PANEL
          HudWrapper(
            item: hud["debug"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["debug"] = ni),
            child: _LiveMonitor(data: _getFormattedData()),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
    COMPONENTS
   ============================================================ */

class HudWrapper extends StatelessWidget {
  final HudItem item;
  final double containerW, containerH;
  final bool editMode, move, scale;
  final ValueChanged<HudItem> onChanged;
  final Widget child;

  const HudWrapper({super.key, required this.item, required this.containerW, required this.containerH, required this.editMode, required this.move, required this.scale, required this.onChanged, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: item.posPct.dx * containerW,
      top: item.posPct.dy * containerH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: editMode && move ? (d) {
          double nx = (item.posPct.dx + d.delta.dx / containerW).clamp(0.0, 0.95);
          double ny = (item.posPct.dy + d.delta.dy / containerH).clamp(0.0, 0.95);
          onChanged(item.copyWith(posPct: Offset(nx, ny)));
        } : null,
        child: Transform.scale(
          scale: item.scale,
          child: Container(
            decoration: BoxDecoration(border: editMode ? Border.all(color: Colors.cyanAccent) : null),
            child: IgnorePointer(ignoring: editMode, child: child),
          ),
        ),
      ),
    );
  }
}

class _Joystick extends StatefulWidget {
  final bool enabled;
  final ValueChanged<Offset> onMove;
  const _Joystick({required this.enabled, required this.onMove});
  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset pos = Offset.zero;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, height: 180,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10, border: Border.all(color: Colors.white24, width: 2)),
      child: GestureDetector(
        onPanUpdate: widget.enabled ? (d) {
          setState(() {
            pos += d.delta;
            if (pos.distance > 70) pos = Offset.fromDirection(pos.direction, 70);
            widget.onMove(Offset(pos.dx / 70, pos.dy / 70));
          });
        } : null,
        onPanEnd: (_) { setState(() => pos = Offset.zero); widget.onMove(Offset.zero); },
        child: Center(
          child: Transform.translate(
            offset: pos,
            child: Container(width: 70, height: 70, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white38)),
          ),
        ),
      ),
    );
  }
}

class _MultiSwitch extends StatelessWidget {
  final String label;
  final int options; // 2 or 3
  final int current;
  final ValueChanged<int> onToggle;
  final bool enabled;

  const _MultiSwitch({required this.label, required this.options, required this.current, required this.onToggle, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: enabled ? () => onToggle((current + 1) % options) : null,
          child: Container(
            width: 45, height: 90,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track visual
                Container(width: 4, height: 60, color: Colors.white24),
                // Toggle Handle
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  bottom: options == 2
                      ? (current == 0 ? 10 : 50)
                      : (current == 0 ? 10 : current == 1 ? 30 : 50),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white54)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad();
  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon) => Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
      child: Icon(icon, color: Colors.white38, size: 25),
    );
    return Column(
      children: [
        arrow(Icons.keyboard_arrow_up),
        Row(children: [arrow(Icons.keyboard_arrow_left), const SizedBox(width: 15), arrow(Icons.keyboard_arrow_right)]),
        arrow(Icons.keyboard_arrow_down),
      ],
    );
  }
}

class _PowerBtn extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;
  const _PowerBtn({required this.isOn, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isOn ? Colors.greenAccent : Colors.white24, width: 3)),
        child: Icon(Icons.power_settings_new, color: isOn ? Colors.greenAccent : Colors.white24, size: 40),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  const _RoundBtn({required this.label, required this.enabled});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75, height: 75,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10, border: Border.all(color: Colors.white24)),
      child: Center(child: Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: enabled ? Colors.white70 : Colors.white24))),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap, backgroundColor: Colors.white10);
  }
}

class _LiveMonitor extends StatelessWidget {
  final String data;
  const _LiveMonitor({required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("LIVE TELEMETRY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          const SizedBox(height: 5),
          Text(data.trim(), style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70)),
        ],
      ),
    );
  }
}

/* ============================================================
    BLUETOOTH PAGE (Standard Connect)
   ============================================================ */
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  List<ScanResult> results = [];
  bool scanning = false;

  void _scan() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    setState(() => scanning = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((l) => setState(() => results = l));
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => scanning = false);
  }

  @override
  void initState() { super.initState(); _scan(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select BLE Device")),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (c, i) => ListTile(
          title: Text(results[i].device.platformName.isEmpty ? "Unknown" : results[i].device.platformName),
          subtitle: Text(results[i].device.remoteId.str),
          onTap: () async {
            await results[i].device.connect();
            var services = await results[i].device.discoverServices();
            for (var s in services) {
              for (var char in s.characteristics) {
                if (char.properties.write || char.properties.writeWithoutResponse) {
                  BleManager().connectedDevice = results[i].device;
                  BleManager().writeChar = char;
                  Navigator.pop(context);
                  return;
                }
              }
            }
          },
        ),
      ),
    );
  }
}