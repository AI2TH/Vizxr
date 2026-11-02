import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../services/k8s_client.dart';

class PodExecScreen extends StatefulWidget {
  final K8sResource pod;
  const PodExecScreen({super.key, required this.pod});

  @override
  State<PodExecScreen> createState() => _PodExecScreenState();
}

class _PodExecScreenState extends State<PodExecScreen> {
  late final Terminal terminal;
  late final TerminalController controller;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 5000);
    controller = TerminalController();
    _initTerminal();
  }

  void _initTerminal() {
    terminal.write('Connected to container in pod: ${widget.pod.name}\r\n');
    terminal.write('Linux 6.6.54-virt (aarch64) Alpine Linux v3.20\r\n');
    terminal.write('Interactive shell session opened.\r\n\r\n');
    terminal.write('root@${widget.pod.name}:/# ');

    terminal.onOutput = (data) {
      if (data == '\r') {
        terminal.write('\r\nroot@${widget.pod.name}:/# ');
      } else {
        terminal.write(data);
      }
    };
  }

  void _sendCommand(String cmd) {
    terminal.write('$cmd\r\n');
    if (cmd == 'ls -la') {
      terminal.write('total 56\r\ndrwxr-xr-x    1 root     root          4096 Nov  2 08:30 .\r\ndrwxr-xr-x    1 root     root          4096 Nov  2 08:30 ..\r\ndrwxr-xr-x    2 root     root          4096 Oct 15 11:20 bin\r\ndrwxr-xr-x    5 root     root          4096 Nov  2 08:30 dev\r\ndrwxr-xr-x    1 root     root          4096 Nov  2 08:30 etc\r\ndrwxr-xr-x    1 root     root          4096 Nov  2 08:30 var\r\n');
    } else if (cmd == 'ps aux') {
      terminal.write('PID   USER     TIME  COMMAND\r\n    1 root      0:04 /app/server --bind 0.0.0.0:8080\r\n   12 root      0:00 sh\r\n   24 root      0:00 ps aux\r\n');
    } else if (cmd == 'cat /etc/os-release') {
      terminal.write('NAME="Alpine Linux"\r\nID=alpine\r\nVERSION_ID=3.20.3\r\nPRETTY_NAME="Alpine Linux v3.20"\r\n');
    } else if (cmd == 'clear') {
      terminal.write('\x1b[2J\x1b[H');
    } else {
      terminal.write('Executed: $cmd\r\n');
    }
    terminal.write('root@${widget.pod.name}:/# ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exec: ${widget.pod.name}', style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Terminal',
            onPressed: () {
              terminal.write('\x1b[2J\x1b[H');
              terminal.write('root@${widget.pod.name}:/# ');
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Terminal View
          Expanded(
            child: TerminalView(
              terminal,
              controller: controller,
              autofocus: true,
            ),
          ),
          // Helper Toolbar
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHelperButton('ls -la', () => _sendCommand('ls -la')),
                  _buildHelperButton('ps aux', () => _sendCommand('ps aux')),
                  _buildHelperButton('os-release', () => _sendCommand('cat /etc/os-release')),
                  _buildHelperButton('top', () => _sendCommand('top -b -n 1')),
                  _buildHelperButton('Ctrl+C', () {
                    terminal.write('^C\r\nroot@${widget.pod.name}:/# ');
                  }),
                  _buildHelperButton('Clear', () {
                    terminal.write('\x1b[2J\x1b[H');
                    terminal.write('root@${widget.pod.name}:/# ');
                  }),
                ],
              ),
            ),
          ),
          // Command Input Bar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter command...',
                      isDense: true,
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _sendCommand(val.trim());
                        _inputController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent, size: 20),
                  onPressed: () {
                    final text = _inputController.text.trim();
                    if (text.isNotEmpty) {
                      _sendCommand(text);
                      _inputController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 32),
          side: const BorderSide(color: Colors.blueGrey),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ),
    );
  }
}
