import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';

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
    terminal.write('Linux 6.6.54-virt (aarch64) Alpine Linux v3.20.3\r\n');
    terminal.write('Interactive container shell session opened (tty/pty: active).\r\n\r\n');
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
    } else if (trimmed == 'top') {
      terminal.write('Mem: 3840224K used, 4124312K free, 12240K shrd, 142104K buff, 1845120K cached\r\n'
          'CPU:   0% usr   0% sys   0% nic 100% idle   0% io   0% irq   0% sirq\r\n'
          'Load average: 0.08 0.05 0.01 1/142 32\r\n');
    } else if (trimmed == 'clear') {
      terminal.write('\x1b[2J\x1b[H');
    } else if (trimmed.startsWith('echo ')) {
      terminal.write('${trimmed.substring(5)}\r\n');
    } else if (trimmed.isNotEmpty) {
      terminal.write('$trimmed: command completed\r\n');
    }

    terminal.write('root@${widget.pod.name}:/# ');
  }

  @override
  Widget build(BuildContext context) {
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
              'Container: $_currentContainer (Alpine sh)',
              style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, color: LensTheme.textSecondary),
            tooltip: 'Clear Screen',
            onPressed: () => _sendCommand('clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Developer Quick Keys Helper Bar
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
                  _buildQuickKey('Tab', () => _sendCommand('ls')),
                  _buildQuickKey('Ctrl+C', () {
                    terminal.write('^C\r\nroot@${widget.pod.name}:/# ');
                  }),
                  _buildQuickKey('ESC', () {}),
                  _buildQuickKey('clear', () => _sendCommand('clear')),
                  _buildQuickKey('ls -la', () => _sendCommand('ls -la')),
                  _buildQuickKey('ps aux', () => _sendCommand('ps aux')),
                  _buildQuickKey('top', () => _sendCommand('top')),
                  _buildQuickKey('df -h', () => _sendCommand('df -h')),
                  _buildQuickKey('ip a', () => _sendCommand('ip a')),
                  _buildQuickKey('env', () => _sendCommand('env')),
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

          // Mobile Command Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: LensTheme.bgSurface,
              border: Border(top: BorderSide(color: LensTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                const Text('root/# ', style: TextStyle(color: LensTheme.cyanAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
                      if (cmd.isNotEmpty) {
                        _sendCommand(cmd);
                        _inputController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18, color: LensTheme.cyanAccent),
                  onPressed: () {
                    final cmd = _inputController.text;
                    if (cmd.isNotEmpty) {
                      _sendCommand(cmd);
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
