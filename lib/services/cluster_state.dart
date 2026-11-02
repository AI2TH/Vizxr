import 'package:flutter/material.dart';
import 'kubeconfig.dart';
import 'k8s_client.dart';

class ClusterState extends ChangeNotifier {
  KubeConfig? _activeConfig;
  late K8sClientService _activeClient;
  List<KubeConfig> _availableConfigs = [];
  String _currentNamespace = 'all-namespaces';
  List<String> _namespaces = ['all-namespaces', 'default', 'kube-system', 'database', 'production', 'monitoring'];
  bool _isLiveConnected = false;

  KubeConfig? get activeConfig => _activeConfig;
  K8sClientService get client => _activeClient;
  List<KubeConfig> get availableConfigs => _availableConfigs;
  String get currentNamespace => _currentNamespace;
  List<String> get namespaces => _namespaces;
  bool get isLiveConnected => _isLiveConnected;

  ClusterState() {
    _initDefaultClient();
    refreshConfigs();
  }

  void _initDefaultClient() {
    _activeClient = K8sClientService(baseUrl: 'https://127.0.0.1:6443');
  }

  Future<void> refreshConfigs() async {
    _availableConfigs = await KubeConfig.loadConfigs();
    if (_availableConfigs.isNotEmpty) {
      if (_activeConfig == null || !_availableConfigs.any((c) => c.name == _activeConfig!.name)) {
        _activeConfig = _availableConfigs.first;
      }
    }
    _initClient();
    await _checkLiveConnection();
    notifyListeners();
  }

  void _initClient() {
    final server = _activeConfig?.server ?? 'https://127.0.0.1:6443';
    final token = _activeConfig?.token;
    final caCert = _activeConfig?.caCert;
    final clientCert = _activeConfig?.clientCertData;
    final clientKey = _activeConfig?.clientKeyData;
    final insecure = _activeConfig?.insecureSkipTlsVerify ?? true;

    _activeClient = K8sClientService(
      baseUrl: server,
      token: token,
      caCertData: caCert,
      clientCertData: clientCert,
      clientKeyData: clientKey,
      insecureSkipTlsVerify: insecure,
    );
  }

  Future<void> _checkLiveConnection() async {
    try {
      _isLiveConnected = await _activeClient.testConnection();
      if (_isLiveConnected) {
        final nsList = await _activeClient.fetchNamespaces();
        if (nsList.isNotEmpty) {
          _namespaces = nsList;
        }
      }
    } catch (_) {
      _isLiveConnected = false;
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
    notifyListeners();
  }

  Future<void> addConfig(KubeConfig config) async {
    await KubeConfig.saveConfig(config);
    await refreshConfigs();
    await setConfig(config);
  }

  Future<void> deleteConfig(String name) async {
    await KubeConfig.deleteConfig(name);
    if (_activeConfig?.name == name) {
      _activeConfig = null;
    }
    await refreshConfigs();
  }

  Future<ManifestApplyResult> applyManifest(String yamlOrJson) async {
    final result = await _activeClient.applyManifest(yamlOrJson, targetNamespace: _currentNamespace);
    notifyListeners();
    return result;
  }

  void triggerReload() {
    notifyListeners();
  }
}
