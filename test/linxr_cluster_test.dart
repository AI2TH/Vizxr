import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizxr/services/k8s_client.dart';
import 'package:vizxr/services/kubeconfig.dart';
import 'package:vizxr/services/secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KubeConfig.secretStore = MemorySecretStore();
  });

  test('a normal cluster on 127.0.0.1 gets no hidden 172.16.0.2 retry', () {
    final config = KubeConfig(name: 'kind', server: 'https://127.0.0.1:6443');
    expect(config.kind, ClusterKind.remote);
    expect(config.fallbackServers, isEmpty);

    final client = K8sClientService(baseUrl: config.server, fallbackBaseUrls: config.fallbackServers);
    expect(client.candidateBaseUrls, ['https://127.0.0.1:6443']);
    client.close();
  });

  test('"Linxr on this phone" tries the other Linxr address on the same port', () {
    final loopback = KubeConfig.linxrOnThisPhone();
    expect(loopback.kind, ClusterKind.linxrOnPhone);
    expect(loopback.fallbackServers, ['https://172.16.0.2:6443']);

    final vm = KubeConfig.linxrOnThisPhone(server: 'https://172.16.0.2:16443');
    expect(vm.fallbackServers, ['https://127.0.0.1:16443']);

    final client = K8sClientService(baseUrl: vm.server, fallbackBaseUrls: vm.fallbackServers);
    expect(client.candidateBaseUrls, ['https://172.16.0.2:16443', 'https://127.0.0.1:16443']);
    client.close();
  });

  test('cluster kind survives a save and load', () async {
    final config = KubeConfig(name: 'phone', server: 'https://10.0.0.1:6443', kind: ClusterKind.linxrOnPhone);
    await KubeConfig.saveConfig(config);
    final loaded = (await KubeConfig.loadConfigs()).firstWhere((c) => c.id == config.id);
    expect(loaded.kind, ClusterKind.linxrOnPhone);
  });

  test('configs saved before cluster kinds keep the Linxr retry only for Linxr addresses', () async {
    SharedPreferences.setMockInitialValues({
      'vizxr_kubeconfigs': [
        '{"name":"Linxr Local Cluster","server":"https://127.0.0.1:6443","insecureSkipTlsVerify":true}',
        '{"name":"k3s-vm","server":"https://172.16.0.2:6443"}',
        '{"name":"cloud","server":"https://k8s.example.com"}',
      ],
    });
    final configs = await KubeConfig.loadConfigs();
    ClusterKind kindOf(String name) => configs.firstWhere((c) => c.name == name).kind;
    expect(kindOf('Linxr Local Cluster'), ClusterKind.linxrOnPhone);
    expect(kindOf('k3s-vm'), ClusterKind.linxrOnPhone);
    expect(kindOf('cloud'), ClusterKind.remote);
    // The legacy entry takes the built-in id, so no second Linxr entry is added.
    expect(configs.where((c) => c.kind == ClusterKind.linxrOnPhone && c.server.contains('127.0.0.1')), hasLength(1));
  });
}
