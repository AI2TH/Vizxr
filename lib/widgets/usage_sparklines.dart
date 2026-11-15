import 'package:flutter/material.dart';

import '../services/k8s_quantity.dart';
import '../services/metrics_history.dart';
import '../theme/lens_theme.dart';
import 'sparkline_chart.dart';

/// Current CPU and memory of one node or pod with sparklines of the recorded
/// history. Keeps the [sampler] polling while it is on screen.
class UsageSparklines extends StatefulWidget {
  final MetricsSampler sampler;
  final String cpuKey;
  final String memKey;

  /// Shown while no sample has been recorded. Null shows nothing.
  final String? emptyText;
  final bool large;

  const UsageSparklines({
    super.key,
    required this.sampler,
    required this.cpuKey,
    required this.memKey,
    this.emptyText,
    this.large = false,
  });

  @override
  State<UsageSparklines> createState() => _UsageSparklinesState();
}

class _UsageSparklinesState extends State<UsageSparklines> {
  @override
  void initState() {
    super.initState();
    widget.sampler.acquire();
  }

  @override
  void didUpdateWidget(covariant UsageSparklines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sampler != widget.sampler) {
      oldWidget.sampler.release();
      widget.sampler.acquire();
    }
  }

  @override
  void dispose() {
    widget.sampler.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sampler,
      builder: (context, _) {
        final cpu = widget.sampler.history.series(widget.cpuKey);
        final mem = widget.sampler.history.series(widget.memKey);
        if (cpu.isEmpty || mem.isEmpty) {
          final text = widget.emptyText;
          if (text == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: LensTheme.textMuted, fontSize: 12)),
          );
        }
        final seconds = widget.sampler.interval.inSeconds;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(Icons.speed_rounded, 'CPU', K8sQuantity.formatCores(cpu.last), cpu, LensTheme.cyanAccent),
            SizedBox(height: widget.large ? 14 : 8),
            _row(Icons.memory_rounded, 'Memory', K8sQuantity.formatBytes(mem.last), mem, LensTheme.purpleAccent),
            const SizedBox(height: 6),
            Text(
              cpu.length < 2
                  ? 'One sample so far; the trend fills in every ${seconds}s.'
                  : 'Last ${cpu.length} samples, every ${seconds}s, from metrics.k8s.io',
              style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
            ),
          ],
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value, List<double> points, Color color) {
    final header = Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: LensTheme.textSecondary, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (points.length >= 2) ...[
          const SizedBox(height: 4),
          SparklineChart(
            dataPoints: points,
            lineColor: color,
            fillColor: color.withOpacity(0.2),
            height: widget.large ? 50 : 26,
          ),
        ],
      ],
    );
  }
}
