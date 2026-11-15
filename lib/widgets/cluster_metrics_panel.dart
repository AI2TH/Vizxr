import 'dart:async';

import 'package:flutter/material.dart';

import '../services/k8s_client.dart';
import '../services/k8s_quantity.dart';
import '../theme/lens_theme.dart';
import 'sparkline_chart.dart';

/// Cluster CPU and memory gauges backed by metrics-server.
///
/// Polls [K8sClientService.fetchClusterMetrics] every [interval] while the
/// widget is mounted and keeps the last [historyLength] samples for the
/// sparklines. Shows "Metrics unavailable" when metrics-server is missing.
class ClusterMetricsPanel extends StatefulWidget {
  final K8sClientService client;
  final Duration interval;
  final int historyLength;

  const ClusterMetricsPanel({
    super.key,
    required this.client,
    this.interval = const Duration(seconds: 15),
    this.historyLength = 20,
  });

  @override
  State<ClusterMetricsPanel> createState() => _ClusterMetricsPanelState();
}

class _ClusterMetricsPanelState extends State<ClusterMetricsPanel> {
  Timer? _timer;
  ClusterMetrics? _latest;
  Object? _error;
  bool _loading = true;
  final List<double> _cpuHistory = [];
  final List<double> _memHistory = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant ClusterMetricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client || oldWidget.interval != widget.interval) {
      _timer?.cancel();
      _cpuHistory.clear();
      _memHistory.clear();
      _latest = null;
      _error = null;
      _loading = true;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _poll();
    _timer = Timer.periodic(widget.interval, (_) => _poll());
  }

  Future<void> _poll() async {
    final client = widget.client;
    try {
      final metrics = await client.fetchClusterMetrics();
      if (!mounted || client != widget.client) return;
      setState(() {
        _latest = metrics;
        _error = null;
        _loading = false;
        if (metrics.metricsAvailable) {
          _cpuHistory.add(metrics.cpuUsageCores!);
          _memHistory.add(metrics.memUsageBytes!);
          while (_cpuHistory.length > widget.historyLength) {
            _cpuHistory.removeAt(0);
          }
          while (_memHistory.length > widget.historyLength) {
            _memHistory.removeAt(0);
          }
        }
      });
    } catch (e) {
      if (!mounted || client != widget.client) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _latest;

    if (_loading && metrics == null) {
      return Container(
        height: 120,
        decoration: LensTheme.cardDecoration(radius: 14),
        child: const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent)),
      );
    }

    if (metrics == null || !metrics.metricsAvailable) {
      final reason = metrics?.unavailableReason ?? 'Metrics unavailable: $_error';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: LensTheme.cardDecoration(
          borderColor: LensTheme.statusAmber.withOpacity(0.35),
          radius: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights_rounded, size: 20, color: LensTheme.statusAmber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                  ),
                  if (metrics != null && metrics.nodeCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Allocatable: ${K8sQuantity.formatCores(metrics.cpuAllocatableCores)} cores, '
                      '${K8sQuantity.formatBytes(metrics.memAllocatableBytes)} across ${metrics.nodeCount} node(s)',
                      style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'CPU and memory usage come from metrics-server (metrics.k8s.io). k3s ships it by default.',
                    style: TextStyle(fontSize: 11, color: LensTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildGauge(
            title: 'Cluster CPU',
            usageText: '${K8sQuantity.formatCores(metrics.cpuUsageCores!)} / '
                '${K8sQuantity.formatCores(metrics.cpuAllocatableCores)} cores',
            fraction: metrics.cpuFraction,
            gradient: LensTheme.cyanGradient,
            icon: Icons.speed_rounded,
            history: _cpuHistory,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildGauge(
            title: 'Cluster Memory',
            usageText: '${K8sQuantity.formatBytes(metrics.memUsageBytes!)} / '
                '${K8sQuantity.formatBytes(metrics.memAllocatableBytes)}',
            fraction: metrics.memFraction,
            gradient: LensTheme.purpleGradient,
            icon: Icons.memory_rounded,
            history: _memHistory,
          ),
        ),
      ],
    );
  }

  Widget _buildGauge({
    required String title,
    required String usageText,
    required double fraction,
    required LinearGradient gradient,
    required IconData icon,
    required List<double> history,
  }) {
    final color = gradient.colors.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: LensTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, color: LensTheme.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            usageText,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.08)),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                    child: Container(decoration: BoxDecoration(gradient: gradient)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(fraction * 100).round()}% of allocatable',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          if (history.length >= 2) ...[
            const SizedBox(height: 6),
            SparklineChart(
              dataPoints: List<double>.of(history),
              lineColor: color,
              fillColor: color.withOpacity(0.2),
              height: 28,
            ),
          ],
        ],
      ),
    );
  }
}
