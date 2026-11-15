import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vizxr/services/k8s_channel.dart';

void main() {
  test('encode prefixes the channel byte', () {
    final frame = K8sChannel.encode(K8sChannel.stdin, utf8.encode('ls\r'));
    expect(frame, [0, 108, 115, 13]);
  });

  test('decode splits channel and payload', () {
    final frame = K8sChannel.decode([1, 104, 105])!;
    expect(frame.channel, K8sChannel.stdout);
    expect(utf8.decode(frame.data), 'hi');
    expect(K8sChannel.decode(<int>[]), isNull);
  });

  test('resize frame is channel 4 JSON', () {
    final frame = K8sChannel.resizeFrame(80, 24);
    expect(frame.first, 4);
    expect(jsonDecode(utf8.decode(frame.sublist(1))), {'Width': 80, 'Height': 24});
  });

  test('parseStatus reads success and exit codes', () {
    final ok = K8sChannel.parseStatus(utf8.encode('{"metadata":{},"status":"Success"}'));
    expect(ok.success, isTrue);
    expect(ok.exitCode, 0);

    final failed = K8sChannel.parseStatus(utf8.encode(
      '{"metadata":{},"status":"Failure","message":"command terminated with non-zero exit code: 2",'
      '"reason":"NonZeroExitCode","details":{"causes":[{"reason":"ExitCode","message":"2"}]}}',
    ));
    expect(failed.success, isFalse);
    expect(failed.exitCode, 2);
    expect(failed.message, contains('non-zero exit code'));

    final raw = K8sChannel.parseStatus(utf8.encode('not json'));
    expect(raw.success, isFalse);
    expect(raw.message, 'not json');
  });

  test('readPort is little-endian', () {
    expect(K8sChannel.readPort([0x50, 0x00]), 80);
    expect(K8sChannel.readPort([0x90, 0x1f]), 8080);
  });
}
