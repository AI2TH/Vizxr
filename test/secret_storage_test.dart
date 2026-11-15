import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/kubeconfig.dart';
import 'package:vizxr/services/secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySecretStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MemorySecretStore();
    KubeConfig.secretStore = store;
  });

  test('saveConfig keeps the token and client key out of SharedPreferences', () async {
    await KubeConfig.saveConfig(KubeConfig(
      name: 'cloud',
      server: 'https://k8s.example.com',
      token: 'sekrit-token',
      clientCertData: 'CERT',
      clientKeyData: 'PRIVATE-KEY',
    ));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('vizxr_kubeconfigs')!.join();
    expect(raw, isNot(contains('sekrit-token')));
    expect(raw, isNot(contains('PRIVATE-KEY')));
    expect(raw, contains('CERT')); // certificates are public

    final secrets = store.values[KubeConfig.secretsStorageKey]!;
    expect(secrets, contains('sekrit-token'));
    expect(secrets, contains('PRIVATE-KEY'));

    final loaded = (await KubeConfig.loadConfigs()).firstWhere((c) => c.name == 'cloud');
    expect(loaded.token, 'sekrit-token');
    expect(loaded.clientKeyData, 'PRIVATE-KEY');
  });

  test('plaintext credentials from older versions are migrated on load', () async {
    SharedPreferences.setMockInitialValues({
      'vizxr_kubeconfigs': [
        jsonEncode({
          'name': 'legacy',
          'server': 'https://10.0.0.1:6443',
          'token': 'old-token',
          'caCert': null,
          'clientCertData': null,
          'clientKeyData': 'old-key',
          'defaultNamespace': 'default',
          'insecureSkipTlsVerify': false,
        }),
      ],
    });

    final configs = await KubeConfig.loadConfigs();
    final legacy = configs.firstWhere((c) => c.name == 'legacy');
    expect(legacy.token, 'old-token');
    expect(legacy.clientKeyData, 'old-key');

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('vizxr_kubeconfigs')!.join();
    expect(raw, isNot(contains('old-token')));
    expect(raw, isNot(contains('old-key')));
    expect(store.values[KubeConfig.secretsStorageKey], contains('old-token'));

    // A second load reads the migrated credentials from secure storage.
    final again = (await KubeConfig.loadConfigs()).firstWhere((c) => c.name == 'legacy');
    expect(again.token, 'old-token');
  });

  test('deleteConfig removes the credentials too', () async {
    final config = KubeConfig(name: 'gone', server: 'https://x', token: 't');
    await KubeConfig.saveConfig(config);
    await KubeConfig.deleteConfig(config.storageKey);
    expect(store.values[KubeConfig.secretsStorageKey], isNull);
  });
}
