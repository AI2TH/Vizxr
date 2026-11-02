import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late K8sClientService client;

  setUp(() {
    client = K8sClientService(baseUrl: 'https://demo.k8s.local');
  });

  group('K8sClientService Tests', () {
    test('fetchResources returns pods from mock store for simulation', () async {
      final pods = await client.fetchResources(K8sResourceType.pod);
      expect(pods, isNotEmpty);
      expect(pods.any((p) => p.name.contains('nginx')), isTrue);
    });

    test('createPod and deleteResource manage pod lifecycle', () async {
      final newPod = await client.createPod(
        name: 'test-redis-unit',
        namespace: 'default',
        image: 'redis:alpine',
        port: 6379,
      );

      expect(newPod.name, equals('test-redis-unit'));
      expect(newPod.namespace, equals('default'));

      // Check it exists in fetchResources
      var pods = await client.fetchResources(K8sResourceType.pod, namespace: 'default');
      expect(pods.any((p) => p.name == 'test-redis-unit'), isTrue);

      // Now delete the pod
      await client.deleteResource(K8sResourceType.pod, 'test-redis-unit', 'default', force: true);

      // Check it was removed
      pods = await client.fetchResources(K8sResourceType.pod, namespace: 'default');
      expect(pods.any((p) => p.name == 'test-redis-unit'), isFalse);
    });

    test('applyManifest successfully creates and parses new resource', () async {
      const yaml = '''
apiVersion: v1
kind: Pod
metadata:
  name: applied-unit-pod
  namespace: default
spec:
  containers:
  - name: web
    image: nginx:alpine
''';

      final result = await client.applyManifest(yaml);
      expect(result.success, isTrue);

      final pods = await client.fetchResources(K8sResourceType.pod, namespace: 'default');
      expect(pods.any((p) => p.name == 'applied-unit-pod'), isTrue);

      // Cleanup
      await client.deleteResource(K8sResourceType.pod, 'applied-unit-pod', 'default');
    });

    test('scaleDeployment modifies replica count', () async {
      await client.scaleDeployment('zyvr-pbx-telephony', 'default', 3);
      final deps = await client.fetchResources(K8sResourceType.deployment, namespace: 'default');
      final dep = deps.firstWhere((d) => d.name == 'zyvr-pbx-telephony');
      expect(dep.status, contains('3/3'));
    });

    test('fetchPodLogs returns log content', () async {
      final logs = await client.fetchPodLogs('test-pod', 'default');
      expect(logs, isNotEmpty);
      expect(logs, contains('Container "test-pod"'));
    });

    test('fetchEvents returns event entries', () async {
      final events = await client.fetchEvents();
      expect(events, isNotEmpty);
    });
  });
}
