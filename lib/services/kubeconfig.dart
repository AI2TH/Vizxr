import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class KubeConfig {
  final String name;
  final String server;
  final String? token;
  final String? caCert;

  KubeConfig({
    required this.name,
    required this.server,
    this.token,
    this.caCert,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'server': server,
    'token': token,
    'caCert': caCert,
  };

  factory KubeConfig.fromJson(Map<String, dynamic> json) => KubeConfig(
    name: json['name'],
    server: json['server'],
    token: json['token'],
    caCert: json['caCert'],
  );

  static Future<void> saveConfig(KubeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList('kubeconfigs') ?? [];
    configs.add(jsonEncode(config.toJson()));
    await prefs.setStringList('kubeconfigs', configs);
  }

  static Future<void> addFromYaml(String yamlString) async {
    // Basic parser for 'clusters' and 'users' in kubeconfig
    // In a production app, we would use the 'yaml' package
    try {
      // Logic to extract 'server', 'token', and 'name' from YAML
      // For now, we simulate adding a parsed config
      final config = KubeConfig(
        name: 'Imported Cluster',
        server: 'https://aks-cluster-dns.azure.com:443',
        token: 'eyJHbGc...',
      );
      await saveConfig(config);
    } catch (e) {
      throw 'Failed to parse Kubeconfig: $e';
    }
  }

  static Future<List<KubeConfig>> loadConfigs() async {
    final List<KubeConfig> configs = [];
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList('kubeconfigs');

    if (stored != null) {
      configs.addAll(stored.map((s) => KubeConfig.fromJson(jsonDecode(s))));
    }

    // Auto-Discovery: Check if the 'k8s' Node app is running
    try {
      final socket = await Socket.connect('127.0.0.1', 6443, timeout: const Duration(milliseconds: 300));
      socket.destroy();
      configs.add(KubeConfig(
        name: 'Local AI2TH Cluster (Active)',
        server: 'https://127.0.0.1:6443',
      ));
    } catch (_) {}

    return configs;
  }
}
