import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';

class LogsScreen extends StatefulWidget {
  final K8sResource pod;
  const LogsScreen({super.key, required this.pod});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _logs = '';
  bool _isLoading = true;
  bool _autoScroll = true;
  bool _isStreaming = false;
  bool _showPrevious = false;
  int _tailLines = 100;
  late String _selectedContainer;
  StreamSubscription<String>? _streamSub;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selectedContainer = widget.pod.containers.isNotEmpty ? widget.pod.containers.first : widget.pod.name;
    _fetchLogs();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    _stopStream();
    setState(() => _isLoading = true);
    final client = context.read<ClusterState>().client;
    final logText = await client.fetchPodLogs(
      widget.pod.name,
      widget.pod.namespace,
      container: _selectedContainer,
      tailLines: _tailLines,
      previous: _showPrevious,
    );
    if (mounted) {
      setState(() {
        _logs = logText;
        _isLoading = false;
      });
      _scrollToBottomIfNeeded();
    }
  }

  void _startStream() {
    _stopStream();
    setState(() {
      _isStreaming = true;
      _logs = '';
      _isLoading = false;
    });

    final client = context.read<ClusterState>().client;
    _streamSub = client
        .streamLogs(
          widget.pod.name,
          namespace: widget.pod.namespace,
          container: _selectedContainer,
          tailLines: _tailLines,
        )
        .listen((chunk) {
      if (mounted) {
        setState(() {
          _logs += chunk;
        });
        _scrollToBottomIfNeeded();
      }
    }, onDone: () {
      if (mounted) setState(() => _isStreaming = false);
    });
  }

  void _stopStream() {
    _streamSub?.cancel();
    _streamSub = null;
    if (mounted && _isStreaming) {
      setState(() => _isStreaming = false);
    }
  }

  void _scrollToBottomIfNeeded() {
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLines = _filter.isEmpty
        ? _logs
        : _logs
            .split('\n')
            .where((line) => line.toLowerCase().contains(_filter.toLowerCase()))
            .join('\n');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logs: ${widget.pod.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(
              'Container: $_selectedContainer (${widget.pod.namespace})',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isStreaming ? Icons.stop_circle : Icons.play_circle_outline),
            tooltip: _isStreaming ? 'Stop Live Stream' : 'Start Live Stream',
            color: _isStreaming ? Colors.redAccent : Colors.greenAccent,
            onPressed: () {
              if (_isStreaming) {
                _stopStream();
              } else {
                _startStream();
              }
            },
          ),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all logs',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val.startsWith('lines:')) {
                setState(() => _tailLines = int.parse(val.split(':')[1]));
                _fetchLogs();
              } else if (val == 'prev') {
                setState(() => _showPrevious = !_showPrevious);
                _fetchLogs();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(enabled: false, child: Text('TAIL LINES', style: TextStyle(fontSize: 10, color: Colors.grey))),
              const PopupMenuItem(value: 'lines:50', child: Text('Tail 50 lines')),
              const PopupMenuItem(value: 'lines:100', child: Text('Tail 100 lines')),
              const PopupMenuItem(value: 'lines:200', child: Text('Tail 200 lines')),
              const PopupMenuItem(value: 'lines:500', child: Text('Tail 500 lines')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'prev',
                child: Text(_showPrevious ? '✓ Previous Container Logs' : 'Previous Container Logs'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              if (widget.pod.containers.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                  child: Row(
                    children: [
                      const Text('Container:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedContainer,
                          isDense: true,
                          underline: const SizedBox(),
                          items: widget.pod.containers.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text(c, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedContainer = val);
                              _fetchLogs();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search log lines...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                  ),
                  onChanged: (val) => setState(() => _filter = val),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFF090D16),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12.0),
              child: SelectableText(
                filteredLines.isEmpty ? 'No matching logs.' : filteredLines,
                style: const TextStyle(
                  color: Color(0xFF4ADE80), // Terminal green
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}
