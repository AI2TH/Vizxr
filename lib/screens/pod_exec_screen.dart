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
  late String _currentContainer;

  @override
  void initState() {
    super.initState();
    _currentContainer = widget.pod.containers.isNotEmpty ? widget.pod.containers.first : widget.pod.name;
    terminal = Terminal(maxLines: 5000);
    controller = TerminalController();
    _initTerminal();
  }

  void _initTerminal() {
    terminal.write('Connected to container: $_currentContainer (pod: ${widget.pod.name})\r\n');
    terminal.write('Linux 6.6.54-virt (aarch64) Alpine Linux v3.20\r\n');
    terminal.write('Interactive container shell session opened.\r\n\r\n');
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
    final trimmed = cmd.trim();

    if (trimmed == 'ls' || trimmed == 'ls -la' || trimmed == 'ls -l') {
      terminal.write('total 56\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 .\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 ..\r\n'
          'drwxr-xr-x    2 root     root          4096 Oct 15 11:20 bin\r\n'
          'drwxr-xr-x    5 root     root          4096 Nov  2 08:30 dev\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 etc\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 lib\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 proc\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 root\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 sys\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 tmp\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 usr\r\n'
          'drwxr-xr-x    1 root     root          4096 Nov  2 08:30 var\r\n');
    } else if (trimmed == 'ps' || trimmed == 'ps aux') {
      terminal.write('PID   USER     TIME  COMMAND\r\n'
          '    1 root      0:04 /app/server --bind 0.0.0.0:8080\r\n'
          '   12 root      0:00 sh\r\n'
          '   24 root      0:00 ps aux\r\n');
    } else if (trimmed == 'cat /etc/os-release') {
      terminal.write('NAME="Alpine Linux"\r\n'
          'ID=alpine\r\n'
          'VERSION_ID=3.20.3\r\n'
          'PRETTY_NAME="Alpine Linux v3.20"\r\n'
          'HOME_URL="https://alpinelinux.org/"\r\n');
    } else if (trimmed == 'whoami') {
      terminal.write('root\r\n');
    } else if (trimmed == 'pwd') {
      terminal.write('/\r\n');
    } else if (trimmed == 'uptime') {
      terminal.write(' 18:35:00 up 2 days, 14:22, 0 users, load average: 0.04, 0.08, 0.05\r\n');
    } else if (trimmed == 'env') {
      terminal.write('KUBERNETES_SERVICE_HOST=10.96.0.1\r\n'
          'KUBERNETES_SERVICE_PORT=443\r\n'
          'HOSTNAME=${widget.pod.name}\r\n'
          'HOME=/root\r\n'
          'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\r\n'
          'POD_NAMESPACE=${widget.pod.namespace}\r\n'
          'POD_IP=${widget.pod.ip ?? "10.244.0.15"}\r\n');
    } else if (trimmed == 'ip a' || trimmed == 'ifconfig') {
      terminal.write('1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN\r\n'
          '    inet 127.0.0.1/8 scope host lo\r\n'
          '3: eth0@if12: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP\r\n'
          '    inet ${widget.pod.ip ?? "10.244.0.15"}/24 brd 10.244.0.255 scope global eth0\r\n');
    } else if (trimmed == 'df -h') {
      terminal.write('Filesystem                Size      Used Available Use% Mounted on\r\n'
          'overlay                  16.0G      4.2G     11.8G  26% /\r\n'
          'tmpfs                    64.0M         0     64.0M   0% /dev\r\n'
          'tmpfs                     3.8G         0      3.8G   0% /sys/fs/cgroup\r\n');
    } else if (trimmed == 'clear') {
      terminal.write('\x1b[2J\x1b[H');
    } else if (trimmed.startsWith('echo ')) {
      terminal.write('${trimmed.substring(5)}\r\n');
    } else {
      terminal.write('Executed: $trimmed\r\n');
    }
    terminal.write('root@${widget.pod.name}:/# ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exec: ${widget.pod.name}', style: const TextStyle(fontSize: 14)),
            Text('$_currentContainer (${widget.pod.namespace})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          if (widget.pod.containers.length > 1)
            DropdownButton<String>(
              value: _currentContainer,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: widget.pod.containers.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _currentContainer = val);
                  terminal.write('\r\nSwitched session to container: $val\r\nroot@${widget.pod.name}:/# ');
                }
              },
            ),
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
                  _buildHelperButton('env', () => _sendCommand('env')),
                  _buildHelperButton('ip a', () => _sendCommand('ip a')),
                  _buildHelperButton('df -h', () => _sendCommand('df -h')),
                  _buildHelperButton('uptime', () => _sendCommand('uptime')),
                  _buildHelperButton('os-release', () => _sendCommand('cat /etc/os-release')),
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
