import 'dart:math';
import 'package:flutter/material.dart';
import 'package:joy_stickcontroller/screens/bluetooth_page.dart';

/* ============================================================
   HUD MODEL (PUBG-style)
============================================================ */

class HudItem {
  final String id;
  final Offset pos;
  final double scale;

  const HudItem({
    required this.id,
    required this.pos,
    this.scale = 1.0,
  });

  HudItem copyWith({Offset? pos, double? scale}) {
    return HudItem(
      id: id,
      pos: pos ?? this.pos,
      scale: scale ?? this.scale,
    );
  }
}

/* ============================================================
   DRONE RC OUTPUT MAPPING (980..2020)
============================================================ */

class RcOutput {
  final int throttle;
  final int yaw;
  final int pitch;
  final int roll;

  const RcOutput({
    required this.throttle,
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  String toCsv() => "$throttle,$yaw,$pitch,$roll\n";

  @override
  String toString() => "THR:$throttle YAW:$yaw PIT:$pitch ROL:$roll";
}

int mapAxisToRc(double v) {
  const int min = 980;
  const int mid = 1500;
  const int max = 2020;

  v = v.clamp(-1.0, 1.0);

  if (v >= 0) return (mid + v * (max - mid)).round();
  return (mid + v * (mid - min)).round();
}

RcOutput computeRcFromJoysticks({
  required Offset leftJoy,
  required Offset rightJoy,
}) {
  return RcOutput(
    throttle: mapAxisToRc(-leftJoy.dy),
    yaw: mapAxisToRc(leftJoy.dx),
    pitch: mapAxisToRc(-rightJoy.dy),
    roll: mapAxisToRc(rightJoy.dx),
  );
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

  double sw1 = 0.25, sw2 = 0.6, sw3 = 0.75, sw4 = 0.2;

  Offset leftJoy = Offset.zero;
  Offset rightJoy = Offset.zero;

  Offset leftPad = Offset.zero;
  Offset rightPad = Offset.zero;

  late Map<String, HudItem> hud;

  @override
  void initState() {
    super.initState();
    _resetHud();
  }

  void _resetHud() {
    hud = {
      "bt": const HudItem(id: "bt", pos: Offset(30, 30)),
      "power": const HudItem(id: "power", pos: Offset(630, 10)),
    };
    setState(() {});
  }

  double _arcGlowStrength() =>
      ((sw1 + sw2 + sw3 + sw4) / 4).clamp(0.0, 1.0);

  /// ✅ FIXED — THIS WAS YOUR MAIN ERROR
  void _openBluetooth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BluetoothPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = computeRcFromJoysticks(leftJoy: leftJoy, rightJoy: rightJoy);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          HudWrapper(
            editMode: hudEditMode,
            hudMoveEnabled: hudMoveEnabled,
            hudResizeEnabled: hudResizeEnabled,
            item: hud["bt"]!,
            onChanged: (u) => setState(() => hud["bt"] = u),
            child: _ChipButton(
              text: "BT UART",
              enabled: powerOn,
              onTap: _openBluetooth,
            ),
          ),

          HudWrapper(
            editMode: hudEditMode,
            hudMoveEnabled: hudMoveEnabled,
            hudResizeEnabled: hudResizeEnabled,
            item: hud["power"]!,
            onChanged: (u) => setState(() => hud["power"] = u),
            child: _PowerButton(
              isOn: powerOn,
              onTap: () => setState(() => powerOn = !powerOn),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              rc.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   HUD WRAPPER
============================================================ */

class HudWrapper extends StatefulWidget {
  final bool editMode;
  final bool hudMoveEnabled;
  final bool hudResizeEnabled;
  final HudItem item;
  final ValueChanged<HudItem> onChanged;
  final Widget child;

  const HudWrapper({
    super.key,
    required this.editMode,
    required this.hudMoveEnabled,
    required this.hudResizeEnabled,
    required this.item,
    required this.onChanged,
    required this.child,
  });

  @override
  State<HudWrapper> createState() => _HudWrapperState();
}

class _HudWrapperState extends State<HudWrapper> {
  late Offset startPos;
  late double startScale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.pos.dx,
      top: widget.item.pos.dy,
      child: GestureDetector(
        onScaleStart: widget.editMode
            ? (d) {
          startPos = widget.item.pos;
          startScale = widget.item.scale;
        }
            : null,
        onScaleUpdate: widget.editMode
            ? (d) {
          widget.onChanged(
            widget.item.copyWith(
              pos: widget.hudMoveEnabled
                  ? startPos + d.focalPointDelta
                  : widget.item.pos,
              scale: widget.hudResizeEnabled
                  ? (startScale * d.scale).clamp(0.6, 2.4)
                  : widget.item.scale,
            ),
          );
        }
            : null,
        child: Transform.scale(
          scale: widget.item.scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/* ============================================================
   BUTTONS
============================================================ */

class _ChipButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _ChipButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;

  const _PowerButton({required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isOn ? Colors.greenAccent : Colors.white24,
            width: 3,
          ),
        ),
        child: Icon(
          Icons.power_settings_new,
          color: isOn ? Colors.greenAccent : Colors.white24,
          size: 32,
        ),
      ),
    );
  }
}
