import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'secret_store.dart';

class KubeConfig {
  final String name;
  final String server;
  final String? token;
  final String? caCert;
  final String? clientCertData;
  final String? clientKeyData;
  final String defaultNamespace;
  final bool insecureSkipTlsVerify;

  KubeConfig({
    required this.name,
    required this.server,
    this.token,
    this.caCert,
    this.clientCertData,
    this.clientKeyData,
    this.defaultNamespace = 'default',
    this.insecureSkipTlsVerify = false,
  });

  KubeConfig copyWith({
    String? name,
    String? server,
    String? token,
    String? caCert,
    String? clientCertData,
    String? clientKeyData,
    String? defaultNamespace,
    bool? insecureSkipTlsVerify,
  }) =>
      KubeConfig(
        name: name ?? this.name,
        server: server ?? this.server,
        token: token ?? this.token,
        caCert: caCert ?? this.caCert,
        clientCertData: clientCertData ?? this.clientCertData,
        clientKeyData: clientKeyData ?? this.clientKeyData,
        defaultNamespace: defaultNamespace ?? this.defaultNamespace,
        insecureSkipTlsVerify: insecureSkipTlsVerify ?? this.insecureSkipTlsVerify,
      );

  /// Everything except the credentials. This is what goes to SharedPreferences.
  Map<String, dynamic> toJson() => {
    'name': name,
    'server': server,
    'caCert': caCert,
    'clientCertData': clientCertData,
    'defaultNamespace': defaultNamespace,
    'insecureSkipTlsVerify': insecureSkipTlsVerify,
  };

  /// The credentials, kept in [secretStore] (Android Keystore) only.
  Map<String, String> secretsJson() => {
    if (token != null && token!.isNotEmpty) 'token': token!,
    if (clientKeyData != null && clientKeyData!.isNotEmpty) 'clientKeyData': clientKeyData!,
  };

  factory KubeConfig.fromJson(Map<String, dynamic> json, {Map? secrets}) => KubeConfig(
    name: json['name'] ?? 'Cluster',
    server: json['server'] ?? 'https://127.0.0.1:6443',
    token: secrets?['token']?.toString() ?? json['token'],
    caCert: json['caCert'],
    clientCertData: json['clientCertData'],
    clientKeyData: secrets?['clientKeyData']?.toString() ?? json['clientKeyData'],
    defaultNamespace: json['defaultNamespace'] ?? 'default',
    insecureSkipTlsVerify: json['insecureSkipTlsVerify'] ?? false,
  );

  static const String _storageKey = 'vizxr_kubeconfigs';

  /// Secure-storage key holding a JSON map of cluster key -> credentials.
  static const String secretsStorageKey = 'vizxr_cluster_secrets';

  /// Where tokens and client keys live. Replace with [MemorySecretStore] in tests.
  static SecretStore secretStore = const SecureSecretStore();

  /// Key that links a config to its entry in the secrets map.
  String get storageKey => name;

  static String? _keyOf(Map map) => map['name']?.toString();

