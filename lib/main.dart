import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:joy_stickcontroller/ble_service.dart';
import 'package:joy_stickcontroller/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';

final bleServiceProvider = Provider<BleService>((ref) {
  return FlutterBlueBleService();
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid) {
    throw UnsupportedError('This app is Android-only');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ProviderScope(child: ControllerApp()));
}

/* ================= APP ROOT ================= */

class ControllerApp extends ConsumerWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.grey.shade800,
        colorScheme: ColorScheme.dark(
          primary: Colors.grey.shade800,
          secondary: Colors.grey.shade600,
        ),
      ),
      home: const ControllerScreen(),
    );
  }
}

/* ================= MAIN SCREEN ================= */

class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key});

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> {
  double throttle = 0.3;
  double yaw = 0;
  double pitch = 0;
  double roll = 0;

  int leftTwo = 0;
  int leftThree = 0;
  int rightTwo = 0;
  int rightThree = 0;

  bool _showHud = false;

  Timer? _controlSender;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    final bleService = ref.read(bleServiceProvider);
    _controlSender = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final data = <int>[
        (throttle * 255).toInt(),
        (yaw * 127 + 128).toInt(),
        (pitch * 127 + 128).toInt(),
        (roll * 127 + 128).toInt(),
        leftTwo,
        leftThree,
        rightTwo,
        rightThree,
      ];
      bleService.sendControl(data);
    });
  }

  @override
  void dispose() {
    _controlSender?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect].request();
  }

  void _showDeviceSheet(BuildContext context, BleService bleService) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<List<ScanResult>>(
          stream: bleService.scanResults,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final device = snapshot.data![index].device;
                  return ListTile(
                    title: Text(device.platformName ?? 'Unknown Device'),
                    subtitle: Text(device.remoteId.toString()),
                    onTap: () {
                      bleService.connect(device);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    );
  }

  Widget _buildHud() {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider);
        return Container(
          color: Colors.black.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Joystick Size: ${settings.joystickSize.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                Slider(
                  value: settings.joystickSize,
                  min: 0.1,
                  max: 0.5,
                  onChanged: (value) => ref.read(settingsProvider.notifier).setJoystickSize(value),
                  activeColor: Colors.grey,
                  inactiveColor: Colors.grey.shade800,
                ),
                Text('Switch Height: ${settings.switchHeight.toInt()}', style: const TextStyle(color: Colors.white)),
                Slider(
                  value: settings.switchHeight,
                  min: 50,
                  max: 200,
                  onChanged: (value) => ref.read(settingsProvider.notifier).setSwitchHeight(value),
                  activeColor: Colors.grey,
                  inactiveColor: Colors.grey.shade800,
                ),
                Text('Arc Slider Radius: ${settings.arcSliderRadius.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                Slider(
                  value: settings.arcSliderRadius,
                  min: 0.1,
                  max: 0.3,
                  onChanged: (value) => ref.read(settingsProvider.notifier).setArcSliderRadius(value),
                  activeColor: Colors.grey,
                  inactiveColor: Colors.grey.shade800,
                ),
                Text('Joystick Shape', style: const TextStyle(color: Colors.white)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text('Circle'),
                      selected: settings.joystickShape == JoystickShape.circle,
                      onSelected: (_) => ref.read(settingsProvider.notifier).setJoystickShape(JoystickShape.circle),
                      selectedColor: Colors.grey,
                    ),
                    ChoiceChip(
                      label: const Text('Square'),
                      selected: settings.joystickShape == JoystickShape.square,
                      onSelected: (_) => ref.read(settingsProvider.notifier).setJoystickShape(JoystickShape.square),
                      selectedColor: Colors.grey,
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bleService = ref.watch(bleServiceProvider);
    final size = MediaQuery.of(context).size;

    final joySize = size.height * settings.joystickSize;
    final gap = size.height * 0.02;
    final joystickBottom = size.height * 0.05;
    final joystickTop = joystickBottom + joySize;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
                  onPressed: () {
                    bleService.startScan();
                    _showDeviceSheet(context, bleService);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => setState(() => _showHud = !_showHud),
                ),
              ],
            ),
          ),
          /* ───── TOP CORNER ARCS ───── */

          Positioned(
            top: 0,
            left: 0,
            child: ArcSlider(radius: size.height * settings.arcSliderRadius, isLeft: true),
          ),

          Positioned(
            top: 0,
            right: 0,
            child: ArcSlider(radius: size.height * settings.arcSliderRadius, isLeft: false),
          ),

          /* ───── LEFT TOGGLES ───── */

          Positioned(
            left: size.width * 0.03,
            bottom: joystickTop + gap,
            child: Row(
              children: [
                TwoPositionSwitch(
                  height: settings.switchHeight,
                  value: leftTwo,
                  onChanged: (v) => setState(() => leftTwo = v),
                ),
                const SizedBox(width: 12),
                ThreePositionSwitch(
                  height: settings.switchHeight * 1.5,
                  value: leftThree,
                  onChanged: (v) => setState(() => leftThree = v),
                ),
              ],
            ),
          ),

          /* ───── RIGHT TOGGLES ───── */

          Positioned(
            right: size.width * 0.03,
            bottom: joystickTop + gap,
            child: Row(
              children: [
                TwoPositionSwitch(
                  height: settings.switchHeight,
                  value: rightTwo,
                  onChanged: (v) => setState(() => rightTwo = v),
                ),
                const SizedBox(width: 12),
                ThreePositionSwitch(
                  height: settings.switchHeight * 1.5,
                  value: rightThree,
                  onChanged: (v) => setState(() => rightThree = v),
                ),
              ],
            ),
          ),

          /* ───── LEFT JOYSTICK (THROTTLE + YAW) ───── */

          Positioned(
            left: size.width * 0.03,
            bottom: joystickBottom,
            child: ThrottleJoystick(
              size: joySize,
              value: throttle,
              onThrottleChanged: (v) => setState(() => throttle = v),
              onYawChanged: (v) => yaw = v,
            ),
          ),

          /* ───── RIGHT JOYSTICK (PITCH + ROLL) ───── */

          Positioned(
            right: size.width * 0.03,
            bottom: joystickBottom,
            child: CenterJoystick(
              size: joySize,
              onChanged: (x, y) {
                roll = x;
                pitch = y;
              },
            ),
          ),
          if (_showHud)
            Center(
              child: _buildHud(),
            ),
        ],
      ),
    );
  }
}

