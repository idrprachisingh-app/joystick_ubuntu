import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:joy_stickcontroller/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Joystick Size: ${settings.joystickSize.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
            Slider(
              value: settings.joystickSize,
              min: 0.1,
              max: 0.5,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setJoystickSize(value);
              },
              activeColor: Colors.grey,
              inactiveColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 20),
            Text('Switch Height: ${settings.switchHeight.toInt()}', style: const TextStyle(color: Colors.white)),
            Slider(
              value: settings.switchHeight,
              min: 50,
              max: 200,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setSwitchHeight(value);
              },
              activeColor: Colors.grey,
              inactiveColor: Colors.grey.shade800,
            ),
          ],
        ),
      ),
    );
  }
}
