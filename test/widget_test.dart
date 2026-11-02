import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/main.dart';
import 'package:vizxr/services/cluster_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Vizxr basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ClusterState()),
        ],
        child: const K8sConsoleApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title text exists in AppBar
    expect(find.text('Vizxr'), findsOneWidget);
  });
}
