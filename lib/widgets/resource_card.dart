import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';

class ResourceCard extends StatelessWidget {
  final K8sResource resource;
  final VoidCallback onTap;
  final Function(String action) onAction;
  final Function(int delta)? onScale;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
    required this.onAction,
    this.onScale,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = resource.status.toLowerCase();
    final bool isHealthy = statusLower.contains('running') ||
        statusLower.contains('ready') ||
        statusLower.contains('bound') ||
        statusLower.contains('completed') ||
        statusLower.contains('active');
    final bool isWarning = statusLower.contains('pending') ||
        statusLower.contains('terminating') ||
        statusLower.contains('waiting') ||
        statusLower.contains('containercreating');
    final bool isError = statusLower.contains('crash') ||
        statusLower.contains('error') ||
        statusLower.contains('fail') ||
        statusLower.contains('backoff') ||
        statusLower.contains('notready');

    Color statusColor = LensTheme.textMuted;
    if (isHealthy) statusColor = LensTheme.statusGreen;
    if (isWarning) statusColor = LensTheme.statusAmber;
    if (isError) statusColor = LensTheme.statusRed;

    // Parse replicas for deployment (e.g. "3/3 Ready")
    int? currentReplicas;
    if (resource.type == K8sResourceType.deployment) {
      final parts = resource.status.split('/');
      if (parts.isNotEmpty) {
        currentReplicas = int.tryParse(parts[0].trim());
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: LensTheme.cardDecoration(
        borderColor: statusColor.withOpacity(0.2),
        glow: isError,
        radius: 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: LensTheme.cyanAccent.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.04),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left glowing accent bar
                  Container(
                    width: 4.5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Resource name + Status badge
                          Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resource.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: LensTheme.textPrimary,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  // Namespace & Age row
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (resource.namespace != 'none')
                                        LensTheme.namespaceBadge(resource.namespace),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          resource.age,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: LensTheme.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (resource.restarts > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: LensTheme.statusAmber.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: LensTheme.statusAmber.withOpacity(0.3), width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.refresh_rounded, size: 10, color: LensTheme.statusAmber),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${resource.restarts} restarts',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: LensTheme.statusAmber,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            LensTheme.statusBadge(resource.status),
                          ],
                        ),

                        // Subtitle: Node & IP Pill
                        if (resource.ip != null || resource.nodeName != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: LensTheme.bgDark.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: LensTheme.borderSubtle, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (resource.ip != null) ...[
                                  const Icon(Icons.wifi_tethering_rounded, size: 12, color: LensTheme.cyanAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    resource.ip!,
                                    style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary, fontFamily: 'monospace'),
                                  ),
                                ],
                                if (resource.ip != null && resource.nodeName != null)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('•', style: TextStyle(fontSize: 11, color: LensTheme.textMuted)),
                                  ),
                                if (resource.nodeName != null) ...[
                                  const Icon(Icons.dns_rounded, size: 12, color: LensTheme.blueAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    resource.nodeName!,
                                    style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: LensTheme.borderSubtle),
                        const SizedBox(height: 8),

                        // Direct Action Bar (Lens-style Tools)
                        Row(
                          children: [
                            if (resource.type == K8sResourceType.pod) ...[
                              _buildActionButton(
                                icon: Icons.terminal_rounded,
                                label: 'Logs',
                                color: LensTheme.cyanAccent,
                                onTap: () => onAction('logs'),
                              ),
                              const SizedBox(width: 6),
                              _buildActionButton(
                                icon: Icons.code_rounded,
                                label: 'Exec',
                                color: LensTheme.blueAccent,
                                onTap: () => onAction('exec'),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (resource.type == K8sResourceType.deployment) ...[
                              if (onScale != null) ...[
                                _buildScaleStepper(currentReplicas ?? 1),
                                const SizedBox(width: 8),
                              ],
                              _buildActionButton(
                                icon: Icons.restart_alt_rounded,
                                label: 'Restart',
                                color: LensTheme.purpleAccent,
                                onTap: () => onAction('restart'),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (resource.type == K8sResourceType.service) ...[
                              _buildActionButton(
                                icon: Icons.forward_to_inbox_rounded,
                                label: 'Port Forward',
                                color: LensTheme.cyanAccent,
                                onTap: () => onAction('portforward'),
                              ),
                              const SizedBox(width: 6),
                            ],
                            _buildActionButton(
                              icon: Icons.article_outlined,
                              label: 'YAML',
                              color: LensTheme.textSecondary,
                              onTap: () => onAction('yaml'),
                            ),
                            const Spacer(),
                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: LensTheme.statusRed),
                              tooltip: 'Delete Resource',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => onAction('delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleStepper(int replicas) {
    return Container(
      decoration: BoxDecoration(
        color: LensTheme.bgDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LensTheme.borderSubtle, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (onScale != null && replicas > 0) onScale!(-1);
            },
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 13, color: LensTheme.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$replicas',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LensTheme.cyanAccent),
            ),
          ),
          InkWell(
            onTap: () {
              if (onScale != null) onScale!(1);
            },
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 13, color: LensTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
