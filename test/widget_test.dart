import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neartalk/main.dart';
import 'package:neartalk/providers/theme_provider.dart';
import 'package:neartalk/providers/auth_provider.dart';
import 'package:neartalk/providers/community_provider.dart';
import 'package:neartalk/providers/question_provider.dart';
import 'package:neartalk/providers/chat_provider.dart';
import 'package:neartalk/providers/notification_provider.dart';
import 'package:neartalk/services/socket_service.dart';
import 'package:neartalk/services/local_store_service.dart';
import 'package:neartalk/services/api_service.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SocketService.disabledForTests = true;
    await LocalStoreService().init();
    await ApiService().init();
  });

  testWidgets('NearTalk App renders LoginScreen when unauthenticated', (WidgetTester tester) async {
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
        child: const NearTalkApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that NearTalk unauthenticated state correctly shows Login screen
    expect(find.text('NearTalk'), findsWidgets);
    expect(find.text('EMAIL OR USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create one with @username'), findsOneWidget);
  });
}
