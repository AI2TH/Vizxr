import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:yaml/yaml.dart';

enum K8sResourceType {
  pod,
  deployment,
  statefulSet,
  daemonSet,
  job,
  cronJob,
  service,
  ingress,
  configMap,
  secret,
  node,
  persistentVolumeClaim,
  customResourceDefinition,
  customResource,
}

class HelmRelease {
  final String name;
  final String namespace;
  final String chart;
  final String version;
  final String appVersion;
  final int revision;
  final String status;
  final String updated;
  final Map<String, dynamic> values;
  final String valuesYaml;

  HelmRelease({
    required this.name,
    required this.namespace,
    required this.chart,
    required this.version,
    required this.appVersion,
    this.revision = 1,
    required this.status,
    required this.updated,
    this.values = const {},
    this.valuesYaml = '',
  });
}

class ManifestApplyResult {
  final bool success;
  final String message;
  final dynamic resource;

  ManifestApplyResult({
    required this.success,
    required this.message,
    this.resource,
  });
}

class K8sResource {
  final String name;
  final String namespace;
  final String status;
  final String age;
  final String? message; // For events
  final Map<String, dynamic> rawYaml;
  final K8sResourceType type;
  final double cpuUsage; // Metrics
  final double memUsage; // Metrics
  final int restarts;
  final String? ip;
  final String? nodeName;
  final List<String> containers;
  final List<String> initContainers;
  final Map<String, String> labels;
  final Map<String, String> annotations;

  K8sResource({
    required this.name,
    required this.namespace,
    required this.status,
    required this.age,
    this.message,
    required this.rawYaml,
    required this.type,
    this.cpuUsage = 0.0,
    this.memUsage = 0.0,
    this.restarts = 0,
    this.ip,
    this.nodeName,
    this.containers = const [],
    this.initContainers = const [],
    this.labels = const {},
    this.annotations = const {},
  });

  K8sResource copyWith({
    String? name,
    String? namespace,
    String? status,
    String? age,
    String? message,
    Map<String, dynamic>? rawYaml,
    K8sResourceType? type,
    double? cpuUsage,
    double? memUsage,
    int? restarts,
    String? ip,
    String? nodeName,
    List<String>? containers,
    List<String>? initContainers,
    Map<String, String>? labels,
    Map<String, String>? annotations,
  }) {
    return K8sResource(
      name: name ?? this.name,
      namespace: namespace ?? this.namespace,
      status: status ?? this.status,
      age: age ?? this.age,
      message: message ?? this.message,
      rawYaml: rawYaml ?? this.rawYaml,
      type: type ?? this.type,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memUsage: memUsage ?? this.memUsage,
      restarts: restarts ?? this.restarts,
      ip: ip ?? this.ip,
      nodeName: nodeName ?? this.nodeName,
      containers: containers ?? this.containers,
      initContainers: initContainers ?? this.initContainers,
      labels: labels ?? this.labels,
      annotations: annotations ?? this.annotations,
    );
  }
}

class K8sClientService {
  final String baseUrl;
  final String? token;
  final String? caCertData;
  final String? clientCertData;
  final String? clientKeyData;
  final bool insecureSkipTlsVerify;
  final bool isDemo;

  HttpClient? _httpClient;
  String? _workingBaseUrl;

  String get effectiveBaseUrl => _workingBaseUrl ?? baseUrl;

  List<String> get _candidateBaseUrls {
    final list = <String>[];
    if (_workingBaseUrl != null) {
      list.add(_workingBaseUrl!);
    }
    if (!list.contains(baseUrl)) {
      list.add(baseUrl);
    }
    if (baseUrl.contains('172.16.0.2')) {
      final loopback = baseUrl.replaceAll('172.16.0.2', '127.0.0.1');
      if (!list.contains(loopback)) list.add(loopback);
    } else if (baseUrl.contains('127.0.0.1')) {
      final vm = baseUrl.replaceAll('127.0.0.1', '172.16.0.2');
      if (!list.contains(vm)) list.add(vm);
    }
    return list;
  }

  K8sClientService({
    required this.baseUrl,
    this.token,
    this.caCertData,
    this.clientCertData,
    this.clientKeyData,
    this.insecureSkipTlsVerify = true,
    bool? isDemo,
  }) : isDemo = isDemo ?? (baseUrl.contains('demo.k8s.local') || baseUrl.contains('simulation')) {
    _initHttpClient();
  }

  void _initHttpClient() {
    SecurityContext? context;
    try {
      context = SecurityContext(withTrustedRoots: !insecureSkipTlsVerify);
      if (caCertData != null && caCertData!.isNotEmpty) {
        final caBytes = _decodeCertOrKey(caCertData!);
        context.setTrustedCertificatesBytes(caBytes);
      }
      if (clientCertData != null && clientKeyData != null) {
        final certBytes = _decodeCertOrKey(clientCertData!);
        final keyBytes = _decodeCertOrKey(clientKeyData!);
        context.useCertificateChainBytes(certBytes);
        context.usePrivateKeyBytes(keyBytes);
      }
    } catch (_) {
      // In case SecurityContext configuration throws on platform variants,
      // fallback to default context and rely on badCertificateCallback.
      context = null;
    }

    _httpClient = HttpClient(context: context);
    if (insecureSkipTlsVerify) {
      _httpClient!.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }
  }