/* ================= ARC SLIDER (DRAWN UI) ================= */

class ArcSlider extends StatelessWidget {
  final double radius;
  final bool isLeft;

  const ArcSlider({
    super.key,
    required this.radius,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(radius, radius),
      painter: _ArcPainter(radius, isLeft),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double radius;
  final bool isLeft;

  _ArcPainter(this.radius, this.isLeft);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = radius * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(isLeft ? 0 : radius, radius);

    final start = (isLeft ? -pi / 2 - pi / 3 : -pi / 2 + pi / 3) + pi;
    final sweep = 2 * pi / 3;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/* ================= JOYSTICKS ================= */

class ThrottleJoystick extends ConsumerStatefulWidget {
  final double size;
  final double value;
  final ValueChanged<double> onThrottleChanged;
  final ValueChanged<double> onYawChanged;

  const ThrottleJoystick({
    super.key,
    required this.size,
    required this.value,
    required this.onThrottleChanged,
    required this.onYawChanged,
  });

  @override
  ConsumerState<ThrottleJoystick> createState() => _ThrottleJoystickState();
}

class _ThrottleJoystickState extends ConsumerState<ThrottleJoystick>
    with SingleTickerProviderStateMixin {
  late double throttle;
  Offset _offset = Offset.zero;
  late AnimationController _controller;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    throttle = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offset = Offset(0, 1 - throttle * 2);
  }

  void _returnToCenter() {
    _anim = Tween<Offset>(
      begin: _offset,
      end: Offset(0, _offset.dy),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _anim.addListener(() {
      setState(() {
        _offset = _anim.value;
        widget.onYawChanged(_offset.dx);
      });
    });

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return GestureDetector(
      onPanUpdate: (d) {
        _controller.stop();
        setState(() {
          throttle = 1 - (d.localPosition.dy / widget.size).clamp(0, 1);
          widget.onThrottleChanged(throttle);

          final r = widget.size / 2;
          final dx = d.localPosition.dx - r;
          _offset = Offset(dx.clamp(-r, r) / r, 1 - throttle * 2);
          widget.onYawChanged(_offset.dx);
        });
      },
      onPanEnd: (_) => _returnToCenter(),
      child: _joystickBase(
        widget.size,
        Alignment(_offset.dx, _offset.dy),
        Colors.grey.shade700,
        settings.joystickShape,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CenterJoystick extends ConsumerStatefulWidget {
  final double size;
  final void Function(double x, double y) onChanged;

  const CenterJoystick({
    super.key,
    required this.size,
    required this.onChanged,
  });

  @override
  ConsumerState<CenterJoystick> createState() => _CenterJoystickState();
}

class _CenterJoystickState extends ConsumerState<CenterJoystick>
    with SingleTickerProviderStateMixin {
  Offset offset = Offset.zero;
  late AnimationController controller;
  late Animation<Offset> anim;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  void _returnToCenter(double r) {
    anim = Tween<Offset>(
      begin: offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    anim.addListener(() {
      offset = anim.value;
      widget.onChanged(
        (offset.dx / r).clamp(-1.0, 1.0),
        (-offset.dy / r).clamp(-1.0, 1.0),
      );
      setState(() {});
    });

    controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final r = widget.size / 2;

    return GestureDetector(
      onPanUpdate: (d) {
        controller.stop();

        final dx = d.localPosition.dx - r;
        final dy = d.localPosition.dy - r;
        final dist = sqrt(dx * dx + dy * dy);

        offset = dist <= r
            ? Offset(dx, dy)
            : Offset(r * cos(atan2(dy, dx)), r * sin(atan2(dy, dx)));

        widget.onChanged(
          (offset.dx / r).clamp(-1.0, 1.0),
          (-offset.dy / r).clamp(-1.0, 1.0),
        );

        setState(() {});
      },
      onPanEnd: (_) => _returnToCenter(r),
      child: _joystickBase(
        widget.size,
        Alignment(offset.dx / r, offset.dy / r),
        Colors.grey.shade700,
        settings.joystickShape,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

Widget _joystickBase(double size, Alignment align, Color color, JoystickShape shape) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: shape == JoystickShape.circle ? BoxShape.circle : BoxShape.rectangle,
      color: Colors.grey.shade900,
    ),
    alignment: align,
    child: Container(
      width: size * 0.35,
      height: size * 0.35,
      decoration: BoxDecoration(
        shape: shape == JoystickShape.circle ? BoxShape.circle : BoxShape.rectangle,
        color: color,
      ),
    ),
  );
}

/* ================= TOGGLE SWITCHES ================= */

class TwoPositionSwitch extends StatelessWidget {
  final double height;
  final int value;
  final ValueChanged<int> onChanged;

  const TwoPositionSwitch({
    super.key,
    required this.height,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _switchBase(
      height: height,
      children: [
        _slot('1', value == 1, () => onChanged(1)),
        _slot('0', value == 0, () => onChanged(0)),
      ],
    );
  }
}

class ThreePositionSwitch extends StatelessWidget {
  final double height;
  final int value;
  final ValueChanged<int> onChanged;

  const ThreePositionSwitch({
    super.key,
    required this.height,
    required this.onChanged,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _switchBase(
      height: height,
      children: [
        _slot('+1', value == 1, () => onChanged(1)),
        _slot('0', value == 0, () => onChanged(0)),
        _slot('-1', value == -1, () => onChanged(-1)),
      ],
    );
  }
}

Widget _switchBase({required double height, required List<Widget> children}) {
  return Container(
    width: 60,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.grey.shade700),
    ),
    child: Column(children: children),
  );
}

Widget _slot(String label, bool active, VoidCallback onTap) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.grey.shade700 : Colors.grey.shade900,
          border: Border.all(color: Colors.black54),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}
