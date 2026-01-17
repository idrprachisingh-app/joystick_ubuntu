
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* ================= HUD MODEL ================= */

class HudItem {
  Offset pos;
  double scale;
  HudItem({required this.pos, this.scale = 1.0});

  Map<String, dynamic> toJson() => {
        "x": pos.dx,
        "y": pos.dy,
        "s": scale,
      };

  static HudItem fromJson(Map<String, dynamic> j) {
    return HudItem(
      pos: Offset(
        (j["x"] as num).toDouble(),
        (j["y"] as num).toDouble(),
      ),
      scale: ((j["s"] ?? 1.0) as num).toDouble(),
    );
  }
}

/* ================= MAIN UI ================= */

class ControllerUI extends StatefulWidget {
  const ControllerUI({super.key});

  @override
  State<ControllerUI> createState() => _ControllerUIState();
}

class _ControllerUIState extends State<ControllerUI> {
  // ---------- POWER ----------
  bool powerOn = true;

  // ---------- HUD EDIT ----------
  bool hudEditMode = false;
  String? selectedHudKey;

  // ---------- HUD ITEMS ----------
  final Map<String, HudItem> hud = {
    "leftJoy": HudItem(pos: const Offset(70, 250), scale: 1.0),
    "rightJoy": HudItem(pos: const Offset(720, 250), scale: 1.0),
    "power": HudItem(pos: const Offset(455, 30), scale: 1.0),
    "bt": HudItem(pos: const Offset(520, 30), scale: 1.0),
    "settings": HudItem(pos: const Offset(585, 30), scale: 1.0),
    "arcLeft": HudItem(pos: const Offset(200, 70), scale: 1.0),
    "arcRight": HudItem(pos: const Offset(650, 70), scale: 1.0),
    "btnUp": HudItem(pos: const Offset(460, 310), scale: 1.0),
    "btnDown": HudItem(pos: const Offset(460, 430), scale: 1.0),
    "btnLeft": HudItem(pos: const Offset(400, 370), scale: 1.0),
    "btnRight": HudItem(pos: const Offset(520, 370), scale: 1.0),
  };

  // ---------- SLIDERS ----------
  double arcLeftValue = 0.35;
  double arcRightValue = 0.65;

  // ---------- JOYSTICK ----------
  Offset leftStick = Offset.zero; // -1..1
  Offset rightStick = Offset.zero;

  // Drone mapping 980..2020
  int ch1 = 1500, ch2 = 1500, ch3 = 1500, ch4 = 1500;

  // ---------- BT ----------
  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;
  StreamSubscription<BluetoothDiscoveryResult>? _discSub;

  bool discovering = false;
  bool connecting = false;

  Map<String, BluetoothDiscoveryResult> discovered = {};
  List<BluetoothDevice> bonded = [];

  BluetoothConnection? connection;
  BluetoothDevice? connectedDevice;

  // ---------- SEND TIMER ----------
  Timer? txTimer;

  @override
  void initState() {
    super.initState();
    _loadHud();
    _initBluetooth();
    _startTxLoop();
  }

  @override
  void dispose() {
    txTimer?.cancel();
    _discSub?.cancel();
    connection?.dispose();
    super.dispose();
  }

  /* ================= HUD PERSIST ================= */

