import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

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
    this.insecureSkipTlsVerify = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'server': server,
    'token': token,
    'caCert': caCert,
    'clientCertData': clientCertData,
    'clientKeyData': clientKeyData,
    'defaultNamespace': defaultNamespace,
    'insecureSkipTlsVerify': insecureSkipTlsVerify,
  };

  factory KubeConfig.fromJson(Map<String, dynamic> json) => KubeConfig(
    name: json['name'] ?? 'Cluster',
    server: json['server'] ?? 'https://127.0.0.1:6443',
    token: json['token'],
    caCert: json['caCert'],
    clientCertData: json['clientCertData'],
    clientKeyData: json['clientKeyData'],
    defaultNamespace: json['defaultNamespace'] ?? 'default',
    insecureSkipTlsVerify: json['insecureSkipTlsVerify'] ?? true,
  );

  static const String _storageKey = 'vizxr_kubeconfigs';

  static const String testKubeconfigYaml = '''apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJVnRrV3g3anlMbFV3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TmpFeE1ETXdOVFF3TkRkYUZ3MHpOakV3TXpFd05UUTFORGRhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURnaWtzbkFvRUVwWUk1OU5Zd1NpTDRJUUJmeG95ZTZsZ09mUlZyYXpwZnBBSTlQVlR1S0Q3VGIxRVkKZ3dRazQ5bmFXSFdHTU41UUltNSt4ZTF3NXFZTTIzaW0vRTBpc2xZRWx4NHEyRVh3eFViR3JoWXVXNVFtTktSUQppSTVwdk1pYXM2aTRzRGVuM0xIdzhndVFzeEx0bkdHcWxQbXFiMnlHUVNEMmN4a1JYT0d2eTVlWDRxZ1FuTVZPCk5PbHYyTkJ6S1RJUmpieFFBQXVxYUk4UmFuanNWQXZlSEZtYTlKUm9KbmZkMXA5NWU4QmRGNG1raFNVeUlhR2EKRGg0NmVTSjgxSTNVa25hY2JnTUE1cW1MSFc1OEk0WjVvdVlvZG9OMTlMMjdDYk16cHR6M2UrcjI0ejZ6VGNnMAp5MmdMNGtVb25TcEVCcDVJS0pZbkdvYVRXb3d6QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJRampZWTBTTko3RTJvOThGTFhPMExPV1F1TnBqQVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ3lucTZBeEwrZgovenJleEJkSXVsNkZMKzhhMTgxYi85WmVtdXVOM1VkK3pUSkd5akVKL0NwSlhQNVQ1OVRNMW93aGYwdkJoRkFOCmJDZzFubzhnZFZuOVJFZU51SHFpUmZZbHhEY0UrcEhKS3dBbHRVcVZiUkJoMmMwUVd5cG54TzNuejBFOXZBWmkKd0NiUExHRWJaMGNBeGpYWUs1TU9GOTAySDVma1VvMVFaUElTcEdJMEZtdEwza1ZjTDFpN3dLOXpFQnlrbll0NgpibDkyQkFXb2M3eW1XdDN2bGMwWFNYS2RyVEo5cGxEU1g4ZjZ5Qjd5dDFkRW1SKys3RExIYWJxWXhIMlpocWM1CjdaRUdud09PdjNHVDllY0tpRWlJOVNmdUFtWVVubkZzYUFyVHU4Wlp6MHVyNDBWT1ZuMTlZV0ZiS1QwZHcrM3gKQ0hFRXBvLzc0VjJpCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://172.16.0.2:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURLVENDQWhHZ0F3SUJBZ0lJY2xuSWt2ZENteU13RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TmpFeE1ETXdOVFF3TkRkYUZ3MHlOekV4TURNd05UUTFORGRhTUR3eApIekFkQmdOVkJBb1RGbXQxWW1WaFpHMDZZMngxYzNSbGNpMWhaRzFwYm5NeEdUQVhCZ05WQkFNVEVHdDFZbVZ5CmJtVjBaWE10WVdSdGFXNHdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFEc28xVVAKS0xBUXJtWkE0aGttU1Btek9hbXE1WjQvcGZBOVVubHFaaEVBMG5FVFZSa0RQdVVmYzJNNDlYMEprNVVSc291OAp4bS9Bem5TWlNXWkVoVzluL3VrczVQenVGY0w0ZkpuZkNuOWtadVkrRGtJODV3SFlDdTljK3hVYU9lNWNkaUc0CjF1aE42aGtmVmM2alYxRmRneFdFRjAzZ2dHdnJCL3cveDVwVXZGeWNkblNDbGF1U1I5ZFYzYzJGbENyRTdGalQKRVBDNHdjd3JCQ3pMSEcxRUd4bWFueUNxcnBVcTZBUjF6ZE1GbTlqL0kxQU5McGhkbWJJcWc4MWN4a3NicXBUbwpPWTNYOFNoaTZ6SmtCbEV5ekdZb05abk5EUDEzTVlDNGNob0xiM2xpNW1wWk96K2NiSG9icG5vczBId014Tm1iCm5rTnRvbDMwanU5MjNYNDdBZ01CQUFHalZqQlVNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUsKQmdnckJnRUZCUWNEQWpBTUJnTlZIUk1CQWY4RUFqQUFNQjhHQTFVZEl3UVlNQmFBRkNPTmhqUkkwbnNUYWozdwpVdGM3UXM1WkM0Mm1NQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUI2NWtrdE9EN2swOERPK0o5TzZwM1JIR2s2CmUxbDZicmhuelFobjBMQWpVNmZIMXpYeWtlWjNUdlY2bkVMV01mK09qdjFjc2pZUDVHSHc0RU05RnhwbXB4Q1AKdFZIckJKSVhGdGdzbVZCZFpVMTZ3alNXWjBKNThnbmtrQTl0akJkQ1lWcjdsTDFHMGRnRStHWm9UcjIyWUdtdQplUTExWkZEeTVXaGRUUkdoaEk0TURLOGZmRkhiWXU0b1BFYi96NzRHTm9RUEE1Ynpld21DdlVrSDc0TWVWNUh6CldwNkUxRGxpNVMyNjFET1pkMEdTZ0phN2VtMlVSV2tCMUtJUStSZmdiaXhJNS9mbzlzYUxyUkZDR0dTMWlEYkIKRlFXaU1UUFhsTFNxTm52eVk2bFRYaDhYSmFGMXRrc252TXVUcXJtWkp2TFptRkRwcFNWVGVSM1AzVURZCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBN0tOVkR5aXdFSzVtUU9JWkprajVzem1wcXVXZVA2WHdQVko1YW1ZUkFOSnhFMVVaCkF6N2xIM05qT1BWOUNaT1ZFYktMdk1adndNNTBtVWxtUklWdlovN3BMT1Q4N2hYQytIeVozd3AvWkdibVBnNUMKUE9jQjJBcnZYUHNWR2pudVhIWWh1TmJvVGVvWkgxWE9vMWRSWFlNVmhCZE40SUJyNndmOFA4ZWFWTHhjbkhaMApncFdya2tmWFZkM05oWlFxeE94WTB4RHd1TUhNS3dRc3l4eHRSQnNabXA4Z3FxNlZLdWdFZGMzVEJadlkveU5RCkRTNllYWm15S29QTlhNWkxHNnFVNkRtTjEvRW9ZdXN5WkFaUk1zeG1LRFdaelF6OWR6R0F1SElhQzI5NVl1WnEKV1RzL25HeDZHNlo2TE5COERNVFptNTVEYmFKZDlJN3ZkdDErT3dJREFRQUJBb0lCQUdtTm5aWnFic2F5RkRoaQo0aGI2dkM3ZXpMakhQYVJrYjFuYkhQK0IwWm5OUk5UN3czRjRMNW1zelppTm9CMlNjQTc1MW16NUVzWXRFVU9DCnd4UlRkTk10bUhNSEhXOVIwNnNsWVRsbEpGZnpza1lCOURmWVR6RkFCMjh4TEVPTGpiQStuV0ltc201MnVvZ0kKcldpY3ZWVjU4RElBZHlOcUJUbE1VWTlkaUpDOHJQUWZoRzZKbis2eVY3bFhDbDZheWFqbmttU1RWMEd6c0xLWQpnbkJ4ZUtsK2FVWmVlRWsvYkhJUXN1aXY1NDdldmVoTlhzbVNsTmpXQ2dSai9tdVY1SkdjMVZPZlRncnEyZ2JYCkJuT2JvNURxQ0NGWU0zWC9IQzI0c29vODdQdGNwZ1Y5RkJBWnJ0alJiTUl1UmZMVlk2ckNrdlpvS1I5ZzNVQmMKTi9jTVBXa0NnWUVBK2c0VUZBRVVkSFZ2bkpXV0YxODhjNkdIK3dTUGdVandacm45UlZHczlVWEsvL04vajgwNgpJc2F2S1FVSWdTbWkxNGZTbWF0M2QvaGJBL05YOHdiaWdrMHVXOVdwL3phQUpBcytYb0FTSHZmL2VKSE1EODdDCjRqWjRJcHB2MFg2Ymo1dWRYYzYzZnNJK2wrL0pFRHBHOFNacEhhS0xCNzVDUEk3SGpOcjVWaDBDZ1lFQThrT1gKN0N5bGovcHE1bzJhcDF5blVQWXRMUUJZWm9FSS9nMGE3b0cvTDFGSE9PK0JCeSs1Q1Q5NXV4OTZwUTROZVNzUQpUVi9TRDJLaTNVN2doQi9SNXBwZUVvVHFkY2pRbklDQ2RTcXZhbG1Uc01HdHh1eWpmNm9uUnYxdGpyZ2djckFQCmNHcHBzM2VDV2NOencvckI0ZGNjSWduaEVTNTRJT1Y5ZUtxRGxqY0NnWUVBeklOeE5uOC9uSlJrQ2J4cWVva2cKNXkzSkNxdkxOeUZSeGFMK201QldsbkJUdkkwSjJySXVoenpiREFDYTJSRVZwNVBsMGx0a0pkSVJscVNUWFNoWApYOTBDT29nQk5zUDdmLzlXTG5JdTMvZFRrZWdrN3hUYlhhclJEUFFrMmtIanQwdStKSGdxcWRqeTJzOTZNZlNJCkN6bXdKVlhJd2plQTh3aVArd3NwZkowQ2dZRUE3L3JEQ0VGbHM0eTB6ak1oS240ZWc1V0lSSmFkK3RRQksxK2gKK1BidmdwaTV1NDJNTzZrcld4elVvZWJaMzV4ZS9sTUpNQXdtRWZWOExVdFFIYkZEaEhJUGs3cTBZZjZObnlteAprUXk2Zk5mRTlBZTI4MkUveUZ1dDBxV0NIQ2tLZzNFaHFoTFBKK2JQYWNteDZFV0NQd3VObzY0ems0aDdtT0tiCmVxYzE5OXNDZ1lFQTRta3BzeGlQWEppaENwQW5XdUY0OGR5TEgweHhUanpCQlZqUVNtR0R1YndGTGhBQzVSV1oKc1FUalJWRnNvK2xUbmI5T2dacnBSQzlmMTVINmdxRlp2M3ZnRHFaRDJrR2QweTgyU0w3bVJORUVsL1lZazFlZQp4ZWZqVjlWWU1CK2pPQWxaVTJSalpUeGtlMnhlQk9nN0paek1meDF2Wk5ydjhlaWNJb2JxTzFVPQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=''';

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
      bool skipTls = true;

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
                if (cMap['insecure-skip-tls-verify'] == true) {
                  skipTls = true;
                }
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
    final List<String>? stored = prefs.getStringList(_storageKey);

    if (stored != null && stored.isNotEmpty) {
      for (final s in stored) {
        try {
          configs.add(KubeConfig.fromJson(jsonDecode(s)));
        } catch (_) {}
      }
    }

    // Always ensure the User's Phone Test Cluster (mTLS / 172.16.0.2 with loopback fallback) is available
    const userClusterName = 'kubernetes-admin@kubernetes';
    final hasUserCluster = configs.any((c) => c.name == userClusterName || c.server.contains('172.16.0.2'));
    if (!hasUserCluster) {
      final userConfig = await addFromYaml(testKubeconfigYaml);
      configs.insert(0, userConfig);
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
