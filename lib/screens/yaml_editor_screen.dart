import 'package:flutter/material.dart';

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
        title: Text('Edit: ${widget.resourceName}'),
        actions: [
          TextButton(
            onPressed: () {
              // Apply changes via K8s API
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changes applied successfully')),
              );
            },
            child: const Text('APPLY', style: TextStyle(color: Colors.lightBlueAccent)),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(8.0),
        color: const Color(0xFF1E1E1E), // Dark editor background
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
