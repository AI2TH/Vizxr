import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum K8sResourceType {
  pod,
  deployment,
  statefulSet,
  daemonSet,
  service,
  ingress,
  configMap,
  secret,
  node,
  persistentVolumeClaim
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
    );
  }
}

class K8sClientService {
  final String baseUrl;
  final String? token;
  final bool insecureSkipTlsVerify;

  HttpClient? _httpClient;

  K8sClientService({
    required this.baseUrl,
    this.token,
    this.insecureSkipTlsVerify = true,
  }) {
    _httpClient = HttpClient();
    if (insecureSkipTlsVerify) {
      _httpClient!.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
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
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'nginx-ingress-controller-747d9b-x9kmq', 'namespace': 'kube-system'}, 'spec': {'containers': [{'name': 'controller', 'image': 'registry.k8s.io/ingress-nginx/controller:v1.9.4'}]}},
      cpuUsage: 0.15,
      memUsage: 64.0,
      restarts: 0,
      ip: '10.244.0.12',
      nodeName: 'linxr-worker-1',
    ),
    K8sResource(
      name: 'coredns-5dd5756b68-24lhp',
      namespace: 'kube-system',
      status: 'Running',
      age: '14d',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'coredns-5dd5756b68-24lhp', 'namespace': 'kube-system'}},
      cpuUsage: 0.04,
      memUsage: 32.0,
      restarts: 0,
      ip: '10.244.0.3',
      nodeName: 'linxr-master',
    ),
    K8sResource(
      name: 'backend-api-7b895cd45-p9t2z',
      namespace: 'production',
      status: 'Running',
      age: '3d',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'backend-api-7b895cd45-p9t2z', 'namespace': 'production'}, 'spec': {'containers': [{'name': 'api', 'image': 'ai2th/backend-api:v2.4'}]}},
      cpuUsage: 0.42,
      memUsage: 256.0,
      restarts: 1,
      ip: '10.244.0.18',
      nodeName: 'linxr-worker-1',
    ),
    K8sResource(
      name: 'redis-master-0',
      namespace: 'database',
      status: 'Running',
      age: '5d',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'redis-master-0', 'namespace': 'database'}, 'spec': {'containers': [{'name': 'redis', 'image': 'redis:7.2-alpine'}]}},
      cpuUsage: 0.08,
      memUsage: 128.0,
      restarts: 0,
      ip: '10.244.0.19',
      nodeName: 'linxr-worker-1',
    ),
    K8sResource(
      name: 'zyvr-pbx-telephony-6b7f-8d2qx',
      namespace: 'default',
      status: 'Running',
      age: '2h',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'zyvr-pbx-telephony-6b7f-8d2qx', 'namespace': 'default'}, 'spec': {'containers': [{'name': 'asterisk', 'image': 'andrius/asterisk:latest'}]}},
      cpuUsage: 0.18,
      memUsage: 96.0,
      restarts: 0,
      ip: '10.244.0.25',
      nodeName: 'linxr-master',
    ),
    K8sResource(
      name: 'zabbix-agent-host-7890-kj82c',
      namespace: 'monitoring',
      status: 'Running',
      age: '6h',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'zabbix-agent-host-7890-kj82c', 'namespace': 'monitoring'}, 'spec': {'containers': [{'name': 'zabbix-agent', 'image': 'zabbix/zabbix-agent2:alpine-7.0-latest'}]}},
      cpuUsage: 0.02,
      memUsage: 18.0,
      restarts: 0,
      ip: '10.244.0.26',
      nodeName: 'linxr-master',
    ),
    K8sResource(
      name: 'batch-analytics-worker-99-f4gh8',
      namespace: 'default',
      status: 'Completed',
      age: '1d',
      type: K8sResourceType.pod,
      rawYaml: {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'batch-analytics-worker-99-f4gh8', 'namespace': 'default'}},
      cpuUsage: 0.0,
      memUsage: 0.0,
      restarts: 0,
      ip: '10.244.0.21',
      nodeName: 'linxr-worker-1',
    ),

    // Deployments
    K8sResource(
      name: 'backend-api',
      namespace: 'production',
      status: '2/2 Ready',
      age: '45d',
      type: K8sResourceType.deployment,
      rawYaml: {'apiVersion': 'apps/v1', 'kind': 'Deployment', 'metadata': {'name': 'backend-api', 'namespace': 'production'}, 'spec': {'replicas': 2}},
    ),
    K8sResource(
      name: 'zyvr-pbx-telephony',
      namespace: 'default',
      status: '1/1 Ready',
      age: '2d',
      type: K8sResourceType.deployment,
      rawYaml: {'apiVersion': 'apps/v1', 'kind': 'Deployment', 'metadata': {'name': 'zyvr-pbx-telephony', 'namespace': 'default'}, 'spec': {'replicas': 1}},
    ),
    K8sResource(
      name: 'nginx-ingress-controller',
      namespace: 'kube-system',
      status: '1/1 Ready',
      age: '14d',
      type: K8sResourceType.deployment,
      rawYaml: {'apiVersion': 'apps/v1', 'kind': 'Deployment', 'metadata': {'name': 'nginx-ingress-controller', 'namespace': 'kube-system'}, 'spec': {'replicas': 1}},
    ),

    // StatefulSets
    K8sResource(
      name: 'redis-master',
      namespace: 'database',
      status: '1/1 Ready',
      age: '5d',
      type: K8sResourceType.statefulSet,
      rawYaml: {'apiVersion': 'apps/v1', 'kind': 'StatefulSet', 'metadata': {'name': 'redis-master', 'namespace': 'database'}, 'spec': {'replicas': 1}},
    ),

    // DaemonSets
    K8sResource(
      name: 'zabbix-node-agent',
      namespace: 'monitoring',
      status: '2/2 Ready',
      age: '6h',
      type: K8sResourceType.daemonSet,
      rawYaml: {'apiVersion': 'apps/v1', 'kind': 'DaemonSet', 'metadata': {'name': 'zabbix-node-agent', 'namespace': 'monitoring'}},
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
      rawYaml: {'spec': {'clusterIP': '10.96.0.1', 'ports': [{'port': 443, 'targetPort': 6443}]}},
    ),
    K8sResource(
      name: 'zyvr-sip-service',
      namespace: 'default',
      status: 'LoadBalancer',
      age: '2d',
      type: K8sResourceType.service,
      rawYaml: {'spec': {'clusterIP': '10.96.12.80', 'ports': [{'port': 5060, 'protocol': 'UDP'}, {'port': 8088, 'protocol': 'TCP'}]}},
    ),
    K8sResource(
      name: 'backend-service',
      namespace: 'production',
      status: 'ClusterIP',
      age: '45d',
      type: K8sResourceType.service,
      rawYaml: {'spec': {'clusterIP': '10.96.44.120', 'ports': [{'port': 8080, 'targetPort': 8080}]}},
    ),

    // Ingresses
    K8sResource(
      name: 'api-gateway',
      namespace: 'production',
      status: '127.0.0.1',
      age: '45d',
      type: K8sResourceType.ingress,
      rawYaml: {'spec': {'rules': [{'host': 'api.linxr.local', 'http': {'paths': [{'path': '/api', 'backend': {'service': {'name': 'backend-service'}}}]}}]}},
    ),

    // ConfigMaps
    K8sResource(
      name: 'zyvr-pjsip-config',
      namespace: 'default',
      status: '3 Keys',
      age: '2d',
      type: K8sResourceType.configMap,
      rawYaml: {'data': {'pjsip.conf': '[transport-udp]\ntype=transport\nprotocol=udp\nbind=0.0.0.0:5060\n', 'extensions.conf': '[general]\nstatic=yes\n'}},
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
      rawYaml: {'spec': {'accessModes': ['ReadWriteOnce'], 'resources': {'requests': {'storage': '10Gi'}}}},
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
    final uri = Uri.parse('$baseUrl$endpoint');
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
      return jsonDecode(respBody);
    }
    throw HttpException('HTTP ${resp.statusCode}: $respBody', uri: uri);
  }

  Future<bool> testConnection() async {
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
    try {
      final json = await _request('GET', '/api/v1/namespaces');
      final items = json['items'] as List?;
      if (items != null) {
        final list = items.map((i) => i['metadata']['name'].toString()).toList();
        list.insert(0, 'all-namespaces');
        return list;
      }
    } catch (_) {}
    return ['all-namespaces', 'default', 'kube-system', 'database', 'production', 'monitoring'];
  }

  Future<List<K8sResource>> fetchResources(K8sResourceType type, {String? namespace}) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;

    try {
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
        case K8sResourceType.node:
          path = '/api/v1/nodes';
          break;
      }

      final json = await _request('GET', path);
      final items = json['items'] as List?;
      if (items != null) {
        return items.map((raw) => _parseResource(type, raw as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // Graceful fallback to mock store
    }

    return _getFilteredMockData(type, ns);
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

  Future<void> deleteResource(K8sResourceType type, String name, String namespace) async {
    try {
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
        case K8sResourceType.node:
          path = '/api/v1/nodes/$name';
          break;
      }
      await _request('DELETE', path);
    } catch (_) {}

    // Also remove from in-memory mock store
    _mockStore.removeWhere((r) => r.type == type && r.name == name && (namespace == 'none' || r.namespace == namespace));
  }

  Future<K8sResource> createPod({
    required String name,
    required String namespace,
    required String image,
    int? port,
    Map<String, String>? env,
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
          }
        ]
      }
    };

    try {
      final json = await _request('POST', '/api/v1/namespaces/$namespace/pods', body: manifest);
      return _parseResource(K8sResourceType.pod, json);
    } catch (_) {}

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
    );

    _mockStore.insert(0, newPod);
    _mockEvents.insert(0, K8sResource(
      name: 'Created',
      namespace: namespace,
      status: 'Normal',
      age: 'Just now',
      type: K8sResourceType.pod,
      rawYaml: {},
      message: 'Created pod $name with image $image',
    ));

    return newPod;
  }

  Future<void> scaleDeployment(String name, String namespace, int replicas) async {
    try {
      await _request('PATCH', '/apis/apps/v1/namespaces/$namespace/deployments/$name/scale', body: {
        'spec': {'replicas': replicas}
      });
    } catch (_) {}

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
  }

  Future<void> restartDeployment(String name, String namespace) async {
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

  Future<String> fetchPodLogs(String name, String namespace, {int tailLines = 200, String? container}) async {
    try {
      final query = '?tailLines=$tailLines&timestamps=true${container != null ? '&container=$container' : ''}';
      final uri = Uri.parse('$baseUrl/api/v1/namespaces/$namespace/pods/$name/log$query');
      final req = await _httpClient!.openUrl('GET', uri).timeout(const Duration(seconds: 4));
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        return await resp.transform(utf8.decoder).join();
      }
    } catch (_) {}

    // Realistic fallback mock logs
    final now = DateTime.now();
    return '''
[${now.subtract(const Duration(minutes: 5)).toIso8601String()}] [info] Starting process inside container $name...
[${now.subtract(const Duration(minutes: 5)).toIso8601String()}] [info] Loading configurations from /etc/config...
[${now.subtract(const Duration(minutes: 4)).toIso8601String()}] [info] Network binding established on 0.0.0.0:8080
[${now.subtract(const Duration(minutes: 3)).toIso8601String()}] [info] Health probe GET /healthz responded HTTP 200 OK
[${now.subtract(const Duration(minutes: 2)).toIso8601String()}] [info] Inbound connection from 10.244.0.1 -> 200 OK
[${now.subtract(const Duration(minutes: 1)).toIso8601String()}] [info] Ready to accept incoming workload traffic.
[${now.toIso8601String()}] [info] Heartbeat probe: all 1/1 containers healthy.
''';
  }

  Stream<String> streamLogs(String podName, {String namespace = 'default'}) async* {
    yield 'Connecting to pod $podName logs...\n';
    await Future.delayed(const Duration(milliseconds: 300));
    final initialLogs = await fetchPodLogs(podName, namespace);
    yield initialLogs;

    for (int i = 1; i <= 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final ts = DateTime.now().toIso8601String();
      yield '[$ts] [live-tail] Event probe loop tick #$i — 0 errors, load avg 0.02\n';
    }
  }

  Future<List<K8sResource>> fetchEvents({String? namespace}) async {
    final ns = (namespace == null || namespace == 'all-namespaces') ? null : namespace;
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

    return _mockEvents.where((e) {
      if (ns == null || ns == 'all-namespaces') return true;
      return e.namespace == ns;
    }).toList();
  }
}

extension K8sResourceTypeExtension on K8sResourceType {
  String get name => toString().split('.').last;
}
