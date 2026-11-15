import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'secret_store.dart';

class KubeConfig {
  /// Stable key for storage. Two kubeconfigs with the same context name
  /// (k3s always calls it "default") no longer overwrite each other.
  final String id;
  final String name;
  final String server;
  final String? token;
  final String? caCert;
  final String? clientCertData;
  final String? clientKeyData;
  final String defaultNamespace;
  final bool insecureSkipTlsVerify;

  KubeConfig({
    String? id,
    required this.name,
    required this.server,
    this.token,
    this.caCert,
    this.clientCertData,
    this.clientKeyData,
    this.defaultNamespace = 'default',
    this.insecureSkipTlsVerify = false,
  }) : id = (id == null || id.isEmpty) ? newId() : id;

  static final Random _random = Random.secure();

  /// A random 16-hex-digit id.
  static String newId() =>
      List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// Ids of the clusters Vizxr always offers.
  static const String linxrLocalId = 'builtin-linxr-local';
  static const String demoId = 'builtin-demo';

  /// [name], or "name (2)", "name (3)"... if it is already taken.
  static String uniqueName(String name, Iterable<String> taken) {
    final used = taken.toSet();
    if (!used.contains(name)) return name;
    var n = 2;
    while (used.contains('$name ($n)')) {
      n++;
    }
    return '$name ($n)';
  }

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
        id: id,
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
    'id': id,
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
    id: json['id']?.toString(),
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

  static String? _keyOf(Map map) => map['id']?.toString();

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
      secrets.remove(config.id);
    } else {
      secrets[config.id] = configSecrets;
    }
    await _writeSecrets(secrets);

    final prefs = await SharedPreferences.getInstance();
    final List<String> configs = prefs.getStringList(_storageKey) ?? [];

    // Remove existing config with same key if any
    configs.removeWhere((s) {
      try {
        return _keyOf(jsonDecode(s)) == config.id;
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

  /// Reads and parses a kubeconfig file. Does not save it.
  static Future<KubeConfig> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Kubeconfig file not found at path', filePath);
    }
    final content = await file.readAsString();
    return parseKubeconfig(content);
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
          return parseKubeconfig(content);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Parses and saves a kubeconfig. See [parseKubeconfig].
  static Future<KubeConfig> addFromYaml(String yamlString) async {
    final config = parseKubeconfig(yamlString);
    await saveConfig(config);
    return config;
  }

  /// Parses a kubeconfig (YAML or JSON) for its current context.
  ///
  /// The whole document is parsed as-is: nothing is cut off after a key
  /// footer. Invalid YAML, a missing cluster or server, and unsupported auth
  /// throw a [FormatException] whose message says what is wrong and where.
  static KubeConfig parseKubeconfig(String yamlString) {
    try {
      return _parseKubeconfig(yamlString);
    } on YamlException catch (e) {
      final line = e.span == null ? '' : ' at line ${e.span!.start.line + 1}';
      throw FormatException('Invalid kubeconfig YAML$line: ${e.message}');
    } on FormatException catch (e) {
      throw FormatException('Invalid kubeconfig: ${e.message}');
    } on TypeError {
      throw const FormatException(
        'Invalid kubeconfig: unexpected structure (clusters, contexts and users must be lists of name/value maps)',
      );
    }
  }

  static KubeConfig _parseKubeconfig(String yamlString) {
    final doc = loadYaml(yamlString);
    if (doc is! Map) {
      throw const FormatException('expected a YAML mapping with clusters, contexts and users');
    }

    String clusterName = 'Imported Cluster';
    String? serverUrl;
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
              serverUrl = cMap['server']?.toString();
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

    if (serverUrl == null || serverUrl.isEmpty) {
      throw FormatException(targetClusterName == null
          ? 'no clusters[].cluster.server found'
          : 'cluster "$targetClusterName" (used by context "$clusterName") is missing or has no server');
    }

    return KubeConfig(
      name: clusterName,
      server: serverUrl,
      token: token,
      caCert: caCert,
      clientCertData: clientCert,
      clientKeyData: clientKey,
      defaultNamespace: defaultNs,
      insecureSkipTlsVerify: skipTls,
    );
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
      // Migration: configs saved before ids existed were keyed by name.
      if (map['id'] == null || map['id'].toString().isEmpty) {
        final legacyName = map['name']?.toString();
        final id = map['name'] == 'Linxr Local Cluster'
            ? linxrLocalId
            : (map['name'] == 'Demo Cluster (Simulation)' ? demoId : newId());
        map['id'] = id;
        if (secrets != null && legacyName != null && secrets.containsKey(legacyName)) {
          secrets[id] = secrets.remove(legacyName)!;
        }
        // Without readable secure storage the name-keyed credentials cannot
        // be re-keyed, so keep the old entries and retry on the next launch.
        if (secrets != null) migrated = true;
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
    if (migrated) {
      if (secrets != null) await _writeSecrets(secrets);
      await prefs.setStringList(_storageKey, rewritten);
    }

    // Always ensure the local Linxr / Kubxr cluster is available
    final hasLocal = configs.any((c) => c.id == linxrLocalId || c.server.contains('127.0.0.1:6443'));
    if (!hasLocal) {
      configs.add(KubeConfig(
        id: linxrLocalId,
        name: 'Linxr Local Cluster',
        server: 'https://127.0.0.1:6443',
        defaultNamespace: 'default',
        insecureSkipTlsVerify: true,
      ));
    }

    // Always ensure Demo Simulator Cluster is available for offline testing
    final hasDemo = configs.any((c) => c.id == demoId || c.name == 'Demo Cluster (Simulation)');
    if (!hasDemo) {
      configs.add(KubeConfig(
        id: demoId,
        name: 'Demo Cluster (Simulation)',
        server: 'https://demo.k8s.local',
        defaultNamespace: 'default',
        insecureSkipTlsVerify: true,
      ));
    }

    return configs;
  }
}
