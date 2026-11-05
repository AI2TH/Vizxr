import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';

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
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
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
                const Icon(Icons.terminal_rounded, size: 16, color: LensTheme.cyanAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.pod.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Container: $_selectedContainer • ${widget.pod.namespace}',
              style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
            ),
          ],
        ),
        actions: [
          // Live follow toggle
          TextButton.icon(
            icon: Icon(
              Icons.fiber_manual_record_rounded,
              size: 12,
              color: _isStreaming ? LensTheme.statusRed : LensTheme.textMuted,
            ),
            label: Text(
              _isStreaming ? 'REC' : 'FOLLOW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _isStreaming ? LensTheme.statusRed : LensTheme.cyanAccent,
              ),
            ),
            onPressed: () {
              if (_isStreaming) {
                _stopStream();
              } else {
                _startStream();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: LensTheme.textSecondary),
            tooltip: 'Copy all logs',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar: Container dropdown, Tail Lines, Search Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: LensTheme.bgDark,
              border: Border(bottom: BorderSide(color: LensTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                // Container Selector
                if (widget.pod.containers.length > 1) ...[
                  DropdownButton<String>(
                    value: _selectedContainer,
                    dropdownColor: LensTheme.bgSurface,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: LensTheme.cyanAccent, size: 18),
                    items: widget.pod.containers.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, color: LensTheme.cyanAccent)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedContainer = val);
                        _fetchLogs();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Tail lines selector
                DropdownButton<int>(
                  value: _tailLines,
                  dropdownColor: LensTheme.bgSurface,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: LensTheme.blueAccent, size: 18),
                  items: [50, 100, 200, 500, 1000].map((lines) {
                    return DropdownMenuItem(value: lines, child: Text('$lines lines', style: const TextStyle(fontSize: 11, color: LensTheme.blueAccent)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _tailLines = val);
                      _fetchLogs();
                    }
                  },
                ),
                const Spacer(),

                // Search Filter Input
                SizedBox(
                  width: 140,
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 11, color: LensTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Filter log...',
                      hintStyle: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 14, color: LensTheme.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: LensTheme.borderSubtle)),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _filter = val.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),

          // Log View Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent))
                : _buildLogContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogContent() {
    final lines = _logs.split('\n');
    final filteredLines = _filter.isEmpty
        ? lines
        : lines.where((l) => l.toLowerCase().contains(_filter)).toList();

    if (filteredLines.isEmpty) {
      return Center(
        child: Text(
          _filter.isEmpty ? 'No logs emitted yet.' : 'No matches found for "$_filter"',
          style: const TextStyle(color: LensTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: filteredLines.length,
        itemBuilder: (context, index) {
          final line = filteredLines[index];
          return _formatLogLine(line);
        },
      ),
    );
  }

  Widget _formatLogLine(String line) {
    Color textColor = LensTheme.textSecondary;
    final lower = line.toLowerCase();

    if (lower.contains('error') || lower.contains('fail') || lower.contains('fatal') || lower.contains('panic')) {
      textColor = LensTheme.statusRed;
    } else if (lower.contains('warn')) {
      textColor = LensTheme.statusAmber;
    } else if (lower.contains('info') || lower.contains('ready') || lower.contains('ok')) {
      textColor = LensTheme.statusGreen;
    } else if (lower.contains('debug') || lower.contains('trace')) {
      textColor = LensTheme.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        line,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontFamily: 'monospace',
          height: 1.35,
        ),
      ),
    );
  }
}
