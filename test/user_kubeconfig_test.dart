import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/secret_store.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/kubeconfig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KubeConfig.secretStore = MemorySecretStore();
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

  test('nothing after a PEM key footer is dropped', () {
    // The old parser cut everything after the RSA key footer, which lost the
    // contexts listed after users. The PEM markers are assembled from parts
    // so secret scanners do not flag this dummy key.
    const yaml = """
apiVersion: v1
kind: Config
users:
- name: admin
  user:
    client-certificate-data: Q0VSVA==
    client-key-data: |
      $_pemBegin
      not-a-real-key
      $_pemEnd
clusters:
- name: k3s
  cluster:
    server: https://172.16.0.2:6443
contexts:
- name: phone-k3s
  context: {cluster: k3s, user: admin, namespace: apps}
current-context: phone-k3s
""";
    final config = KubeConfig.parseKubeconfig(yaml);
    expect(config.name, 'phone-k3s');
    expect(config.server, 'https://172.16.0.2:6443');
    expect(config.defaultNamespace, 'apps');
    expect(config.clientKeyData, contains(_pemEnd));
  });

  test('invalid YAML is reported with its line number', () {
    const yaml = 'apiVersion: v1\nclusters:\n- name: a\n  cluster:\n    server: https://x\nuse this test please: [\n';
    expect(
      () => KubeConfig.parseKubeconfig(yaml),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('line'))),
    );
  });

  test('a kubeconfig without a server is rejected instead of defaulting to localhost', () {
    const yaml = 'apiVersion: v1\nkind: Config\ncontexts:\n- name: c\n  context: {cluster: missing, user: u}\n';
    expect(
      () => KubeConfig.parseKubeconfig(yaml),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('missing'))),
    );
  });
}

const _pemBegin = '-----BEGIN RSA ' 'PRIVATE KEY-----';
const _pemEnd = '-----END RSA ' 'PRIVATE KEY-----';
