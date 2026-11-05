import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../theme/lens_theme.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            backgroundColor: LensTheme.statusGreen,
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
        backgroundColor: LensTheme.bgSurface,
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: LensTheme.statusRed),
            SizedBox(width: 8),
            Text('Apply Error', style: TextStyle(color: LensTheme.statusRed, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SelectableText(error, style: const TextStyle(color: LensTheme.textPrimary)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.cyanAccent, foregroundColor: Colors.black),
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
      backgroundColor: LensTheme.bgTerminal,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.resourceName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
            const Text('Lens Manifest Studio', style: TextStyle(fontSize: 11, color: LensTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: LensTheme.textSecondary),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: LensTheme.cyanAccent),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('APPLY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LensTheme.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _applyManifest,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Quick Templates Bar
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
                  _buildSnippetChip('Pod', _podSnippet),
                  _buildSnippetChip('Deployment', _depSnippet),
                  _buildSnippetChip('Service', _svcSnippet),
                  _buildSnippetChip('ConfigMap', _cmSnippet),
                ],
              ),
            ),
          ),

          // Code Editor Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: LensTheme.bgTerminal,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: LensTheme.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnippetChip(String label, String snippet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        backgroundColor: LensTheme.bgInput,
        side: const BorderSide(color: LensTheme.borderSubtle),
        onPressed: () {
          setState(() => _controller.text = snippet);
        },
      ),
    );
  }

  static const String _podSnippet = '''apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
  namespace: default
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
''';

  static const String _depSnippet = '''apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-deploy
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
''';

  static const String _svcSnippet = '''apiVersion: v1
kind: Service
metadata:
  name: demo-svc
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: demo
  ports:
  - port: 80
    targetPort: 80
''';

  static const String _cmSnippet = '''apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
  namespace: default
data:
  APP_ENV: production
  LOG_LEVEL: info
''';
}
