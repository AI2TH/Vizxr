import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/yaml_writer.dart';
import 'package:yaml/yaml.dart';

/// Converts the yaml package's YamlMap/YamlList into plain Dart collections.
Object? plain(Object? v) {
  if (v is Map) return {for (final e in v.entries) e.key.toString(): plain(e.value)};
  if (v is List) return v.map(plain).toList();
  return v;
}

void main() {
  final service = <String, dynamic>{
    'apiVersion': 'v1',
    'kind': 'Service',
    'metadata': {
      'name': 'web',
      'namespace': 'shop',
      'labels': {'app.kubernetes.io/name': 'web', 'tier': 'true'},
      'annotations': {
        'note': 'a: colon and # hash',
        'script': 'line one\nline two\n',
        'empty': '',
        'version': '1.10',
        'padded': ' leading space',
      },
      'managedFields': [
        {'manager': 'kubectl'},
      ],
    },
    'spec': {
      'type': 'ClusterIP',
      'selector': {'app': 'web'},
      'ports': [
        {'name': 'http', 'port': 80, 'targetPort': 8080, 'protocol': 'TCP'},
        {'name': 'https', 'port': 443, 'targetPort': 'https'},
      ],
      'externalIPs': <dynamic>[],
      'sessionAffinityConfig': <String, dynamic>{},
      'weights': [0.5, 1, null, false],
      'matrix': [
        [1, 2],
        ['a', 'b'],
      ],
    },
  };

  test('round-trips through the YAML parser', () {
    final yaml = toYaml(service);
    expect(plain(loadYaml(yaml)), equals(service));
  });

  test('is block YAML, not flattened key: value pairs or JSON', () {
    final yaml = toYaml(service);
    expect(yaml, startsWith('apiVersion: v1\nkind: Service\nmetadata:\n  name: web\n'));
    expect(yaml, contains('  ports:\n  - name: http\n    port: 80\n'));
    expect(yaml, contains('tier: "true"'));
    expect(yaml, contains('version: "1.10"'));
    expect(yaml, contains('script: |\n      line one\n      line two\n'));
    expect(yaml, isNot(contains('{name: web')));
  });

  test('manifestToYaml hides managedFields', () {
    final yaml = manifestToYaml(service);
    expect(yaml, isNot(contains('managedFields')));
    expect(service['metadata'], contains('managedFields')); // input untouched
  });

  test('strings that look like other types stay strings', () {
    for (final s in ['null', 'yes', 'No', '0x1F', '1e3', '-1', '.5', '2024-01-01', '~', '@at', '*star', 'a #b', '- dash']) {
      expect(plain(loadYaml(toYaml({'v': s}))), {'v': s}, reason: s);
    }
  });
}
