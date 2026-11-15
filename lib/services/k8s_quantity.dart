/// Parsing and formatting for Kubernetes `resource.Quantity` strings, such as
/// `250m` (CPU), `1500000n` (CPU from metrics-server) or `512Mi` (memory).
class K8sQuantity {
  K8sQuantity._();

  static const Map<String, double> _multipliers = {
    '': 1,
    // Decimal SI suffixes.
    'n': 1e-9,
    'u': 1e-6,
    'm': 1e-3,
    'k': 1e3,
    'M': 1e6,
    'G': 1e9,
    'T': 1e12,
    'P': 1e15,
    'E': 1e18,
    // Binary suffixes.
    'Ki': 1024,
    'Mi': 1048576,
    'Gi': 1073741824,
    'Ti': 1099511627776,
    'Pi': 1125899906842624,
    'Ei': 1152921504606846976,
  };

  // A number with an optional decimal exponent (1e3, 2.5E-3), then an
  // optional suffix. "1E" (no digits after E) is the exa suffix.
  static final RegExp _pattern = RegExp(r'^([+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)([a-zA-Z]*)$');

  /// Returns the value in base units (cores for CPU, bytes for memory), or
  /// null when [input] is not a valid quantity.
  static double? tryParse(Object? input) {
    if (input == null) return null;
    if (input is num) return input.toDouble();
    final text = input.toString().trim();
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    final multiplier = _multipliers[match.group(2)!];
    if (number == null || multiplier == null) return null;
    return number * multiplier;
  }

  /// Like [tryParse] but throws a [FormatException] for invalid input.
  static double parse(Object? input) {
    final value = tryParse(input);
    if (value == null) throw FormatException('Invalid Kubernetes quantity', input?.toString());
    return value;
  }

  /// Formats cores, for example 0.25 -> "250m" and 1.5 -> "1.50".
  static String formatCores(double cores) {
    if (cores < 1) return '${(cores * 1000).round()}m';
    return cores.toStringAsFixed(2);
  }

  /// Formats bytes in binary units, for example 536870912 -> "512 MiB".
  static String formatBytes(double bytes) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
    var value = bytes;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit >= 3 ? 1 : 0;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}

/// CPU and memory for the whole cluster: allocatable from the nodes, usage
/// from metrics.k8s.io when metrics-server is installed.
class ClusterMetrics {
  final int nodeCount;
  final double cpuAllocatableCores;
  final double memAllocatableBytes;

  /// Null when the metrics API is unavailable.
  final double? cpuUsageCores;
  final double? memUsageBytes;

  /// Why usage is missing, for display. Null when usage is available.
  final String? unavailableReason;

  /// Usage per node name, from the same metrics.k8s.io sample.
  final Map<String, ({double cpuCores, double memBytes})> nodeUsage;

  const ClusterMetrics({
    required this.nodeCount,
    required this.cpuAllocatableCores,
    required this.memAllocatableBytes,
    this.cpuUsageCores,
    this.memUsageBytes,
    this.unavailableReason,
    this.nodeUsage = const {},
  });

  bool get metricsAvailable => cpuUsageCores != null && memUsageBytes != null;

  double get cpuFraction =>
      (cpuUsageCores == null || cpuAllocatableCores <= 0) ? 0 : cpuUsageCores! / cpuAllocatableCores;

  double get memFraction =>
      (memUsageBytes == null || memAllocatableBytes <= 0) ? 0 : memUsageBytes! / memAllocatableBytes;

  /// Sums `status.allocatable` of a NodeList and `usage` of a NodeMetricsList.
  /// Either list may be null; pass null for [nodeMetricsList] when the
  /// metrics API is unavailable.
  factory ClusterMetrics.fromLists({
    required Map<String, dynamic>? nodeList,
    required Map<String, dynamic>? nodeMetricsList,
    String? unavailableReason,
  }) {
    var cpuAlloc = 0.0;
    var memAlloc = 0.0;
    var nodes = 0;
    for (final item in (nodeList?['items'] as List?) ?? const []) {
      if (item is! Map) continue;
      nodes++;
      final allocatable = (item['status'] is Map) ? (item['status'] as Map)['allocatable'] : null;
      if (allocatable is Map) {
        cpuAlloc += K8sQuantity.tryParse(allocatable['cpu']) ?? 0;
        memAlloc += K8sQuantity.tryParse(allocatable['memory']) ?? 0;
      }
    }

    double? cpuUse;
    double? memUse;
    final perNode = <String, ({double cpuCores, double memBytes})>{};
    final metricsItems = nodeMetricsList?['items'] as List?;
    if (metricsItems != null) {
      var cpuSum = 0.0;
      var memSum = 0.0;
      for (final item in metricsItems) {
        if (item is! Map || item['usage'] is! Map) continue;
        final usage = item['usage'] as Map;
        final cpu = K8sQuantity.tryParse(usage['cpu']) ?? 0;
        final mem = K8sQuantity.tryParse(usage['memory']) ?? 0;
        cpuSum += cpu;
        memSum += mem;
        final name = item['metadata'] is Map ? (item['metadata'] as Map)['name']?.toString() : null;
        if (name != null) perNode[name] = (cpuCores: cpu, memBytes: mem);
      }
      cpuUse = cpuSum;
      memUse = memSum;
    }

    return ClusterMetrics(
      nodeCount: nodes,
      cpuAllocatableCores: cpuAlloc,
      memAllocatableBytes: memAlloc,
      cpuUsageCores: cpuUse,
      memUsageBytes: memUse,
      unavailableReason: metricsItems == null ? (unavailableReason ?? 'Metrics unavailable') : null,
      nodeUsage: perNode,
    );
  }
}
