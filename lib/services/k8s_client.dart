import 'dart:convert';
import 'package:kubernetes/kubernetes.dart';

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
  final double cpuUsage; // Mock metrics
  final double memUsage; // Mock metrics

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
  });
}

class K8sClientService {
  final String baseUrl;
  final String? token;
  K8sClientService({required this.baseUrl, this.token});

  Future<List<K8sResource>> fetchResources(K8sResourceType type, {String? namespace}) async {
    // Mock the kubernetes client since we don't have ApiClient properly set up here
    return _getMockData(type, namespace);
  }

  List<K8sResource> _getMockData(K8sResourceType type, String? ns) {
    switch (type) {
      case K8sResourceType.pod:
        return [
          K8sResource(name: 'nginx-7fb96c846-abcde', namespace: 'default', status: 'Running', age: '2h', type: type, rawYaml: {'apiVersion': 'v1', 'kind': 'Pod'}, cpuUsage: 0.12, memUsage: 45.5),
          K8sResource(name: 'redis-master-0', namespace: 'redis', status: 'Running', age: '5d', type: type, rawYaml: {}, cpuUsage: 0.05, memUsage: 128.0),
        ];
      case K8sResourceType.deployment:
        return [
          K8sResource(name: 'backend-api', namespace: 'production', status: '2/2 Ready', age: '45d', type: type, rawYaml: {}),
        ];
      case K8sResourceType.statefulSet:
        return [
          K8sResource(name: 'mongodb', namespace: 'database', status: '3/3 Ready', age: '12d', type: type, rawYaml: {}),
        ];
      case K8sResourceType.service:
        return [
          K8sResource(name: 'kubernetes', namespace: 'default', status: 'ClusterIP', age: '30d', type: type, rawYaml: {}),
          K8sResource(name: 'nginx-service', namespace: 'default', status: 'LoadBalancer', age: '2d', type: type, rawYaml: {}),
          K8sResource(name: 'db-service', namespace: 'database', status: 'ClusterIP', age: '12d', type: type, rawYaml: {}),
        ];
      case K8sResourceType.ingress:
        return [
          K8sResource(name: 'main-ingress', namespace: 'default', status: '1.2.3.4', age: '2d', type: type, rawYaml: {}),
        ];
      case K8sResourceType.persistentVolumeClaim:
        return [
          K8sResource(name: 'data-pvc', namespace: 'default', status: 'Bound', age: '5d', type: type, rawYaml: {}),
          K8sResource(name: 'mongo-storage', namespace: 'database', status: 'Bound', age: '12d', type: type, rawYaml: {}),
        ];
      case K8sResourceType.node:
        return [
          K8sResource(name: 'ai2th-k8s-node-1', namespace: 'none', status: 'Ready', age: '30d', type: type, rawYaml: {}),
        ];
      default:
        return [
          K8sResource(name: 'mock-${type.name}-1', namespace: ns ?? 'default', status: 'Active', age: '1h', type: type, rawYaml: {}),
        ];
    }
  }

  Future<void> deleteResource(K8sResourceType type, String name, String namespace) async {
    // In real implementation: coreApi.deleteNamespacedPod(name, namespace)
    print('Deleting ${type.name}: $name in $namespace');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> scaleDeployment(String name, String namespace, int replicas) async {
    // In real implementation: appsApi.patchNamespacedDeploymentScale(...)
    print('Scaling deployment $name to $replicas replicas');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Stream<String> streamLogs(String podName, {String namespace = 'default'}) async* {
    // Mock log stream for testing
    yield 'Initializing log stream for pod: $podName...\n';
    await Future.delayed(const Duration(milliseconds: 500));
    yield 'Server started on port 8080\n';
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      yield '[${DateTime.now().toIso8601String()}] Connection received from 10.0.$i.${i * 2}\n';
    }
    yield 'Stream ended unexpectedly.\n';
  }

  Future<List<K8sResource>> fetchEvents({String? namespace}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      K8sResource(name: 'Scheduled', namespace: 'default', status: 'Normal', age: '10m', type: K8sResourceType.pod, rawYaml: {},
        message: 'Successfully assigned default/nginx-7fb96c846-abcde to node-1'),
      K8sResource(name: 'BackOff', namespace: 'default', status: 'Warning', age: '2m', type: K8sResourceType.pod, rawYaml: {},
        message: 'Back-off restarting failed container'),
    ];
  }
}

extension on K8sResourceType {
  String get name => toString().split('.').last;
}
