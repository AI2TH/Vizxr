import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/secret_store.dart';
import 'package:vizxr/services/kubeconfig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KubeConfig.secretStore = MemorySecretStore();
  });

  group('KubeConfig Tests', () {
    const sampleYaml = '''
apiVersion: v1
kind: Config
current-context: default-context
contexts:
- name: default-context
  context:
    cluster: k3s-cluster
    user: admin-user
    namespace: production
clusters:
- name: k3s-cluster
  cluster:
    server: https://192.168.1.50:6443
    certificate-authority-data: Y2EtY2VydC1kYXRh
users:
- name: admin-user
  user:
    client-certificate-data: Y2xpZW50LWNlcnQtZGF0YQ==
    client-key-data: Y2xpZW50LWtleS1kYXRh
''';

    test('addFromYaml parses clusters, contexts, users, and mTLS certs correctly', () async {
      final config = await KubeConfig.addFromYaml(sampleYaml);

      expect(config.name, equals('default-context'));
      expect(config.server, equals('https://192.168.1.50:6443'));
      expect(config.defaultNamespace, equals('production'));
      expect(config.caCert, equals('Y2EtY2VydC1kYXRh'));
      expect(config.clientCertData, equals('Y2xpZW50LWNlcnQtZGF0YQ=='));
      expect(config.clientKeyData, equals('Y2xpZW50LWtleS1kYXRh'));
      // No insecure-skip-tls-verify in the kubeconfig, so TLS must be verified.
      expect(config.insecureSkipTlsVerify, isFalse);
    });

    test('loadConfigs ensures default local and demo clusters are present', () async {
      final configs = await KubeConfig.loadConfigs();
      expect(configs.any((c) => c.server.contains('127.0.0.1:6443')), isTrue);
      expect(configs.any((c) => c.name.contains('Demo Cluster')), isTrue);
    });

    test('saveConfig and deleteConfig persist to SharedPreferences', () async {
      final custom = KubeConfig(
        name: 'test-cloud',
        server: 'https://k8s.example.com:6443',
        token: 'secret-token',
        defaultNamespace: 'staging',
      );
      await KubeConfig.saveConfig(custom);

      var list = await KubeConfig.loadConfigs();
      expect(list.any((c) => c.name == 'test-cloud'), isTrue);

      await KubeConfig.deleteConfig(custom.id);
      list = await KubeConfig.loadConfigs();
      expect(list.any((c) => c.name == 'test-cloud'), isFalse);
    });

    test('two kubeconfigs with the same context name are kept apart', () async {
      final a = KubeConfig(name: 'default', server: 'https://10.0.0.1:6443', token: 'a');
      final b = KubeConfig(name: 'default', server: 'https://10.0.0.2:6443', token: 'b');
      expect(a.id, isNot(equals(b.id)));
      await KubeConfig.saveConfig(a);
      await KubeConfig.saveConfig(b);

      final list = await KubeConfig.loadConfigs();
      final defaults = list.where((c) => c.name == 'default').toList();
      expect(defaults, hasLength(2));
      expect(defaults.map((c) => c.token).toSet(), {'a', 'b'});
    });

    test('renaming keeps the id and credentials', () async {
      final a = KubeConfig(name: 'default', server: 'https://10.0.0.1:6443', token: 'a');
      await KubeConfig.saveConfig(a);
      await KubeConfig.saveConfig(a.copyWith(name: 'home-lab'));

      final list = await KubeConfig.loadConfigs();
      expect(list.where((c) => c.id == a.id), hasLength(1));
      final renamed = list.firstWhere((c) => c.id == a.id);
      expect(renamed.name, 'home-lab');
      expect(renamed.token, 'a');
    });

    test('uniqueName adds a numeric suffix', () {
      expect(KubeConfig.uniqueName('default', []), 'default');
      expect(KubeConfig.uniqueName('default', ['default']), 'default (2)');
      expect(KubeConfig.uniqueName('default', ['default', 'default (2)']), 'default (3)');
    });

    test('configs saved without an id get one, and their credentials follow', () async {
      SharedPreferences.setMockInitialValues({
        'vizxr_kubeconfigs': [
          '{"name":"old","server":"https://10.0.0.9:6443","token":"t-old","defaultNamespace":"default","insecureSkipTlsVerify":false}',
        ],
      });
      final first = (await KubeConfig.loadConfigs()).firstWhere((c) => c.name == 'old');
      expect(first.id, isNotEmpty);
      expect(first.token, 't-old');

      final second = (await KubeConfig.loadConfigs()).firstWhere((c) => c.name == 'old');
      expect(second.id, first.id);
      expect(second.token, 't-old');
    });
  });
}
