import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/academic_alarm_provider.dart';
import '../providers/academic_provider.dart';

class AcademicReminderSettingsPage extends ConsumerStatefulWidget {
  const AcademicReminderSettingsPage({super.key});

  @override
  ConsumerState<AcademicReminderSettingsPage> createState() =>
      _AcademicReminderSettingsPageState();
}

class _AcademicReminderSettingsPageState
    extends ConsumerState<AcademicReminderSettingsPage> {
  late AudioPlayer _audioPlayer;
  
  int _minutesBefore = 15;
  String _ringtoneType = 'asset'; // 'asset' or 'local'
  String _ringtonePath = 'assets/freedom.mp3';
  String _ringtoneName = 'Freedom';
  
  bool _isPlaying = false;
  String? _playingPath;

  final List<Map<String, String>> _defaultRingtones = [
    {'name': 'Freedom', 'path': 'assets/freedom.mp3', 'assetKey': 'freedom.mp3'},
    {'name': 'If it smiles', 'path': 'assets/slow.mp3', 'assetKey': 'slow.mp3'},
    {'name': 'Feel Something Good', 'path': 'assets/feel.mp3', 'assetKey': 'feel.mp3'},
  ];

  final List<int> _offsetOptions = [0, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadSettings();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final settings = ref.read(academicReminderSettingsProvider);
    setState(() {
      _minutesBefore = settings.minutesBefore;
      _ringtoneType = settings.ringtoneType;
      _ringtonePath = settings.ringtonePath;
      _ringtoneName = settings.ringtoneName;
    });
  }

  Future<void> _saveSettings() async {
    await ref.read(academicReminderSettingsProvider.notifier).updateSettings(
          minutesBefore: _minutesBefore,
          ringtoneType: _ringtoneType,
          ringtonePath: _ringtonePath,
          ringtoneName: _ringtoneName,
        );

    // Reschedule all active alarms with the new warning offset and ringtone
    final academicState = ref.read(academicStateProvider);
    final schedule = academicState.schedule;
    if (schedule != null) {
      await ref.read(academicAlarmProvider.notifier).reschedulePassedAlarms(schedule.schedule);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _togglePreview(String path, String type, String assetKey) async {
    if (_isPlaying && _playingPath == path) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingPath = null;
      });
    } else {
      await _audioPlayer.stop();
      setState(() {
        _playingPath = path;
        _isPlaying = true;
      });
      try {
        if (type == 'asset') {
          await _audioPlayer.play(AssetSource(assetKey));
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      } catch (e) {
        setState(() {
          _isPlaying = false;
          _playingPath = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to play preview: $e')),
          );
        }
      }
    }
  }

  Future<void> _pickLocalRingtone() async {
    await _audioPlayer.stop();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final originalPath = result.files.single.path!;
      final originalName = result.files.single.name;

      try {
        // Copy to app documents dir for persistent access
        final appDir = await getApplicationDocumentsDirectory();
        final ringtonesDir = Directory('${appDir.path}/ringtones');
        if (!await ringtonesDir.exists()) {
          await ringtonesDir.create(recursive: true);
        }

        final targetPath = p.join(ringtonesDir.path, originalName);
        await File(originalPath).copy(targetPath);

        setState(() {
          _ringtoneType = 'local';
          _ringtonePath = targetPath;
          _ringtoneName = originalName;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save selected audio file: $e')),
          );
        }
      }
    }
  }

  Future<void> _showOffsetDialog() async {
    int tempOffset = _minutesBefore;
    final textController = TextEditingController(
      text: _offsetOptions.contains(_minutesBefore) ? '' : _minutesBefore.toString()
    );
    bool isCustom = !_offsetOptions.contains(_minutesBefore);

    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Reminder Warning Offset'),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              content: SingleChildScrollView(
                child: RadioGroup<int>(
                  groupValue: isCustom ? -1 : tempOffset,
                  onChanged: (int? val) {
                    if (val != null) {
                      setDialogState(() {
                        if (val == -1) {
                          isCustom = true;
                        } else {
                          tempOffset = val;
                          isCustom = false;
                          textController.clear();
                        }
                      });
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._offsetOptions.map((opt) {
                        final label = opt == 0 ? 'Exactly at class time' : '$opt minutes before';
                        return RadioListTile<int>(
                          title: Text(label, style: theme.textTheme.bodyMedium),
                          value: opt,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                        );
                      }),
                      RadioListTile<int>(
                        title: Text('Custom minutes', style: theme.textTheme.bodyMedium),
                        value: -1,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      if (isCustom)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: TextField(
                            controller: textController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter minutes',
                              suffixText: 'mins',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 0) {
                                tempOffset = parsed;
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (isCustom) {
                      final parsed = int.tryParse(textController.text);
                      if (parsed == null || parsed < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid number of minutes.')),
                        );
                        return;
                      }
                      tempOffset = parsed;
                    }
                    Navigator.pop(context, tempOffset);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _minutesBefore = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Offset Section
            Text(
              'Reminder Warning Offset',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
              ),
              color: colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: _showOffsetDialog,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _minutesBefore == 0
                              ? 'Exactly at class time'
                              : '$_minutesBefore minutes before class',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.edit_calendar_rounded, color: colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ringtone Section
            Text(
              'Select Ringtone',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Default list and Local Device wrapped in a single RadioGroup
            RadioGroup<String>(
              groupValue: _ringtoneType == 'local' ? 'local' : _ringtonePath,
              onChanged: (String? value) {
                if (value == 'local') {
                  _pickLocalRingtone();
                } else if (value != null) {
                  final matched = _defaultRingtones.firstWhere((r) => r['path'] == value);
                  setState(() {
                    _ringtoneType = 'asset';
                    _ringtonePath = value;
                    _ringtoneName = matched['name']!;
                  });
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._defaultRingtones.map((ringtone) {
                    final isSelected = _ringtoneType == 'asset' && _ringtonePath == ringtone['path'];
                    final isRingtonePlaying = _isPlaying && _playingPath == ringtone['path'];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withAlpha(120),
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? colorScheme.primaryContainer.withAlpha(50)
                            : colorScheme.surfaceContainerLow,
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _ringtoneType = 'asset';
                            _ringtonePath = ringtone['path']!;
                            _ringtoneName = ringtone['name']!;
                          });
                        },
                        leading: Radio<String>(
                          value: ringtone['path']!,
                        ),
                        title: Text(
                          ringtone['name']!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isRingtonePlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          onPressed: () => _togglePreview(ringtone['path']!, 'asset', ringtone['assetKey']!),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  
                  // Local Device Section
                  Text(
                    'Custom Ringtone',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _ringtoneType == 'local'
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withAlpha(120),
                        width: _ringtoneType == 'local' ? 2 : 1,
                      ),
                      color: _ringtoneType == 'local'
                          ? colorScheme.primaryContainer.withAlpha(50)
                          : colorScheme.surfaceContainerLow,
                    ),
                    child: ListTile(
                      onTap: _pickLocalRingtone,
                      leading: const Radio<String>(
                        value: 'local',
                      ),
                      title: Text(
                        _ringtoneType == 'local' ? _ringtoneName : 'Choose from local device...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: _ringtoneType == 'local' ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_ringtoneType == 'local')
                            IconButton(
                              icon: Icon(
                                _isPlaying && _playingPath == _ringtonePath
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () => _togglePreview(_ringtonePath, 'local', ''),
                            ),
                          IconButton(
                            icon: Icon(Icons.folder_open_rounded, color: colorScheme.primary),
                            onPressed: _pickLocalRingtone,
                            tooltip: 'Select local audio file',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (ref.watch(academicAlarmProvider).isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Reminders?'),
                      content: const Text('This will turn off and delete all currently set reminders.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(academicAlarmProvider.notifier).clearAllReminders();
                    // messenger.showSnackBar(
                    //   const SnackBar(content: Text('All active reminders have been cleared.')),
                    // );
                  }
                },
                icon: Icon(Icons.alarm_off_rounded, color: colorScheme.error),
                label: Text(
                  'Clear All Active Reminders',
                  style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save Action Button
            FilledButton(
              onPressed: _saveSettings,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