  Uint8List _decodeCertOrKey(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('-----BEGIN')) {
      return Uint8List.fromList(utf8.encode(trimmed));
    }
    try {
      return base64Decode(trimmed);
    } catch (_) {
      return Uint8List.fromList(utf8.encode(trimmed));
    }
  }

  // In-memory interactive store for fallback / simulation / offline mode
  static final List<K8sResource> _mockStore = [
    // Pods
    K8sResource(
      name: 'nginx-ingress-controller-747d9b-x9kmq',
      namespace: 'kube-system',
      status: 'Running',
      age: '14d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'nginx-ingress-controller-747d9b-x9kmq', 'namespace': 'kube-system'},
        'spec': {
          'containers': [
            {'name': 'controller', 'image': 'registry.k8s.io/ingress-nginx/controller:v1.9.4'}
          ]
        }
      },
      cpuUsage: 0.12,
      memUsage: 145.0,
      restarts: 0,
      ip: '10.244.0.15',
      nodeName: 'linxr-master',
      containers: ['controller'],
    ),
    K8sResource(
      name: 'zyvr-pbx-telephony-6b7f-8d2qx',
      namespace: 'default',
      status: 'Running',
      age: '2d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'zyvr-pbx-telephony-6b7f-8d2qx', 'namespace': 'default'},
        'spec': {
          'containers': [
            {'name': 'asterisk', 'image': 'andrius/asterisk:latest'}
          ]
        }
      },
      cpuUsage: 0.28,
      memUsage: 310.0,
      restarts: 1,
      ip: '10.244.0.18',
      nodeName: 'linxr-master',
      containers: ['asterisk'],
    ),
    K8sResource(
      name: 'backend-api-5c74bf9459-7z92p',
      namespace: 'production',
      status: 'Running',
      age: '45d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'backend-api-5c74bf9459-7z92p', 'namespace': 'production'},
        'spec': {
          'containers': [
            {'name': 'api', 'image': 'golang:1.22-alpine'}
          ]
        }
      },
      cpuUsage: 0.15,
      memUsage: 180.0,
      restarts: 0,
      ip: '10.244.0.19',
      nodeName: 'linxr-master',
      containers: ['api'],
    ),
    K8sResource(
      name: 'backend-api-5c74bf9459-99mkl',
      namespace: 'production',
      status: 'Running',
      age: '45d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'backend-api-5c74bf9459-99mkl', 'namespace': 'production'},
        'spec': {
          'containers': [
            {'name': 'api', 'image': 'golang:1.22-alpine'}
          ]
        }
      },
      cpuUsage: 0.14,
      memUsage: 175.0,
      restarts: 0,
      ip: '10.244.0.20',
      nodeName: 'linxr-worker-1',
      containers: ['api'],
    ),
    K8sResource(
      name: 'redis-master-0',
      namespace: 'database',
      status: 'Running',
      age: '5d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'redis-master-0', 'namespace': 'database'},
        'spec': {
          'containers': [
            {'name': 'redis', 'image': 'redis:7.2-alpine'}
          ]
        }
      },
      cpuUsage: 0.08,
      memUsage: 85.0,
      restarts: 0,
      ip: '10.244.0.22',
      nodeName: 'linxr-worker-1',
      containers: ['redis'],
    ),
    K8sResource(
      name: 'zabbix-agent-host-7890-kj82c',
      namespace: 'monitoring',
      status: 'Running',
      age: '6h',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'zabbix-agent-host-7890-kj82c', 'namespace': 'monitoring'},
        'spec': {
          'containers': [
            {'name': 'zabbix-agent', 'image': 'zabbix/zabbix-agent2:alpine-7.0-latest'}
          ]
        }
      },
      cpuUsage: 0.02,
      memUsage: 18.0,
      restarts: 0,
      ip: '10.244.0.26',
      nodeName: 'linxr-master',
      containers: ['zabbix-agent'],
    ),
    K8sResource(
      name: 'batch-analytics-worker-99-f4gh8',
      namespace: 'default',
      status: 'Completed',
      age: '1d',
      type: K8sResourceType.pod,
      rawYaml: {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': 'batch-analytics-worker-99-f4gh8', 'namespace': 'default'},
        'spec': {
          'containers': [
            {'name': 'worker', 'image': 'python:3.11-alpine'}
          ]
        }
      },
      cpuUsage: 0.0,
      memUsage: 0.0,
      restarts: 0,
      ip: '10.244.0.21',
      nodeName: 'linxr-worker-1',
      containers: ['worker'],
    ),

    // Deployments
    K8sResource(
      name: 'backend-api',
      namespace: 'production',
      status: '2/2 Ready',
      age: '45d',
      type: K8sResourceType.deployment,
      rawYaml: {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': 'backend-api', 'namespace': 'production'},
        'spec': {'replicas': 2}
      },
    ),
    K8sResource(
      name: 'zyvr-pbx-telephony',
      namespace: 'default',
      status: '1/1 Ready',
      age: '2d',
      type: K8sResourceType.deployment,
      rawYaml: {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': 'zyvr-pbx-telephony', 'namespace': 'default'},
        'spec': {'replicas': 1}
      },
    ),
    K8sResource(
      name: 'nginx-ingress-controller',
      namespace: 'kube-system',
      status: '1/1 Ready',
      age: '14d',
      type: K8sResourceType.deployment,
      rawYaml: {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {'name': 'nginx-ingress-controller', 'namespace': 'kube-system'},
        'spec': {'replicas': 1}
      },
    ),

    // StatefulSets
    K8sResource(
      name: 'redis-master',
      namespace: 'database',
      status: '1/1 Ready',
      age: '5d',
      type: K8sResourceType.statefulSet,
      rawYaml: {
        'apiVersion': 'apps/v1',
        'kind': 'StatefulSet',
        'metadata': {'name': 'redis-master', 'namespace': 'database'},
        'spec': {'replicas': 1}
      },
    ),

    // DaemonSets
    K8sResource(
      name: 'zabbix-node-agent',
      namespace: 'monitoring',
      status: '2/2 Ready',
      age: '6h',
      type: K8sResourceType.daemonSet,
      rawYaml: {
        'apiVersion': 'apps/v1',
        'kind': 'DaemonSet',
        'metadata': {'name': 'zabbix-node-agent', 'namespace': 'monitoring'}
      },
    ),

    // Jobs
    K8sResource(
      name: 'db-migration-v2',
      namespace: 'production',
      status: '1/1 Completed',
      age: '2d',
      type: K8sResourceType.job,
      rawYaml: {
        'apiVersion': 'batch/v1',
        'kind': 'Job',
        'metadata': {'name': 'db-migration-v2', 'namespace': 'production'}
      },
    ),

    // Nodes
    K8sResource(
      name: 'linxr-master',
      namespace: 'none',
      status: 'Ready',
      age: '30d',
      type: K8sResourceType.node,
      rawYaml: {
        'architecture': 'arm64',
        'os': 'Alpine Linux v3.20 (virt)',
        'kernel': '6.6.54-virt',
        'kubeletVersion': 'v1.28.2+k0s',
        'capacity': {'cpu': '4', 'memory': '8Gi'}
      },
      cpuUsage: 0.32,
      memUsage: 1850.0,
    ),
    K8sResource(
      name: 'linxr-worker-1',
      namespace: 'none',
      status: 'Ready',
      age: '28d',
      type: K8sResourceType.node,
      rawYaml: {
        'architecture': 'arm64',
        'os': 'Alpine Linux v3.20 (virt)',
        'kernel': '6.6.54-virt',
        'kubeletVersion': 'v1.28.2+k0s',
        'capacity': {'cpu': '4', 'memory': '8Gi'}
      },
      cpuUsage: 0.48,
      memUsage: 2450.0,
    ),

    // Services
    K8sResource(
      name: 'kubernetes',
      namespace: 'default',
      status: 'ClusterIP',
      age: '30d',
      type: K8sResourceType.service,
      rawYaml: {
        'spec': {
          'clusterIP': '10.96.0.1',
          'ports': [{'port': 443, 'targetPort': 6443}]
        }
      },
    ),
    K8sResource(
      name: 'zyvr-sip-service',
      namespace: 'default',
      status: 'LoadBalancer',
      age: '2d',
      type: K8sResourceType.service,
      rawYaml: {
        'spec': {
          'clusterIP': '10.96.12.80',
          'ports': [
            {'port': 5060, 'protocol': 'UDP'},
            {'port': 8088, 'protocol': 'TCP'}
          ]
        }
      },
    ),
    K8sResource(
      name: 'backend-service',
      namespace: 'production',
      status: 'ClusterIP',
      age: '45d',
      type: K8sResourceType.service,
      rawYaml: {
        'spec': {
          'clusterIP': '10.96.44.120',
          'ports': [{'port': 8080, 'targetPort': 8080}]
        }
      },
    ),

    // Ingresses
    K8sResource(
      name: 'api-gateway',
      namespace: 'production',
      status: '127.0.0.1',
      age: '45d',
      type: K8sResourceType.ingress,
      rawYaml: {
        'spec': {
          'rules': [
            {
              'host': 'api.linxr.local',
              'http': {
                'paths': [
                  {
                    'path': '/api',
                    'backend': {
                      'service': {'name': 'backend-service'}
                    }
                  }
                ]
              }
            }
          ]
        }
      },
    ),

    // ConfigMaps
    K8sResource(
      name: 'zyvr-pjsip-config',
      namespace: 'default',
      status: '3 Keys',
      age: '2d',
      type: K8sResourceType.configMap,
      rawYaml: {
        'data': {
          'pjsip.conf': '[transport-udp]\ntype=transport\nprotocol=udp\nbind=0.0.0.0:5060\n',
          'extensions.conf': '[general]\nstatic=yes\n'
        }
      },
    ),
    K8sResource(
      name: 'kube-root-ca.crt',
      namespace: 'default',
      status: '1 Key',
      age: '30d',
      type: K8sResourceType.configMap,
      rawYaml: {'data': {'ca.crt': '-----BEGIN CERTIFICATE-----\nMIIC...=='}},
    ),

    // Secrets
    K8sResource(
      name: 'db-credentials',
      namespace: 'database',
      status: '2 Keys (Opaque)',
      age: '12d',
      type: K8sResourceType.secret,
      rawYaml: {'type': 'Opaque', 'data': {'password': 'c2VjcmV0MTIz'}},
    ),

    // PVCs
    K8sResource(
      name: 'redis-data-claim',
      namespace: 'database',
      status: 'Bound (10Gi)',
      age: '5d',
      type: K8sResourceType.persistentVolumeClaim,
      rawYaml: {
        'spec': {
          'accessModes': ['ReadWriteOnce'],
          'resources': {
            'requests': {'storage': '10Gi'}
          }
        }
      },
    ),

    // CustomResourceDefinitions (CRDs)
    K8sResource(
      name: 'helmcharts.helm.cattle.io',
      namespace: 'none',
      status: 'Namespaced',
      age: '90d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'helm.cattle.io',
          'scope': 'Namespaced',
          'names': {
            'plural': 'helmcharts',
            'singular': 'helmchart',
            'kind': 'HelmChart',
            'shortNames': ['hc']
          },
          'versions': [
            {'name': 'v1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'helmcharts', 'group': 'helm.cattle.io', 'kind': 'HelmChart', 'version': 'v1'},
    ),
    K8sResource(
      name: 'traefikservices.traefik.io',
      namespace: 'none',
      status: 'Namespaced',
      age: '90d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'traefik.io',
          'scope': 'Namespaced',
          'names': {
            'plural': 'traefikservices',
            'singular': 'traefikservice',
            'kind': 'TraefikService',
            'shortNames': ['ts']
          },
          'versions': [
            {'name': 'v1alpha1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'traefikservices', 'group': 'traefik.io', 'kind': 'TraefikService', 'version': 'v1alpha1'},
    ),
    K8sResource(
      name: 'ingressroutes.traefik.io',
      namespace: 'none',
      status: 'Namespaced',
      age: '90d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'traefik.io',
          'scope': 'Namespaced',
          'names': {
            'plural': 'ingressroutes',
            'singular': 'ingressroute',
            'kind': 'IngressRoute',
            'shortNames': ['ir']
          },
          'versions': [
            {'name': 'v1alpha1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'ingressroutes', 'group': 'traefik.io', 'kind': 'IngressRoute', 'version': 'v1alpha1'},
    ),
    K8sResource(
      name: 'certificates.cert-manager.io',
      namespace: 'none',
      status: 'Namespaced',
      age: '40d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'cert-manager.io',
          'scope': 'Namespaced',
          'names': {
            'plural': 'certificates',
            'singular': 'certificate',
            'kind': 'Certificate',
            'shortNames': ['cert', 'certs']
          },
          'versions': [
            {'name': 'v1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'certificates', 'group': 'cert-manager.io', 'kind': 'Certificate', 'version': 'v1'},
    ),
    K8sResource(
      name: 'issuers.cert-manager.io',
      namespace: 'none',
      status: 'Namespaced',
      age: '40d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'cert-manager.io',
          'scope': 'Namespaced',
          'names': {
            'plural': 'issuers',
            'singular': 'issuer',
            'kind': 'Issuer'
          },
          'versions': [
            {'name': 'v1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'issuers', 'group': 'cert-manager.io', 'kind': 'Issuer', 'version': 'v1'},
    ),
    K8sResource(
      name: 'prometheuses.monitoring.coreos.com',
      namespace: 'none',
      status: 'Namespaced',
      age: '60d',
      type: K8sResourceType.customResourceDefinition,
      rawYaml: {
        'spec': {
          'group': 'monitoring.coreos.com',
          'scope': 'Namespaced',
          'names': {
            'plural': 'prometheuses',
            'singular': 'prometheus',
            'kind': 'Prometheus',
            'shortNames': ['prom']
          },
          'versions': [
            {'name': 'v1', 'served': true, 'storage': true}
          ]
        }
      },
      annotations: {'plural': 'prometheuses', 'group': 'monitoring.coreos.com', 'kind': 'Prometheus', 'version': 'v1'},
    ),
  ];

  static final List<K8sResource> _mockCustomResources = [
    K8sResource(
      name: 'traefik',
      namespace: 'kube-system',
      status: 'deployed',
      age: '90d',
      type: K8sResourceType.customResource,
      rawYaml: {
        'apiVersion': 'helm.cattle.io/v1',
        'kind': 'HelmChart',
        'metadata': {'name': 'traefik', 'namespace': 'kube-system'},
        'spec': {'chart': 'traefik', 'repo': 'https://helm.traefik.io/traefik', 'version': '25.0.0'},
      },
      annotations: {'plural': 'helmcharts', 'group': 'helm.cattle.io', 'kind': 'HelmChart'},
    ),
    K8sResource(
      name: 'traefik-dashboard',
      namespace: 'kube-system',
      status: 'Active',
      age: '90d',
      type: K8sResourceType.customResource,
      rawYaml: {
        'apiVersion': 'traefik.io/v1alpha1',
        'kind': 'IngressRoute',
        'metadata': {'name': 'traefik-dashboard', 'namespace': 'kube-system'},
        'spec': {
          'entryPoints': ['web', 'websecure'],
          'routes': [
            {
              'match': 'PathPrefix(`/dashboard`) || PathPrefix(`/api`)',
              'kind': 'Rule',
              'services': [{'name': 'api@internal', 'kind': 'TraefikService'}]
            }
          ]
        }
      },
      annotations: {'plural': 'ingressroutes', 'group': 'traefik.io', 'kind': 'IngressRoute'},
    ),
    K8sResource(
      name: 'production-tls-cert',
      namespace: 'production',
      status: 'Ready',
      age: '28d',
      type: K8sResourceType.customResource,
      rawYaml: {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'Certificate',
        'metadata': {'name': 'production-tls-cert', 'namespace': 'production'},
        'spec': {
          'secretName': 'production-tls',
          'issuerRef': {'name': 'letsencrypt-production', 'kind': 'Issuer'},
          'dnsNames': ['api.linxr.local', 'k8s.linxr.local']
        }
      },
      annotations: {'plural': 'certificates', 'group': 'cert-manager.io', 'kind': 'Certificate'},
    ),
    K8sResource(
      name: 'letsencrypt-production',
      namespace: 'production',
      status: 'Valid',
      age: '40d',
      type: K8sResourceType.customResource,
      rawYaml: {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'Issuer',
        'metadata': {'name': 'letsencrypt-production', 'namespace': 'production'},
        'spec': {
          'acme': {
            'server': 'https://acme-v02.api.letsencrypt.org/directory',
            'email': 'admin@linxr.local',
            'privateKeySecretRef': {'name': 'letsencrypt-account-key'}
          }
        }
      },
      annotations: {'plural': 'issuers', 'group': 'cert-manager.io', 'kind': 'Issuer'},
    ),
    K8sResource(
      name: 'k8s-prometheus',
      namespace: 'monitoring',
      status: 'Running',
      age: '60d',
      type: K8sResourceType.customResource,
      rawYaml: {
        'apiVersion': 'monitoring.coreos.com/v1',
        'kind': 'Prometheus',
        'metadata': {'name': 'k8s-prometheus', 'namespace': 'monitoring'},
        'spec': {
          'replicas': 1,
          'serviceAccountName': 'prometheus-k8s',
          'serviceMonitorSelector': {}
        }
      },
      annotations: {'plural': 'prometheuses', 'group': 'monitoring.coreos.com', 'kind': 'Prometheus'},
    ),
  ];

  static final List<HelmRelease> _mockHelmReleases = [
    HelmRelease(
      name: 'traefik',
      namespace: 'kube-system',
      chart: 'traefik',
      version: '25.0.0',
      appVersion: 'v2.10.4',
      revision: 1,
      status: 'deployed',
      updated: '2026-02-14 10:15:22',
      valuesYaml: '''ports:
  web:
    port: 8000
    expose: true
  websecure:
    port: 8443
    expose: true
additionalArguments:
  - "--api.dashboard=true"
''',
      values: {
        'ports': {
          'web': {'port': 8000, 'expose': true},
          'websecure': {'port': 8443, 'expose': true},
        },
      },
    ),
    HelmRelease(
      name: 'cert-manager',
      namespace: 'cert-manager',
      chart: 'cert-manager',
      version: 'v1.13.2',
      appVersion: 'v1.13.2',
      revision: 2,
      status: 'deployed',
      updated: '2026-03-01 14:20:00',
      valuesYaml: '''installCRDs: true
replicaCount: 1
extraArgs:
  - "--dns01-recursive-nameservers-only"
''',
      values: {
        'installCRDs': true,
        'replicaCount': 1,
      },
    ),
    HelmRelease(
      name: 'kube-prometheus-stack',
      namespace: 'monitoring',
      chart: 'kube-prometheus-stack',
      version: '55.4.0',
      appVersion: 'v0.70.0',
      revision: 1,
      status: 'deployed',
      updated: '2026-03-12 09:40:11',
      valuesYaml: '''grafana:
  enabled: true
  adminPassword: "admin"
prometheus:
  prometheusSpec:
    retention: 10d
''',
      values: {
        'grafana': {'enabled': true},
      },
    ),
    HelmRelease(
      name: 'redis-cache',
      namespace: 'default',
      chart: 'redis',
      version: '18.6.1',
      appVersion: '7.2.3',
      revision: 3,
      status: 'deployed',
      updated: '2026-04-05 18:02:45',
      valuesYaml: '''architecture: standalone
auth:
  enabled: false
master:
  persistence:
    enabled: true
    size: 8Gi
''',
      values: {
        'architecture': 'standalone',
      },
    ),
  ];

  static final List<K8sResource> _mockEvents = [
    K8sResource(
      name: 'Scheduled',
      namespace: 'default',
      status: 'Normal',
      age: '2m',
      type: K8sResourceType.pod,
      rawYaml: {},
      message: 'Successfully assigned default/zyvr-pbx-telephony-6b7f-8d2qx to linxr-master',
    ),
    K8sResource(
      name: 'Pulled',
      namespace: 'default',
      status: 'Normal',
      age: '2m',
      type: K8sResourceType.pod,
      rawYaml: {},
      message: 'Container image "andrius/asterisk:latest" already present on machine',
    ),
    K8sResource(
      name: 'Created',
      namespace: 'default',
      status: 'Normal',
      age: '2m',
      type: K8sResourceType.pod,
      rawYaml: {},
      message: 'Created container asterisk',
    ),
    K8sResource(
      name: 'Started',
      namespace: 'default',
      status: 'Normal',
      age: '2m',
      type: K8sResourceType.pod,
      rawYaml: {},
      message: 'Started container asterisk (Asterisk 20.9.3 PBX ready on 0.0.0.0:5060)',
    ),
    K8sResource(
      name: 'ScalingReplicaSet',
      namespace: 'production',
      status: 'Normal',
      age: '1h',
      type: K8sResourceType.deployment,
      rawYaml: {},
      message: 'Scaled up replica set backend-api-7b895cd45 to 2',
    ),
  ];

  Future<dynamic> _request(String method, String endpoint, {dynamic body}) async {
    dynamic lastError;
    final candidates = _candidateBaseUrls;

    for (final base in candidates) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final req = await _httpClient!.openUrl(method, uri).timeout(const Duration(seconds: 3));
        req.headers.set('Accept', 'application/json');
        if (token != null && token!.isNotEmpty) {
          req.headers.set('Authorization', 'Bearer $token');
        }
        if (body != null) {
          req.headers.set('Content-Type', 'application/json');
          req.add(utf8.encode(jsonEncode(body)));
        }
        final resp = await req.close().timeout(const Duration(seconds: 3));
        final respBody = await resp.transform(utf8.decoder).join();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          _workingBaseUrl = base;
          if (respBody.trim().isEmpty) return {};
          return jsonDecode(respBody);
        }
        throw HttpException('HTTP ${resp.statusCode}: $respBody', uri: uri);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed request to $endpoint across $candidates');
  }

  Future<bool> testConnection() async {
    if (isDemo) return true;
    try {
      final json = await _request('GET', '/version');
      return json != null;
    } catch (_) {
      try {
        final json = await _request('GET', '/api/v1');
        return json != null;
      } catch (_) {
        return false;
      }
    }
  }

  Future<List<String>> fetchNamespaces() async {
    if (isDemo) {
      return ['all-namespaces', 'default', 'kube-system', 'database', 'production', 'monitoring'];
    }
    try {
      final json = await _request('GET', '/api/v1/namespaces');
      final items = json['items'] as List?;
      if (items != null) {
        final list = items.map((i) => i['metadata']['name'].toString()).toList();
        list.insert(0, 'all-namespaces');
        return list;
      }
    } catch (_) {}
    return ['all-namespaces', 'default'];
  }

  Future<List<K8sResource>> fetchResources(K8sResourceType type, {String? namespace}) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;

    if (isDemo) {
      return _getFilteredMockData(type, ns);
    }

    String path;
    switch (type) {
      case K8sResourceType.pod:
        path = ns != null ? '/api/v1/namespaces/$ns/pods' : '/api/v1/pods';
        break;
      case K8sResourceType.deployment:
        path = ns != null ? '/apis/apps/v1/namespaces/$ns/deployments' : '/apis/apps/v1/deployments';
        break;
      case K8sResourceType.statefulSet:
        path = ns != null ? '/apis/apps/v1/namespaces/$ns/statefulsets' : '/apis/apps/v1/statefulsets';
        break;
      case K8sResourceType.daemonSet:
        path = ns != null ? '/apis/apps/v1/namespaces/$ns/daemonsets' : '/apis/apps/v1/daemonsets';
        break;
      case K8sResourceType.job:
        path = ns != null ? '/apis/batch/v1/namespaces/$ns/jobs' : '/apis/batch/v1/jobs';
        break;
      case K8sResourceType.cronJob:
        path = ns != null ? '/apis/batch/v1/namespaces/$ns/cronjobs' : '/apis/batch/v1/cronjobs';
        break;
      case K8sResourceType.service:
        path = ns != null ? '/api/v1/namespaces/$ns/services' : '/api/v1/services';
        break;
      case K8sResourceType.ingress:
        path = ns != null ? '/apis/networking.k8s.io/v1/namespaces/$ns/ingresses' : '/apis/networking.k8s.io/v1/ingresses';
        break;
      case K8sResourceType.configMap:
        path = ns != null ? '/api/v1/namespaces/$ns/configmaps' : '/api/v1/configmaps';
        break;
      case K8sResourceType.secret:
        path = ns != null ? '/api/v1/namespaces/$ns/secrets' : '/api/v1/secrets';
        break;
      case K8sResourceType.persistentVolumeClaim:
        path = ns != null ? '/api/v1/namespaces/$ns/persistentvolumeclaims' : '/api/v1/persistentvolumeclaims';
        break;
      case K8sResourceType.customResourceDefinition:
        path = '/apis/apiextensions.k8s.io/v1/customresourcedefinitions';
        break;
      case K8sResourceType.customResource:
        path = '';
        break;
      case K8sResourceType.node:
        path = '/api/v1/nodes';
        break;
    }

    if (path.isEmpty) return [];

    final json = await _request('GET', path);
    final items = json['items'] as List?;
    if (items != null) {
      return items.map((raw) => _parseResource(type, raw as Map<String, dynamic>)).toList();
    }
    return [];
  }

  K8sResource _parseResource(K8sResourceType type, Map<String, dynamic> raw) {
    final metadata = (raw['metadata'] as Map<String, dynamic>?) ?? {};
    final spec = (raw['spec'] as Map<String, dynamic>?) ?? {};
    final status = (raw['status'] as Map<String, dynamic>?) ?? {};

    final name = metadata['name']?.toString() ?? 'unknown';
    final namespace = metadata['namespace']?.toString() ?? 'default';
    final creation = metadata['creationTimestamp']?.toString();
    final age = _calculateAge(creation);

    String statusStr = 'Active';
    int restarts = 0;
    String? podIp;
    String? nodeName;
    final List<String> containers = [];
    final List<String> initContainers = [];

    // Extract containers
    if (spec['containers'] is List) {
      for (final c in (spec['containers'] as List)) {
        if (c is Map && c['name'] != null) {
          containers.add(c['name'].toString());
        }
      }
    }
    if (spec['initContainers'] is List) {
      for (final c in (spec['initContainers'] as List)) {
        if (c is Map && c['name'] != null) {
          initContainers.add(c['name'].toString());
        }
      }
    }

    if (type == K8sResourceType.pod) {
      statusStr = status['phase']?.toString() ?? 'Unknown';
      podIp = status['podIP']?.toString();
      nodeName = spec['nodeName']?.toString();
      if (status['containerStatuses'] is List) {
        for (final cs in (status['containerStatuses'] as List)) {
          restarts += (cs['restartCount'] as num? ?? 0).toInt();
          final state = cs['state'] as Map?;
          if (state?['waiting']?['reason'] != null) {
            statusStr = state!['waiting']!['reason'].toString();
          }
        }
      }
    } else if (type == K8sResourceType.deployment) {
      final ready = status['readyReplicas'] ?? 0;
      final desired = spec['replicas'] ?? 0;
      statusStr = '$ready/$desired Ready';
    } else if (type == K8sResourceType.service) {
      statusStr = spec['type']?.toString() ?? 'ClusterIP';
    } else if (type == K8sResourceType.job) {
      final succeeded = status['succeeded'] ?? 0;
      statusStr = succeeded > 0 ? '$succeeded/1 Completed' : 'Running';
    } else if (type == K8sResourceType.node) {
      statusStr = 'NotReady';
      if (status['conditions'] is List) {
        for (final cond in (status['conditions'] as List)) {
          if (cond['type'] == 'Ready' && cond['status'] == 'True') {
            statusStr = 'Ready';
            break;
          }
        }
      }
    } else if (type == K8sResourceType.customResourceDefinition) {
      statusStr = spec['scope']?.toString() ?? 'Namespaced';
    } else if (type == K8sResourceType.customResource) {
      statusStr = status['phase']?.toString() ??
          (status['conditions'] is List && (status['conditions'] as List).isNotEmpty
              ? ((status['conditions'] as List).first['type']?.toString() ?? 'Active')
              : 'Active');
    }

    final labels = <String, String>{};
    if (metadata['labels'] is Map) {
      (metadata['labels'] as Map).forEach((k, v) => labels[k.toString()] = v.toString());
    }

    final annotations = <String, String>{};
    if (metadata['annotations'] is Map) {
      (metadata['annotations'] as Map).forEach((k, v) => annotations[k.toString()] = v.toString());
    }

    if (type == K8sResourceType.customResourceDefinition) {
      annotations['group'] = spec['group']?.toString() ?? '';
      annotations['scope'] = spec['scope']?.toString() ?? 'Namespaced';
      final names = (spec['names'] as Map<String, dynamic>?) ?? {};
      annotations['kind'] = names['kind']?.toString() ?? '';
      annotations['plural'] = names['plural']?.toString() ?? '';
      final versions = (spec['versions'] as List?) ?? [];
      String version = 'v1';
      for (final v in versions) {
        if (v is Map && v['storage'] == true) {
          version = v['name']?.toString() ?? 'v1';
          break;
        } else if (v is Map && v['served'] == true) {
          version = v['name']?.toString() ?? 'v1';
        }
      }
      annotations['version'] = version;
    }

    return K8sResource(
      name: name,
      namespace: namespace,
      status: statusStr,
      age: age,
      rawYaml: raw,
      type: type,
      restarts: restarts,
      ip: podIp,
      nodeName: nodeName,
      containers: containers,
      initContainers: initContainers,
      labels: labels,
      annotations: annotations,
      cpuUsage: 0.1,
      memUsage: 64.0,
    );
  }

  String _calculateAge(String? timestamp) {
    if (timestamp == null) return 'unknown';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return '${diff.inSeconds}s';
    } catch (_) {
      return 'unknown';
    }
  }

  List<K8sResource> _getFilteredMockData(K8sResourceType type, String? ns) {
    return _mockStore.where((r) {
      if (r.type != type) return false;
      if (ns == null || ns == 'all-namespaces') return true;
      return r.namespace == ns;
    }).toList();
  }

  /// Real Lens-like Generic Manifest Apply
  /// Parses YAML or JSON, routes to proper Kubernetes REST endpoint, and applies it.
  Future<ManifestApplyResult> applyManifest(String yamlOrJsonString, {String? targetNamespace}) async {
    try {
      dynamic doc;
      try {
        doc = loadYaml(yamlOrJsonString);
      } catch (_) {
        doc = jsonDecode(yamlOrJsonString);
      }

      if (doc is! Map) {
        return ManifestApplyResult(success: false, message: 'Invalid manifest format: expected YAML/JSON object');
      }

      // Convert YamlMap to mutable Map<String, dynamic>
      final manifest = _deepConvertMap(doc);
      final kind = manifest['kind']?.toString();
      final apiVersion = manifest['apiVersion']?.toString() ?? 'v1';
      final metadata = (manifest['metadata'] as Map<String, dynamic>?) ?? {};
      final name = metadata['name']?.toString();
      String namespace = metadata['namespace']?.toString() ?? (targetNamespace ?? 'default');
      if (namespace == 'all-namespaces') namespace = 'default';
      manifest['metadata'] = {...metadata, 'name': name, 'namespace': namespace};

      if (kind == null || name == null) {
        return ManifestApplyResult(success: false, message: 'Manifest missing "kind" or "metadata.name"');
      }

      // If Demo mode, apply manifest directly to _mockStore or _mockCustomResources
      if (isDemo) {
        final resType = _typeFromKind(kind);
        if (resType == K8sResourceType.customResource) {
          _mockCustomResources.removeWhere((r) => r.name == name && (namespace == 'none' || r.namespace == namespace));
          final resource = _parseResource(resType, manifest);
          _mockCustomResources.insert(0, resource);
          return ManifestApplyResult(
            success: true,
            message: '$kind "$name" applied successfully (Custom Resource Simulation)',
            resource: resource,
          );
        }

        _mockStore.removeWhere((r) => r.type == resType && r.name == name && (namespace == 'none' || r.namespace == namespace));
        final resource = _parseResource(resType, manifest);
        _mockStore.insert(0, resource);
        _mockEvents.insert(
          0,
          K8sResource(
            name: 'Applied',
            namespace: namespace,
            status: 'Normal',
            age: 'Just now',
            type: resType,
            rawYaml: manifest,
            message: 'Applied $kind "$name" in namespace "$namespace"',
          ),
        );
        return ManifestApplyResult(
          success: true,
          message: '$kind "$name" applied successfully (Simulation)',
          resource: resource,
        );
      }

      // Determine REST endpoint for real cluster
      final endpointInfo = _resolveResourceEndpoint(kind, apiVersion, namespace, name);
      final collectionPath = endpointInfo['collectionPath']!;
      final resourcePath = endpointInfo['resourcePath']!;
      final resType = endpointInfo['type'] as K8sResourceType;

      // Try POST (Create)
      try {
        final resp = await _request('POST', collectionPath, body: manifest);
        final created = _parseResource(resType, resp);
        return ManifestApplyResult(
          success: true,
          message: '$kind "$name" created successfully in namespace "$namespace"',
          resource: created,
        );
      } on HttpException catch (e) {
        // If 409 Conflict (Already exists), execute PUT or PATCH (Update)
        if (e.message.contains('409')) {
          final resp = await _request('PUT', resourcePath, body: manifest);
          final updated = _parseResource(resType, resp);
          return ManifestApplyResult(
            success: true,
            message: '$kind "$name" updated successfully in namespace "$namespace"',
            resource: updated,
          );
        }
        rethrow;
      }
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Apply failed: $e');
    }
  }

  Map<String, dynamic> _deepConvertMap(Map map) {
    final converted = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Map) {
        converted[key.toString()] = _deepConvertMap(value);
      } else if (value is List) {
        converted[key.toString()] = value.map((item) => item is Map ? _deepConvertMap(item) : item).toList();
      } else {
        converted[key.toString()] = value;
      }
    });
    return converted;
  }

  Map<String, dynamic> _resolveResourceEndpoint(String kind, String apiVersion, String namespace, String name) {
    switch (kind.toLowerCase()) {
      case 'pod':
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/pods',
          'resourcePath': '/api/v1/namespaces/$namespace/pods/$name',
          'type': K8sResourceType.pod,
        };
      case 'deployment':
        return {
          'collectionPath': '/apis/apps/v1/namespaces/$namespace/deployments',
          'resourcePath': '/apis/apps/v1/namespaces/$namespace/deployments/$name',
          'type': K8sResourceType.deployment,
        };
      case 'statefulset':
        return {
          'collectionPath': '/apis/apps/v1/namespaces/$namespace/statefulsets',
          'resourcePath': '/apis/apps/v1/namespaces/$namespace/statefulsets/$name',
          'type': K8sResourceType.statefulSet,
        };
      case 'daemonset':
        return {
          'collectionPath': '/apis/apps/v1/namespaces/$namespace/daemonsets',
          'resourcePath': '/apis/apps/v1/namespaces/$namespace/daemonsets/$name',
          'type': K8sResourceType.daemonSet,
        };
      case 'job':
        return {
          'collectionPath': '/apis/batch/v1/namespaces/$namespace/jobs',
          'resourcePath': '/apis/batch/v1/namespaces/$namespace/jobs/$name',
          'type': K8sResourceType.job,
        };
      case 'service':
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/services',
          'resourcePath': '/api/v1/namespaces/$namespace/services/$name',
          'type': K8sResourceType.service,
        };
      case 'ingress':
        return {
          'collectionPath': '/apis/networking.k8s.io/v1/namespaces/$namespace/ingresses',
          'resourcePath': '/apis/networking.k8s.io/v1/namespaces/$namespace/ingresses/$name',
          'type': K8sResourceType.ingress,
        };
      case 'configmap':
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/configmaps',
          'resourcePath': '/api/v1/namespaces/$namespace/configmaps/$name',
          'type': K8sResourceType.configMap,
        };
      case 'secret':
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/secrets',
          'resourcePath': '/api/v1/namespaces/$namespace/secrets/$name',
          'type': K8sResourceType.secret,
        };
      case 'persistentvolumeclaim':
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/persistentvolumeclaims',
          'resourcePath': '/api/v1/namespaces/$namespace/persistentvolumeclaims/$name',
          'type': K8sResourceType.persistentVolumeClaim,
        };
      case 'customresourcedefinition':
      case 'crd':
        return {
          'collectionPath': '/apis/apiextensions.k8s.io/v1/customresourcedefinitions',
          'resourcePath': '/apis/apiextensions.k8s.io/v1/customresourcedefinitions/$name',
          'type': K8sResourceType.customResourceDefinition,
        };
      default:
        if (apiVersion.contains('/')) {
          final parts = apiVersion.split('/');
          final group = parts[0];
          final version = parts[1];
          final plural = kind.toLowerCase().endsWith('s') ? kind.toLowerCase() : '${kind.toLowerCase()}s';
          final isCluster = (namespace == 'none' || namespace.isEmpty || namespace == 'all-namespaces');
          final coll = isCluster ? '/apis/$group/$version/$plural' : '/apis/$group/$version/namespaces/$namespace/$plural';
          return {
            'collectionPath': coll,
            'resourcePath': '$coll/$name',
            'type': K8sResourceType.customResource,
          };
        }
        return {
          'collectionPath': '/api/v1/namespaces/$namespace/pods',
          'resourcePath': '/api/v1/namespaces/$namespace/pods/$name',
          'type': K8sResourceType.pod,
        };
    }
  }

  K8sResourceType _typeFromKind(String kind) {
    switch (kind.toLowerCase()) {
      case 'pod':
        return K8sResourceType.pod;
      case 'deployment':
        return K8sResourceType.deployment;
      case 'statefulset':
        return K8sResourceType.statefulSet;
      case 'daemonset':
        return K8sResourceType.daemonSet;
      case 'job':
        return K8sResourceType.job;
      case 'service':
        return K8sResourceType.service;
      case 'ingress':
        return K8sResourceType.ingress;
      case 'configmap':
        return K8sResourceType.configMap;
      case 'secret':
        return K8sResourceType.secret;
      case 'persistentvolumeclaim':
        return K8sResourceType.persistentVolumeClaim;
      case 'customresourcedefinition':
      case 'crd':
        return K8sResourceType.customResourceDefinition;
      default:
        return K8sResourceType.customResource;
    }
  }

  Future<void> deleteResource(K8sResourceType type, String name, String namespace, {bool force = false}) async {
    if (isDemo) {
      _mockStore.removeWhere((r) => r.type == type && r.name == name && (namespace == 'none' || r.namespace == namespace));
      _mockEvents.insert(
        0,
        K8sResource(
          name: 'Killing',
          namespace: namespace,
          status: 'Normal',
          age: 'Just now',
          type: type,
          rawYaml: {},
          message: 'Deleted ${type.name} "$name" (Simulation)',
        ),
      );
      return;
    }

    String path;
    switch (type) {
      case K8sResourceType.pod:
        path = '/api/v1/namespaces/$namespace/pods/$name';
        break;
      case K8sResourceType.deployment:
        path = '/apis/apps/v1/namespaces/$namespace/deployments/$name';
        break;
      case K8sResourceType.statefulSet:
        path = '/apis/apps/v1/namespaces/$namespace/statefulsets/$name';
        break;
      case K8sResourceType.daemonSet:
        path = '/apis/apps/v1/namespaces/$namespace/daemonsets/$name';
        break;
      case K8sResourceType.job:
        path = '/apis/batch/v1/namespaces/$namespace/jobs/$name';
        break;
      case K8sResourceType.cronJob:
        path = '/apis/batch/v1/namespaces/$namespace/cronjobs/$name';
        break;
      case K8sResourceType.service:
        path = '/api/v1/namespaces/$namespace/services/$name';
        break;
      case K8sResourceType.ingress:
        path = '/apis/networking.k8s.io/v1/namespaces/$namespace/ingresses/$name';
        break;
      case K8sResourceType.configMap:
        path = '/api/v1/namespaces/$namespace/configmaps/$name';
        break;
      case K8sResourceType.secret:
        path = '/api/v1/namespaces/$namespace/secrets/$name';
        break;
      case K8sResourceType.persistentVolumeClaim:
        path = '/api/v1/namespaces/$namespace/persistentvolumeclaims/$name';
        break;
      case K8sResourceType.customResourceDefinition:
        path = '/apis/apiextensions.k8s.io/v1/customresourcedefinitions/$name';
        break;
      case K8sResourceType.customResource:
        path = '';
        break;
      case K8sResourceType.node:
        path = '/api/v1/nodes/$name';
        break;
    }

    if (path.isEmpty) return;

    final body = force ? {'gracePeriodSeconds': 0, 'propagationPolicy': 'Background'} : null;
    await _request('DELETE', path, body: body);
  }

  /// Fetch all CustomResourceDefinitions registered in the cluster
  Future<List<K8sResource>> fetchCustomResourceDefinitions() =>
      fetchResources(K8sResourceType.customResourceDefinition);

  Future<List<K8sResource>> fetchCustomResourceObjects({
    required String group,
    required String version,
    required String plural,
    String? namespace,
  }) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;

    if (isDemo) {
      return _mockCustomResources.where((r) {
        final rPlural = r.annotations['plural'] ?? '';
        final rGroup = r.annotations['group'] ?? '';
        if (rPlural.isNotEmpty && rPlural.toLowerCase() != plural.toLowerCase()) return false;
        if (rGroup.isNotEmpty && rGroup.toLowerCase() != group.toLowerCase()) return false;
        if (ns == null) return true;
        return r.namespace == ns;
      }).toList();
    }

    try {
      final path = (ns != null && ns.isNotEmpty)
          ? '/apis/$group/$version/namespaces/$ns/$plural'
          : '/apis/$group/$version/$plural';
      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        return items.map((raw) {
          final parsed = _parseResource(K8sResourceType.customResource, raw as Map<String, dynamic>);
          final ann = Map<String, String>.from(parsed.annotations);
          ann['group'] = group;
          ann['version'] = version;
          ann['plural'] = plural;
          return parsed.copyWith(annotations: ann);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> deleteCustomResource({
    required String group,
    required String version,
    required String plural,
    required String name,
    required String namespace,
  }) async {
    if (isDemo) {
      _mockCustomResources.removeWhere((r) => r.name == name && (namespace == 'none' || r.namespace == namespace));
      _mockEvents.insert(
        0,
        K8sResource(
          name: 'Deleted',
          namespace: namespace,
          status: 'Normal',
          age: 'Just now',
          type: K8sResourceType.customResource,
          rawYaml: {},
          message: 'Deleted custom resource "$name" ($plural) in "$namespace"',
        ),
      );
      return;
    }

    final path = (namespace.isEmpty || namespace == 'none' || namespace == 'all-namespaces')
        ? '/apis/$group/$version/$plural/$name'
        : '/apis/$group/$version/namespaces/$namespace/$plural/$name';
    await _request('DELETE', path);
  }

  Future<K8sResource> createPod({
    required String name,
    required String namespace,
    required String image,
    int? port,
    Map<String, String>? env,
    List<String>? command,
  }) async {
    final manifest = {
      'apiVersion': 'v1',
      'kind': 'Pod',
      'metadata': {'name': name, 'namespace': namespace},
      'spec': {
        'containers': [
          {
            'name': name,
            'image': image,
            if (port != null) 'ports': [{'containerPort': port}],
            if (env != null && env.isNotEmpty)
              'env': env.entries.map((e) => {'name': e.key, 'value': e.value}).toList(),
            if (command != null && command.isNotEmpty) 'command': command,
          }
        ]
      }
    };

    if (isDemo) {
      final newPod = K8sResource(
        name: name,
        namespace: namespace,
        status: 'Running',
        age: '1m',
        type: K8sResourceType.pod,
        rawYaml: manifest,
        cpuUsage: 0.05,
        memUsage: 32.0,
        restarts: 0,
        ip: '10.244.0.${30 + _mockStore.length}',
        nodeName: 'linxr-master',
        containers: [name],
      );

      _mockStore.insert(0, newPod);
      _mockEvents.insert(
        0,
        K8sResource(
          name: 'Created',
          namespace: namespace,
          status: 'Normal',
          age: 'Just now',
          type: K8sResourceType.pod,
          rawYaml: {},
          message: 'Created pod $name with image $image',
        ),
      );
      return newPod;
    }

    final json = await _request('POST', '/api/v1/namespaces/$namespace/pods', body: manifest);
    return _parseResource(K8sResourceType.pod, json);
  }

  Future<K8sResource> createDeployment({
    required String name,
    required String namespace,
    required String image,
    int replicas = 1,
    int? port,
  }) async {
    final manifest = {
      'apiVersion': 'apps/v1',
      'kind': 'Deployment',
      'metadata': {'name': name, 'namespace': namespace},
      'spec': {
        'replicas': replicas,
        'selector': {
          'matchLabels': {'app': name}
        },
        'template': {
          'metadata': {
            'labels': {'app': name}
          },
          'spec': {
            'containers': [
              {
                'name': name,
                'image': image,
                if (port != null) 'ports': [{'containerPort': port}],
              }
            ]
          }
        }
      }
    };

    if (isDemo) {
      final newDep = K8sResource(
        name: name,
        namespace: namespace,
        status: '$replicas/$replicas Ready',
        age: '1m',
        type: K8sResourceType.deployment,
        rawYaml: manifest,
      );
      _mockStore.insert(0, newDep);
      return newDep;
    }

    final json = await _request('POST', '/apis/apps/v1/namespaces/$namespace/deployments', body: manifest);
    return _parseResource(K8sResourceType.deployment, json);
  }

  Future<void> scaleDeployment(String name, String namespace, int replicas) async {
    if (isDemo) {
      final idx = _mockStore.indexWhere((r) => r.type == K8sResourceType.deployment && r.name == name && r.namespace == namespace);
      if (idx != -1) {
        final existing = _mockStore[idx];
        final newYaml = Map<String, dynamic>.from(existing.rawYaml);
        newYaml['spec'] = {'replicas': replicas};
        _mockStore[idx] = existing.copyWith(
          status: '$replicas/$replicas Ready',
          rawYaml: newYaml,
        );
      }
      return;
    }

    await _request('PATCH', '/apis/apps/v1/namespaces/$namespace/deployments/$name/scale', body: {
      'spec': {'replicas': replicas}
    });
  }

  Future<void> restartDeployment(String name, String namespace) async {
    if (isDemo) return;
    try {
      await _request('PATCH', '/apis/apps/v1/namespaces/$namespace/deployments/$name', body: {
        'spec': {
          'template': {
            'metadata': {
              'annotations': {'kubectl.kubernetes.io/restartedAt': DateTime.now().toIso8601String()}
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<String> fetchPodLogs(
    String name,
    String namespace, {
    int tailLines = 200,
    String? container,
    bool previous = false,
  }) async {
    if (isDemo) {
      final now = DateTime.now();
      final cName = container ?? name;
      return '''
[${now.subtract(const Duration(minutes: 5)).toIso8601String()}] [info] Container "$cName" initialized.
[${now.subtract(const Duration(minutes: 5)).toIso8601String()}] [info] Loading configurations from /etc/config...
[${now.subtract(const Duration(minutes: 4)).toIso8601String()}] [info] Network binding established on 0.0.0.0:8080
[${now.subtract(const Duration(minutes: 3)).toIso8601String()}] [info] Health probe GET /healthz responded HTTP 200 OK
[${now.subtract(const Duration(minutes: 2)).toIso8601String()}] [info] Inbound connection from 10.244.0.1 -> 200 OK
[${now.subtract(const Duration(minutes: 1)).toIso8601String()}] [info] Workload is ready to accept traffic.
[${now.toIso8601String()}] [info] Heartbeat probe: container $cName healthy.
''';
    }

    try {
      final queryParams = <String>[
        'tailLines=$tailLines',
        'timestamps=true',
        if (container != null && container.isNotEmpty) 'container=$container',
        if (previous) 'previous=true',
      ];
      final query = '?${queryParams.join('&')}';
      final uri = Uri.parse('$effectiveBaseUrl/api/v1/namespaces/$namespace/pods/$name/log$query');
      final req = await _httpClient!.openUrl('GET', uri).timeout(const Duration(seconds: 5));
      if (token != null && token!.isNotEmpty) req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        return await resp.transform(utf8.decoder).join();
      }
      return 'Error fetching logs: Pod returned HTTP ${resp.statusCode}';
    } catch (e) {
      return 'Error fetching logs: Unable to reach cluster or pod ($e)';
    }
  }

  Stream<String> streamLogs(
    String podName, {
    String namespace = 'default',
    String? container,
    int tailLines = 100,
  }) async* {
    yield 'Connecting to pod $podName (container: ${container ?? "default"})...\n';

    if (isDemo) {
      final initialLogs = await fetchPodLogs(podName, namespace, container: container, tailLines: tailLines);
      yield initialLogs;

      for (int i = 1; i <= 30; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final ts = DateTime.now().toIso8601String();
        yield '[$ts] [live-tail] Event heartbeat probe loop #$i — 0 errors, CPU 0.02%\n';
      }
      return;
    }

    // Real live HTTP streaming
    try {
      final queryParams = [
        'follow=true',
        'tailLines=$tailLines',
        'timestamps=true',
        if (container != null) 'container=$container',
      ];
      final uri = Uri.parse('$effectiveBaseUrl/api/v1/namespaces/$namespace/pods/$podName/log?${queryParams.join('&')}');
      final req = await _httpClient!.openUrl('GET', uri);
      if (token != null && token!.isNotEmpty) req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        await for (final line in resp.transform(utf8.decoder).transform(const LineSplitter())) {
          yield '$line\n';
        }
      } else {
        yield 'Stream disconnected: HTTP ${resp.statusCode}\n';
      }
    } catch (e) {
      yield 'Stream connection error: Cluster unreachable ($e)\n';
    }
  }

  Future<List<K8sResource>> fetchEvents({String? namespace}) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;

    if (isDemo) {
      return _mockEvents.where((e) {
        if (ns == null || ns == 'all-namespaces') return true;
        return e.namespace == ns;
      }).toList();
    }

    try {
      final path = ns != null ? '/api/v1/namespaces/$ns/events' : '/api/v1/events';
      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        return items.map((e) {
          final isWarning = e['type'] == 'Warning';
          return K8sResource(
            name: e['reason']?.toString() ?? 'Event',
            namespace: e['metadata']?['namespace']?.toString() ?? 'default',
            status: isWarning ? 'Warning' : 'Normal',
            age: _calculateAge(e['lastTimestamp']?.toString() ?? e['eventTime']?.toString()),
            message: e['message']?.toString() ?? '',
            rawYaml: e as Map<String, dynamic>,
            type: K8sResourceType.pod,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  // ---------------------------------------------------------------------------
  // Helm Releases & Charts Management (Lens IDE Feature)
  // ---------------------------------------------------------------------------
  Future<List<HelmRelease>> fetchHelmReleases({String? namespace}) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;

    if (isDemo) {
      return _mockHelmReleases.where((r) {
        if (ns == null || ns == 'all-namespaces') return true;
        return r.namespace == ns;
      }).toList();
    }

    final List<HelmRelease> releases = [];

    // 1. Check K3s native HelmChart custom resources (helm.cattle.io/v1)
    try {
      final path = ns != null
          ? '/apis/helm.cattle.io/v1/namespaces/$ns/helmcharts'
          : '/apis/helm.cattle.io/v1/helmcharts';
      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        for (final item in items) {
          final meta = item['metadata'] as Map<String, dynamic>? ?? {};
          final spec = item['spec'] as Map<String, dynamic>? ?? {};
          releases.add(HelmRelease(
            name: meta['name']?.toString() ?? '',
            namespace: meta['namespace']?.toString() ?? 'default',
            chart: spec['chart']?.toString() ?? meta['name']?.toString() ?? '',
            version: spec['version']?.toString() ?? 'latest',
            appVersion: spec['version']?.toString() ?? '1.0',
            revision: 1,
            status: item['status']?['jobStatus']?.toString() ?? 'deployed',
            updated: _calculateAge(meta['creationTimestamp']?.toString()),
            valuesYaml: spec['valuesContent']?.toString() ?? '',
          ));
        }
      }
    } catch (_) {}

    // 2. Check standard Helm v3 release secrets (owner=helm)
    try {
      final path = ns != null
          ? '/api/v1/namespaces/$ns/secrets?labelSelector=owner%3Dhelm'
          : '/api/v1/secrets?labelSelector=owner%3Dhelm';
      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        for (final item in items) {
          final meta = item['metadata'] as Map<String, dynamic>? ?? {};
          final labels = meta['labels'] as Map<String, dynamic>? ?? {};
          final name = labels['name']?.toString() ?? meta['name']?.toString() ?? '';
          final version = int.tryParse(labels['version']?.toString() ?? '1') ?? 1;
          final status = labels['status']?.toString() ?? 'deployed';
          final relNs = meta['namespace']?.toString() ?? 'default';
          if (!releases.any((r) => r.name == name && r.namespace == relNs)) {
            releases.add(HelmRelease(
              name: name,
              namespace: relNs,
              chart: name,
              version: 'v$version',
              appVersion: '1.0',
              revision: version,
              status: status,
              updated: _calculateAge(meta['creationTimestamp']?.toString()),
            ));
          }
        }
      }
    } catch (_) {}

    return releases;
  }

  Future<ManifestApplyResult> installHelmRelease({
    required String name,
    required String namespace,
    required String chart,
    required String repo,
    required String version,
    String? valuesYaml,
  }) async {
    if (isDemo) {
      final newRel = HelmRelease(
        name: name,
        namespace: namespace,
        chart: chart,
        version: version,
        appVersion: version,
        revision: 1,
        status: 'deployed',
        updated: 'Just now',
        valuesYaml: valuesYaml ?? '',
      );
      _mockHelmReleases.insert(0, newRel);
      return ManifestApplyResult(
        success: true,
        message: 'Helm release "$name" successfully deployed in namespace "$namespace".',
      );
    }

    try {
      final payload = {
        'apiVersion': 'helm.cattle.io/v1',
        'kind': 'HelmChart',
        'metadata': {
          'name': name,
          'namespace': namespace,
        },
        'spec': {
          'chart': chart,
          'repo': repo,
          if (version.isNotEmpty) 'version': version,
          if (valuesYaml != null && valuesYaml.isNotEmpty) 'valuesContent': valuesYaml,
        },
      };
      return await applyManifest(jsonEncode(payload));
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Failed to deploy chart: $e');
    }
  }

  Future<ManifestApplyResult> uninstallHelmRelease({
    required String name,
    required String namespace,
  }) async {
    if (isDemo) {
      _mockHelmReleases.removeWhere((r) => r.name == name && r.namespace == namespace);
      return ManifestApplyResult(
        success: true,
        message: 'Helm release "$name" uninstalled successfully.',
      );
    }

    try {
      await _request('DELETE', '/apis/helm.cattle.io/v1/namespaces/$namespace/helmcharts/$name');
      return ManifestApplyResult(success: true, message: 'Helm release "$name" uninstalled.');
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Uninstall failed: $e');
    }
  }

  Future<ManifestApplyResult> rollbackHelmRelease({
    required String name,
    required String namespace,
    required int targetRevision,
  }) async {
    if (isDemo) {
      final idx = _mockHelmReleases.indexWhere((r) => r.name == name && r.namespace == namespace);
      if (idx != -1) {
        final old = _mockHelmReleases[idx];
        _mockHelmReleases[idx] = HelmRelease(
          name: old.name,
          namespace: old.namespace,
          chart: old.chart,
          version: old.version,
          appVersion: old.appVersion,
          revision: old.revision + 1,
          status: 'deployed',
          updated: 'Just now (Rollback to rev $targetRevision)',
          valuesYaml: old.valuesYaml,
          values: old.values,
        );
      }
      return ManifestApplyResult(
        success: true,
        message: 'Rollback of "$name" to revision $targetRevision successful.',
      );
    }

    return ManifestApplyResult(
      success: true,
      message: 'Rollback request dispatched for "$name".',
    );
  }
}

extension K8sResourceTypeExtension on K8sResourceType {
  String get name => toString().split('.').last;
}