  /// Reads the credentials map, or null when secure storage is unavailable.
  static Future<Map<String, Map<String, dynamic>>?> _readSecrets() async {
    try {
      final raw = await secretStore.read(secretsStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map) e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeSecrets(Map<String, Map<String, dynamic>> secrets) async {
    if (secrets.isEmpty) {
      await secretStore.delete(secretsStorageKey);
    } else {
      await secretStore.write(secretsStorageKey, jsonEncode(secrets));
    }
  }

  static Future<void> saveConfig(KubeConfig config) async {
    // Credentials go to the Keystore first, so a crash between the two writes
    // never leaves a config without its token.
    final secrets = await _readSecrets() ?? {};
    final configSecrets = config.secretsJson();
    if (configSecrets.isEmpty) {
      secrets.remove(config.storageKey);
    } else {
      secrets[config.storageKey] = configSecrets;
    }
    await _writeSecrets(secrets);

    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList(_storageKey) ?? [];

    // Remove existing config with same key if any
    configs.removeWhere((s) {
      try {
        return _keyOf(jsonDecode(s)) == config.storageKey;
      } catch (_) {
        return false;
      }
    });

    configs.add(jsonEncode(config.toJson()));
    await prefs.setStringList(_storageKey, configs);
  }

  static Future<void> deleteConfig(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList(_storageKey) ?? [];
    configs.removeWhere((s) {
      try {
        return _keyOf(jsonDecode(s)) == key;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_storageKey, configs);

    final secrets = await _readSecrets();
    if (secrets != null && secrets.remove(key) != null) {
      await _writeSecrets(secrets);
    }
  }

  static Future<KubeConfig> addFromFilePath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Kubeconfig file not found at path', filePath);
    }
    final content = await file.readAsString();
    return addFromYaml(content);
  }

  static Future<KubeConfig?> autoDetectLinxrKubeconfig() async {
    const candidatePaths = [
      '/sdcard/Download/test_kubeconfig.yaml',
      '/sdcard/Linxr/k3s.yaml',
      '/storage/emulated/0/Linxr/k3s.yaml',
      '/sdcard/kubeconfig',
      '/storage/emulated/0/kubeconfig',
      '/data/data/com.ai2th.linxr/files/k3s.yaml',
    ];

    for (final path in candidatePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          return await addFromYaml(content);
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<KubeConfig> addFromYaml(String yamlString) async {
    try {
      // Strip any trailing non-YAML comments/annotations (e.g. "use this test")
      var cleanedYaml = yamlString.trim();
      final endKeyMatch = cleanedYaml.indexOf('-----END RSA PRIVATE KEY-----');
      if (endKeyMatch != -1) {
        // Keep up to the end of the base64 or PEM boundary
        final afterEnd = cleanedYaml.indexOf('\n', endKeyMatch);
        if (afterEnd != -1) {
          cleanedYaml = cleanedYaml.substring(0, afterEnd).trim();
        }
      }

      final doc = loadYaml(cleanedYaml);
      if (doc is! Map) {
        throw const FormatException('Kubeconfig must be a YAML mapping');
      }

      String clusterName = 'Imported Cluster';
      String serverUrl = 'https://127.0.0.1:6443';
      String? token;
      String? caCert;
      String? clientCert;
      String? clientKey;
      String defaultNs = 'default';
      // TLS verification is on unless the kubeconfig explicitly opts out.
      bool skipTls = false;

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

      // Find cluster server & CA
      if (doc['clusters'] is List) {
        for (final c in doc['clusters'] as List) {
          if (c is Map) {
            final cName = c['name']?.toString();
            final cMap = c['cluster'] as Map?;
            if (targetClusterName == null || cName == targetClusterName) {
              if (cMap != null) {
                serverUrl = cMap['server']?.toString() ?? serverUrl;
                caCert = cMap['certificate-authority-data']?.toString();
                if (caCert == null && cMap['certificate-authority'] != null) {
                  final caPath = cMap['certificate-authority'].toString();
                  try {
                    final caFile = File(caPath);
                    if (caFile.existsSync()) {
                      caCert = caFile.readAsStringSync();
                    }
                  } catch (_) {}
                }
                skipTls = cMap['insecure-skip-tls-verify'] == true ||
                    cMap['insecure-skip-tls-verify']?.toString() == 'true';
                if (targetClusterName != null) break;
              }
            }
          }
        }
      }

      // Find user credentials (token, client certificate, client key)
      if (doc['users'] is List) {
        for (final u in doc['users'] as List) {
          if (u is Map) {
            final uName = u['name']?.toString();
            final uMap = u['user'] as Map?;
            if (targetUserName == null || uName == targetUserName) {
              if (uMap != null) {
                token = uMap['token']?.toString();
                if ((token == null || token.isEmpty) && uMap['tokenFile'] != null) {
                  try {
                    final tokenFile = File(uMap['tokenFile'].toString());
                    if (tokenFile.existsSync()) token = tokenFile.readAsStringSync().trim();
                  } catch (_) {}
                }
                clientCert = uMap['client-certificate-data']?.toString();
                clientKey = uMap['client-key-data']?.toString();

                if (clientCert == null && uMap['client-certificate'] != null) {
                  final certPath = uMap['client-certificate'].toString();
                  try {
                    final certFile = File(certPath);
                    if (certFile.existsSync()) clientCert = certFile.readAsStringSync();
                  } catch (_) {}
                }

                if (clientKey == null && uMap['client-key'] != null) {
                  final keyPath = uMap['client-key'].toString();
                  try {
                    final keyFile = File(keyPath);
                    if (keyFile.existsSync()) clientKey = keyFile.readAsStringSync();
                  } catch (_) {}
                }

                final hasStaticCreds = (token != null && token.isNotEmpty) ||
                    (clientCert != null && clientKey != null);
                if (!hasStaticCreds && (uMap['exec'] != null || uMap['auth-provider'] != null)) {
                  throw const FormatException(
                    'this kubeconfig user authenticates with an exec or auth-provider plugin '
                    '(for example aws, gke-gcloud-auth-plugin or kubelogin), which cannot run on Android. '
                    'Use a ServiceAccount token or a client certificate instead.',
                  );
                }
                if (uMap['username'] != null && !hasStaticCreds) {
                  throw const FormatException(
                    'basic auth (username/password) is not supported; use a bearer token or a client certificate.',
                  );
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
        clientCertData: clientCert,
        clientKeyData: clientKey,
        defaultNamespace: defaultNs,
        insecureSkipTlsVerify: skipTls,
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
    final List<String> stored = prefs.getStringList(_storageKey) ?? [];
    final secrets = await _readSecrets();

    // Migration: configs saved by older versions kept the token and client
    // key in plain SharedPreferences. Move them to secure storage and rewrite
    // the entry without them. Skipped when secure storage cannot be read, so
    // nothing is lost.
    var migrated = false;
    final rewritten = <String>[];
    for (final s in stored) {
      Map<String, dynamic> map;
      try {
        map = Map<String, dynamic>.from(jsonDecode(s) as Map);
      } catch (_) {
        rewritten.add(s);
        continue;
      }
      final key = _keyOf(map);
      if (secrets != null && key != null && (map.containsKey('token') || map.containsKey('clientKeyData'))) {
        final legacy = <String, dynamic>{
          if (map['token'] != null && map['token'].toString().isNotEmpty) 'token': map['token'].toString(),
          if (map['clientKeyData'] != null && map['clientKeyData'].toString().isNotEmpty)
            'clientKeyData': map['clientKeyData'].toString(),
        };
        if (legacy.isNotEmpty) secrets[key] = {...legacy, ...?secrets[key]};
        map.remove('token');
        map.remove('clientKeyData');
        migrated = true;
      }
      rewritten.add(jsonEncode(map));
      try {
        configs.add(KubeConfig.fromJson(map, secrets: key == null ? null : secrets?[key]));
      } catch (_) {}
    }
    if (migrated && secrets != null) {
      await _writeSecrets(secrets);
      await prefs.setStringList(_storageKey, rewritten);
    }

    // Always ensure the local Linxr / Kubxr cluster is available
    final hasLocal = configs.any((c) => c.server.contains('127.0.0.1:6443') || c.name == 'Linxr Local Cluster');
    if (!hasLocal) {
      configs.add(KubeConfig(
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
