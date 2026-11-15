import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';

/// Runs without the Flutter test binding so the real HttpClient talks to a
/// local fake API server.
void main() {
  group('parseManifestDocuments', () {
    test('splits a multi-document stream and skips empty documents', () {
      final docs = K8sClientService.parseManifestDocuments('''
apiVersion: v1
kind: Namespace
metadata:
  name: shop
---
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: settings
  namespace: shop
data:
  mode: "prod"
''');
      expect(docs.map((d) => d['kind']), ['Namespace', 'ConfigMap']);
      expect((docs[1]['data'] as Map)['mode'], 'prod');
    });

    test('expands kind: List', () {
      final docs = K8sClientService.parseManifestDocuments(
        '{"apiVersion":"v1","kind":"List","items":[{"apiVersion":"v1","kind":"Pod","metadata":{"name":"a"}},'
        '{"apiVersion":"v1","kind":"Pod","metadata":{"name":"b"}}]}',
      );
      expect(docs.map((d) => (d['metadata'] as Map)['name']), ['a', 'b']);
    });

    test('rejects a document that is not an object', () {
      expect(() => K8sClientService.parseManifestDocuments('- just\n- a list\n'), throwsFormatException);
    });
  });

  group('server-side apply', () {
    late HttpServer server;
    late List<({String method, Uri uri, String? contentType, Map body})> requests;
    int status = 200;

    setUp(() async {
      requests = [];
      status = 200;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = await utf8.decoder.bind(req).join();
        final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map;
        requests.add((method: req.method, uri: req.uri, contentType: req.headers.contentType?.mimeType, body: decoded));
        req.response.statusCode = status;
        req.response.headers.contentType = ContentType.json;
        req.response.write(status == 200 ? jsonEncode(decoded) : jsonEncode({'kind': 'Status', 'message': 'Apply failed with 1 conflict'}));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    K8sClientService client() => K8sClientService(baseUrl: 'http://localhost:${server.port}', isDemo: false);

    test('PATCHes each document with apply-patch+yaml and fieldManager=vizxr', () async {
      final c = client();
      final result = await c.applyManifest('''
apiVersion: v1
kind: Namespace
metadata:
  name: shop
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  managedFields: [{manager: kubectl}]
spec:
  replicas: 2
''', targetNamespace: 'shop');
      c.close();

      expect(result.success, isTrue, reason: result.message);
      expect(requests, hasLength(2));
      for (final r in requests) {
        expect(r.method, 'PATCH');
        expect(r.contentType, 'application/apply-patch+yaml');
        expect(r.uri.queryParameters['fieldManager'], 'vizxr');
        expect(r.uri.queryParameters.containsKey('force'), isFalse);
      }
      expect(requests[0].uri.path, '/api/v1/namespaces/shop');
      expect(requests[1].uri.path, '/apis/apps/v1/namespaces/shop/deployments/web');
      expect((requests[1].body['metadata'] as Map).containsKey('managedFields'), isFalse);
      expect((requests[1].body['metadata'] as Map)['namespace'], 'shop');
    });

    test('a 409 is reported as a conflict and force=true is sent on retry', () async {
      status = 409;
      final c = client();
      const yaml = 'apiVersion: v1\nkind: ConfigMap\nmetadata: {name: cfg, namespace: default}\n';
      final first = await c.applyManifest(yaml);
      expect(first.success, isFalse);
      expect(first.conflict, isTrue);

      status = 200;
      final second = await c.applyManifest(yaml, forceConflicts: true);
      c.close();
      expect(second.success, isTrue);
      expect(requests.last.uri.queryParameters['force'], 'true');
    });
  });
}
