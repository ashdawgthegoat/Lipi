import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../infrastructure/themes/theme_model.dart';
import '../../infrastructure/themes/theme_service.dart';

/// Modal dialog for managing and switching Lipi application themes.
class ThemeSettingsDialog extends StatefulWidget {
  final ThemeService themeService;

  const ThemeSettingsDialog({
    super.key,
    required this.themeService,
  });

  static Future<void> show(BuildContext context, ThemeService themeService) {
    return showDialog(
      context: context,
      builder: (ctx) => ThemeSettingsDialog(themeService: themeService),
    );
  }

  @override
  State<ThemeSettingsDialog> createState() => _ThemeSettingsDialogState();
}

class _ThemeSettingsDialogState extends State<ThemeSettingsDialog> {
  String? _statusMessage;
  bool _isError = false;

  Future<void> _handleImportFile() async {
    setState(() {
      _statusMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final jsonStr = await file.readAsString();
        final imported = await widget.themeService.importThemeFromJson(jsonStr);
        if (mounted) {
          setState(() {
            _statusMessage = "Successfully imported '${imported.name}'.";
            _isError = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Import failed: $e";
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleDeleteTheme(LipiTheme theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Theme'),
        content: Text("Are you sure you want to remove '${theme.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.themeService.deleteCustomTheme(theme.id);
        if (mounted) {
          setState(() {
            _statusMessage = "Theme '${theme.name}' removed.";
            _isError = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = "Delete failed: $e";
            _isError = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LipiTheme>(
      valueListenable: widget.themeService.activeThemeNotifier,
      builder: (context, activeTheme, _) {
        final themes = widget.themeService.availableThemes;

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.palette_outlined, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text('Theme & Presentation Settings'),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select a presentation theme. Themes affect interface styling and borders only; clinical records and encryption are strictly preserved.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isError ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isError ? const Color(0xFF991B1B) : const Color(0xFF166534),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ...themes.map((theme) {
                    final isSelected = theme.id == activeTheme.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => widget.themeService.switchTheme(theme.id),
                        borderRadius: BorderRadius.circular(theme.shapes.cardBorderRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colors.surface,
                            borderRadius: BorderRadius.circular(theme.shapes.cardBorderRadius),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colors.primary
                                  : theme.colors.border,
                              width: isSelected ? 2.5 : theme.shapes.borderWidth,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colors.primary.withAlpha(40),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              // Selection radio indicator
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? theme.colors.primary
                                    : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 12),

                              // Theme details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          theme.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.isBuiltIn
                                                ? theme.colors.primaryContainer
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            theme.isBuiltIn ? 'Built-in' : 'Custom',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: theme.isBuiltIn
                                                  ? theme.colors.primary
                                                  : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      theme.description,
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Palette swatches
                              _buildPalettePreview(theme),

                              // Custom theme delete button
                              if (!theme.isBuiltIn) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  tooltip: 'Delete custom theme',
                                  onPressed: () => _handleDeleteTheme(theme),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import Theme (.json)'),
              onPressed: _handleImportFile,
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPalettePreview(LipiTheme theme) {
    final swatches = [
      theme.colors.primary,
      theme.colors.appBarBg,
      theme.colors.background,
      theme.colors.accent,
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: swatches.map((c) {
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
          );
        }).toList(),
      ),
    );
  }
}
