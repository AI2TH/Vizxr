import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<K8sResource>> _future;
  String _filter = 'All';
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _future = clusterState.client.fetchEvents(
        namespace: clusterState.currentNamespace,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: LensTheme.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Cluster Events', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            LensTheme.namespaceBadge(clusterState.currentNamespace, context: context),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: LensTheme.cyanAccent),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: LensTheme.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LensTheme.borderSubtle),
                    ),
                    child: TextField(
                      style: const TextStyle(fontSize: 12, color: LensTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search events...',
                        hintStyle: TextStyle(fontSize: 12, color: LensTheme.textMuted),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: LensTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Severity Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: ['All', 'Warning', 'Normal'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    selectedColor: LensTheme.cyanAccent.withOpacity(0.18),
                    backgroundColor: LensTheme.bgInput,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? LensTheme.cyanAccent : LensTheme.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected ? LensTheme.cyanAccent.withOpacity(0.5) : LensTheme.borderSubtle,
                      width: 0.8,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<K8sResource>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading events: ${snapshot.error}', style: const TextStyle(color: LensTheme.statusRed)),
                  );
                }

                final events = (snapshot.data ?? []).where((e) {
                  if (_filter != 'All' && e.status != _filter) return false;
                  if (_searchQuery.isNotEmpty) {
                    final match = e.name.toLowerCase().contains(_searchQuery) ||
                        (e.message ?? '').toLowerCase().contains(_searchQuery) ||
                        e.namespace.toLowerCase().contains(_searchQuery);
                    if (!match) return false;
                  }
                  return true;
                }).toList();

                if (events.isEmpty) {
                  return const Center(
                    child: Text('No cluster events match your filters.', style: TextStyle(color: LensTheme.textMuted, fontSize: 13)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: LensTheme.cyanAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final ev = events[index];
                      final isWarning = ev.status == 'Warning';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: LensTheme.cardDecoration(
                          borderColor: isWarning ? LensTheme.statusAmber.withOpacity(0.3) : LensTheme.borderSubtle,
                          radius: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                              size: 18,
                              color: isWarning ? LensTheme.statusAmber : LensTheme.cyanAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ev.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isWarning ? LensTheme.statusAmber : LensTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        ev.age,
                                        style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ev.message ?? '',
                                    style: const TextStyle(fontSize: 12, color: LensTheme.textSecondary, height: 1.3),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      LensTheme.namespaceBadge(ev.namespace, fontSize: 9),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isWarning ? LensTheme.statusAmber.withOpacity(0.12) : LensTheme.statusGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          ev.status,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isWarning ? LensTheme.statusAmber : LensTheme.statusGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
