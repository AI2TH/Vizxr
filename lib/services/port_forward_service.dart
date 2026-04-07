import 'dart:async';

class PortForward {
  final String podName;
  final int containerPort;
  final int localPort;
  bool isActive;

  PortForward({
    required this.podName,
    required this.containerPort,
    required this.localPort,
    this.isActive = false,
  });
}

class PortForwardService {
  static final List<PortForward> _forwards = [];

  static List<PortForward> get activeForwards => _forwards;

  static Future<void> startForward(String podName, int containerPort, int localPort) async {
    // In a real implementation, this would use the K8s SPDY/HTTP2 protocol
    // to tunnel traffic from a local socket to the K8s API server.
    _forwards.add(PortForward(
      podName: podName,
      containerPort: containerPort,
      localPort: localPort,
      isActive: true,
    ));
  }

  static void stopForward(PortForward forward) {
    _forwards.remove(forward);
  }
}
