import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/* ============================================================
    GLOBAL BLE MANAGER
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
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

  Offset leftJoy = Offset.zero;
  Offset rightJoy = Offset.zero;
  int sw1 = 0, sw2 = 0, sw3 = 0, sw4 = 0;

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
        "swLeft": const HudItem(id: "swLeft", posPct: Offset(0.18, 0.18)),
        "swRight": const HudItem(id: "swRight", posPct: Offset(0.72, 0.18)),
        "joyLeft": const HudItem(id: "joyLeft", posPct: Offset(0.15, 0.45)),
        "joyRight": const HudItem(id: "joyRight", posPct: Offset(0.68, 0.45)),
        "dpadLeft": const HudItem(id: "dpadLeft", posPct: Offset(0.05, 0.70)),
        "dpadRight": const HudItem(id: "dpadRight", posPct: Offset(0.88, 0.70)),
        "ab": const HudItem(id: "ab", posPct: Offset(0.42, 0.72)),
        "monitor": const HudItem(id: "monitor", posPct: Offset(0.02, 0.85)),
      };
    });
  }

  String _getFormattedData() {
    int map(double v) => (1500 + (v.clamp(-1.0, 1.0) * 500)).round();
    return "${map(-leftJoy.dy)},${map(leftJoy.dx)},${map(-rightJoy.dy)},${map(rightJoy.dx)},$sw1,$sw2,$sw3,$sw4\n";
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMState) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView( // ✅ FIXED OVERFLOW
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("HUD EDITOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                SwitchListTile(
                  title: const Text("Edit Layout Mode"),
                  subtitle: const Text("Move and resize UI elements"),
                  value: hudEditMode,
                  onChanged: (v) { setState(() => hudEditMode = v); setMState(() {}); },
                ),
                if (hudEditMode) ...[
                  CheckboxListTile(title: const Text("Allow Moving"), value: hudMoveEnabled, onChanged: (v) { setState(() => hudMoveEnabled = v!); setMState(() {}); }),
                  CheckboxListTile(title: const Text("Allow Scaling"), value: hudResizeEnabled, onChanged: (v) { setState(() => hudResizeEnabled = v!); setMState(() {}); }),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () { _resetHud(); Navigator.pop(context); },
                    icon: const Icon(Icons.refresh),
                    label: const Text("RESET TO DEFAULT"),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
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
          HudWrapper(
            item: hud["bt"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["bt"] = ni),
            child: _ActionChip(
              label: BleManager().isReady ? "LINKED" : "BT UART",
              active: BleManager().isReady,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BluetoothPage())).then((_) => setState(() {})),
            ),
          ),
          HudWrapper(
            item: hud["power"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["power"] = ni),
            child: _PowerBtn(isOn: powerOn, onTap: () => setState(() => powerOn = !powerOn)),
          ),
          HudWrapper(
            item: hud["topRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["topRight"] = ni),
            child: Row(children: [
              const Icon(Icons.link, color: Colors.white54, size: 28),
              const SizedBox(width: 15),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white54), onPressed: _openSettings),
            ]),
          ),
          HudWrapper(
            item: hud["swLeft"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["swLeft"] = ni),
            child: Row(children: [
              _DigitalSwitch(label: "SW1", options: 2, current: sw1, onToggle: (v) => setState(() => sw1 = v), enabled: powerOn),
              const SizedBox(width: 15),
              _DigitalSwitch(label: "SW2", options: 2, current: sw2, onToggle: (v) => setState(() => sw2 = v), enabled: powerOn),
            ]),
          ),
          HudWrapper(
            item: hud["swRight"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["swRight"] = ni),
            child: Row(children: [
              _DigitalSwitch(label: "SW3", options: 2, current: sw3, onToggle: (v) => setState(() => sw3 = v), enabled: powerOn),
              const SizedBox(width: 15),
              _DigitalSwitch(label: "SW4", options: 3, current: sw4, onToggle: (v) => setState(() => sw4 = v), enabled: powerOn),
            ]),
          ),
          // FIXED JOYSTICKS
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
          HudWrapper(
            item: hud["monitor"]!, containerW: w, containerH: h, editMode: hudEditMode,
            move: hudMoveEnabled, scale: hudResizeEnabled,
            onChanged: (ni) => setState(() => hud["monitor"] = ni),
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
      width: 160, height: 160,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10, border: Border.all(color: Colors.white24)),
      child: GestureDetector(
        onPanUpdate: widget.enabled ? (d) {
          setState(() {
            pos += d.delta; // Accumulate movement
            if (pos.distance > 60) pos = Offset.fromDirection(pos.direction, 60);
            widget.onMove(Offset(pos.dx / 60, pos.dy / 60));
          });
        } : null,
        onPanEnd: (_) { setState(() => pos = Offset.zero); widget.onMove(Offset.zero); },
        child: Center(
          child: Transform.translate(
            offset: pos,
            child: Container(width: 65, height: 65, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white30)),
          ),
        ),
      ),
    );
  }
}

class _DigitalSwitch extends StatelessWidget {
  final String label;
  final int options;
  final int current;
  final ValueChanged<int> onToggle;
  final bool enabled;

  const _DigitalSwitch({required this.label, required this.options, required this.current, required this.onToggle, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white30)),
        const SizedBox(height: 5),
        GestureDetector(
          onVerticalDragEnd: enabled ? (details) {
            if (details.primaryVelocity! < 0) {
              if (current < options - 1) onToggle(current + 1);
            } else if (details.primaryVelocity! > 0) {
              if (current > 0) onToggle(current - 1);
            }
          } : null,
          onTap: enabled ? () => onToggle((current + 1) % options) : null,
          child: Container(
            width: 40, height: 85,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 2, height: 50, color: Colors.white24),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  bottom: options == 2
                      ? (current == 0 ? 10 : 45)
                      : (current == 0 ? 10 : current == 1 ? 28 : 45),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white54)),
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
    Widget btn(IconData icon) => Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
      child: Icon(icon, color: Colors.white30, size: 22),
    );
    return Column(
      children: [
        btn(Icons.keyboard_arrow_up),
        Row(children: [btn(Icons.keyboard_arrow_left), const SizedBox(width: 12), btn(Icons.keyboard_arrow_right)]),
        btn(Icons.keyboard_arrow_down),
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
        child: Icon(Icons.power_settings_new, color: isOn ? Colors.greenAccent : Colors.white24, size: 38),
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
      width: 70, height: 70,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10, border: Border.all(color: Colors.white24)),
      child: Center(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: enabled ? Colors.white70 : Colors.white24))),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: active ? Colors.cyan.withOpacity(0.3) : Colors.white10,
    );
  }
}

class _LiveMonitor extends StatelessWidget {
  final String data;
  const _LiveMonitor({required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MONITOR", style: TextStyle(fontSize: 8, color: Colors.cyanAccent)),
          Text(data.trim(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
        ],
      ),
    );
  }
}

/* ============================================================
    BLUETOOTH PAGE
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
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((l) => setState(() => results = l));
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => scanning = false);
  }

  @override
  void initState() { super.initState(); _scan(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Controller")),
      body: Column(
        children: [
          if (BleManager().connectedDevice != null)
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.cyanAccent),
                title: Text(BleManager().connectedDevice!.platformName),
                subtitle: const Text("CONNECTED", style: TextStyle(color: Colors.cyanAccent)),
                trailing: TextButton(
                    onPressed: () {
                      BleManager().connectedDevice!.disconnect();
                      setState(() { BleManager().connectedDevice = null; BleManager().writeChar = null; });
                    },
                    child: const Text("DISCONNECT")
                ),
              ),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (c, i) {
                final d = results[i].device;
                if (d.remoteId == BleManager().connectedDevice?.remoteId) return const SizedBox.shrink();

                return ListTile(
                  title: Text(d.platformName.isEmpty ? "Unknown Device" : d.platformName),
                  subtitle: Text(d.remoteId.str),
                  onTap: () async {
                    try {
                      await d.connect();
                      var services = await d.discoverServices();
                      for (var s in services) {
                        for (var char in s.characteristics) {
                          if (char.properties.write || char.properties.writeWithoutResponse) {
                            BleManager().connectedDevice = d;
                            BleManager().writeChar = char;
                            Navigator.pop(context);
                            return;
                          }
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}