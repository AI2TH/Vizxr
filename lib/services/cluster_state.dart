import 'package:flutter/material.dart';
import 'kubeconfig.dart';

class ClusterState extends ChangeNotifier {
  KubeConfig? _activeConfig;
  List<KubeConfig> _availableConfigs = [];
  String _currentNamespace = 'all-namespaces';
  final List<String> _namespaces = ['all-namespaces', 'default', 'kube-system', 'database', 'production'];

  KubeConfig? get activeConfig => _activeConfig;
  List<KubeConfig> get availableConfigs => _availableConfigs;
  String get currentNamespace => _currentNamespace;
  List<String> get namespaces => _namespaces;

  ClusterState() {
    refreshConfigs();
  }

  Future<void> refreshConfigs() async {
    _availableConfigs = await KubeConfig.loadConfigs();
    if (_availableConfigs.isNotEmpty && _activeConfig == null) {
      _activeConfig = _availableConfigs.first;
    }
    notifyListeners();
  }

  void setConfig(KubeConfig config) {
    _activeConfig = config;
    notifyListeners();
  }

  void setNamespace(String namespace) {
    _currentNamespace = namespace;
    notifyListeners();
  }
}
