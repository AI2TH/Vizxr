import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/k8s_quantity.dart';
import 'package:vizxr/services/metrics_history.dart';

void main() {
  test('keeps only the last samples of each series', () {
    final h = MetricsHistory(capacity: 3);
    for (var i = 1; i <= 5; i++) {
      h.add('x', i.toDouble());
    }
    expect(h.series('x'), [3.0, 4.0, 5.0]);
    expect(h.series('unknown'), isEmpty);
  });

  test('records the cluster total and each node', () {
    final metrics = ClusterMetrics.fromLists(
      nodeList: {
        'items': [
          {'metadata': {'name': 'a'}, 'status': {'allocatable': {'cpu': '2', 'memory': '4Gi'}}},
          {'metadata': {'name': 'b'}, 'status': {'allocatable': {'cpu': '2', 'memory': '4Gi'}}},
        ],
      },
      nodeMetricsList: {
        'items': [
          {'metadata': {'name': 'a'}, 'usage': {'cpu': '250m', 'memory': '1Gi'}},
          {'metadata': {'name': 'b'}, 'usage': {'cpu': '500m', 'memory': '2Gi'}},
        ],
      },
    );
    expect(metrics.nodeUsage['b']!.cpuCores, closeTo(0.5, 1e-9));

    final h = MetricsHistory();
    h.recordCluster(metrics);
    h.recordCluster(metrics);
    expect(h.series(MetricsHistory.clusterCpu), [closeTo(0.75, 1e-9), closeTo(0.75, 1e-9)]);
    expect(h.series(MetricsHistory.nodeMem('a')), [1073741824.0, 1073741824.0]);
  });

  test('nothing is recorded when metrics-server is missing', () {
    final h = MetricsHistory();
    h.recordCluster(ClusterMetrics.fromLists(nodeList: {'items': []}, nodeMetricsList: null));
    expect(h.series(MetricsHistory.clusterCpu), isEmpty);
  });

  test('parsePodMetricsList sums containers per pod', () {
    final pods = K8sClientService.parsePodMetricsList({
      'items': [
        {
          'metadata': {'name': 'web-1', 'namespace': 'shop'},
          'containers': [
            {'usage': {'cpu': '100m', 'memory': '64Mi'}},
            {'usage': {'cpu': '50m', 'memory': '16Mi'}},
          ],
        },
      ],
    });
    expect(pods.keys, ['shop/web-1']);
    expect(pods['shop/web-1']!.cpuCores, closeTo(0.15, 1e-9));
    expect(pods['shop/web-1']!.memBytes, 80 * 1048576.0);

    final h = MetricsHistory()..recordPods(pods);
    expect(h.series(MetricsHistory.podCpu('shop', 'web-1')), [closeTo(0.15, 1e-9)]);
  });

  test('the sampler fills the history and starts over on a new cluster', () async {
    final sampler = MetricsSampler(interval: const Duration(hours: 1));
    final demo = K8sClientService(baseUrl: 'https://demo.k8s.local');
    sampler.bind(demo, 'default');
    await sampler.poll();
    await sampler.poll();
    expect(sampler.history.series(MetricsHistory.clusterCpu), hasLength(2));
    expect(sampler.latest!.metricsAvailable, isTrue);

    sampler.bind(K8sClientService(baseUrl: 'https://demo.k8s.local'), 'default');
    expect(sampler.history.series(MetricsHistory.clusterCpu), isEmpty);
    sampler.dispose();
  });
}
