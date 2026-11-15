import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';

/// No Flutter test binding: the real HttpClient talks to a local fake API
/// server that either serves helm.cattle.io/v1 (k3s) or not (other clusters).
void main() {
  late HttpServer server;
  late bool k3s;

  setUp(() async {
    k3s = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      final served = k3s && req.uri.path.startsWith('/apis/helm.cattle.io/v1');
      req.response.statusCode = served ? 200 : 404;
      req.response.headers.contentType = ContentType.json;
      req.response.write(served
          ? jsonEncode({'kind': 'APIResourceList', 'groupVersion': 'helm.cattle.io/v1'})
          : jsonEncode({'kind': 'Status', 'message': 'the server could not find the requested resource'}));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  K8sClientService client() => K8sClientService(baseUrl: 'http://localhost:${server.port}', isDemo: false);

  test('a cluster without helm.cattle.io is detected', () async {
    final c = client();
    expect(await c.hasK3sHelmController(), isFalse);
    c.close();
  });

  test('a k3s cluster is detected', () async {
    k3s = true;
    final c = client();
    expect(await c.hasK3sHelmController(), isTrue);
    c.close();
  });

  test('installing outside k3s explains why instead of a bare 404', () async {
    final c = client();
    final result = await c.installHelmRelease(
      name: 'redis',
      namespace: 'default',
      chart: 'redis',
      repo: 'https://charts.bitnami.com/bitnami',
      version: '',
    );
    c.close();
    expect(result.success, isFalse);
    expect(result.message, K8sClientService.k3sHelmOnlyMessage);
  });

  test('the demo cluster always allows installs', () async {
    final demo = K8sClientService(baseUrl: 'https://demo.k8s.local');
    expect(await demo.hasK3sHelmController(), isTrue);
    demo.close();
  });
}
