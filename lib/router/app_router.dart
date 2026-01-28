import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/protege/home/protege_home_screen.dart';
import '../features/chaperone/home/chaperone_home_screen.dart';
import '../features/admin/admin_dashboard.dart';
import '../features/community/community_screen.dart';
import '../features/auth/presentation/invite_signup_screen.dart';

/// Auth state notifier for GoRouter refresh
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// Provider for the auth state notifier
final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  return AuthStateNotifier(ref);
});

/// App router configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;

      // Don't redirect during loading - show nothing
      if (isLoading) {
        return null;
      }

      // Auth routes
      final isAuthRoute = currentPath == '/login' || 
          currentPath == '/signup' ||
          currentPath == '/invite' ||
          currentPath == '/';

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // If not authenticated and on root, go to login
      if (!isAuthenticated && currentPath == '/') {
        return '/login';
      }

      // If authenticated and on auth route or root, redirect to appropriate home
      if (isAuthenticated && isAuthRoute) {
        final role = authState.user?.role ?? 'protege';
        if (role == 'admin') {
          return '/admin';
        } else if (role == 'chaperone') {
          return '/chaperone';
        }
        return '/protege';
      }

      return null;
    },
    routes: [
      // Root redirect
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),
      
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) => const InviteSignupScreen(),
      ),

      // Protege routes
      GoRoute(
        path: '/protege',
        builder: (context, state) => const ProtegeHomeScreen(),
        routes: [
          GoRoute(
            path: 'habits',
            builder: (context, state) => const ProtegeHomeScreen(),
          ),
          GoRoute(
            path: 'tasks',
            builder: (context, state) => const ProtegeHomeScreen(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const ProtegeHomeScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProtegeHomeScreen(),
          ),
        ],
      ),

      // Chaperone routes
      GoRoute(
        path: '/chaperone',
        builder: (context, state) => const ChaperoneHomeScreen(),
        routes: [
          GoRoute(
            path: 'proteges',
            builder: (context, state) => const ChaperoneHomeScreen(),
          ),
          GoRoute(
            path: 'tasks',
            builder: (context, state) => const ChaperoneHomeScreen(),
          ),
          GoRoute(
            path: 'habits',
            builder: (context, state) => const ChaperoneHomeScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ChaperoneHomeScreen(),
          ),
        ],
      ),

      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Community route
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
    ],
  );
});
