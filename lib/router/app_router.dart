import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_admin/screens/comments/comments_list_screen.dart';
import 'package:social_media_admin/screens/dashboard_screen.dart';
import 'package:social_media_admin/screens/login_screen.dart';
import 'package:social_media_admin/screens/posts/posts_list_screen.dart';
import 'package:social_media_admin/screens/users/users_list_screen.dart';
import 'package:social_media_admin/widgets/admin_shell.dart';

final router = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    // TODO: Add your Auth Logic here later
    // For now, just let us see the dashboard
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
  ],
);
