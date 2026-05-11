import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:palette_generator/palette_generator.dart';

/// Builds the global [ThemeData] for the app.
///
/// Two layers:
/// 1. **Dynamic color** from the OS wallpaper (`dynamic_color` package) is the
///    default seed.
/// 2. When a track is playing, the Now-Playing screen overrides this with a
///    palette extracted from the current album art via [albumArtScheme].
ThemeData buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C3AED), // fallback violet
        brightness: brightness,
      );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
  );
}

/// Extract a Material 3 [ColorScheme] from album art.
/// Used by the Now-Playing screen to recolor the gradient background.
Future<ColorScheme> albumArtScheme(
  ImageProvider provider,
  Brightness brightness,
) async {
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      provider,
      maximumColorCount: 8,
      size: const Size(120, 120),
    );
    final seed = palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        const Color(0xFF7C3AED);
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  } catch (_) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED),
      brightness: brightness,
    );
  }
}

/// Helper used by [MaterialApp.builder] to get dynamic color synchronously.
class DynamicColorGate extends StatelessWidget {
  const DynamicColorGate({required this.builder, super.key});
  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;
  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
        builder: (light, dark) => builder(light, dark),
      );
}
