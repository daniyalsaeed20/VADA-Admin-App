import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/cache/shared_prefs_key_value_store.dart';
import 'src/core/firebase/firebase_providers.dart';
import 'src/core/notifications/local_notifications_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<SharedPrefsKeyValueStore> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _startInitialization();
  }

  Future<SharedPrefsKeyValueStore> _startInitialization() {
    return _initializeApp().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'App initialization timed out after 30 seconds.',
        );
      },
    );
  }

  Future<SharedPrefsKeyValueStore> _initializeApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Offline persistence is enabled by default on web; assigning settings here
    // can hang in production without throwing (IndexedDB / multi-tab issues).
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
      } catch (_) {
        // Non-fatal — app works without offline cache.
      }
    }

    final store = await SharedPrefsKeyValueStore.create();
    await LocalNotificationsService.instance.initialize();
    return store;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPrefsKeyValueStore>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapMaterialApp(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to initialize app. Please retry.',
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _initialization = _startInitialization();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return ProviderScope(
            overrides: [
              keyValueStoreProvider.overrideWithValue(snapshot.data!),
            ],
            child: const VadaAdminApp(),
          );
        }

        return const _BootstrapMaterialApp(
          child: _LaunchSplashScreen(),
        );
      },
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB50E16)),
      ),
      // Accept any initial route (e.g. "/login" on web refresh) while the
      // bootstrap splash is active, preventing "no corresponding route" errors.
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: child),
        );
      },
    );
  }
}

class _LaunchSplashScreen extends StatelessWidget {
  const _LaunchSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: AssetImage('assets/vada_logo.png'),
            width: 220,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 24),
          _LineLoader(),
        ],
      ),
    );
  }
}

class _LineLoader extends StatefulWidget {
  const _LineLoader();

  @override
  State<_LineLoader> createState() => _LineLoaderState();
}

class _LineLoaderState extends State<_LineLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColoredBox(
          color: const Color(0xFFECECEC),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final x = Tween<double>(
                begin: -1.2,
                end: 1.2,
              ).transform(Curves.easeInOut.transform(_controller.value));
              return Align(
                alignment: Alignment(x, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.45,
                  heightFactor: 1,
                  child: const ColoredBox(color: Color(0xFFB50E16)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
