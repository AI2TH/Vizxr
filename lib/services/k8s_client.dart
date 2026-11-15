import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:yaml/yaml.dart';
import 'k8s_quantity.dart';

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
  /// A release installed with the helm CLI (Helm v3 storage Secret).
  static const String sourceHelm = 'Helm';

  /// A k3s helm-controller `HelmChart` object (helm.cattle.io/v1).
  static const String sourceK3s = 'k3s HelmChart';

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
  final String source;
  final String description;

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
    this.source = sourceHelm,
    this.description = '',
  });

  bool get isK3sHelmChart => source == sourceK3s;
}

class ManifestApplyResult {
  final bool success;
  final String message;
  final dynamic resource;

  /// True when server-side apply refused the change because another field
  /// manager owns a field. Retrying with `forceConflicts` takes ownership.
  final bool conflict;

  ManifestApplyResult({
    required this.success,
    required this.message,
    this.resource,
    this.conflict = false,
  });
}

/// The pod and container port behind a Service port, for port forwarding.
class PortForwardTarget {
  final String podName;
  final int containerPort;
  final int servicePort;

  const PortForwardTarget({required this.podName, required this.containerPort, required this.servicePort});
}

/// An error response from the Kubernetes API server.
class K8sApiException implements Exception {
  final int statusCode;
  final String message;
  final Uri? uri;

  const K8sApiException(this.statusCode, this.message, {this.uri});

  @override
  String toString() => message;