  Future<void> _loadHud() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString("hud_layout");
    final edit = sp.getBool("hud_edit") ?? false;

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          if (hud.containsKey(k)) {
            hud[k] = HudItem.fromJson(Map<String, dynamic>.from(v as Map));
          }
        });
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        hudEditMode = edit;
      });
    }
  }

  Future<void> _saveHud() async {
    final sp = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    hud.forEach((k, v) => out[k] = v.toJson());
    await sp.setString("hud_layout", jsonEncode(out));
    await sp.setBool("hud_edit", hudEditMode);
  }

  Future<void> _resetHud() async {
    setState(() {
      hud["leftJoy"] = HudItem(pos: const Offset(70, 250), scale: 1.0);
      hud["rightJoy"] = HudItem(pos: const Offset(720, 250), scale: 1.0);
      hud["power"] = HudItem(pos: const Offset(455, 30), scale: 1.0);
      hud["bt"] = HudItem(pos: const Offset(520, 30), scale: 1.0);
      hud["settings"] = HudItem(pos: const Offset(585, 30), scale: 1.0);
      hud["arcLeft"] = HudItem(pos: const Offset(200, 70), scale: 1.0);
      hud["arcRight"] = HudItem(pos: const Offset(650, 70), scale: 1.0);
      hud["btnUp"] = HudItem(pos: const Offset(460, 310), scale: 1.0);
      hud["btnDown"] = HudItem(pos: const Offset(460, 430), scale: 1.0);
      hud["btnLeft"] = HudItem(pos: const Offset(400, 370), scale: 1.0);
      hud["btnRight"] = HudItem(pos: const Offset(520, 370), scale: 1.0);
      selectedHudKey = null;
    });
    await _saveHud();
  }

  /* ================= Bluetooth ================= */

  Future<void> _initBluetooth() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

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
      if (r.device.name != null && r.device.name!.isNotEmpty) {
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

      if (device.bondState != BluetoothBondState.bonded) {
        final ok = await _bt.bondDeviceAtAddress(device.address);
        if (ok != true) throw "Pairing failed";
      }

      await connection?.close();
      connection = null;

      final conn = await BluetoothConnection.toAddress(device.address);

      connection = conn;
      connectedDevice = device;
      if (mounted) setState(() {});

      conn.input?.listen((data) {}).onDone(() {
        if (mounted) {
          setState(() {
            connection = null;
            connectedDevice = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Connect failed: $e")));
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> disconnectBt() async {
    await connection?.close();
    connection = null;
    connectedDevice = null;
    if (mounted) setState(() {});
  }

  /* ================= Drone channels ================= */

  int _mapTo980_2020(double v) {
    final scaled = ((v + 1) / 2);
    final out = 980 + (scaled * (2020 - 980));
    return out.round().clamp(980, 2020);
  }

  int _map01To980_2020(double v) {
    final out = 980 + (v * (2020 - 980));
    return out.round().clamp(980, 2020);
  }

  void _updateChannels() {
    ch1 = _mapTo980_2020(rightStick.dx); // Roll
    ch2 = _mapTo980_2020(-rightStick.dy); // Pitch
    ch3 = _mapTo980_2020(-leftStick.dy); // Throttle
    ch4 = _mapTo980_2020(leftStick.dx); // Yaw
  }

  /* ================= TX LOOP ================= */

  void _startTxLoop() {
    txTimer?.cancel();
    txTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!powerOn || connection?.isConnected != true) return;
      _updateChannels();
      final msg =
          "CH:$ch1,$ch2,$ch3,$ch4,AL:${_map01To980_2020(arcLeftValue)},AR:${_map01To980_2020(arcRightValue)}\n";
      try {
        connection!.output.add(Uint8List.fromList(msg.codeUnits));
        await connection!.output.allSent;
      } catch (_) {}
    });
  }

  /* ================= SHEETS ================= */

  void openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(builder: (context, setSheet) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("HUD Edit Mode"),
                value: hudEditMode,
                onChanged: (v) {
                  setState(() => hudEditMode = v);
                  setSheet(() {});
                  _saveHud();
                },
                activeColor: const Color(0xFF35F6A3),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.replay),
                  label: const Text("Reset HUD Layout"),
                  onPressed: () {
                    Navigator.pop(context);
                    _resetHud();
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void openBluetoothSheet() {
    stopDiscovery();
    startDiscovery();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(builder: (context, setSheet) {
          final discoveredList = discovered.values.toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.2,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0C0C),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        height: 4,
                        width: 55,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text("Bluetooth Connection"),
                      trailing: discovering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                stopDiscovery();
                                startDiscovery();
                              },
                            ),
                    ),
                    if (connectedDevice != null)
                      ListTile(
                        leading: const Icon(Icons.bluetooth_connected,
                            color: Color(0xFF35F6A3)),
                        title: Text(connectedDevice!.name ?? "Connected"),
                        subtitle: const Text("Tap to disconnect"),
                        onTap: disconnectBt,
                      ),
                    const Divider(),
                    ...bonded.map((d) => ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(d.name ?? "Paired Device"),
                          subtitle: Text(d.address),
                          onTap: () => connectTo(d),
                          onLongPress: () => connectTo(d),
                        )),
                    if (discovered.isNotEmpty) const Divider(),
                    ...discoveredList.map((r) => ListTile(
                          leading: const Icon(Icons.bluetooth_searching),
                          title: Text(r.device.name ?? "Discovered Device"),
                          subtitle: Text(r.device.address),
                          onTap: () => connectTo(r.device),
                        )),
                  ],
                ),
              );
            },
          );
        });
      },
    ).whenComplete(stopDiscovery);
  }

  /* ================= BUILD ================= */
  @override
  Widget build(BuildContext context) {
    final enableControls = powerOn && !hudEditMode;
    final glow = powerOn && connection?.isConnected == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: [
              _BackgroundGlow(
                powerOn: powerOn,
                glow: glow,
              ),
              ...hud.entries.map((entry) {
                final k = entry.key;
                final v = entry.value;

                return HudWrapper(
                  key: ValueKey(k),
                  item: v,
                  editMode: hudEditMode,
                  isSelected: selectedHudKey == k,
                  onSelect: () => setState(() => selectedHudKey = k),
                  onUpdate: (item) => setState(() => hud[k] = item),
                  child: Opacity(
                    opacity: powerOn ? 1.0 : 0.4,
                    child: _buildHudWidget(
                      k,
                      enableControls: enableControls,
                      glow: glow,
                    ),
                  ),
                );
              }),
              if (hudEditMode && selectedHudKey == null)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text("Tap an item to edit",
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHudWidget(String key,
      {required bool enableControls, required bool glow}) {
    switch (key) {
      case "leftJoy":
        return _JoystickKnob(
          enabled: enableControls,
          onChanged: (v) => setState(() => leftStick = v),
        );
      case "rightJoy":
        return _JoystickKnob(
          enabled: enableControls,
          onChanged: (v) => setState(() => rightStick = v),
        );
      case "power":
        return _IconButton(
          icon: Icons.power_settings_new,
          glow: powerOn,
          onTap: () => setState(() => powerOn = !powerOn),
        );
      case "bt":
        return _IconButton(
          icon: Icons.bluetooth,
          glow: connection?.isConnected == true,
          onTap: openBluetoothSheet,
        );
      case "settings":
        return _IconButton(
          icon: Icons.settings,
          onTap: openSettings,
        );
      case "arcLeft":
        return ArcSliderKnob(
          enabled: enableControls,
          glow: glow,
          flip: true,
          value: arcLeftValue,
          onChanged: (v) => setState(() => arcLeftValue = v),
        );
      case "arcRight":
        return ArcSliderKnob(
          enabled: enableControls,
          glow: glow,
          value: arcRightValue,
          onChanged: (v) => setState(() => arcRightValue = v),
        );
      case "btnUp":
      case "btnDown":
      case "btnLeft":
      case "btnRight":
        return _DpadButton(onTap: () {});
      default:
        return const SizedBox.shrink();
    }
  }
}

/* ================= WIDGETS ================= */

class _BackgroundGlow extends StatelessWidget {
  final bool powerOn;
  final bool glow;
  const _BackgroundGlow({required this.powerOn, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [
                powerOn
                    ? (glow
                        ? const Color(0xFF35F6A3)
                        : Colors.white.withOpacity(0.2))
                    : Colors.transparent,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HudWrapper extends StatefulWidget {
  final HudItem item;
  final Widget child;
  final bool editMode;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<HudItem> onUpdate;

  const HudWrapper({
    super.key,
    required this.item,
    required this.child,
    required this.editMode,
    required this.isSelected,
    required this.onSelect,
    required this.onUpdate,
  });

  @override
  State<HudWrapper> createState() => _HudWrapperState();
}

class _HudWrapperState extends State<HudWrapper> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.pos.dx,
      top: widget.item.pos.dy,
      child: GestureDetector(
        onTap: widget.editMode ? widget.onSelect : null,
        onScaleStart: widget.editMode && widget.isSelected
            ? (d) => setState(() {})
            : null,
        onScaleUpdate: widget.editMode && widget.isSelected
            ? (d) => widget.onUpdate(HudItem(
                  pos: widget.item.pos + d.focalPointDelta,
                  scale: (widget.item.scale * d.scale).clamp(0.5, 2.5),
                ))
            : null,
        child: Transform.scale(
          scale: widget.item.scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (widget.editMode && widget.isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF35F6A3).withOpacity(0.7),
                        width: 2 / widget.item.scale,
                      ),
                      borderRadius: BorderRadius.circular(8 / widget.item.scale),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoystickKnob extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  final bool enabled;
  const _JoystickKnob({required this.onChanged, required this.enabled});

  @override
  State<_JoystickKnob> createState() => _JoystickKnobState();
}

class _JoystickKnobState extends State<_JoystickKnob> {
  Offset localPos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.enabled
          ? (d) => setState(() => localPos = d.localPosition)
          : null,
      onPanUpdate: widget.enabled
          ? (d) => setState(() {
                final off = d.localPosition - localPos;
                final dist = off.distance.clamp(0.0, 60.0);
                final ang = off.direction;
                widget.onChanged(Offset.fromDirection(ang, dist / 60.0));
              })
          : null,
      onPanEnd: widget.enabled ? (_) => widget.onChanged(Offset.zero) : null,
      child:  SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(painter:  _JoystickPainter()),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = Paint()..color = Colors.white.withOpacity(0.1);
    canvas.drawCircle(center, 60, base);
  }

  @override
  bool shouldRepaint(_) => false;
}

class ArcSliderKnob extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final bool glow;
  final bool flip;
  const ArcSliderKnob({
    super.key,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.glow = false,
    this.flip = false,
  });

  @override
  State<ArcSliderKnob> createState() => _ArcSliderKnobState();
}

class _ArcSliderKnobState extends State<ArcSliderKnob> {
  void _onPan(Offset pos) {
    if (!widget.enabled) return;
    final center = Offset(100, 100);
    final ang = (pos - center).direction;
    final v = (ang / pi).clamp(0.0, 1.0);
    widget.onChanged(widget.flip ? 1.0 - v : v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _onPan(d.localPosition),
      onPanUpdate: (d) => _onPan(d.localPosition),
      child: SizedBox(
        width: 200,
        height: 100,
        child: CustomPaint(
          painter: _ArcPainter(
            v: widget.value,
            glow: widget.glow,
            flip: widget.flip,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double v;
  final bool glow;
  final bool flip;

  _ArcPainter({required this.v, required this.glow, required this.flip});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.10);

    canvas.drawArc(rect, pi, pi, false, base);

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = (glow ? const Color(0xFF35F6A3) : Colors.white.withOpacity(0.25))
          .withOpacity(glow ? 0.9 : 0.35);

    final sweep = pi * v;
    final start = flip ? (pi + (pi - sweep)) : pi;

    canvas.drawArc(rect, start, sweep, false, active);

    final knobAng = flip ? (pi + (pi - sweep)) : (pi + sweep);
    final knobPos =
        Offset(center.dx + cos(knobAng) * r, center.dy + sin(knobAng) * r);
    final knobPaint = Paint()..color = Colors.white.withOpacity(0.12);
    canvas.drawCircle(knobPos, 12, knobPaint);

    final knobBorder = Paint()
      ..color = const Color(0xFF35F6A3).withOpacity(glow ? 0.75 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(knobPos, 12, knobBorder);

    if (glow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF35F6A3).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(knobPos, 12, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.v != v ||
        oldDelegate.glow != glow ||
        oldDelegate.flip != flip;
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool glow;
  final VoidCallback onTap;
  const _IconButton(
      {required this.icon, this.glow = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (glow ? const Color(0xFF35F6A3) : Colors.white)
                .withOpacity(glow ? 0.8 : 0.2),
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: glow ? const Color(0xFF35F6A3) : Colors.white),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DpadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
      ),
    );
  }
}
