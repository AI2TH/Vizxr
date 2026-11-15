import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/screens/edit_cluster_screen.dart';
import 'package:vizxr/services/cluster_state.dart';
import 'package:vizxr/services/kubeconfig.dart';
import 'package:vizxr/services/secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KubeConfig.secretStore = MemorySecretStore();
  });

  testWidgets('turning on "Verify TLS certificates" saves the config with verification on', (tester) async {
    final config = KubeConfig(
      name: 'old-lab',
      server: 'https://demo.k8s.local',
      token: 'tok',
      insecureSkipTlsVerify: true,
    );
    await KubeConfig.saveConfig(config);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ClusterState(),
        child: MaterialApp(home: EditClusterScreen(config: config)),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(SwitchListTile, 'Verify TLS certificates');
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final saved = (await KubeConfig.loadConfigs()).firstWhere((c) => c.name == 'old-lab');
    expect(saved.insecureSkipTlsVerify, isFalse);
    expect(saved.token, 'tok');
  });
}
