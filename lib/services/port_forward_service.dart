import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'k8s_channel.dart';
import 'k8s_client.dart';

/// One local port forwarded to a pod port.
class PortForward {
  final String namespace;
  final String podName;
  final int containerPort;
  final int localPort;

  /// What the user picked, for display (for example `svc/web:80`).
  final String label;

  final ServerSocket _server;
  final Set<Socket> _sockets = {};
  final Set<WebSocket> _webSockets = {};

  bool isActive = true;
  int totalConnections = 0;
  String? lastError;

  PortForward._({
    required this.namespace,
    required this.podName,
    required this.containerPort,
    required this.localPort,
    required this.label,
    required ServerSocket server,
  }) : _server = server;

  int get openConnections => _sockets.length;

  String get localUrl => 'http://localhost:$localPort';

  /// URL to open in a browser: https for the usual TLS ports, http otherwise.
  String get browserUrl => browserUrlFor(containerPort, localPort);

  static String browserUrlFor(int remotePort, int localPort) {
    const tlsPorts = {443, 8443, 9443};
    final scheme = tlsPorts.contains(remotePort) ? 'https' : 'http';
    return '$scheme://localhost:$localPort';
  }
}

/// Forwards local TCP ports to pod ports through the Kubernetes
/// `portforward` subresource (WebSocket, `v4.channel.k8s.io`).
///
/// Each accepted local connection gets its own WebSocket. With one port per
/// WebSocket, channel 0 carries data and channel 1 carries errors; the
/// server starts each channel with the port number as 2 little-endian bytes.
class PortForwardService {
  PortForwardService._();

  static final List<PortForward> _forwards = [];

  /// Bumped whenever a forward starts, stops or changes state, so the UI can
  /// rebuild.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static List<PortForward> get activeForwards => List.unmodifiable(_forwards);

  static void _notify() => changes.value++;

  /// Local port to try first: the same port when it is unprivileged,
  /// otherwise 8000 + port (80 -> 8080, 443 -> 8443).
  static int preferredLocalPort(int remotePort) => remotePort >= 1024 ? remotePort : 8000 + remotePort;

  /// Starts listening on 127.0.0.1 and forwards each connection to
  /// [podName]:[containerPort]. Falls back to a free port when [localPort]
  /// is taken.
  static Future<PortForward> startForward({
    required K8sClientService client,
    required String namespace,
    required String podName,
    required int containerPort,
    int? localPort,
    String? label,
  }) async {
    if (client.isDemo) {
      throw UnsupportedError('Port forwarding needs a live cluster; the demo cluster has no pods to reach.');
    }
    final wanted = localPort ?? preferredLocalPort(containerPort);
    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, wanted);
    } on SocketException {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    }

    final forward = PortForward._(
      namespace: namespace,
      podName: podName,
      containerPort: containerPort,
      localPort: server.port,
      label: label ?? 'pod/$podName:$containerPort',
      server: server,
    );
    server.listen(
      (socket) => _handleConnection(client, forward, socket),
      onError: (Object e) {
        forward.lastError = e.toString();
        _notify();
      },
      onDone: () {
        forward.isActive = false;
        _notify();
      },
    );
    _forwards.add(forward);
    _notify();
    return forward;
  }

  static Future<void> _handleConnection(K8sClientService client, PortForward forward, Socket socket) async {
    forward._sockets.add(socket);
    forward.totalConnections++;
    _notify();

    WebSocket? opened;
    try {
      opened = await client.openPodWebSocket(
        namespace: forward.namespace,
        pod: forward.podName,
        subresource: 'portforward',
        query: {'ports': '${forward.containerPort}'},
      );
    } catch (e) {
      forward.lastError = 'Could not open tunnel: $e';
    }
    if (opened == null) {
      forward._sockets.remove(socket);
      socket.destroy();
      _notify();
      return;
    }
    final ws = opened;
    if (!forward.isActive) {
      ws.close();
      forward._sockets.remove(socket);
      socket.destroy();
      return;
    }
    forward._webSockets.add(ws);

    var closed = false;
    var dataPrefixSeen = false;
    var errorPrefixSeen = false;
    StreamSubscription<dynamic>? wsSub;
    StreamSubscription<List<int>>? socketSub;

    void closeBoth() {
      if (closed) return;
      closed = true;
      wsSub?.cancel();
      socketSub?.cancel();
      ws.close();
      socket.destroy();
      forward._webSockets.remove(ws);
      forward._sockets.remove(socket);
      _notify();
    }

    wsSub = ws.listen(
      (message) {
        final frame = K8sChannel.decode(message);
        if (frame == null) return;
        List<int> data = frame.data;
        if (frame.channel == 0) {
          if (!dataPrefixSeen) {
            if (data.length < 2) return;
            dataPrefixSeen = true;
            data = data.sublist(2);
          }
          if (data.isNotEmpty) socket.add(data);
        } else if (frame.channel == 1) {
          if (!errorPrefixSeen) {
            if (data.length < 2) return;
            errorPrefixSeen = true;
            data = data.sublist(2);
          }
          if (data.isNotEmpty) {
            forward.lastError = utf8.decode(data, allowMalformed: true).trim();
            closeBoth();
          }
        }
      },
      onDone: closeBoth,
      onError: (Object e) {
        forward.lastError = e.toString();
        closeBoth();
      },
      cancelOnError: true,
    );

    socketSub = socket.listen(
      (data) => ws.add(K8sChannel.encode(0, data)),
      onDone: closeBoth,
      onError: (Object _) => closeBoth(),
      cancelOnError: true,
    );
  }

  static Future<void> stopForward(PortForward forward) async {
    forward.isActive = false;
    _forwards.remove(forward);
    for (final ws in List<WebSocket>.of(forward._webSockets)) {
      ws.close();
    }
    for (final socket in List<Socket>.of(forward._sockets)) {
      socket.destroy();
    }
    forward._webSockets.clear();
    forward._sockets.clear();
    await forward._server.close();
    _notify();
  }

  /// Stops every forward, for example when the active cluster changes.
  static Future<void> stopAll() async {
    for (final forward in List<PortForward>.of(_forwards)) {
      await stopForward(forward);
    }
  }
}
