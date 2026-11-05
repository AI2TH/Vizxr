import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';

/// Modern Lens-inspired Cyber Dark Theme for Vizxr
class LensTheme {
  // Backgrounds
  static const Color bgDark = Color(0xFF090D16);
  static const Color bgSurface = Color(0xFF111827);
  static const Color bgCard = Color(0xFF151F32);
  static const Color bgCardElevated = Color(0xFF1E2B45);
  static const Color bgInput = Color(0xFF0D1424);
  static const Color bgTerminal = Color(0xFF070A0F);

  // Borders
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color borderMedium = Color(0x33FFFFFF);
  static const Color borderGlow = Color(0x6600E5FF);
  static const Color borderCard = Color(0x18FFFFFF);

  // Accents
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color blueAccent = Color(0xFF38BDF8);
  static const Color k8sBlue = Color(0xFF326CE5);
  static const Color purpleAccent = Color(0xFFA855F7);
  static const Color indigoAccent = Color(0xFF6366F1);

  // Status Colors
  static const Color statusGreen = Color(0xFF10B981);
  static const Color statusGreenGlow = Color(0xFF34D399);
  static const Color statusAmber = Color(0xFFF59E0B);
  static const Color statusRed = Color(0xFFF43F5E);
  static const Color statusMuted = Color(0xFF64748B);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF152035), Color(0xFF0F172A)],
  );

  static const LinearGradient elevatedCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2740), Color(0xFF121B2F)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient roseGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF121A2D), Color(0xFF090D16)],
  );

  // Card Decoration
  static BoxDecoration cardDecoration({
    Color? borderColor,
    bool glow = false,
    double radius = 16,
    LinearGradient? gradient,
  }) {
    return BoxDecoration(
      gradient: gradient ?? cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? borderCard,
        width: 1,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: (borderColor ?? cyanAccent).withOpacity(0.18),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ]
          : [
              const BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
    );
  }

  // Status Badge Builder
  static Widget statusBadge(String status, {double fontSize = 11}) {
    final s = status.toLowerCase();
    Color color = statusMuted;
    Color bg = statusMuted.withOpacity(0.15);
    IconData icon = Icons.circle;

    if (s.contains('running') || s.contains('ready') || s.contains('active') || s.contains('bound') || s.contains('completed')) {
      color = statusGreen;
      bg = statusGreen.withOpacity(0.15);
      icon = Icons.check_circle_rounded;
    } else if (s.contains('pending') || s.contains('waiting') || s.contains('containercreating') || s.contains('terminating')) {
      color = statusAmber;
      bg = statusAmber.withOpacity(0.15);
      icon = Icons.hourglass_top_rounded;
    } else if (s.contains('crash') || s.contains('error') || s.contains('fail') || s.contains('backoff') || s.contains('notready')) {
      color = statusRed;
      bg = statusRed.withOpacity(0.18);
      icon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 1, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Interactive Namespace Pill Builder
  static Widget namespaceBadge(
    String namespace, {
    double fontSize = 10,
    BuildContext? context,
    VoidCallback? onTap,
  }) {
    final isAll = namespace == 'all-namespaces';
    final label = isAll ? 'all-namespaces' : namespace;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: k8sBlue.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cyanAccent.withOpacity(0.4), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_rounded, size: fontSize + 2, color: cyanAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          if (context != null || onTap != null) ...[
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded, size: 14, color: cyanAccent),
          ],
        ],
      ),
    );

    if (context != null || onTap != null) {
      return InkWell(
        onTap: onTap ?? () => showNamespacePicker(context!),
        borderRadius: BorderRadius.circular(6),
        child: badge,
      );
    }
    return badge;
  }

  // Lens First-Class Namespace Picker Sheet
  static void showNamespacePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _NamespacePickerSheet(),
    );
  }

  // ThemeData
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: cyanAccent,
      canvasColor: bgSurface,
      cardColor: bgCard,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        secondary: blueAccent,
        surface: bgSurface,
        error: statusRed,
      ),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanAccent,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: cyanAccent.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyanAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderSubtle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgInput,
        selectedColor: cyanAccent.withOpacity(0.2),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: cyanAccent, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: bgSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgSurface,
        modalBackgroundColor: bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cyanAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _NamespacePickerSheet extends StatefulWidget {
  const _NamespacePickerSheet();

  @override
  State<_NamespacePickerSheet> createState() => _NamespacePickerSheetState();
}

class _NamespacePickerSheetState extends State<_NamespacePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final current = clusterState.currentNamespace;
    final namespaces = clusterState.namespaces;

    final filtered = namespaces.where((ns) {
      if (_filter.isEmpty) return true;
      return ns.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: LensTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: LensTheme.cyanAccent, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: LensTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: LensTheme.cyanAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.layers_rounded, color: LensTheme.cyanAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Namespace',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                      ),
                      Text(
                        'Cluster: ${clusterState.activeConfig?.name ?? "Vizxr"}',
                        style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: LensTheme.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LensTheme.borderSubtle),

          // Search Filter Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search namespaces...',
                hintStyle: const TextStyle(fontSize: 12, color: LensTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LensTheme.cyanAccent),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: LensTheme.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: LensTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LensTheme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LensTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: LensTheme.cyanAccent, width: 1.2),
                ),
              ),
            ),
          ),

          // Namespaces List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No namespaces match search.', style: TextStyle(color: LensTheme.textMuted, fontSize: 13)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final ns = filtered[idx];
                      final isSelected = ns == current;
                      final isAll = ns == 'all-namespaces';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? LensTheme.cyanAccent.withOpacity(0.12) : LensTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? LensTheme.cyanAccent.withOpacity(0.6) : LensTheme.borderSubtle,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isAll
                                  ? LensTheme.purpleAccent.withOpacity(0.15)
                                  : (isSelected ? LensTheme.cyanAccent.withOpacity(0.2) : LensTheme.borderSubtle),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isAll ? Icons.auto_awesome_rounded : Icons.layers_rounded,
                              size: 16,
                              color: isAll
                                  ? LensTheme.purpleAccent
                                  : (isSelected ? LensTheme.cyanAccent : LensTheme.textSecondary),
                            ),
                          ),
                          title: Text(
                            isAll ? 'All Namespaces (Cluster-Wide)' : ns,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? LensTheme.cyanAccent : LensTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isAll ? 'View all pods, services & workloads' : 'Namespace: $ns',
                            style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, size: 20, color: LensTheme.cyanAccent)
                              : null,
                          onTap: () {
                            clusterState.setNamespace(ns);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
