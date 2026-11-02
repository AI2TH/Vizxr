import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/cluster_state.dart';
import 'widgets/cluster_drawer.dart';
import 'screens/workloads_screen.dart';
import 'screens/networking_screen.dart';
import 'screens/storage_screen.dart';
import 'screens/events_screen.dart';
import 'screens/config_screen.dart';
import 'screens/cluster_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClusterState()),
      ],
      child: const K8sConsoleApp(),
    ),
  );
}

class K8sConsoleApp extends StatelessWidget {
  const K8sConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vizxr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        useMaterial3: true,
        textTheme: GoogleFonts.firaCodeTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Default to Workloads

  static const List<Widget> _screens = [
    ClusterScreen(), // Nodes and Cluster Overview
    WorkloadsScreen(), // Pods, Deployments, STS, DaemonSets
    ConfigScreen(), // ConfigMaps, Secrets
    NetworkingScreen(), // Services, Ingress
    StorageScreen(), // PVC, StorageClasses
  ];

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final isLive = clusterState.isLiveConnected;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vizxr', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: isLive ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 5),
                Text(
                  clusterState.activeConfig?.name ?? 'Connecting...',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLive ? Colors.greenAccent : Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            tooltip: 'Cluster Events',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventsScreen()),
              );
            },
          ),
          DropdownButton<String>(
            value: clusterState.namespaces.contains(clusterState.currentNamespace)
                ? clusterState.currentNamespace
                : (clusterState.namespaces.isNotEmpty ? clusterState.namespaces.first : 'all-namespaces'),
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list, size: 20),
            items: clusterState.namespaces.map((String ns) {
              return DropdownMenuItem<String>(
                value: ns,
                child: Text(ns, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                clusterState.setNamespace(newValue);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const ClusterDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: Colors.blueAccent.withOpacity(0.2),
        height: 65,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hub_outlined, size: 22), label: 'Cluster'),
          NavigationDestination(icon: Icon(Icons.layers_outlined, size: 22), label: 'Workloads'),
          NavigationDestination(icon: Icon(Icons.settings_input_component, size: 22), label: 'Config'),
          NavigationDestination(icon: Icon(Icons.router_outlined, size: 22), label: 'Network'),
          NavigationDestination(icon: Icon(Icons.storage_outlined, size: 22), label: 'Storage'),
        ],
      ),
    );
  }
}