  /// Builds the exception from a response, using the `message` of a
  /// Kubernetes `Status` body when there is one.
  factory K8sApiException.fromResponse(int statusCode, String body, Uri uri) {
    var detail = body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) detail = decoded['message'].toString();
    } catch (_) {}
    return K8sApiException(statusCode, 'HTTP $statusCode: $detail', uri: uri);
  }
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

  /// Other URLs for the same API server, tried only when [baseUrl] cannot
  /// be reached. Set for "Linxr on this phone" clusters, empty otherwise.
  final List<String> fallbackBaseUrls;

  /// URLs tried in order: the last one that answered, [baseUrl], then
  /// [fallbackBaseUrls].
  List<String> get candidateBaseUrls {
    final list = <String>[];
    for (final url in [if (_workingBaseUrl != null) _workingBaseUrl!, baseUrl, ...fallbackBaseUrls]) {
      if (!list.contains(url)) list.add(url);
    }
    return list;
  }

  K8sClientService({
    required this.baseUrl,
    this.token,
    this.caCertData,
    this.clientCertData,
    this.clientKeyData,
    this.insecureSkipTlsVerify = false,
    this.fallbackBaseUrls = const [],
    bool? isDemo,
  }) : isDemo = isDemo ?? isDemoServer(baseUrl) {
    _initHttpClient();
  }

  /// Host name of the built-in in-memory simulator.
  static const String demoHost = 'demo.k8s.local';

  /// True only for the simulator URL. A real cluster whose name or URL merely
  /// contains "demo" must never be served mock data.
  static bool isDemoServer(String url) => Uri.tryParse(url)?.host == demoHost;

  /// Releases the underlying HTTP client. Call this when the client is
  /// replaced (for example on a cluster switch) so sockets are not leaked.
  void close() {
    _httpClient?.close();
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
    // Only accept unverifiable certificates when the kubeconfig explicitly
    // sets insecure-skip-tls-verify. Otherwise the default (reject) applies.
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

  /// Sends one API request.
  ///
  /// The [fallbackBaseUrls] (Linxr clusters only) are tried only when the
  /// connection itself fails. Once a server has answered, its HTTP error is thrown
  /// as-is: retrying a POST or DELETE elsewhere could apply it twice and
  /// would hide the real error (403, 409, 422...) behind a connect error.
  Future<dynamic> _request(
    String method,
    String endpoint, {
    dynamic body,
    String? contentType,
  }) async {
    final client = _httpClient;
    if (client == null) throw StateError('Kubernetes client is closed');
    Object? lastError;
    final candidates = candidateBaseUrls;

    for (final base in candidates) {
      final uri = Uri.parse('$base$endpoint');
      HttpClientResponse? resp;
      try {
        final req = await client.openUrl(method, uri).timeout(const Duration(seconds: 5));
        req.headers.set('Accept', 'application/json');
        if (token != null && token!.isNotEmpty) {
          req.headers.set('Authorization', 'Bearer $token');
        }
        if (body != null) {
          // PATCH needs a patch media type; plain application/json gets 415.
          req.headers.set(
            'Content-Type',
            contentType ?? (method == 'PATCH' ? 'application/merge-patch+json' : 'application/json'),
          );
          req.add(utf8.encode(body is String ? body : jsonEncode(body)));
        }
        resp = await req.close().timeout(const Duration(seconds: 30));
      } on SocketException catch (e) {
        lastError = e;
        continue;
      } on TimeoutException catch (e) {
        lastError = e;
        continue;
      } on HandshakeException catch (e) {
        lastError = e;
        continue;
      }

      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _workingBaseUrl = base;
        if (respBody.trim().isEmpty) return <String, dynamic>{};
        return jsonDecode(respBody);
      }
      throw K8sApiException.fromResponse(resp.statusCode, respBody, uri);
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
  /// Field manager name used for server-side apply.
  static const String fieldManager = 'vizxr';

  /// Splits a YAML stream (documents separated by `---`) or a JSON object
  /// into Kubernetes objects. Empty documents are skipped and a `kind: List`
  /// is expanded into its items. Throws [FormatException] on anything that
  /// is not an object.
  static List<Map<String, dynamic>> parseManifestDocuments(String text) {
    List<dynamic> docs;
    try {
      docs = loadYamlStream(text).toList();
    } on YamlException catch (yamlError) {
      try {
        docs = [jsonDecode(text)];
      } catch (_) {
        throw FormatException('Invalid YAML: ${yamlError.message}');
      }
    }

    final objects = <Map<String, dynamic>>[];
    void add(dynamic doc, int index) {
      if (doc == null) return;
      if (doc is! Map) {
        throw FormatException('Document ${index + 1} is not an object');
      }
      final map = _deepConvert(doc);
      if (map['kind'] == 'List' && map['items'] is List) {
        for (final item in map['items'] as List) {
          add(item, index);
        }
        return;
      }
      objects.add(map);
    }

    for (var i = 0; i < docs.length; i++) {
      add(docs[i], i);
    }
    return objects;
  }

  static Map<String, dynamic> _deepConvert(Map map) {
    dynamic convert(dynamic v) {
      if (v is Map) return _deepConvert(v);
      if (v is List) return v.map(convert).toList();
      return v;
    }

    return {for (final e in map.entries) e.key.toString(): convert(e.value)};
  }

  /// Applies every object in [yamlOrJsonString], like `kubectl apply
  /// --server-side`. Objects are applied in order and a failure does not
  /// stop the rest.
  Future<ManifestApplyResult> applyManifest(
    String yamlOrJsonString, {
    String? targetNamespace,
    bool forceConflicts = false,
  }) async {
    List<Map<String, dynamic>> docs;
    try {
      docs = parseManifestDocuments(yamlOrJsonString);
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Invalid manifest: $e');
    }
    if (docs.isEmpty) {
      return ManifestApplyResult(success: false, message: 'Invalid manifest: no objects found');
    }

    final results = <ManifestApplyResult>[];
    for (final doc in docs) {
      results.add(await _applyObject(doc, targetNamespace: targetNamespace, forceConflicts: forceConflicts));
    }
    if (results.length == 1) return results.first;

    final applied = results.where((r) => r.success).length;
    return ManifestApplyResult(
      success: applied == results.length,
      conflict: results.any((r) => r.conflict),
      message: '$applied of ${results.length} objects applied\n'
          '${results.map((r) => '${r.success ? 'OK' : 'FAILED'}  ${r.message}').join('\n')}',
      resource: results.lastWhere((r) => r.success, orElse: () => results.last).resource,
    );
  }

  Future<ManifestApplyResult> _applyObject(
    Map<String, dynamic> manifest, {
    String? targetNamespace,
    bool forceConflicts = false,
  }) async {
    try {
      final kind = manifest['kind']?.toString();
      final apiVersion = manifest['apiVersion']?.toString() ?? 'v1';
      final metadata = manifest['metadata'] is Map
          ? Map<String, dynamic>.from(manifest['metadata'] as Map)
          : <String, dynamic>{};
      final name = metadata['name']?.toString();
      if (kind == null || name == null) {
        return ManifestApplyResult(success: false, message: 'Manifest missing "kind" or "metadata.name"');
      }
      manifest['apiVersion'] = apiVersion;
      // Server-side apply rejects objects that carry managedFields, which
      // YAML copied from the inspector does.
      metadata.remove('managedFields');

      final clusterScoped = isClusterScopedKind(kind);
      String namespace = clusterScoped
          ? 'none'
          : (metadata['namespace']?.toString() ?? (targetNamespace ?? 'default'));
      if (namespace == 'all-namespaces') namespace = 'default';
      if (clusterScoped) {
        manifest['metadata'] = metadata..remove('namespace');
      } else {
        manifest['metadata'] = {...metadata, 'name': name, 'namespace': namespace};
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
      final resourcePath = endpointInfo['resourcePath']!;
      final resType = endpointInfo['type'] as K8sResourceType;

      // Server-side apply: one PATCH creates or updates the object, and the
      // API server merges fields the way `kubectl apply --server-side` does.
      final query = 'fieldManager=$fieldManager${forceConflicts ? '&force=true' : ''}';
      final where = clusterScoped || namespace == 'none' ? 'cluster-wide' : 'in namespace "$namespace"';
      try {
        final resp = await _request(
          'PATCH',
          '$resourcePath?$query',
          body: jsonEncode(manifest),
          contentType: 'application/apply-patch+yaml',
        );
        final applied = resp is Map<String, dynamic> && resp.isNotEmpty ? _parseResource(resType, resp) : null;
        return ManifestApplyResult(
          success: true,
          message: '$kind "$name" applied $where',
          resource: applied,
        );
      } on K8sApiException catch (e) {
        if (e.statusCode == 409) {
          return ManifestApplyResult(
            success: false,
            conflict: true,
            message: '$kind "$name": conflict with another field manager. $e',
          );
        }
        return ManifestApplyResult(success: false, message: '$kind "$name": $e');
      }
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Apply failed: $e');
    }
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
        // Any other kind: build the REST path from apiVersion and kind.
        // Core kinds (apiVersion "v1") live under /api/v1, the rest under
        // /apis/<group>/<version>. Previously an unknown core kind such as
        // Namespace or ServiceAccount was POSTed to the pods endpoint.
        final prefix = apiVersion.contains('/') ? '/apis/$apiVersion' : '/api/$apiVersion';
        final plural = pluralizeKind(kind);
        final isCluster = isClusterScopedKind(kind) ||
            namespace == 'none' ||
            namespace.isEmpty ||
            namespace == 'all-namespaces';
        final coll = isCluster ? '$prefix/$plural' : '$prefix/namespaces/$namespace/$plural';
        return {
          'collectionPath': coll,
          'resourcePath': '$coll/$name',
          'type': _typeFromKind(kind),
        };
    }
  }

  static const Set<String> _clusterScopedKinds = {
    'namespace',
    'node',
    'persistentvolume',
    'clusterrole',
    'clusterrolebinding',
    'storageclass',
    'customresourcedefinition',
    'priorityclass',
    'ingressclass',
    'runtimeclass',
    'csidriver',
    'csinode',
    'volumeattachment',
    'mutatingwebhookconfiguration',
    'validatingwebhookconfiguration',
    'validatingadmissionpolicy',
    'validatingadmissionpolicybinding',
    'apiservice',
    'certificatesigningrequest',
    'clusterissuer',
    'volumesnapshotclass',
  };

  /// Whether a built-in or well-known kind is cluster-scoped.
  static bool isClusterScopedKind(String kind) => _clusterScopedKinds.contains(kind.toLowerCase());

  /// Lower-case plural resource name for a kind, following the English rules
  /// Kubernetes uses (NetworkPolicy -> networkpolicies, Ingress -> ingresses).
  static String pluralizeKind(String kind) {
    final k = kind.toLowerCase();
    if (k == 'endpoints') return k;
    if (k.endsWith('s') || k.endsWith('x') || k.endsWith('ch') || k.endsWith('sh')) return '${k}es';
    if (k.length > 1 && k.endsWith('y') && !'aeiou'.contains(k[k.length - 2])) {
      return '${k.substring(0, k.length - 1)}ies';
    }
    return '${k}s';
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

    if (path.isEmpty) {
      throw UnsupportedError('Use deleteCustomResource() for custom resources');
    }

    final body = force ? {'gracePeriodSeconds': 0, 'propagationPolicy': 'Background'} : null;
    await _request('DELETE', path, body: body);
  }

  /// Fetch all CustomResourceDefinitions registered in the cluster
  Future<List<K8sResource>> fetchCustomResourceDefinitions() =>
      fetchResources(K8sResourceType.customResourceDefinition);

  /// REST path of one custom resource. Cluster-scoped resources have no
  /// `namespaces/<ns>` segment, whatever namespace the UI is showing.
  static String customResourcePath({
    required String group,
    required String version,
    required String plural,
    required String name,
    required String namespace,
    required bool clusterScoped,
  }) {
    final noNamespace = clusterScoped || namespace.isEmpty || namespace == 'none' || namespace == 'all-namespaces';
    return noNamespace
        ? '/apis/$group/$version/$plural/$name'
        : '/apis/$group/$version/namespaces/$namespace/$plural/$name';
  }

  Future<List<K8sResource>> fetchCustomResourceObjects({
    required String group,
    required String version,
    required String plural,
    String? namespace,
    bool clusterScoped = false,
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
          ann['scope'] = clusterScoped ? 'Cluster' : 'Namespaced';
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
    bool clusterScoped = false,
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

    final path = customResourcePath(
      group: group,
      version: version,
      plural: plural,
      name: name,
      namespace: namespace,
      clusterScoped: clusterScoped,
    );
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
    // Same patch as `kubectl rollout restart`. Errors propagate so the UI does
    // not report a restart that never happened.
    await _request('PATCH', '/apis/apps/v1/namespaces/$namespace/deployments/$name', body: {
      'spec': {
        'template': {
          'metadata': {
            'annotations': {'kubectl.kubernetes.io/restartedAt': DateTime.now().toUtc().toIso8601String()}
          }
        }
      }
    });
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

  /// Opens a WebSocket to a pod subresource such as `exec` or `portforward`,
  /// with this client's bearer token, CA, client certificate and
  /// skip-verify setting (the same HttpClient is used for the upgrade).
  ///
  /// [query] values may be a String or an Iterable<String> for repeated
  /// parameters (for example several `command` arguments).
  Future<WebSocket> openPodWebSocket({
    required String namespace,
    required String pod,
    required String subresource,
    required Map<String, dynamic> query,
    List<String> protocols = const ['v4.channel.k8s.io'],
  }) {
    final client = _httpClient;
    if (client == null) throw StateError('Kubernetes client is closed');
    final base = Uri.parse(effectiveBaseUrl);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    final uri = base.replace(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      path: '$basePath/api/v1/namespaces/${Uri.encodeComponent(namespace)}'
          '/pods/${Uri.encodeComponent(pod)}/$subresource',
      queryParameters: query,
    );
    return WebSocket.connect(
      uri.toString(),
      protocols: protocols,
      headers: {
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      compression: CompressionOptions.compressionOff,
      customClient: client,
    ).timeout(const Duration(seconds: 15));
  }

  /// Resolves a Service port to a running pod and container port, like
  /// `kubectl port-forward svc/NAME`: list pods matching the selector, take a
  /// Running one, and map `targetPort` (a number or a named container port).
  Future<PortForwardTarget> resolveServicePortForward(K8sResource service, {int? servicePort}) async {
    final spec = service.rawYaml['spec'] is Map ? service.rawYaml['spec'] as Map : const {};
    final selector = spec['selector'] is Map ? spec['selector'] as Map : const {};
    if (selector.isEmpty) {
      throw StateError('Service ${service.name} has no selector, so it has no pods to forward to');
    }
    final ports = spec['ports'] is List ? spec['ports'] as List : const [];
    Map portSpec = const {};
    for (final p in ports) {
      if (p is Map && (servicePort == null || p['port'] == servicePort)) {
        portSpec = p;
        break;
      }
    }
    if (portSpec.isEmpty) throw StateError('Service ${service.name} has no matching port');
    final svcPort = (portSpec['port'] as num?)?.toInt() ?? 0;

    final labelSelector = selector.entries.map((e) => '${e.key}=${e.value}').join(',');
    final json = await _request(
      'GET',
      '/api/v1/namespaces/${service.namespace}/pods?labelSelector=${Uri.encodeQueryComponent(labelSelector)}',
    );
    Map? pod;
    for (final item in (json['items'] as List?) ?? const []) {
      if (item is! Map) continue;
      final phase = item['status'] is Map ? (item['status'] as Map)['phase'] : null;
      final deleting = item['metadata'] is Map && (item['metadata'] as Map)['deletionTimestamp'] != null;
      if (phase == 'Running' && !deleting) {
        pod = item;
        break;
      }
    }
    if (pod == null) throw StateError('No running pod matches service ${service.name}');

    final targetPort = portSpec['targetPort'] ?? svcPort;
    int? containerPort;
    if (targetPort is num) {
      containerPort = targetPort.toInt();
    } else {
      final asInt = int.tryParse(targetPort.toString());
      if (asInt != null) {
        containerPort = asInt;
      } else {
        // Named port: look it up in the pod's containers.
        final podSpec = pod['spec'] is Map ? pod['spec'] as Map : const {};
        for (final c in (podSpec['containers'] as List?) ?? const []) {
          for (final p in (c is Map ? c['ports'] as List? : null) ?? const []) {
            if (p is Map && p['name'] == targetPort) {
              containerPort = (p['containerPort'] as num?)?.toInt();
            }
          }
        }
      }
    }
    if (containerPort == null) {
      throw StateError('Could not resolve target port "$targetPort" of service ${service.name}');
    }

    final meta = pod['metadata'] is Map ? pod['metadata'] as Map : const {};
    return PortForwardTarget(
      podName: meta['name']?.toString() ?? '',
      containerPort: containerPort,
      servicePort: svcPort,
    );
  }

  /// Current CPU (cores) and memory (bytes) of a pod, summed over its
  /// containers, from metrics.k8s.io. Null when metrics-server is missing,
  /// the pod has no sample yet, or in demo mode.
  Future<({double cpuCores, double memBytes})?> fetchPodMetrics(String namespace, String name) async {
    if (isDemo) return null;
    try {
      final json = await _request('GET', '/apis/metrics.k8s.io/v1beta1/namespaces/$namespace/pods/$name');
      var cpu = 0.0;
      var mem = 0.0;
      for (final c in (json['containers'] as List?) ?? const []) {
        if (c is! Map || c['usage'] is! Map) continue;
        final usage = c['usage'] as Map;
        cpu += K8sQuantity.tryParse(usage['cpu']) ?? 0;
        mem += K8sQuantity.tryParse(usage['memory']) ?? 0;
      }
      return (cpuCores: cpu, memBytes: mem);
    } catch (_) {
      return null;
    }
  }

  /// Usage of every pod in [namespace] (or the whole cluster), keyed by
  /// "namespace/name", from one metrics.k8s.io list call. Null when
  /// metrics-server is unavailable, and in demo mode.
  Future<Map<String, ({double cpuCores, double memBytes})>?> fetchPodMetricsList({String? namespace}) async {
    if (isDemo) return null;
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;
    try {
      final json = await _request(
        'GET',
        ns == null ? '/apis/metrics.k8s.io/v1beta1/pods' : '/apis/metrics.k8s.io/v1beta1/namespaces/$ns/pods',
      );
      return parsePodMetricsList(json is Map ? json : const {});
    } catch (_) {
      return null;
    }
  }

  /// Sums container usage per pod in a PodMetricsList.
  static Map<String, ({double cpuCores, double memBytes})> parsePodMetricsList(Map json) {
    final result = <String, ({double cpuCores, double memBytes})>{};
    for (final item in (json['items'] as List?) ?? const []) {
      if (item is! Map || item['metadata'] is! Map) continue;
      final meta = item['metadata'] as Map;
      final name = meta['name']?.toString();
      if (name == null) continue;
      var cpu = 0.0;
      var mem = 0.0;
      for (final c in (item['containers'] as List?) ?? const []) {
        if (c is! Map || c['usage'] is! Map) continue;
        final usage = c['usage'] as Map;
        cpu += K8sQuantity.tryParse(usage['cpu']) ?? 0;
        mem += K8sQuantity.tryParse(usage['memory']) ?? 0;
      }
      result['${meta['namespace'] ?? 'default'}/$name'] = (cpuCores: cpu, memBytes: mem);
    }
    return result;
  }

  /// Cluster-wide CPU and memory: allocatable from `/api/v1/nodes`, usage
  /// from `metrics.k8s.io/v1beta1` node metrics. When metrics-server is not
  /// installed (404) or not ready (503), usage is null and
  /// [ClusterMetrics.unavailableReason] says why.
  Future<ClusterMetrics> fetchClusterMetrics() async {
    if (isDemo) {
      final rnd = Random();
      return ClusterMetrics(
        nodeCount: 2,
        cpuAllocatableCores: 8,
        memAllocatableBytes: 16 * 1073741824.0,
        cpuUsageCores: 1.2 + rnd.nextDouble() * 0.4,
        memUsageBytes: (3.7 + rnd.nextDouble() * 0.2) * 1073741824.0,
      );
    }

    final nodes = await _request('GET', '/api/v1/nodes');
    Map<String, dynamic>? nodeMetrics;
    String? reason;
    try {
      final json = await _request('GET', '/apis/metrics.k8s.io/v1beta1/nodes');
      if (json is Map<String, dynamic>) nodeMetrics = json;
    } on K8sApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 503) {
        reason = 'Metrics unavailable: install metrics-server';
      } else if (e.statusCode == 403) {
        reason = 'Metrics unavailable: no permission to read metrics.k8s.io';
      } else {
        reason = 'Metrics unavailable: ${e.message}';
      }
    } catch (e) {
      reason = 'Metrics unavailable: $e';
    }

    return ClusterMetrics.fromLists(
      nodeList: nodes is Map<String, dynamic> ? nodes : null,
      nodeMetricsList: nodeMetrics,
      unavailableReason: reason,
    );
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

    // 1. k3s helm-controller HelmChart objects (helm.cattle.io/v1).
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
          final conditions = item['status'] is Map ? (item['status'] as Map)['conditions'] : null;
          final failed = conditions is List &&
              conditions.any((c) => c is Map && c['type'] == 'Failed' && c['status'] == 'True');
          releases.add(HelmRelease(
            name: meta['name']?.toString() ?? '',
            namespace: meta['namespace']?.toString() ?? 'default',
            chart: spec['chart']?.toString() ?? meta['name']?.toString() ?? '',
            version: spec['version']?.toString() ?? 'latest',
            appVersion: spec['version']?.toString() ?? '',
            revision: 1,
            status: failed ? 'failed' : 'applied',
            updated: _calculateAge(meta['creationTimestamp']?.toString()),
            valuesYaml: spec['valuesContent']?.toString() ?? '',
            source: HelmRelease.sourceK3s,
          ));
        }
      }
    } catch (_) {}

    // 2. Helm v3 releases, stored as Secrets labelled owner=helm with one
    //    Secret per revision. Keep the latest revision of each release.
    try {
      final path = ns != null
          ? '/api/v1/namespaces/$ns/secrets?labelSelector=owner%3Dhelm'
          : '/api/v1/secrets?labelSelector=owner%3Dhelm';
      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        final latest = <String, Map>{};
        final latestRevision = <String, int>{};
        for (final item in items) {
          if (item is! Map || item['type'] != 'helm.sh/release.v1') continue;
          final meta = item['metadata'] is Map ? item['metadata'] as Map : const {};
          final labels = meta['labels'] is Map ? meta['labels'] as Map : const {};
          final key = '${meta['namespace']}/${labels['name'] ?? meta['name']}';
          final revision = int.tryParse(labels['version']?.toString() ?? '') ?? 0;
          if (!latest.containsKey(key) || revision > latestRevision[key]!) {
            latest[key] = item;
            latestRevision[key] = revision;
          }
        }
        for (final secret in latest.values) {
          final release = decodeHelmReleaseSecret(secret);
          if (release != null) releases.add(release);
        }
      }
    } catch (_) {}

    releases.sort((a, b) {
      final byNs = a.namespace.compareTo(b.namespace);
      return byNs != 0 ? byNs : a.name.compareTo(b.name);
    });
    return releases;
  }

  /// Decodes a Helm v3 storage Secret (type helm.sh/release.v1).
  ///
  /// `data.release` is base64 (Secret encoding) of base64 (Helm's encoding)
  /// of a gzipped JSON release. Returns null when it cannot be decoded.
  static HelmRelease? decodeHelmReleaseSecret(Map secret) {
    try {
      final data = secret['data'];
      if (data is! Map || data['release'] == null) return null;
      final helmEncoded = utf8.decode(base64Decode(data['release'].toString().trim()));
      List<int> payload = base64Decode(helmEncoded.trim());
      if (payload.length > 2 && payload[0] == 0x1f && payload[1] == 0x8b) {
        payload = gzip.decode(payload);
      }
      final json = jsonDecode(utf8.decode(payload));
      if (json is! Map) return null;

      final info = json['info'] is Map ? json['info'] as Map : const {};
      final chart = json['chart'] is Map ? json['chart'] as Map : const {};
      final chartMeta = chart['metadata'] is Map ? chart['metadata'] as Map : const {};
      final config = json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : <String, dynamic>{};
      final lastDeployed = info['last_deployed']?.toString() ?? '';

      return HelmRelease(
        name: json['name']?.toString() ?? '',
        namespace: json['namespace']?.toString() ?? 'default',
        chart: chartMeta['name']?.toString() ?? '',
        version: chartMeta['version']?.toString() ?? '',
        appVersion: chartMeta['appVersion']?.toString() ?? '',
        revision: (json['version'] as num?)?.toInt() ?? 1,
        status: info['status']?.toString() ?? 'unknown',
        updated: lastDeployed.length >= 19 ? lastDeployed.substring(0, 19).replaceFirst('T', ' ') : lastDeployed,
        values: config,
        // JSON is valid YAML, and package:yaml has no writer.
        valuesYaml: config.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(config),
        source: HelmRelease.sourceHelm,
        description: info['description']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
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
      final result = await applyManifest(jsonEncode(payload));
      if (!result.success && result.message.contains('HTTP 404')) {
        return ManifestApplyResult(success: false, message: k3sHelmOnlyMessage);
      }
      return result;
    } catch (e) {
      return ManifestApplyResult(success: false, message: 'Failed to deploy chart: $e');
    }
  }

  /// Why chart installs are unavailable outside k3s.
  static const String k3sHelmOnlyMessage =
      'Installing charts needs the k3s helm-controller (HelmChart objects, helm.cattle.io/v1), which this '
      'cluster does not have. Install charts with the helm CLI; Vizxr lists the resulting releases read-only.';

  /// Whether the cluster serves helm.cattle.io/v1 (k3s and RKE2 ship its
  /// helm-controller). Without it Vizxr's Helm screen is read-only.
  Future<bool> hasK3sHelmController() async {
    if (isDemo) return true;
    try {
      await _request('GET', '/apis/helm.cattle.io/v1');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ManifestApplyResult> uninstallHelmRelease({
    required String name,
    required String namespace,
    String source = HelmRelease.sourceK3s,
  }) async {
    if (isDemo) {
      _mockHelmReleases.removeWhere((r) => r.name == name && r.namespace == namespace);
      return ManifestApplyResult(
        success: true,
        message: 'Helm release "$name" uninstalled successfully.',
      );
    }

    if (source != HelmRelease.sourceK3s) {
      return ManifestApplyResult(
        success: false,
        message: 'Helm v3 releases are read-only in Vizxr. Run "helm uninstall $name -n $namespace".',
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

    // Neither source supports a safe rollback over raw REST: Helm v3 rollback
    // needs the Helm SDK (re-render and three-way merge), and a k3s HelmChart
    // has no revision history. Do not report a rollback that never happened.
    return ManifestApplyResult(
      success: false,
      message: 'Rollback is not supported from Vizxr. Run "helm rollback $name $targetRevision -n $namespace".',
    );
  }
}

extension K8sResourceTypeExtension on K8sResourceType {
  String get name => toString().split('.').last;
}
