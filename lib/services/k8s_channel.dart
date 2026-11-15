import 'dart:convert';
import 'dart:typed_data';

/// One frame of the Kubernetes `v4.channel.k8s.io` WebSocket protocol used by
/// the exec, attach and portforward subresources: the first byte is the
/// channel number, the rest is the payload.
class K8sChannelFrame {
  final int channel;
  final Uint8List data;

  const K8sChannelFrame(this.channel, this.data);
}

/// Result of an exec session, from the JSON `Status` sent on channel 3.
class K8sExecStatus {
  final bool success;
  final String message;
  final int? exitCode;

  const K8sExecStatus({required this.success, required this.message, this.exitCode});
}

class K8sChannel {
  K8sChannel._();

  /// The protocol requested from the API server.
  static const String protocol = 'v4.channel.k8s.io';

  // Exec / attach channels.
  static const int stdin = 0;
  static const int stdout = 1;
  static const int stderr = 2;
  static const int error = 3;
  static const int resize = 4;

  /// Prefixes [data] with the [channel] byte.
  static Uint8List encode(int channel, List<int> data) {
    final out = Uint8List(data.length + 1);
    out[0] = channel;
    out.setRange(1, out.length, data);
    return out;
  }

  /// Splits a received WebSocket message into channel and payload. Returns
  /// null for an empty message.
  static K8sChannelFrame? decode(dynamic message) {
    final List<int> bytes;
    if (message is List<int>) {
      bytes = message;
    } else if (message is String) {
      bytes = utf8.encode(message);
    } else {
      return null;
    }
    if (bytes.isEmpty) return null;
    return K8sChannelFrame(bytes[0], Uint8List.fromList(bytes.sublist(1)));
  }

  /// The terminal-size message for channel 4.
  static Uint8List resizeFrame(int width, int height) =>
      encode(resize, utf8.encode(jsonEncode({'Width': width, 'Height': height})));

  /// Parses the `Status` object sent on the error channel when an exec ends
  /// or is refused.
  static K8sExecStatus parseStatus(List<int> data) {
    final text = utf8.decode(data, allowMalformed: true);
    try {
      final json = jsonDecode(text);
      if (json is Map) {
        final success = json['status'] == 'Success';
        int? exitCode = success ? 0 : null;
        final causes = (json['details'] is Map) ? (json['details'] as Map)['causes'] : null;
        if (causes is List) {
          for (final c in causes) {
            if (c is Map && c['reason'] == 'ExitCode') {
              exitCode = int.tryParse(c['message']?.toString() ?? '');
            }
          }
        }
        return K8sExecStatus(
          success: success,
          message: json['message']?.toString() ?? (success ? 'Success' : text),
          exitCode: exitCode,
        );
      }
    } catch (_) {}
    return K8sExecStatus(success: false, message: text);
  }

  /// Reads the 2-byte little-endian port number that starts each portforward
  /// channel.
  static int readPort(List<int> data) => data[0] | (data[1] << 8);
}
