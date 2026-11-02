import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';

class YamlEditorScreen extends StatefulWidget {
  final String resourceName;
  final String initialYaml;

  const YamlEditorScreen({
    super.key,
    required this.resourceName,
    required this.initialYaml,
  });

  @override
  State<YamlEditorScreen> createState() => _YamlEditorScreenState();
}

class _YamlEditorScreenState extends State<YamlEditorScreen> {
  late TextEditingController _controller;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialYaml);
  }

  Future<void> _applyManifest() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isApplying = true);
    final clusterState = context.read<ClusterState>();

    try {
      final result = await clusterState.applyManifest(text);
      if (!mounted) return;
      setState(() => _isApplying = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green[800],
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      _showErrorDialog('Failed to apply manifest: $e');
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Apply Error'),
          ],
        ),
        content: SelectableText(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manifest: ${widget.resourceName}', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Manifest',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _controller.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manifest copied to clipboard')),
              );
            },
          ),
          if (_isApplying)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.check, size: 18, color: Colors.lightBlueAccent),
              onPressed: _applyManifest,
              label: const Text(
                'APPLY',
                style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(12.0),
        color: const Color(0xFF0F172A),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.4,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
