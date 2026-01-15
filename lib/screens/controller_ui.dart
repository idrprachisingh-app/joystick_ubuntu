import 'dart:math';
import 'package:flutter/material.dart';

import 'bluetooth_page.dart';

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
  final throttle = mapAxisToRc(-leftJoy.dy);
  final yaw = mapAxisToRc(leftJoy.dx);

  final pitch = mapAxisToRc(-rightJoy.dy);
  final roll = mapAxisToRc(rightJoy.dx);

  return RcOutput(throttle: throttle, yaw: yaw, pitch: pitch, roll: roll);
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

  // HUD editor controls
  bool hudEditMode = false;
  bool hudMoveEnabled = true;
  bool hudResizeEnabled = true;

  // Switch sliders (0..1)
  double sw1 = 0.25;
  double sw2 = 0.60;
  double sw3 = 0.75;
  double sw4 = 0.20;

  // joystick normalized offsets (-1..1)
  Offset leftJoy = Offset.zero;
  Offset rightJoy = Offset.zero;

  // D-pad hold vectors (-1..1)
  Offset leftPad = Offset.zero;
  Offset rightPad = Offset.zero;

  // HUD layout
  late Map<String, HudItem> hud;

  @override
  void initState() {
    super.initState();
    _resetHud();
  }

  void _resetHud() {
    hud = {
      "bt": const HudItem(id: "bt", pos: Offset(30, 30), scale: 1.0),
      "power": const HudItem(id: "power", pos: Offset(630, 10), scale: 1.0),
      "topIcons": const HudItem(id: "topIcons", pos: Offset(1180, 30), scale: 1.0),

      "swLeft": const HudItem(id: "swLeft", pos: Offset(260, 140), scale: 1.0),
      "swRight": const HudItem(id: "swRight", pos: Offset(980, 140), scale: 1.0),

      "dpadLeft": const HudItem(id: "dpadLeft", pos: Offset(110, 440), scale: 1.0),
      "dpadRight": const HudItem(id: "dpadRight", pos: Offset(1260, 440), scale: 1.0),

      "joyLeft": const HudItem(id: "joyLeft", pos: Offset(260, 300), scale: 1.0),
      "joyRight": const HudItem(id: "joyRight", pos: Offset(920, 300), scale: 1.0),

      "ab": const HudItem(id: "ab", pos: Offset(610, 610), scale: 1.0),

      "debug": const HudItem(id: "debug", pos: Offset(20, 600), scale: 1.0),
    };
    setState(() {});
  }

  double _arcGlowStrength() {
    final avg = (sw1 + sw2 + sw3 + sw4) / 4.0;
    return avg.clamp(0.0, 1.0);
  }

  void _openBluetooth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BluetoothPage()),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    "Settings",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.tune, color: Colors.white.withOpacity(0.6)),
                ],
              ),
              const SizedBox(height: 16),

              _settingsTile(
                title: "Bluetooth",
                subtitle: "Scan & connect nearby BLE devices",
                trailing: IconButton(
                  icon: const Icon(Icons.bluetooth, color: Color(0xFF35F6A3)),
                  onPressed: () {
                    Navigator.pop(context);
                    _openBluetooth();
                  },
                ),
              ),

              _settingsTile(
                title: "Power",
                subtitle: "Enable/disable controller glow + controls",
                trailing: Switch(
                  value: powerOn,
                  onChanged: (v) => setState(() => powerOn = v),
                ),
              ),

              _settingsTile(
                title: "HUD Edit Mode",
                subtitle: "Move + Resize controls like PUBG HUD",
                trailing: Switch(
                  value: hudEditMode,
                  onChanged: (v) => setState(() => hudEditMode = v),
                ),
              ),

              _settingsTile(
                title: "HUD Move",
                subtitle: "Allow drag reposition",
                trailing: Switch(
                  value: hudMoveEnabled,
                  onChanged: (v) => setState(() => hudMoveEnabled = v),
                ),
              ),

              _settingsTile(
                title: "HUD Resize",
                subtitle: "Allow pinch zoom resize",
                trailing: Switch(
                  value: hudResizeEnabled,
                  onChanged: (v) => setState(() => hudResizeEnabled = v),
                ),
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      text: "Reset HUD",
                      icon: Icons.refresh,
                      onTap: () {
                        Navigator.pop(context);
                        _resetHud();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      text: "Close",
                      icon: Icons.close,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.65)),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arcStrength = powerOn ? _arcGlowStrength() : 0.0;
    final rc = computeRcFromJoysticks(leftJoy: leftJoy, rightJoy: rightJoy);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _BackgroundGlow(powerOn: powerOn, arcStrength: arcStrength),
            ),

            // ✅ ARC SLIDER LEFT
            ArcSliderKnob(
              enabled: powerOn && !hudEditMode,
              leftSide: true,
              value: (sw1 + sw2) / 2,
              onChanged: (v) => setState(() {
                sw1 = v;
                sw2 = v;
              }),
            ),

            // ✅ ARC SLIDER RIGHT
            ArcSliderKnob(
              enabled: powerOn && !hudEditMode,
              leftSide: false,
              value: (sw3 + sw4) / 2,
              onChanged: (v) => setState(() {
                sw3 = v;
                sw4 = v;
              }),
            ),

            // BT UART
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["bt"]!,
              onChanged: (u) => setState(() => hud["bt"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: _ChipButton(
                  text: "BT UART",
                  enabled: powerOn,
                  onTap: _openBluetooth,
                ),
              ),
            ),

            // Power
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

            // top icons
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["topIcons"]!,
              onChanged: (u) => setState(() => hud["topIcons"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: Row(
                  children: [
                    _SquareIcon(
                      icon: Icons.link,
                      enabled: powerOn,
                      onTap: () {},
                    ),
                    const SizedBox(width: 18),
                    _SquareIcon(
                      icon: Icons.settings,
                      enabled: true,
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
            ),

            // Left switches
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["swLeft"]!,
              onChanged: (u) => setState(() => hud["swLeft"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: Row(
                  children: [
                    _SwipeSwitch(
                      label: "SW1",
                      value: sw1,
                      enabled: powerOn && !hudEditMode,
                      onChanged: (v) => setState(() => sw1 = v),
                    ),
                    const SizedBox(width: 22),
                    _SwipeSwitch(
                      label: "SW2",
                      value: sw2,
                      enabled: powerOn && !hudEditMode,
                      onChanged: (v) => setState(() => sw2 = v),
                    ),
                  ],
                ),
              ),
            ),

            // Right switches
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["swRight"]!,
              onChanged: (u) => setState(() => hud["swRight"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: Row(
                  children: [
                    _SwipeSwitch(
                      label: "SW3",
                      value: sw3,
                      enabled: powerOn && !hudEditMode,
                      onChanged: (v) => setState(() => sw3 = v),
                    ),
                    const SizedBox(width: 22),
                    _SwipeSwitch(
                      label: "SW4",
                      value: sw4,
                      enabled: powerOn && !hudEditMode,
                      onChanged: (v) => setState(() => sw4 = v),
                    ),
                  ],
                ),
              ),
            ),

            // Left D-pad
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["dpadLeft"]!,
              onChanged: (u) => setState(() => hud["dpadLeft"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: _DpadHold(
                  enabled: powerOn && !hudEditMode,
                  onVector: (v) => setState(() => leftPad = v),
                ),
              ),
            ),

            // Right D-pad
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["dpadRight"]!,
              onChanged: (u) => setState(() => hud["dpadRight"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: _DpadHold(
                  enabled: powerOn && !hudEditMode,
                  onVector: (v) => setState(() => rightPad = v),
                ),
              ),
            ),

            // Left joystick
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["joyLeft"]!,
              onChanged: (u) => setState(() => hud["joyLeft"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: _JoystickKnob(
                  enabled: powerOn && !hudEditMode,
                  onChanged: (o) => setState(() => leftJoy = o),
                ),
              ),
            ),

            // Right joystick
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["joyRight"]!,
              onChanged: (u) => setState(() => hud["joyRight"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: _JoystickKnob(
                  enabled: powerOn && !hudEditMode,
                  onChanged: (o) => setState(() => rightJoy = o),
                ),
              ),
            ),

            // A/B Buttons
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["ab"]!,
              onChanged: (u) => setState(() => hud["ab"] = u),
              child: Opacity(
                opacity: powerOn ? 1.0 : 0.35,
                child: Row(
                  children: [
                    _RoundButton(
                      text: "A",
                      enabled: powerOn && !hudEditMode,
                      onTap: () {},
                    ),
                    const SizedBox(width: 70),
                    _RoundButton(
                      text: "B",
                      enabled: powerOn && !hudEditMode,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Debug Panel
            HudWrapper(
              editMode: hudEditMode,
              hudMoveEnabled: hudMoveEnabled,
              hudResizeEnabled: hudResizeEnabled,
              item: hud["debug"]!,
              onChanged: (u) => setState(() => hud["debug"] = u),
              child: Opacity(
                opacity: 0.72,
                child: _DebugPanel(
                  powerOn: powerOn,
                  sw: [sw1, sw2, sw3, sw4],
                  leftJoy: leftJoy,
                  rightJoy: rightJoy,
                  leftPad: leftPad,
                  rightPad: rightPad,
                  rc: rc,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   HUD WRAPPER (Drag + Pinch Resize)
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
  Offset startPos = Offset.zero;
  Offset startFocal = Offset.zero;
  double startScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.pos.dx,
      top: widget.item.pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: widget.editMode
            ? (details) {
          startPos = widget.item.pos;
          startScale = widget.item.scale;
          startFocal = details.focalPoint;
        }
            : null,
        onScaleUpdate: widget.editMode
            ? (details) {
          final focalDelta = details.focalPoint - startFocal;

          final newPos = widget.hudMoveEnabled ? (startPos + focalDelta) : widget.item.pos;

          final newScale = widget.hudResizeEnabled
              ? (startScale * details.scale).clamp(0.6, 2.4)
              : widget.item.scale;

          widget.onChanged(widget.item.copyWith(pos: newPos, scale: newScale));
        }
            : null,
        child: Transform.scale(
          scale: widget.item.scale,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: widget.editMode
                  ? Border.all(color: Colors.white.withOpacity(0.35), width: 1.6)
                  : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   BACKGROUND + GLOW ARCS
============================================================ */

class _BackgroundGlow extends StatelessWidget {
  final bool powerOn;
  final double arcStrength;

  const _BackgroundGlow({required this.powerOn, required this.arcStrength});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowPainter(powerOn: powerOn, arcStrength: arcStrength),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final bool powerOn;
  final double arcStrength;

  const _GlowPainter({required this.powerOn, required this.arcStrength});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final glowAlpha = powerOn ? (0.05 + 0.40 * arcStrength) : 0.0;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Color.fromRGBO(53, 246, 163, glowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

    final rectLeft = Rect.fromCircle(center: Offset(size.width * 0.22, 0), radius: 260);
    final rectRight = Rect.fromCircle(center: Offset(size.width * 0.78, 0), radius: 260);

    canvas.drawArc(rectLeft, 0.15, 1.1, false, base);
    canvas.drawArc(rectRight, 1.9, 1.1, false, base);

    if (powerOn) {
      canvas.drawArc(rectLeft, 0.15, 1.1, false, glow);
      canvas.drawArc(rectRight, 1.9, 1.1, false, glow);

      final p = Paint()
        ..color = Color.fromRGBO(53, 246, 163, 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
      canvas.drawCircle(Offset(size.width / 2, 55), 140, p);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return powerOn != oldDelegate.powerOn || arcStrength != oldDelegate.arcStrength;
  }
}

/* ============================================================
   SEMICIRCULAR ARC SLIDER WITH KNOB
============================================================ */

class ArcSliderKnob extends StatelessWidget {
  final bool enabled;
  final bool leftSide;
  final double value; // 0..1
  final ValueChanged<double> onChanged;

  const ArcSliderKnob({
    super.key,
    required this.enabled,
    required this.leftSide,
    required this.value,
    required this.onChanged,
  });

  double _valueToAngle(double v) {
    final start = leftSide ? 0.15 : 1.9;
    final sweep = 1.1;
    return start + sweep * v.clamp(0, 1);
  }

  double _angleToValue(double a) {
    final start = leftSide ? 0.15 : 1.9;
    final sweep = 1.1;

    // normalize
    while (a < 0) a += 2 * pi;
    while (a > 2 * pi) a -= 2 * pi;

    final t = ((a - start) / sweep).clamp(0.0, 1.0);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          final center = leftSide ? Offset(w * 0.22, 0) : Offset(w * 0.78, 0);
          const radius = 260.0;

          final a = _valueToAngle(value);
          final knob = Offset(
            center.dx + radius * cos(a),
            center.dy + radius * sin(a),
          );

          return Stack(
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _ArcKnobPainter(leftSide: leftSide, value: value),
              ),
              Positioned(
                left: knob.dx - 18,
                top: knob.dy - 18,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    final local = knob + d.delta;
                    final dx = local.dx - center.dx;
                    final dy = local.dy - center.dy;
                    final ang = atan2(dy, dx);
                    onChanged(_angleToValue(ang));
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF35F6A3).withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF35F6A3).withOpacity(0.25),
                          blurRadius: 18,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcKnobPainter extends CustomPainter {
  final bool leftSide;
  final double value;

  _ArcKnobPainter({required this.leftSide, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = leftSide ? Offset(size.width * 0.22, 0) : Offset(size.width * 0.78, 0);
    const radius = 260.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final start = leftSide ? 0.15 : 1.9;
    final sweep = 1.1;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.12);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF35F6A3).withOpacity(0.50);

    canvas.drawArc(rect, start, sweep, false, base);
    canvas.drawArc(rect, start, sweep * value.clamp(0, 1), false, fill);
  }

  @override
  bool shouldRepaint(covariant _ArcKnobPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.leftSide != leftSide;
  }
}

/* ============================================================
   UI WIDGETS
============================================================ */

class _ChipButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _ChipButton({required this.text, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SquareIcon({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.55)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isOn ? const Color(0xFF35F6A3) : Colors.white.withOpacity(0.18),
            width: 3,
          ),
          boxShadow: [
            if (isOn)
              BoxShadow(
                color: const Color(0xFF35F6A3).withOpacity(0.22),
                blurRadius: 22,
                spreadRadius: 2,
              )
          ],
        ),
        child: Center(
          child: Icon(
            Icons.power_settings_new,
            color: isOn ? const Color(0xFF35F6A3) : Colors.white.withOpacity(0.25),
            size: 32,
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   SWIPE SLIDER SWITCH
============================================================ */

class _SwipeSwitch extends StatefulWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SwipeSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_SwipeSwitch> createState() => _SwipeSwitchState();
}

class _SwipeSwitchState extends State<_SwipeSwitch> {
  double _val = 0.0;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SwipeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    const trackH = 105.0;
    const thumbH = 40.0;
    const margin = 8.0;
    final maxY = trackH - thumbH - margin * 2;
    final thumbY = (maxY * (1 - _val)).clamp(0.0, maxY);

    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.22),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onVerticalDragUpdate: widget.enabled
              ? (d) {
            setState(() {
              final newThumb = (thumbY + d.delta.dy).clamp(0.0, maxY);
              _val = 1 - (newThumb / maxY);
              widget.onChanged(_val);
            });
          }
              : null,
          onDoubleTap: widget.enabled
              ? () {
            setState(() {
              _val = _val > 0.5 ? 0.0 : 1.0;
              widget.onChanged(_val);
            });
          }
              : null,
          child: Container(
            width: 52,
            height: trackH,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 70),
                  left: margin,
                  right: margin,
                  top: margin + thumbY,
                  child: Container(
                    height: thumbH,
                    decoration: BoxDecoration(
                      color: widget.enabled
                          ? Colors.white.withOpacity(0.14)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ============================================================
   JOYSTICK
============================================================ */

class _JoystickKnob extends StatefulWidget {
  final bool enabled;
  final ValueChanged<Offset> onChanged; // (-1..1)

  const _JoystickKnob({required this.enabled, required this.onChanged});

  @override
  State<_JoystickKnob> createState() => _JoystickKnobState();
}

class _JoystickKnobState extends State<_JoystickKnob> {
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    const baseSize = 260.0;
    const knobSize = 90.0;
    final radius = (baseSize - knobSize) / 2;

    return GestureDetector(
      onPanUpdate: widget.enabled
          ? (d) {
        setState(() {
          offset += d.delta;
          if (offset.distance > radius) {
            offset = Offset.fromDirection(offset.direction, radius);
          }
          final norm = Offset(offset.dx / radius, offset.dy / radius);
          widget.onChanged(norm);
        });
      }
          : null,
      onPanEnd: widget.enabled
          ? (_) {
        setState(() => offset = Offset.zero);
        widget.onChanged(Offset.zero);
      }
          : null,
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: offset,
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.92),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   DPAD HOLD BUTTONS
============================================================ */

class _DpadHold extends StatelessWidget {
  final bool enabled;
  final ValueChanged<Offset> onVector;

  const _DpadHold({required this.enabled, required this.onVector});

  Widget _btn(IconData icon, Offset vec) {
    return GestureDetector(
      onTapDown: enabled ? (_) => onVector(vec) : null,
      onTapUp: enabled ? (_) => onVector(Offset.zero) : null,
      onTapCancel: enabled ? () => onVector(Offset.zero) : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.30)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _btn(Icons.keyboard_arrow_up, const Offset(0, -1)),
        const SizedBox(height: 10),
        Row(
          children: [
            _btn(Icons.keyboard_arrow_left, const Offset(-1, 0)),
            const SizedBox(width: 10),
            _btn(Icons.keyboard_arrow_right, const Offset(1, 0)),
          ],
        ),
        const SizedBox(height: 10),
        _btn(Icons.keyboard_arrow_down, const Offset(0, 1)),
      ],
    );
  }
}

/* ============================================================
   A / B BUTTONS
============================================================ */

class _RoundButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _RoundButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.28),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   DEBUG PANEL
============================================================ */

class _DebugPanel extends StatelessWidget {
  final bool powerOn;
  final List<double> sw;
  final Offset leftJoy;
  final Offset rightJoy;
  final Offset leftPad;
  final Offset rightPad;
  final RcOutput rc;

  const _DebugPanel({
    required this.powerOn,
    required this.sw,
    required this.leftJoy,
    required this.rightJoy,
    required this.leftPad,
    required this.rightPad,
    required this.rc,
  });

  String _f(double d) => d.toStringAsFixed(2);
  String _o(Offset o) => "(${_f(o.dx)}, ${_f(o.dy)})";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("POWER: ${powerOn ? "ON" : "OFF"}"),
            Text("SW: ${sw.map((e) => e.toStringAsFixed(2)).join(", ")}"),
            Text("LJOY: ${_o(leftJoy)}   RJOY: ${_o(rightJoy)}"),
            Text("LPAD: ${_o(leftPad)}   RPAD: ${_o(rightPad)}"),
            const SizedBox(height: 6),
            Text("RC => $rc"),
            Text("UART => ${rc.toCsv().trim()}"),
          ],
        ),
      ),
    );
  }
}
