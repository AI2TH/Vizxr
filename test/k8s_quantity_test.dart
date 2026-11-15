import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/k8s_quantity.dart';

void main() {
  group('K8sQuantity.parse', () {
    test('CPU quantities', () {
      expect(K8sQuantity.parse('250m'), closeTo(0.25, 1e-12));
      expect(K8sQuantity.parse('1500000n'), closeTo(0.0015, 1e-12));
      expect(K8sQuantity.parse('1200u'), closeTo(0.0012, 1e-12));
      expect(K8sQuantity.parse('4'), 4);
      expect(K8sQuantity.parse('1.5'), 1.5);
    });

    test('memory quantities', () {
      expect(K8sQuantity.parse('512Mi'), 512 * 1024 * 1024);
      expect(K8sQuantity.parse('2Gi'), 2 * 1024 * 1024 * 1024);
      expect(K8sQuantity.parse('8015712Ki'), 8015712 * 1024);
      expect(K8sQuantity.parse('1k'), 1000);
      expect(K8sQuantity.parse('1M'), 1e6);
      expect(K8sQuantity.parse('1G'), 1e9);
      expect(K8sQuantity.parse('1e3'), 1000);
    });

    test('invalid input', () {
      expect(K8sQuantity.tryParse('abc'), isNull);
      expect(K8sQuantity.tryParse('12Xi'), isNull);
      expect(K8sQuantity.tryParse(null), isNull);
      expect(() => K8sQuantity.parse('Mi'), throwsFormatException);
    });

    test('numbers pass through', () {
      expect(K8sQuantity.tryParse(3), 3.0);
    });
  });

  group('ClusterMetrics.fromLists', () {
    final nodeList = {
      'items': [
        {
          'status': {
            'allocatable': {'cpu': '4', 'memory': '8Gi', 'pods': '110'}
          }
        },
        {
          'status': {
            'allocatable': {'cpu': '3500m', 'memory': '4Gi'}
          }
        },
      ]
    };

    test('sums allocatable and usage', () {
      final m = ClusterMetrics.fromLists(
        nodeList: nodeList,
        nodeMetricsList: {
          'items': [
            {
              'usage': {'cpu': '250000000n', 'memory': '1Gi'}
            },
            {
              'usage': {'cpu': '500m', 'memory': '524288Ki'}
            },
          ]
        },
      );
      expect(m.nodeCount, 2);
      expect(m.cpuAllocatableCores, closeTo(7.5, 1e-9));
      expect(m.memAllocatableBytes, 12 * 1024 * 1024 * 1024);
      expect(m.metricsAvailable, isTrue);
      expect(m.cpuUsageCores, closeTo(0.75, 1e-9));
      expect(m.memUsageBytes, 1.5 * 1024 * 1024 * 1024);
      expect(m.cpuFraction, closeTo(0.1, 1e-9));
      expect(m.memFraction, closeTo(0.125, 1e-9));
    });

    test('reports unavailable metrics without usage', () {
      final m = ClusterMetrics.fromLists(
        nodeList: nodeList,
        nodeMetricsList: null,
        unavailableReason: 'Metrics unavailable: install metrics-server',
      );
      expect(m.metricsAvailable, isFalse);
      expect(m.unavailableReason, contains('metrics-server'));
      expect(m.cpuFraction, 0);
      expect(m.cpuAllocatableCores, closeTo(7.5, 1e-9));
    });
  });

  test('demo client returns mock cluster metrics', () async {
    final client = K8sClientService(baseUrl: 'https://demo.k8s.local');
    final m = await client.fetchClusterMetrics();
    expect(m.metricsAvailable, isTrue);
    expect(m.cpuAllocatableCores, 8);
    expect(m.cpuFraction, inInclusiveRange(0.0, 1.0));
  });

  test('formatting', () {
    expect(K8sQuantity.formatCores(0.25), '250m');
    expect(K8sQuantity.formatCores(1.5), '1.50');
    expect(K8sQuantity.formatBytes(512 * 1024 * 1024), '512 MiB');
    expect(K8sQuantity.formatBytes(16 * 1024 * 1024 * 1024), '16.0 GiB');
  });
}
