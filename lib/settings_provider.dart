import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum JoystickShape { circle, square }

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

class SettingsNotifier extends StateNotifier<Settings> {
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

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
