import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../services/cluster_state.dart';
import '../services/k8s_channel.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';

/// Interactive shell in a container, over the Kubernetes exec subresource
/// (WebSocket, `v4.channel.k8s.io`). In demo mode a small simulated shell is
/// used instead and the screen says so.
class PodExecScreen extends StatefulWidget {
  final K8sResource pod;
  const PodExecScreen({super.key, required this.pod});

  @override
  State<PodExecScreen> createState() => _PodExecScreenState();
}

enum _ExecState { connecting, connected, closed }

class _PodExecScreenState extends State<PodExecScreen> {
  // Prefer bash when the image has it, otherwise sh.
  static const List<String> _shellCommand = [
    'sh',
    '-c',
    'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi',
  ];
  static const List<String> _bashCommand = ['/bin/bash'];

  late final Terminal terminal;
  late final TerminalController controller;
  final TextEditingController _inputController = TextEditingController();
  late String _currentContainer;

  late K8sClientService _client;
  bool _isDemo = false;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  _ExecState _state = _ExecState.connecting;
  bool _receivedOutput = false;
  ByteConversionSink? _stdoutSink;
  ByteConversionSink? _stderrSink;

  @override
  void initState() {
    super.initState();
    _currentContainer = widget.pod.containers.isNotEmpty ? widget.pod.containers.first : widget.pod.name;
    terminal = Terminal(maxLines: 5000);
    controller = TerminalController();
    final clusterState = context.read<ClusterState>();
    _client = clusterState.client;
    _isDemo = clusterState.isDemo;

    terminal.onOutput = (data) {
      if (_isDemo) {
        _demoInput(data);
      } else {
        _sendStdin(data);
      }
    };
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _sendResize(width, height);
    };

