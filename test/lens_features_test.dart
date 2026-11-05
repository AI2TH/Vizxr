import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late K8sClientService client;

  setUp(() {
    client = K8sClientService(baseUrl: 'https://demo.k8s.local');
  });

  group('Helm Management Tests', () {
    test('fetchHelmReleases returns mock releases in demo mode', () async {
      final releases = await client.fetchHelmReleases();
      expect(releases, isNotEmpty);
      expect(releases.any((r) => r.name == 'traefik'), isTrue);
      expect(releases.any((r) => r.name == 'cert-manager'), isTrue);
    });

    test('installHelmRelease adds new release to releases list', () async {
      final result = await client.installHelmRelease(
        name: 'test-postgres-release',
        namespace: 'default',
        chart: 'postgresql',
        repo: 'https://charts.bitnami.com/bitnami',
        version: '13.2.24',
        valuesYaml: 'global:\n  postgresql:\n    auth:\n      password: test\n',
      );

      expect(result.success, isTrue);

      final releases = await client.fetchHelmReleases(namespace: 'default');
      expect(releases.any((r) => r.name == 'test-postgres-release'), isTrue);
      final rel = releases.firstWhere((r) => r.name == 'test-postgres-release');
      expect(rel.chart, equals('postgresql'));
      expect(rel.version, equals('13.2.24'));
    });

    test('rollbackHelmRelease updates release revision', () async {
      final rollbackRes = await client.rollbackHelmRelease(
        name: 'test-postgres-release',
        namespace: 'default',
        targetRevision: 1,
      );
      expect(rollbackRes.success, isTrue);

      final releases = await client.fetchHelmReleases(namespace: 'default');
      final rel = releases.firstWhere((r) => r.name == 'test-postgres-release');
      expect(rel.revision, equals(2));
    });

    test('uninstallHelmRelease removes release', () async {
      final deleteRes = await client.uninstallHelmRelease(
        name: 'test-postgres-release',
        namespace: 'default',
      );
      expect(deleteRes.success, isTrue);

      final releases = await client.fetchHelmReleases(namespace: 'default');
      expect(releases.any((r) => r.name == 'test-postgres-release'), isFalse);
    });
  });

  group('CustomResourceDefinition (CRD) Tests', () {
    test('fetchCustomResourceDefinitions returns CRDs', () async {
      final crds = await client.fetchCustomResourceDefinitions();
      expect(crds, isNotEmpty);
      expect(crds.any((c) => c.name.contains('helmcharts')), isTrue);
      expect(crds.any((c) => c.name.contains('certificates')), isTrue);
    });

    test('fetchCustomResourceObjects returns CR instances', () async {
      final crList = await client.fetchCustomResourceObjects(
        group: 'helm.cattle.io',
        version: 'v1',
        plural: 'helmcharts',
      );
      expect(crList, isNotEmpty);
      expect(crList.first.name, equals('traefik'));
    });
  });
}
