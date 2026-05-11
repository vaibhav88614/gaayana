import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/auth/login_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/library/library_screen.dart';
import '../features/lyrics/lyrics_screen.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';

class GaayanaApp extends ConsumerWidget {
  const GaayanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final auth = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return DynamicColorGate(
      builder: (light, dark) => MaterialApp(
        title: 'Gaayana',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(light, Brightness.light),
        darkTheme: buildTheme(dark, Brightness.dark),
        themeMode: themeMode,
        routes: {
          '/search': (_) => const SearchScreen(),
          '/playlists': (_) => const PlaylistsScreen(),
          '/favorites': (_) => const FavoritesScreen(),
          '/downloads': (_) => const DownloadsScreen(),
          '/lyrics': (_) => const LyricsScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
        home: !firebaseReady
            ? const LibraryScreen()
            : auth.when(
                loading: () => const _Splash(),
                error: (e, _) => _Splash(error: e.toString()),
                data: (user) =>
                    user == null ? const LoginScreen() : const LibraryScreen(),
              ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: error != null
              ? Text(error!)
              : const CircularProgressIndicator(),
        ),
      );
}
