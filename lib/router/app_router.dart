import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_admin/screens/admin_violation_screen.dart';
import 'package:social_media_admin/screens/comments/comments_list_screen.dart';
import 'package:social_media_admin/screens/dashboard_screen.dart';
import 'package:social_media_admin/screens/login_screen.dart';
import 'package:social_media_admin/screens/logout_screen.dart';
import 'package:social_media_admin/screens/posts/posts_list_screen.dart';
import 'package:social_media_admin/screens/users/users_list_screen.dart';
import 'package:social_media_admin/services/admin_auth_service.dart';
import 'package:social_media_admin/widgets/admin_shell.dart';

final _adminAuthService = AdminAuthService();
final _auth = FirebaseAuth.instance;


final router = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(_auth.authStateChanges(),),
  redirect: (context, state) async {
    final user = _auth.currentUser;
    final isLoginRoute = state.matchedLocation == '/login';

    // Not logged in
    if (user == null) {
      return isLoginRoute ? null : '/login';
    }

    // Check if user has admin claim
    final isAdmin = await _adminAuthService.isAdmin();

    // User is logged in but not an admin
    if (!isAdmin) {
      await _adminAuthService.adminLogout();
      return '/login';
    }

    // User is admin and trying to access login page
    if (isLoginRoute) {
      return '/dashboard';
    }

    // Allow access to requested route
    return null;
  },
  routes: [
    // 1. LOGIN (No Sidebar)
    GoRoute(path: '/login', builder: (context, state) => LoginScreen()),

    // 2. ADMIN PANEL (has Sidebar)
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => DashboardScreen(),
        ),
        GoRoute(path: '/users', builder: (context, state) => UsersListScreen()),
        GoRoute(path: '/posts', builder: (context, state) => PostsListScreen()),
        GoRoute(path: '/violations', builder: (context, state) => AdminViolationScreen()),
        GoRoute(
          path: '/comments',
          builder: (context, state) => CommentsListScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('Quản lí báo cáo'))),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('Cài đặt'))),
        ),
      ],
    ),
    GoRoute(
      path:'/logout',
      builder: (context,state)=> const LogoutScreen(),
    )
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}