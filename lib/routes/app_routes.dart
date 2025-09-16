import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/detection_result.dart';
import '../screens/collection/history_screen.dart';
import '../screens/detail/detail_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/ar_viewer/ar_viewer_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // スプラッシュ画面
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // ホーム画面（履歴画面）
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HistoryScreen(),
    ),

    // 詳細画面
    GoRoute(
      path: '/detail/:index',
      builder: (context, state) {
        final indexStr = state.pathParameters['index'];
        
        if (indexStr == null) {
          return const Scaffold(
            appBar: null,
            body: Center(child: Text('無効なパラメータです')),
          );
        }

        final index = int.tryParse(indexStr);
        
        if (index == null) {
          return const Scaffold(
            appBar: null,
            body: Center(child: Text('無効なインデックスです')),
          );
        }

        return DetailScreen(historyIndex: index);
      },
    ),

    // 結果画面
    GoRoute(
      path: '/result',
      name: 'result',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid parameters for result screen')),
          );
        }

        final imageBytes = extra['imageBytes'] as Uint8List?;
        final detection = extra['detection'] as DetectionResult?;

        if (detection == null) {
          return const Scaffold(
            body: Center(child: Text('Missing required parameters')),
          );
        }

        return ResultScreen(imageBytes: imageBytes, detection: detection);
      },
    ),

    // AR Viewer画面
    GoRoute(
      path: '/ar_viewer',
      name: 'ar_viewer',
      builder: (context, state) {
        final glbModelUrl = state.extra as String?;
        if (glbModelUrl == null) {
          return const Scaffold(
            body: Center(child: Text('ARモデルのURLが指定されていません')),
          );
        }
        return ARViewerScreen(glbModelUrl: glbModelUrl);
      },
    ),

  ],

  // エラーハンドリング
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found: ${state.matchedLocation}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
