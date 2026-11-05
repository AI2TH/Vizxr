import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/cluster_state.dart';
import 'theme/lens_theme.dart';
import 'widgets/cluster_drawer.dart';
import 'screens/cluster_screen.dart';
import 'screens/workloads_screen.dart';
import 'screens/networking_screen.dart';
import 'screens/config_screen.dart';
import 'screens/crd_screen.dart';
import 'screens/events_screen.dart';
import 'screens/yaml_editor_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClusterState()),
      ],
      child: const VizxrApp(),
    ),
  );
}

class VizxrApp extends StatelessWidget {
  const VizxrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vizxr — Kubernetes IDE',
      debugShowCheckedModeBanner: false,
      theme: LensTheme.themeData,
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
  int _selectedIndex = 0; // Default to Dashboard (Cluster Overview)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<Widget> _screens = [
    ClusterScreen(),
    WorkloadsScreen(),
    NetworkingScreen(),
    ConfigScreen(),
    CrdScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final activeConfig = clusterState.activeConfig;
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    Color beaconColor = LensTheme.statusRed;
    String statusText = 'Offline';
    if (isDemo) {
      beaconColor = LensTheme.purpleAccent;
      statusText = 'Demo';
    } else if (isLive) {
      beaconColor = LensTheme.statusGreen;
      statusText = 'Live';
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: LensTheme.bgDark,
      drawer: const ClusterDrawer(),
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: LensTheme.cyanAccent),
          tooltip: 'Clusters Switcher',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: InkWell(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: '$statusText: ${activeConfig?.name ?? "Vizxr"}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: LensTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LensTheme.borderSubtle, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: beaconColor,
                      boxShadow: [
                        BoxShadow(
                          color: beaconColor.withOpacity(0.8),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      activeConfig?.name ?? 'Vizxr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: LensTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: LensTheme.textMuted),
                ],
              ),
            ),
          ),
        ),
        actions: [
          // Quick YAML Manifest Launcher
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 20, color: LensTheme.cyanAccent),
            tooltip: 'Apply YAML Manifest',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const YamlEditorScreen(
                    resourceName: 'New Resource',
                    initialYaml: '''apiVersion: v1
kind: Pod
metadata:
  name: quick-pod
  namespace: default
spec:
  containers:
  - name: web
    image: nginx:alpine
''',
                  ),
                ),
              );
            },
          ),
          // Events Feed Bell
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 20, color: LensTheme.textSecondary),
            tooltip: 'Cluster Events',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Lens Global Namespace Scope Bar
          _buildNamespaceScopeBar(context, clusterState),
          // Active Screen Stack
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: LensTheme.bgSurface,
          border: Border(top: BorderSide(color: LensTheme.borderSubtle)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          indicatorColor: LensTheme.cyanAccent.withOpacity(0.18),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 20, color: LensTheme.textMuted),
              selectedIcon: Icon(Icons.dashboard_rounded, size: 20, color: LensTheme.cyanAccent),
              label: 'Cluster',
            ),
            NavigationDestination(
              icon: Icon(Icons.layers_outlined, size: 20, color: LensTheme.textMuted),
              selectedIcon: Icon(Icons.layers_rounded, size: 20, color: LensTheme.cyanAccent),
              label: 'Workloads',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined, size: 20, color: LensTheme.textMuted),
              selectedIcon: Icon(Icons.hub_rounded, size: 20, color: LensTheme.cyanAccent),
              label: 'Network',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined, size: 20, color: LensTheme.textMuted),
              selectedIcon: Icon(Icons.tune_rounded, size: 20, color: LensTheme.cyanAccent),
              label: 'Config',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined, size: 20, color: LensTheme.textMuted),
              selectedIcon: Icon(Icons.extension_rounded, size: 20, color: LensTheme.purpleAccent),
              label: 'CRDs',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamespaceScopeBar(BuildContext context, ClusterState clusterState) {
    final ns = clusterState.currentNamespace;
    final isAll = ns == 'all-namespaces';

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: LensTheme.bgSurface,
        border: Border(bottom: BorderSide(color: LensTheme.borderSubtle, width: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 14, color: LensTheme.textMuted),
          const SizedBox(width: 6),
          const Text(
            'SCOPE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: LensTheme.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => LensTheme.showNamespacePicker(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LensTheme.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAll ? LensTheme.purpleAccent.withOpacity(0.4) : LensTheme.cyanAccent.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAll ? Icons.auto_awesome_rounded : Icons.layers_rounded,
                          size: 13,
                          color: isAll ? LensTheme.purpleAccent : LensTheme.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAll ? 'All Namespaces (Cluster-wide)' : ns,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAll ? LensTheme.purpleAccent : LensTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 14,
                      color: isAll ? LensTheme.purpleAccent : LensTheme.cyanAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
