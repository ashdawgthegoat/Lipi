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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
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
                  Text(
                    'Select a presentation theme. Themes affect interface styling and borders only; clinical records and encryption are strictly preserved.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isError ? cs.error.withValues(alpha: 0.1) : cs.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isError ? cs.error : cs.tertiary,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isError ? cs.error : cs.tertiary,
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
                                    : cs.onSurfaceVariant,
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
                                                : cs.secondaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            theme.isBuiltIn ? 'Built-in' : 'Custom',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: theme.isBuiltIn
                                                  ? theme.colors.primary
                                                  : cs.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      theme.description,
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Palette swatches
                              _buildMiniaturePreview(theme),

                              // Custom theme delete button
                              if (!theme.isBuiltIn) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
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

  Widget _buildMiniaturePreview(LipiTheme previewTheme) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: previewTheme.colors.background,
        borderRadius: BorderRadius.circular(previewTheme.shapes.borderRadius),
        border: Border.all(color: previewTheme.colors.border, width: previewTheme.shapes.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Mock AppBar
          Container(
            height: 14,
            color: previewTheme.colors.appBarBg,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 20,
              height: 4,
              decoration: BoxDecoration(
                color: previewTheme.colors.appBarFg,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const Spacer(),
          // Mock Card
          Container(
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: previewTheme.colors.surface,
              borderRadius: BorderRadius.circular(previewTheme.shapes.cardBorderRadius),
              border: Border.all(color: previewTheme.colors.border, width: previewTheme.shapes.borderWidth),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mock text line
                Container(
                  width: double.infinity,
                  height: 3,
                  color: previewTheme.colors.mutedText,
                  margin: const EdgeInsets.only(bottom: 3),
                ),
                // Mock button
                Container(
                  width: 24,
                  height: 6,
                  decoration: BoxDecoration(
                    color: previewTheme.colors.primary,
                    borderRadius: BorderRadius.circular(previewTheme.shapes.buttonBorderRadius),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
