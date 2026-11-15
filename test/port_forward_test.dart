import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/port_forward_service.dart';

void main() {
  test('preferredLocalPort avoids privileged ports', () {
    expect(PortForwardService.preferredLocalPort(80), 8080);
    expect(PortForwardService.preferredLocalPort(443), 8443);
    expect(PortForwardService.preferredLocalPort(5432), 5432);
  });

  test('demo clusters refuse to fake a forward', () async {
    final client = K8sClientService(baseUrl: 'https://demo.k8s.local');
    await expectLater(
      PortForwardService.startForward(
        client: client,
        namespace: 'default',
        podName: 'web',
        containerPort: 80,
      ),
      throwsUnsupportedError,
    );
    expect(PortForwardService.activeForwards, isEmpty);
  });

  test('a forward listens on loopback and can be stopped', () async {
    final client = K8sClientService(baseUrl: 'https://10.255.255.1:6443');
    final forward = await PortForwardService.startForward(
      client: client,
      namespace: 'default',
      podName: 'web',
      containerPort: 8080,
      localPort: 0,
    );
    expect(forward.localPort, greaterThan(0));
    expect(PortForwardService.activeForwards, contains(forward));
    await PortForwardService.stopForward(forward);
    expect(PortForwardService.activeForwards, isEmpty);
    client.close();
  });
}
