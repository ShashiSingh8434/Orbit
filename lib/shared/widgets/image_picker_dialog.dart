import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A shared dialog for selecting images via Camera or Gallery.
/// Supports both single-image and multi-image selection.
class ImagePickerDialog extends StatelessWidget {
  /// Whether to allow selecting multiple images from the gallery.
  final bool allowMultiple;

  const ImagePickerDialog({super.key, this.allowMultiple = true});

  /// Shows the dialog and returns the picked [XFile]s, or null/empty if cancelled.
  static Future<List<XFile>?> show(
    BuildContext context, {
    bool allowMultiple = true,
  }) {
    return showDialog<List<XFile>>(
      context: context,
      builder: (context) => ImagePickerDialog(allowMultiple: allowMultiple),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final picker = ImagePicker();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_photo_alternate_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Upload Document'),
        ],
      ),
      content: const Text(
        'Take a photo or choose screenshots of your document. '
        'Gemini will intelligently merge the information.',
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                onPressed: () async {
                  try {
                    final file = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(file != null ? [file] : null);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Camera access failed: $e')),
                      );
                      Navigator.of(context).pop(null);
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  allowMultiple
                      ? Icons.photo_library_rounded
                      : Icons.photo_rounded,
                ),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    if (allowMultiple) {
                      final files = await picker.pickMultiImage(
                        imageQuality: 85,
                      );
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pop(files.isNotEmpty ? files : null);
                      }
                    } else {
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(file != null ? [file] : null);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to pick images: $e')),
                      );
                      Navigator.of(context).pop(null);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