    if (_isDemo) {
      _startDemo();
    } else {
      _connect(_shellCommand);
    }
  }

  @override
  void dispose() {
    _closeSocket();
    _inputController.dispose();
    controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Real exec over WebSocket
  // ---------------------------------------------------------------------------

  Future<void> _connect(List<String> command) async {
    _closeSocket();
    if (_state != _ExecState.connecting) {
      setState(() => _state = _ExecState.connecting);
    }
    _receivedOutput = false;
    terminal.write('\x1b[90mConnecting to ${widget.pod.namespace}/${widget.pod.name} '
        '(container: $_currentContainer)...\x1b[0m\r\n');

    try {
      final socket = await _client.openPodWebSocket(
        namespace: widget.pod.namespace,
        pod: widget.pod.name,
        subresource: 'exec',
        query: {
          'container': _currentContainer,
          'command': command,
          'stdin': 'true',
          'stdout': 'true',
          'stderr': 'true',
          'tty': 'true',
        },
      );
      if (!mounted) {
        socket.close();
        return;
      }
      _socket = socket;
      _stdoutSink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_TerminalSink(terminal));
      _stderrSink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_TerminalSink(terminal));
      _subscription = socket.listen(
        (message) => _onMessage(message, command),
        onDone: _onDone,
        onError: (Object e) {
          terminal.write('\r\n\x1b[31mConnection error: $e\x1b[0m\r\n');
        },
        cancelOnError: true,
      );
      setState(() => _state = _ExecState.connected);
      if (terminal.viewWidth > 0 && terminal.viewHeight > 0) {
        _sendResize(terminal.viewWidth, terminal.viewHeight);
      }
    } catch (e) {
      if (!mounted) return;
      terminal.write('\x1b[31mCould not open exec session: $e\x1b[0m\r\n');
      setState(() => _state = _ExecState.closed);
    }
  }

  void _onMessage(dynamic message, List<String> command) {
    final frame = K8sChannel.decode(message);
    if (frame == null || frame.data.isEmpty) return;
    switch (frame.channel) {
      case K8sChannel.stdout:
        _receivedOutput = true;
        _stdoutSink?.add(frame.data);
        break;
      case K8sChannel.stderr:
        _receivedOutput = true;
        _stderrSink?.add(frame.data);
        break;
      case K8sChannel.error:
        final status = K8sChannel.parseStatus(frame.data);
        if (status.success) {
          terminal.write('\r\n\x1b[90m[session ended]\x1b[0m\r\n');
          return;
        }
        final notFound = status.message.contains('executable file not found') ||
            status.message.contains('no such file or directory');
        if (!_receivedOutput && notFound && command != _bashCommand) {
          terminal.write('\x1b[33msh not found in the container, trying /bin/bash...\x1b[0m\r\n');
          // Retry after this socket has been torn down.
          scheduleMicrotask(() => _connect(_bashCommand));
          return;
        }
        final exit = status.exitCode != null ? ' (exit code ${status.exitCode})' : '';
        terminal.write('\r\n\x1b[31m${status.message}$exit\x1b[0m\r\n');
        break;
    }
  }

  void _onDone() {
    if (!mounted) return;
    final code = _socket?.closeCode;
    final reason = _socket?.closeReason;
    if (_state == _ExecState.connected) {
      terminal.write('\r\n\x1b[90mConnection closed'
          '${code != null ? ' ($code${reason != null && reason.isNotEmpty ? ': $reason' : ''})' : ''}'
          '.\x1b[0m\r\n');
    }
    setState(() => _state = _ExecState.closed);
  }

  void _closeSocket() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _stdoutSink?.close();
    _stdoutSink = null;
    _stderrSink?.close();
    _stderrSink = null;
  }

  void _sendStdin(String data) {
    final socket = _socket;
    if (socket == null || _state != _ExecState.connected) return;
    socket.add(K8sChannel.encode(K8sChannel.stdin, utf8.encode(data)));
  }

  void _sendResize(int width, int height) {
    final socket = _socket;
    if (socket == null || _state != _ExecState.connected || _isDemo) return;
    socket.add(K8sChannel.resizeFrame(width, height));
  }

  /// Sends typed input from the quick keys and the input bar.
  void _sendInput(String data) {
    if (_isDemo) {
      _demoInput(data);
    } else {
      _sendStdin(data);
    }
  }

  void _switchContainer(String container) {
    if (container == _currentContainer) return;
    setState(() => _currentContainer = container);
    terminal.write('\r\n');
    if (_isDemo) {
      _startDemo();
    } else {
      _connect(_shellCommand);
    }
  }

  // ---------------------------------------------------------------------------
  // Demo mode: simulated shell, clearly labelled
  // ---------------------------------------------------------------------------

  String _demoLine = '';

  String get _demoPrompt => 'root@${widget.pod.name}:/# ';

  void _startDemo() {
    _state = _ExecState.connected;
    terminal.write('\x1b[35mDemo cluster: this is a simulated shell, not a real container.\x1b[0m\r\n');
    terminal.write('Container: $_currentContainer (pod: ${widget.pod.name})\r\n\r\n');
    terminal.write(_demoPrompt);
  }

  void _demoInput(String data) {
    for (final ch in data.split('')) {
      if (ch == '\r' || ch == '\n') {
        terminal.write('\r\n');
        _demoRun(_demoLine);
        _demoLine = '';
        terminal.write(_demoPrompt);
      } else if (ch == '\x7f' || ch == '\b') {
        if (_demoLine.isNotEmpty) {
          _demoLine = _demoLine.substring(0, _demoLine.length - 1);
          terminal.write('\b \b');
        }
      } else if (ch == '\x03') {
        _demoLine = '';
        terminal.write('^C\r\n$_demoPrompt');
      } else if (ch.codeUnitAt(0) >= 0x20) {
        _demoLine += ch;
        terminal.write(ch);
      }
    }
  }

  void _demoRun(String cmd) {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    switch (trimmed) {
      case 'ls':
      case 'ls -la':
      case 'ls -l':
        terminal.write('bin  dev  etc  home  lib  proc  root  sys  tmp  usr  var\r\n');
        break;
      case 'whoami':
        terminal.write('root\r\n');
        break;
      case 'pwd':
        terminal.write('/\r\n');
        break;
      case 'hostname':
        terminal.write('${widget.pod.name}\r\n');
        break;
      case 'clear':
        terminal.write('\x1b[2J\x1b[H');
        break;
      default:
        if (trimmed.startsWith('echo ')) {
          terminal.write('${trimmed.substring(5)}\r\n');
        } else {
          terminal.write('(demo) $trimmed: not available in the simulated shell\r\n');
        }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final containers = widget.pod.containers;
    final statusText = _isDemo
        ? 'Demo (simulated shell)'
        : switch (_state) {
            _ExecState.connecting => 'Connecting...',
            _ExecState.connected => 'Connected',
            _ExecState.closed => 'Disconnected',
          };

    return Scaffold(
      backgroundColor: LensTheme.bgTerminal,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, size: 16, color: LensTheme.cyanAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'exec: ${widget.pod.name}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Container: $_currentContainer • $statusText',
              style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
            ),
          ],
        ),
        actions: [
          if (containers.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.view_module_rounded, color: LensTheme.textSecondary),
              tooltip: 'Switch container',
              onSelected: _switchContainer,
              itemBuilder: (context) => [
                for (final c in containers) PopupMenuItem(value: c, child: Text(c)),
              ],
            ),
          if (!_isDemo && _state == _ExecState.closed)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: LensTheme.cyanAccent),
              tooltip: 'Reconnect',
              onPressed: () => _connect(_shellCommand),
            ),
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, color: LensTheme.textSecondary),
            tooltip: 'Clear Screen',
            onPressed: () => terminal.write('\x1b[2J\x1b[H'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick keys for keys a phone keyboard lacks, plus common commands.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: LensTheme.bgDark,
              border: Border(bottom: BorderSide(color: LensTheme.borderSubtle)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickKey('Tab', () => _sendInput('\t')),
                  _buildQuickKey('Ctrl+C', () => _sendInput('\x03')),
                  _buildQuickKey('Ctrl+D', () => _sendInput('\x04')),
                  _buildQuickKey('ESC', () => _sendInput('\x1b')),
                  _buildQuickKey('↑', () => _sendInput('\x1b[A')),
                  _buildQuickKey('↓', () => _sendInput('\x1b[B')),
                  _buildQuickKey('clear', () => _sendInput('clear\r')),
                  _buildQuickKey('ls -la', () => _sendInput('ls -la\r')),
                  _buildQuickKey('ps aux', () => _sendInput('ps aux\r')),
                  _buildQuickKey('df -h', () => _sendInput('df -h\r')),
                  _buildQuickKey('env', () => _sendInput('env\r')),
                ],
              ),
            ),
          ),

          // Terminal View
          Expanded(
            child: TerminalView(
              terminal,
              controller: controller,
              backgroundOpacity: 1.0,
              autofocus: false,
            ),
          ),

          // Mobile command input bar: sends the line followed by Enter.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: LensTheme.bgSurface,
              border: Border(top: BorderSide(color: LensTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                const Text('\$ ', style: TextStyle(color: LensTheme.cyanAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: LensTheme.textPrimary, fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type command...',
                      hintStyle: TextStyle(color: LensTheme.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      isDense: true,
                    ),
                    onSubmitted: (cmd) {
                      _sendInput('$cmd\r');
                      _inputController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18, color: LensTheme.cyanAccent),
                  onPressed: () {
                    _sendInput('${_inputController.text}\r');
                    _inputController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        backgroundColor: LensTheme.bgInput,
        side: const BorderSide(color: LensTheme.borderSubtle, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onPressed: onTap,
      ),
    );
  }
}

/// Writes decoded UTF-8 text to the terminal.
class _TerminalSink implements Sink<String> {
  final Terminal terminal;

  _TerminalSink(this.terminal);

  @override
  void add(String data) => terminal.write(data);

  @override
  void close() {}
}
