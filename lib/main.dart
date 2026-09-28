import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/community_provider.dart';
import 'providers/question_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'services/local_store_service.dart';
import 'services/api_service.dart';
import 'widgets/mobile_device_frame.dart';
import 'screens/main_nav_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  await LocalStoreService().init();
  await ApiService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const NearTalkApp(),
    ),
  );
}

class NearTalkApp extends StatelessWidget {
  const NearTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'NearTalk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MobileDeviceFrame(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: authProvider.isAuthenticated
          ? const MainNavScreen()
          : const LoginScreen(),
    );
  }
}
