import 'package:flutter/material.dart';
import '../services/k8s_client.dart';

class ResourceCard extends StatelessWidget {
  final K8sResource resource;
  final VoidCallback onTap;
  final Function(String) onAction;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
    required this.onAction,
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
        statusLower.contains('waiting');
    final bool isError = statusLower.contains('crash') ||
        statusLower.contains('error') ||
        statusLower.contains('fail') ||
        statusLower.contains('backoff');

    Color statusColor = Colors.grey;
    if (isHealthy) statusColor = Colors.greenAccent;
    if (isWarning) statusColor = Colors.orangeAccent;
    if (isError) statusColor = Colors.redAccent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 9, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resource.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: onAction,
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[
                        const PopupMenuItem(value: 'yaml', child: Text('View / Edit YAML')),
                      ];
                      if (resource.type == K8sResourceType.pod) {
                        items.add(const PopupMenuItem(value: 'logs', child: Text('View Logs')));
                        items.add(const PopupMenuItem(value: 'exec', child: Text('Shell (Exec)')));
                      }
                      if (resource.type == K8sResourceType.job) {
                        items.add(const PopupMenuItem(value: 'logs', child: Text('View Logs')));
                      }
                      if (resource.type == K8sResourceType.deployment) {
                        items.add(const PopupMenuItem(value: 'scale', child: Text('Scale Replicas')));
                        items.add(const PopupMenuItem(value: 'restart', child: Text('Restart Rollout')));
                      }
                      items.add(const PopupMenuDivider());
                      items.add(const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ));
                      return items;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (resource.namespace != 'none') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        resource.namespace,
                        style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    resource.age,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  if (resource.restarts > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${resource.restarts} restarts)',
                      style: const TextStyle(fontSize: 10, color: Colors.orangeAccent),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    resource.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              if (resource.nodeName != null || resource.ip != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (resource.ip != null)
                      Text(
                        'IP: ${resource.ip}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    if (resource.ip != null && resource.nodeName != null)
                      Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    if (resource.nodeName != null)
                      Text(
                        'Node: ${resource.nodeName}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ],
              if (resource.cpuUsage > 0 || resource.memUsage > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniMetric('CPU', resource.cpuUsage, Colors.blueAccent),
                    const SizedBox(width: 12),
                    _buildMiniMetric('MEM', (resource.memUsage / 1024).clamp(0.0, 1.0), Colors.purpleAccent),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.grey[800],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
