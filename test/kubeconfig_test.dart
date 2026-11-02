import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/kubeconfig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      expect(config.insecureSkipTlsVerify, isTrue);
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

      await KubeConfig.deleteConfig('test-cloud');
      list = await KubeConfig.loadConfigs();
      expect(list.any((c) => c.name == 'test-cloud'), isFalse);
    });
  });
}
