import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

class KubeConfig {
  final String name;
  final String server;
  final String? token;
  final String? caCert;
  final String defaultNamespace;
  final bool insecureSkipTlsVerify;

  KubeConfig({
    required this.name,
    required this.server,
    this.token,
    this.caCert,
    this.defaultNamespace = 'default',
    this.insecureSkipTlsVerify = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'server': server,
    'token': token,
    'caCert': caCert,
    'defaultNamespace': defaultNamespace,
    'insecureSkipTlsVerify': insecureSkipTlsVerify,
  };

  factory KubeConfig.fromJson(Map<String, dynamic> json) => KubeConfig(
    name: json['name'] ?? 'Cluster',
    server: json['server'] ?? 'https://127.0.0.1:6443',
    token: json['token'],
    caCert: json['caCert'],
    defaultNamespace: json['defaultNamespace'] ?? 'default',
    insecureSkipTlsVerify: json['insecureSkipTlsVerify'] ?? true,
  );

  static const String _storageKey = 'vizxr_kubeconfigs';

  static Future<void> saveConfig(KubeConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList(_storageKey) ?? [];
    
    // Remove existing config with same name if any
    configs.removeWhere((s) {
      try {
        final map = jsonDecode(s);
        return map['name'] == config.name;
      } catch (_) {
        return false;
      }
    });

    configs.add(jsonEncode(config.toJson()));
    await prefs.setStringList(_storageKey, configs);
  }

  static Future<void> deleteConfig(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList(_storageKey) ?? [];
    configs.removeWhere((s) {
      try {
        final map = jsonDecode(s);
        return map['name'] == name;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_storageKey, configs);
  }

  static Future<KubeConfig> addFromYaml(String yamlString) async {
    try {
      final doc = loadYaml(yamlString);
      if (doc is! Map) {
        throw FormatException('Kubeconfig must be a YAML mapping');
      }

      String clusterName = 'Imported Cluster';
      String serverUrl = 'https://127.0.0.1:6443';
      String? token;
      String? caCert;
      String defaultNs = 'default';

      // Find current-context
      final currentContext = doc['current-context']?.toString();
      Map? activeContextMap;

      if (doc['contexts'] is List) {
        final contexts = doc['contexts'] as List;
        for (final ctx in contexts) {
          if (ctx is Map) {
            if (currentContext != null && ctx['name']?.toString() == currentContext) {
              activeContextMap = ctx['context'] as Map?;
              clusterName = currentContext;
              break;
            }
          }
        }
        if (activeContextMap == null && contexts.isNotEmpty && contexts.first is Map) {
          final first = contexts.first as Map;
          activeContextMap = first['context'] as Map?;
          clusterName = first['name']?.toString() ?? clusterName;
        }
      }

      final targetClusterName = activeContextMap?['cluster']?.toString();
      final targetUserName = activeContextMap?['user']?.toString();
      if (activeContextMap?['namespace'] != null) {
        defaultNs = activeContextMap!['namespace'].toString();
      }

      // Find cluster server
      if (doc['clusters'] is List) {
        for (final c in doc['clusters'] as List) {
          if (c is Map) {
            final cName = c['name']?.toString();
            final cMap = c['cluster'] as Map?;
            if (targetClusterName == null || cName == targetClusterName) {
              if (cMap != null) {
                serverUrl = cMap['server']?.toString() ?? serverUrl;
                caCert = cMap['certificate-authority-data']?.toString();
                if (targetClusterName != null) break;
              }
            }
          }
        }
      }

      // Find user token
      if (doc['users'] is List) {
        for (final u in doc['users'] as List) {
          if (u is Map) {
            final uName = u['name']?.toString();
            final uMap = u['user'] as Map?;
            if (targetUserName == null || uName == targetUserName) {
              if (uMap != null) {
                token = uMap['token']?.toString();
                if (token == null && uMap['client-certificate-data'] != null) {
                  token = uMap['client-certificate-data']?.toString();
                }
                if (targetUserName != null) break;
              }
            }
          }
        }
      }

      final config = KubeConfig(
        name: clusterName,
        server: serverUrl,
        token: token,
        caCert: caCert,
        defaultNamespace: defaultNs,
        insecureSkipTlsVerify: true,
      );

      await saveConfig(config);
      return config;
    } catch (e) {
      throw 'Failed to parse Kubeconfig YAML: $e';
    }
  }

  static Future<List<KubeConfig>> loadConfigs() async {
    final List<KubeConfig> configs = [];
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList(_storageKey);

    if (stored != null && stored.isNotEmpty) {
      for (final s in stored) {
        try {
          configs.add(KubeConfig.fromJson(jsonDecode(s)));
        } catch (_) {}
      }
    }

    // Always ensure the local Linxr / Kubxr cluster is available
    final hasLocal = configs.any((c) => c.server.contains('127.0.0.1:6443'));
    if (!hasLocal) {
      configs.insert(0, KubeConfig(
        name: 'Linxr Local Cluster',
        server: 'https://127.0.0.1:6443',
        defaultNamespace: 'default',
        insecureSkipTlsVerify: true,
      ));
    }

    // Always ensure Demo Simulator Cluster is available for offline testing
    final hasDemo = configs.any((c) => c.name == 'Demo Cluster (Simulation)');
    if (!hasDemo) {
      configs.add(KubeConfig(
        name: 'Demo Cluster (Simulation)',
        server: 'https://demo.k8s.local',
        defaultNamespace: 'default',
        insecureSkipTlsVerify: true,
      ));
    }

    return configs;
  }
}
