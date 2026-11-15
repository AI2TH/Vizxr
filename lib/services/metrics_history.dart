import 'dart:async';

import 'package:flutter/foundation.dart';

import 'k8s_client.dart';
import 'k8s_quantity.dart';

/// CPU or memory usage of one pod or node.
typedef UsageSample = ({double cpuCores, double memBytes});

/// The last [capacity] samples of each series: the cluster total, every
/// node and every pod seen by metrics-server.
class MetricsHistory {
  MetricsHistory({this.capacity = 40});

  final int capacity;
  final Map<String, List<double>> _series = {};

  static const String clusterCpu = 'cluster/cpu';
  static const String clusterMem = 'cluster/mem';
  static String nodeCpu(String node) => 'node/$node/cpu';
  static String nodeMem(String node) => 'node/$node/mem';
  static String podCpu(String namespace, String pod) => 'pod/$namespace/$pod/cpu';
  static String podMem(String namespace, String pod) => 'pod/$namespace/$pod/mem';

  void add(String key, double value) {
    final list = _series.putIfAbsent(key, () => []);
    list.add(value);
    if (list.length > capacity) list.removeRange(0, list.length - capacity);
  }

  /// Oldest first. Empty when nothing was recorded.
  List<double> series(String key) => List.unmodifiable(_series[key] ?? const <double>[]);

  /// Records the cluster total and each node, when metrics are available.
  void recordCluster(ClusterMetrics metrics) {
    if (!metrics.metricsAvailable) return;
    add(clusterCpu, metrics.cpuUsageCores!);
    add(clusterMem, metrics.memUsageBytes!);
    metrics.nodeUsage.forEach((node, usage) {
      add(nodeCpu(node), usage.cpuCores);
      add(nodeMem(node), usage.memBytes);
    });
  }

  /// Records pods keyed by "namespace/name".
  void recordPods(Map<String, UsageSample> pods) {
    pods.forEach((key, usage) {
      final slash = key.indexOf('/');
      if (slash <= 0) return;
      final ns = key.substring(0, slash);
      final name = key.substring(slash + 1);
      add(podCpu(ns, name), usage.cpuCores);
      add(podMem(ns, name), usage.memBytes);
    });
  }

  void clear() => _series.clear();
}

/// Polls metrics-server while at least one screen uses it, and keeps the
/// history across screens. Owned by `ClusterState`; screens call [acquire]
/// when they appear and [release] when they go away.
class MetricsSampler extends ChangeNotifier {
  MetricsSampler({this.interval = const Duration(seconds: 15), int capacity = 40})
      : history = MetricsHistory(capacity: capacity);

  final Duration interval;
  final MetricsHistory history;

  ClusterMetrics? latest;
  Object? error;
  bool loading = true;

  K8sClientService? _client;
  String _namespace = 'all-namespaces';
  int _users = 0;
  Timer? _timer;
  K8sClientService? _inFlight;

  /// Points the sampler at a cluster and namespace. A new cluster starts a
  /// new history.
  void bind(K8sClientService client, String namespace) {
    final newClient = !identical(client, _client);
    _client = client;
    _namespace = namespace;
    if (newClient) {
      history.clear();
      latest = null;
      error = null;
      loading = true;
      if (_users > 0) _restart();
    }
  }

  void acquire() {
    _users++;
    if (_users == 1) _restart();
  }

  void release() {
    if (_users > 0) _users--;
    if (_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _restart() {
    _timer?.cancel();
    poll();
    _timer = Timer.periodic(interval, (_) => poll());
  }

  /// Adds a sample taken elsewhere (for example when a pod is opened).
  void recordPod(String namespace, String pod, UsageSample usage) {
    history.add(MetricsHistory.podCpu(namespace, pod), usage.cpuCores);
    history.add(MetricsHistory.podMem(namespace, pod), usage.memBytes);
    notifyListeners();
  }

  /// Takes one sample now.
  Future<void> poll() async {
    final client = _client;
    if (client == null || identical(client, _inFlight)) return;
    _inFlight = client;
    try {
      final metrics = await client.fetchClusterMetrics();
      if (!identical(client, _client)) return;
      latest = metrics;
      error = null;
      history.recordCluster(metrics);
      if (metrics.metricsAvailable) {
        final pods = await client.fetchPodMetricsList(namespace: _namespace);
        if (identical(client, _client) && pods != null) history.recordPods(pods);
      }
    } catch (e) {
      if (identical(client, _client)) error = e;
    } finally {
      if (identical(client, _inFlight)) _inFlight = null;
      if (identical(client, _client)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
