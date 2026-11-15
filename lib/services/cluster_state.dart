import 'package:flutter/material.dart';
import 'kubeconfig.dart';
import 'k8s_client.dart';
import 'metrics_history.dart';
import 'port_forward_service.dart';

class ClusterState extends ChangeNotifier {
  KubeConfig? _activeConfig;
  late K8sClientService _activeClient;
  List<KubeConfig> _availableConfigs = [];
  String _currentNamespace = 'all-namespaces';
  List<String> _namespaces = ['all-namespaces', 'default', 'kube-system', 'database', 'production', 'monitoring'];
  bool _isLiveConnected = false;

  /// Polls metrics-server for the active cluster and keeps a short history
  /// per node and pod for the sparklines.
  final MetricsSampler metrics = MetricsSampler();

  KubeConfig? get activeConfig => _activeConfig;
  K8sClientService get client => _activeClient;
  List<KubeConfig> get availableConfigs => _availableConfigs;
  String get currentNamespace => _currentNamespace;
  List<String> get namespaces => _namespaces;
  bool get isLiveConnected => _isLiveConnected;
  bool get isDemo => _activeClient.isDemo;

  ClusterState() {
    _initDefaultClient();
    refreshConfigs();
  }

  void _initDefaultClient() {
    _activeClient = K8sClientService(baseUrl: 'https://127.0.0.1:6443', isDemo: false);
    metrics.bind(_activeClient, _currentNamespace);
  }

  Future<void> refreshConfigs() async {
    _availableConfigs = await KubeConfig.loadConfigs();
    if (_availableConfigs.isNotEmpty) {
      final activeId = _activeConfig?.id;
      _activeConfig = _availableConfigs.firstWhere(
        (c) => c.id == activeId,
        orElse: () => _availableConfigs.first,
      );
    }
    _initClient();
    await _checkLiveConnection();
    notifyListeners();
  }

  void _initClient() {
    final server = _activeConfig?.server ?? 'https://127.0.0.1:6443';
    // Decide demo mode from the server URL only: a real cluster named
    // "demo-prod" must not be replaced by mock data.
    final isDemo = K8sClientService.isDemoServer(server);
    final token = _activeConfig?.token;
    final caCert = _activeConfig?.caCert;
    final clientCert = _activeConfig?.clientCertData;
    final clientKey = _activeConfig?.clientKeyData;
    final insecure = _activeConfig?.insecureSkipTlsVerify ?? false;

    // Tunnels use the old client's credentials; stop them with it.
    PortForwardService.stopAll();
    _activeClient.close();
    _activeClient = K8sClientService(
      baseUrl: server,
      token: token,
      caCertData: caCert,
      clientCertData: clientCert,
      clientKeyData: clientKey,
      insecureSkipTlsVerify: insecure,
      fallbackBaseUrls: _activeConfig?.fallbackServers ?? const [],
      isDemo: isDemo,
    );
    metrics.bind(_activeClient, _currentNamespace);
  }

  Future<void> _checkLiveConnection() async {
    try {
      if (_activeClient.isDemo) {
        _isLiveConnected = true;
        _namespaces = ['all-namespaces', 'default', 'kube-system', 'database', 'production', 'monitoring'];
        return;
      }
      _isLiveConnected = await _activeClient.testConnection();
      if (_isLiveConnected) {
        final nsList = await _activeClient.fetchNamespaces();
        if (nsList.isNotEmpty) {
          _namespaces = nsList;
        }
      } else {
        _namespaces = ['all-namespaces', 'default'];
      }
    } catch (_) {
      _isLiveConnected = false;
      _namespaces = ['all-namespaces', 'default'];
    }
  }

  Future<void> setConfig(KubeConfig config) async {
    _activeConfig = config;
    _initClient();
    await _checkLiveConnection();
    notifyListeners();
  }

  void setNamespace(String namespace) {
    _currentNamespace = namespace;
    metrics.bind(_activeClient, namespace);
    notifyListeners();
  }

  /// Saves a new cluster and connects to it. A name already used by another
  /// cluster gets a " (2)" suffix; rename it from the edit screen.
  Future<void> addConfig(KubeConfig config) async {
    final existing = await KubeConfig.loadConfigs();
    final taken = existing.where((c) => c.id != config.id).map((c) => c.name);
    final toSave = config.copyWith(name: KubeConfig.uniqueName(config.name, taken));
    await KubeConfig.saveConfig(toSave);
    _activeConfig = toSave;
    await refreshConfigs();
  }

  /// Saves changes to an existing cluster. Reconnects when it is the active one.
  Future<void> updateConfig(KubeConfig config) async {
    await KubeConfig.saveConfig(config);
    final wasActive = _activeConfig?.id == config.id;
    _availableConfigs = await KubeConfig.loadConfigs();
    if (wasActive) {
      await setConfig(_availableConfigs.firstWhere((c) => c.id == config.id, orElse: () => config));
    } else {
      notifyListeners();
    }
  }

  Future<void> deleteConfig(String id) async {
    await KubeConfig.deleteConfig(id);
    if (_activeConfig?.id == id) {
      _activeConfig = null;
    }
    await refreshConfigs();
  }

  Future<ManifestApplyResult> applyManifest(String yamlOrJson, {bool forceConflicts = false}) async {
    final result = await _activeClient.applyManifest(
      yamlOrJson,
      targetNamespace: _currentNamespace,
      forceConflicts: forceConflicts,
    );
    notifyListeners();
    return result;
  }

  void triggerReload() {
    notifyListeners();
  }
}
