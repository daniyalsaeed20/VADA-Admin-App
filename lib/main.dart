import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';

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
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeFirebase();
  }

  Future<void> _initializeFirebase() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const ProviderScope(child: VadaAdminApp());
        }

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
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _initialization = _initializeFirebase();
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
