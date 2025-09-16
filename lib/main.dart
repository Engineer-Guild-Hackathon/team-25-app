// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

import 'routes/app_routes.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Web用WebViewプラットフォームを初期化
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }

  runApp(const ChemiLensApp());
}

class ChemiLensApp extends StatelessWidget {
  const ChemiLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ChemiLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          primary: AppColors.primary,
          onPrimary: AppColors.surface,
          secondary: AppColors.primaryDark,
          onSecondary: AppColors.surface,
          tertiary: AppColors.textSecondary,
          error: Colors.red,
          onError: Colors.white,
        ),
        fontFamily: 'Fredoka',
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.surface,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textSecondary),
          titleLarge: TextStyle(color: AppColors.textPrimary),
          titleMedium: TextStyle(color: AppColors.textPrimary),
          titleSmall: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      locale: const Locale('ja', 'JP'),
    );
  }
}
