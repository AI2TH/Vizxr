import 'dart:convert';

/// Writes JSON-like data (maps, lists, strings, numbers, booleans, null) as
/// block-style YAML, the way `kubectl get -o yaml` prints objects.
///
/// Strings that YAML would read as another type ("true", "8080", "null"...)
/// or that contain YAML syntax are double-quoted; multi-line strings use a
/// literal block (`|`) when that is lossless. `loadYaml(toYaml(x))` equals x.
String toYaml(Object? value) {
  final out = StringBuffer();
  if (value is Map && value.isNotEmpty) {
    _writeMap(out, value, 0, indentFirst: true);
  } else if (value is List && value.isNotEmpty) {
    _writeList(out, value, 0);
  } else {
    out.writeln(_scalar(value, 2));
  }
  return out.toString();
}

/// A Kubernetes object as YAML, without `metadata.managedFields`
/// (hidden by kubectl too unless --show-managed-fields is given).
String manifestToYaml(Map<String, dynamic> object) {
  final copy = Map<String, dynamic>.from(object);
  final metadata = copy['metadata'];
  if (metadata is Map && metadata.containsKey('managedFields')) {
    copy['metadata'] = Map<String, dynamic>.from(metadata)..remove('managedFields');
  }
  return toYaml(copy);
}

void _writeMap(StringBuffer out, Map map, int indent, {required bool indentFirst}) {
  var first = true;
  for (final entry in map.entries) {
    if (!first || indentFirst) out.write(' ' * indent);
    first = false;
    out.write(_key(entry.key.toString()));
    out.write(':');
    final v = entry.value;
    if (v is Map && v.isNotEmpty) {
      out.writeln();
      _writeMap(out, v, indent + 2, indentFirst: true);
    } else if (v is List && v.isNotEmpty) {
      out.writeln();
      // kubectl style: list items at the same indent as their key.
      _writeList(out, v, indent);
    } else {
      out.write(' ');
      out.writeln(_scalar(v, indent + 2));
    }
  }
}

void _writeList(StringBuffer out, List list, int indent) {
  for (final item in list) {
    out.write(' ' * indent);
    if (item is Map && item.isNotEmpty) {
      out.write('- ');
      _writeMap(out, item, indent + 2, indentFirst: false);
    } else if (item is List && item.isNotEmpty) {
      out.writeln('-');
      _writeList(out, item, indent + 2);
    } else {
      out.write('- ');
      out.writeln(_scalar(item, indent + 2));
    }
  }
}

final RegExp _plain = RegExp(r'^[A-Za-z_/][A-Za-z0-9_./:@=+,()~$%-]*( [A-Za-z0-9_./:@=+,()~$%-]+)*$');
const Set<String> _reserved = {'true', 'false', 'yes', 'no', 'on', 'off', 'y', 'n', 'null'};

bool _isPlainSafe(String s) =>
    _plain.hasMatch(s) && !s.contains(': ') && !s.endsWith(':') && !_reserved.contains(s.toLowerCase());

String _key(String key) => _isPlainSafe(key) ? key : jsonEncode(key);

String _scalar(Object? v, int indent) {
  if (v == null) return 'null';
  if (v is Map) return '{}';
  if (v is List) return '[]';
  if (v is bool) return v.toString();
  if (v is num) {
    if (v is double) {
      if (v.isNaN) return '.nan';
      if (v.isInfinite) return v > 0 ? '.inf' : '-.inf';
    }
    return v.toString();
  }
  final s = v.toString();
  if (s.contains('\n') && _canUseLiteralBlock(s)) {
    final keep = s.endsWith('\n');
    final body = keep ? s.substring(0, s.length - 1) : s;
    final pad = ' ' * indent;
    final lines = body.split('\n').map((l) => l.isEmpty ? '' : '$pad$l').join('\n');
    return '${keep ? '|' : '|-'}\n$lines';
  }
  return _isPlainSafe(s) ? s : jsonEncode(s);
}

/// A literal block keeps the text exactly only if the first line sets the
/// indentation, no line ends in whitespace and there is at most one
/// trailing newline.
bool _canUseLiteralBlock(String s) {
  if (s.contains('\r') || s.endsWith('\n\n')) return false;
  final lines = (s.endsWith('\n') ? s.substring(0, s.length - 1) : s).split('\n');
  if (lines.first.isEmpty || lines.first.startsWith(' ') || lines.first.startsWith('\t')) return false;
  return lines.every((l) => !l.endsWith(' ') && !l.endsWith('\t'));
}
