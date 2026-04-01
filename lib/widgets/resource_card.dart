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
    final bool isHealthy = resource.status == 'Running' || resource.status == 'Ready' || resource.status.contains('Ready');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: isHealthy ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resource.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit YAML')),
                      const PopupMenuItem(value: 'restart', child: Text('Restart')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      resource.namespace,
                      style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    resource.age,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Text(
                    resource.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isHealthy ? Colors.green[300] : Colors.orange[300],
                    ),
                  ),
                ],
              ),
              if (resource.cpuUsage > 0 || resource.memUsage > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMiniMetric('CPU', resource.cpuUsage, Colors.blue),
                    const SizedBox(width: 12),
                    _buildMiniMetric('MEM', resource.memUsage / 1024, Colors.purple),
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
