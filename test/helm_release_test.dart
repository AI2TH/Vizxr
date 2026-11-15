import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';

void main() {
  // A Helm v3 storage Secret as returned by the API: data.release is
  // base64(base64(gzip(JSON))). Built from a small release JSON.
  const fixture = 'SDRzSUFNWGorV29DLzFXUVFVL0VJQkNGLzBvelo1Y0EzYTdhNjU2OGVWQVBYc3hJWjdza0xSQ1lybTZhL25jQm85RWI3NXZodlFjck9Kd0orZ1krNkIxdW1pcFRRRk1aaHBBS3ZGQk0xcnVNMnF5c08vbDhYQ0V4OHBMSzRrQmg4bGNheXZLRWlkOStRUjVxcVE4N3BYWlNQU25aYTltM1VpamQ3cnZEN2QzOWE3a3lVRExSQnY3T2dPY3dSaHlvTVg0T0V6SEJsbmZNR1NQWDJKa1lCMlNzNHFlK0c2MzcvTjhWVkNmMlFoZVlIL0x5aHd2ZGlSYTJhdXZkeVk3Vkt1Yk8xdURSTDY0RTZUeE5GQysyL3NVS2ZBMDE2VGd0aVNrK1BHYUQ3UXNISnB6WlFBRUFBQT09';

  test('decodeHelmReleaseSecret reads a Helm v3 release', () {
    final rel = K8sClientService.decodeHelmReleaseSecret({
      'type': 'helm.sh/release.v1',
      'metadata': {
        'name': 'sh.helm.release.v1.web.v3',
        'namespace': 'apps',
        'labels': {'owner': 'helm', 'name': 'web', 'version': '3', 'status': 'deployed'},
      },
      'data': {'release': fixture},
    })!;

    expect(rel.name, 'web');
    expect(rel.namespace, 'apps');
    expect(rel.chart, 'nginx');
    expect(rel.version, '15.4.2');
    expect(rel.appVersion, '1.25.3');
    expect(rel.revision, 3);
    expect(rel.status, 'deployed');
    expect(rel.updated, '2026-11-01 10:20:30');
    expect(rel.description, 'Upgrade complete');
    expect(rel.source, HelmRelease.sourceHelm);
    expect(rel.values['replicaCount'], 2);
    expect(jsonDecode(rel.valuesYaml), {
      'replicaCount': 2,
      'service': {'type': 'ClusterIP'},
    });
  });

  test('decodeHelmReleaseSecret accepts an uncompressed payload', () {
    final json = jsonEncode({
      'name': 'plain',
      'namespace': 'default',
      'version': 1,
      'info': {'status': 'failed'},
      'chart': {
        'metadata': {'name': 'demo', 'version': '0.1.0'}
      },
    });
    final helmEncoded = base64Encode(utf8.encode(json));
    final secretValue = base64Encode(utf8.encode(helmEncoded));
    final rel = K8sClientService.decodeHelmReleaseSecret({
      'data': {'release': secretValue}
    })!;
    expect(rel.name, 'plain');
    expect(rel.status, 'failed');
    expect(rel.valuesYaml, isEmpty);
  });

  test('decodeHelmReleaseSecret round-trips gzip like Helm does', () {
    final json = jsonEncode({'name': 'gz', 'namespace': 'ns', 'version': 7, 'info': {'status': 'deployed'}});
    final helmEncoded = base64Encode(gzip.encode(utf8.encode(json)));
    final rel = K8sClientService.decodeHelmReleaseSecret({
      'data': {'release': base64Encode(utf8.encode(helmEncoded))}
    })!;
    expect(rel.revision, 7);
  });

  test('decodeHelmReleaseSecret returns null for garbage', () {
    expect(K8sClientService.decodeHelmReleaseSecret({'data': {'release': 'not-base64!'}}), isNull);
    expect(K8sClientService.decodeHelmReleaseSecret({'data': {}}), isNull);
  });

  test('live-cluster rollback is refused instead of faking success', () async {
    final client = K8sClientService(baseUrl: 'https://10.255.255.1:6443');
    final res = await client.rollbackHelmRelease(name: 'web', namespace: 'apps', targetRevision: 2);
    expect(res.success, isFalse);
    final un = await client.uninstallHelmRelease(name: 'web', namespace: 'apps', source: HelmRelease.sourceHelm);
    expect(un.success, isFalse);
    client.close();
  });
}
