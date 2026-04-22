import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin/queue_screen.dart';
import 'screens/app_detail_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/developer/dashboard_screen.dart';
import 'screens/developer/upload_screen.dart';
import 'screens/fix_rejection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/install_guide_screen.dart';
import 'screens/security_report_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AlMobarmgStoreApp()));
}

final secureStorageProvider =
    Provider<FlutterSecureStorage>((_) => const FlutterSecureStorage());

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref.read(secureStorageProvider)),
);

class AuthState {
  final bool loading;
  final String? token;
  final String? role;

  const AuthState({this.loading = false, this.token, this.role});

  bool get isAuthenticated => token != null && token!.isNotEmpty;
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._storage) : super(const AuthState(loading: true)) {
    restore();
  }

  final FlutterSecureStorage _storage;

  Future<void> restore() async {
    final token = await _storage.read(key: 'access_token');
    final role = await _storage.read(key: 'role');
    state = AuthState(loading: false, token: token, role: role);
  }

  Future<void> saveSession(String token, String role) async {
    await _storage.write(key: 'access_token', value: token);
    await _storage.write(key: 'role', value: role);
    state = AuthState(loading: false, token: token, role: role);
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
    state = const AuthState(loading: false);
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashGate()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/apps/:id',
        builder: (context, state) =>
            AppDetailScreen(appId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/apps/:id/security-report',
        builder: (context, state) =>
            SecurityReportScreen(appId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/install-guide',
        builder: (context, state) => const InstallGuideScreen(),
      ),
      GoRoute(
        path: '/developer/dashboard',
        builder: (context, state) => const DeveloperDashboardScreen(),
      ),
      GoRoute(
        path: '/developer/upload',
        builder: (context, state) => const DeveloperUploadScreen(),
      ),
      GoRoute(path: '/admin/queue', builder: (context, state) => const AdminQueueScreen()),
      GoRoute(path: '/fix-rejection', builder: (_, __) => const FixRejectionScreen()),
    ],
    redirect: (context, state) {
      if (auth.loading) return null;
      final onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/verify-email' ||
          state.matchedLocation == '/reset-password';
      if (!auth.isAuthenticated && !onAuthPage && state.matchedLocation != '/') {
        return '/login';
      }
      if (auth.isAuthenticated && onAuthPage) {
        if (auth.role == 'admin') return '/admin/queue';
        if (auth.role == 'developer') return '/developer/dashboard';
        return '/home';
      }
      return null;
    },
  );
});

class AlMobarmgStoreApp extends ConsumerWidget {
  const AlMobarmgStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Al Mobarmg Store',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('en');
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en');
      },
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        return Directionality(
          textDirection:
              locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class SplashGate extends ConsumerWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!auth.isAuthenticated) {
        context.go('/login');
      } else if (auth.role == 'admin') {
        context.go('/admin/queue');
      } else if (auth.role == 'developer') {
        context.go('/developer/dashboard');
      } else {
        context.go('/home');
      }
    });

    return const Scaffold(
      body: Center(child: Text('Launching Al Mobarmg Store...')),
    );
  }
}
