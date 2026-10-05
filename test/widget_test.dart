import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echogram/main.dart';
import 'package:echogram/providers/theme_provider.dart';
import 'package:echogram/providers/auth_provider.dart';
import 'package:echogram/providers/community_provider.dart';
import 'package:echogram/providers/question_provider.dart';
import 'package:echogram/providers/chat_provider.dart';
import 'package:echogram/providers/notification_provider.dart';
import 'package:echogram/services/socket_service.dart';
import 'package:echogram/services/local_store_service.dart';
import 'package:echogram/services/api_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SocketService.disabledForTests = true;
    await LocalStoreService().init();
    await ApiService().init();
  });

  testWidgets('EchoGram App renders LoginScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CommunityProvider()),
          ChangeNotifierProvider(create: (_) => QuestionProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const EchoGramApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that EchoGram unauthenticated state correctly shows Login screen
    expect(find.text('EchoGram'), findsWidgets);
    expect(find.text('EMAIL OR USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create one with @username'), findsOneWidget);
  });
}
