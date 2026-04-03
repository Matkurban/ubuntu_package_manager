import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
/// The [AppTheme] defines light and dark themes for the app.
///
/// Theme setup for FlexColorScheme package v8.
/// Use same major flex_color_scheme package version. If you use a
/// lower minor version, some properties may not be supported.
/// In that case, remove them after copying this theme to your
/// app or upgrade the package to version 8.4.0.
///
/// Use it in a [MaterialApp] like this:
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// );
abstract final class AppTheme {
  // The FlexColorScheme defined light mode ThemeData.
  static ThemeData light = FlexThemeData.light(
    // Using FlexColorScheme built-in FlexScheme enum based colors
    scheme: FlexScheme.shadBlue,
    // Input color modifiers.
    useMaterial3ErrorColors: true,
    // Surface color adjustments.
    lightIsWhite: true,
    // Convenience direct styling properties.
    bottomAppBarElevation: 0.0,
    // Component theme configurations for light mode.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      adaptiveInputDecoratorRadius: FlexAdaptive.all(),
      defaultRadius: 10.0,
      inputDecoratorIsDense: true,
      inputDecoratorBackgroundAlpha: 100,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      alignedDropdown: true,
      appBarScrolledUnderElevation: 1.0,
      appBarCenterTitle: true,
      menuBarShadowColor: Color(0x00000000),
      searchBarElevation: 2.0,
      searchViewElevation: 2.0,
      searchUseGlobalShape: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // The FlexColorScheme defined dark mode ThemeData.
  static ThemeData dark = FlexThemeData.dark(
    // Using FlexColorScheme built-in FlexScheme enum based colors.
    scheme: FlexScheme.shadBlue,
    // Input color modifiers.
    useMaterial3ErrorColors: true,
    // Component theme configurations for dark mode.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      adaptiveInputDecoratorRadius: FlexAdaptive.all(),
      defaultRadius: 10.0,
      inputDecoratorIsDense: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      alignedDropdown: true,
      appBarCenterTitle: true,
      menuBarShadowColor: Color(0x00000000),
      searchBarElevation: 2.0,
      searchViewElevation: 2.0,
      searchUseGlobalShape: true,
      navigationRailUseIndicator: true,
    ),
    // Direct ThemeData properties.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}
