import 'package:flutter/material.dart';
import '../services/k8s_client.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final K8sClientService _client = K8sClientService(baseUrl: 'https://127.0.0.1:6443');
  late Future<List<K8sResource>> _future;

  @override
  void initState() {
    super.initState();
    _future = _client.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cluster Events')),
      body: FutureBuilder<List<K8sResource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No events found.'));
          }

          final events = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _client.fetchEvents();
              });
            },
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ev = events[index];
                final isWarning = ev.status == 'Warning';
                return ListTile(
                  leading: Icon(
                    isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: isWarning ? Colors.redAccent : Colors.blueAccent,
                  ),
                  title: Text(ev.message ?? '', style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${ev.name} • ${ev.namespace} • ${ev.age}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
