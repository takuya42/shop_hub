import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'screens/admin.dart';
import 'screens/store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BootstrapApp()));
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<FirebaseApp> initialization;
  bool demo = false;
  @override
  void initState() {
    super.initState();
    initialization = initialize();
  }

  Future<FirebaseApp> initialize() => Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(const Duration(seconds: 15));
  @override
  Widget build(BuildContext context) {
    if (demo) return const ShopHubApp();
    return FutureBuilder<FirebaseApp>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasData) return const ShopHubApp();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NotoSansJP',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!snapshot.hasError) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text('ショップを読み込んでいます…'),
                    ] else ...[
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 24),
                      const Text(
                        '接続できませんでした。接続状況を確認してください。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => initialization = initialize()),
                        child: const Text('再試行'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => demo = true),
                        child: const Text('デモを開く'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/admin'),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => adminPage(const Dashboard()),
          ),
          GoRoute(
            path: '/admin/products',
            builder: (_, _) => adminPage(const ProductsPage()),
          ),
          GoRoute(
            path: '/admin/products/new',
            builder: (_, _) => adminPage(const ProductEditor()),
          ),
          GoRoute(
            path: '/admin/products/:id',
            builder: (_, s) =>
                adminPage(AdminProductDetail(id: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/admin/products/:id/edit',
            builder: (_, s) =>
                adminPage(ProductEditor(id: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (_, _) => adminPage(const OrdersPage()),
          ),
          GoRoute(
            path: '/admin/orders/:id',
            builder: (_, s) =>
                adminPage(OrderDetail(id: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, _) => adminPage(const SettingsPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/shop/:slug',
        builder: (_, s) => StorePage(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/shop/:slug/products/:id',
        builder: (_, s) => StorePage(
          slug: s.pathParameters['slug']!,
          productId: s.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('ページが見つかりません'))),
  );
  ref.onDispose(router.dispose);
  return router;
});

class ShopHubApp extends ConsumerWidget {
  const ShopHubApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'shop_hub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      fontFamily: 'NotoSansJP',
      fontFamilyFallback: const ['Noto Sans JP', 'Yu Gothic', 'sans-serif'],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    routerConfig: ref.watch(routerProvider),
  );
}

Widget adminPage(Widget child) => SingleChildScrollView(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  ),
);
