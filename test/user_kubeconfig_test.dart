import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/kubeconfig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('insecure-skip-tls-verify: true is honoured', () async {
    const yaml = '''
apiVersion: v1
kind: Config
current-context: lab
contexts:
- name: lab
  context: {cluster: lab, user: lab}
clusters:
- name: lab
  cluster:
    server: https://10.0.0.5:6443
    insecure-skip-tls-verify: true
users:
- name: lab
  user:
    token: abc123
''';
    final config = await KubeConfig.addFromYaml(yaml);
    expect(config.insecureSkipTlsVerify, isTrue);
    expect(config.token, equals('abc123'));

    final client = K8sClientService(
      baseUrl: config.server,
      token: config.token,
      insecureSkipTlsVerify: config.insecureSkipTlsVerify,
    );
    expect(client.baseUrl, equals('https://10.0.0.5:6443'));
    expect(client.isDemo, isFalse);
    client.close();
  });

  test('exec credential plugins are rejected with a clear message', () async {
    const yaml = '''
apiVersion: v1
kind: Config
current-context: eks
contexts:
- name: eks
  context: {cluster: eks, user: eks}
clusters:
- name: eks
  cluster:
    server: https://example.eks.amazonaws.com
users:
- name: eks
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args: [eks, get-token, --cluster-name, demo]
''';
    await expectLater(
      KubeConfig.addFromYaml(yaml),
      throwsA(predicate((e) => e.toString().contains('exec or auth-provider plugin'))),
    );
  });

  test('K8sClientService defaults to verifying TLS', () {
    final client = K8sClientService(baseUrl: 'https://10.0.0.5:6443');
    expect(client.insecureSkipTlsVerify, isFalse);
    expect(client.isDemo, isFalse);
    client.close();
  });

  test('a real cluster whose name contains "demo" is not treated as the simulator', () {
    final client = K8sClientService(baseUrl: 'https://demo-prod.example.com:6443');
    expect(client.isDemo, isFalse);
    client.close();
    final sim = K8sClientService(baseUrl: 'https://demo.k8s.local');
    expect(sim.isDemo, isTrue);
    sim.close();
  });
}
