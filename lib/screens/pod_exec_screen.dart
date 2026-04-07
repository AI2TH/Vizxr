import 'dart:convert';
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
  final terminal = Terminal();

  @override
  void initState() {
    super.initState();
    _startExec();
  }

  void _startExec() {
    terminal.write('Connecting to ${widget.pod.name}...\r\n');
    // In a real implementation, this would establish a WebSocket connection
    // to the Kubernetes API /exec endpoint.
    terminal.write('root@${widget.pod.name}:/\$ ');

    terminal.onOutput = (data) {
      // Mock echo for now
      if (data == '\r') {
        terminal.write('\r\nroot@${widget.pod.name}:/\$ ');
      } else {
        terminal.write(data);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exec: ${widget.pod.name}')),
      backgroundColor: Colors.black,
      body: TerminalView(terminal),
    );
  }
}
