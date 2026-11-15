import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/secret_store.dart';
import 'package:vizxr/main.dart';
import 'package:vizxr/services/cluster_state.dart';
import 'package:vizxr/services/kubeconfig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KubeConfig.secretStore = MemorySecretStore();
  });

  testWidgets('Vizxr basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ClusterState()),
        ],
        child: const VizxrApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The app bar shows the cluster switcher. Before data loading moved out
    // of build(), requests discarded on rebuild failed unobserved here.
    expect(find.byTooltip('Clusters Switcher'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
