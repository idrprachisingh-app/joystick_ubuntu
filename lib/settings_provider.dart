// lib/settings_provider.dart

// FIX: Added the required import for Riverpod state management.
import 'package:flutter_riverpod/flutter_riverpod.dart';

// FIX: Removed unused import for 'package:flutter/material.dart'.

// Enum to define the possible shapes for the joystick.
enum JoystickShape { circle, square }

// 1. DATA MODEL: Defines the immutable structure of our application's settings.
class Settings {
  final double joystickSize;
  final double switchHeight;
  final double arcSliderRadius;
  final JoystickShape joystickShape;

  Settings({
    required this.joystickSize,
    required this.switchHeight,
    required this.arcSliderRadius,
    required this.joystickShape,
  });

  // The 'copyWith' method is a best practice for immutable state.
  // It allows us to create a new Settings object with modified values.
  Settings copyWith({
    double? joystickSize,
    double? switchHeight,
    double? arcSliderRadius,
    JoystickShape? joystickShape,
  }) {
    return Settings(
      joystickSize: joystickSize ?? this.joystickSize,
      switchHeight: switchHeight ?? this.switchHeight,
      arcSliderRadius: arcSliderRadius ?? this.arcSliderRadius,
      joystickShape: joystickShape ?? this.joystickShape,
    );
  }
}

// 2. NOTIFIER: Manages the state and provides methods to update it.
// This is the only place where the state should be modified.
class SettingsNotifier extends StateNotifier<Settings> {
  // Set the initial default values for the settings here.
  SettingsNotifier()
      : super(Settings(
    joystickSize: 0.22,
    switchHeight: 90,
    arcSliderRadius: 0.18,
    joystickShape: JoystickShape.circle,
  ));

  void setJoystickSize(double size) {
    state = state.copyWith(joystickSize: size);
  }

  void setSwitchHeight(double height) {
    state = state.copyWith(switchHeight: height);
  }

  void setArcSliderRadius(double radius) {
    state = state.copyWith(arcSliderRadius: radius);
  }

  void setJoystickShape(JoystickShape shape) {
    state = state.copyWith(joystickShape: shape);
  }
}

// 3. PROVIDER: The global reference that the UI will use to access the notifier.
// The UI will 'watch' this provider to get the current settings state.
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
