import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialYaml);
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated ${widget.resourceName} manifest successfully')),
              );
            },
            child: const Text('APPLY', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
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
