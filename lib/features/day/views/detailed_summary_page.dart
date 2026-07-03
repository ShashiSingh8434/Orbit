import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../shared/widgets/space_painter.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/ai/engine/detailed_summary_pipeline.dart';

enum SummaryState { loading, loaded, error }

class DetailedSummaryPage extends ConsumerStatefulWidget {
  final DateTime date;

  const DetailedSummaryPage({super.key, required this.date});

  @override
  ConsumerState<DetailedSummaryPage> createState() =>
      _DetailedSummaryPageState();
}

class _DetailedSummaryPageState extends ConsumerState<DetailedSummaryPage>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _starController;

  SummaryState _state = SummaryState.loading;
  String? _paragraphText;
  String? _bulletText;
  bool _isBulletMode = false;

  int _loadingTextIndex = 0;
  Timer? _loadingTextTimer;
  final List<String> _loadingMessages = [
    "Analyzing your day...",
    "Reading your reflections...",
    "Reviewing your tasks...",
    "Synthesizing events...",
    "Crafting your story...",
    "Adding some magic...",
    "Almost there...",
  ];

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _generateSummaries();
  }

  @override
  void dispose() {
    _loadingTextTimer?.cancel();
    _orbitController.dispose();
    _pulseController.dispose();
    _starController.dispose();
    super.dispose();
  }

  void _startLoadingTextTimer() {
    _loadingTextIndex = 0;
    _loadingTextTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          if (_loadingTextIndex < _loadingMessages.length - 1) {
            _loadingTextIndex++;
          }
        });
      }
    });
  }

  Future<void> _generateSummaries() async {
    _startLoadingTextTimer();

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final pipeline = ref.read(detailedSummaryPipelineProvider);
    final summaries = await pipeline.generateDetailedSummaries(
      uid,
      widget.date,
    );

    if (mounted) {
      _loadingTextTimer?.cancel();
      setState(() {
        if (summaries.paragraph != null && summaries.bullet != null) {
          _paragraphText = summaries.paragraph;
          _bulletText = summaries.bullet;
          _state = SummaryState.loaded;
        } else {
          _paragraphText = "Failed to generate detailed summary.";
          _state = SummaryState.error;
        }
      });
    }
  }

  Widget _buildLoadingState(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _orbitController,
            _pulseController,
            _starController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: SpacePainter(
                orbitProgress: _orbitController.value,
                pulseProgress: _pulseController.value,
                starProgress: _starController.value,
                colorScheme: colorScheme,
                isDark: isDark,
              ),
            );
          },
        ),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              _loadingMessages[_loadingTextIndex],
              key: ValueKey<int>(_loadingTextIndex),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _preprocessMarkdown(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n');
    final processedLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('## ') && i > 0) {
        processedLines.add('');
        processedLines.add('---');
        processedLines.add('');
      }
      processedLines.add(line);
    }
    return processedLines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget body;
    switch (_state) {
      case SummaryState.loading:
        body = _buildLoadingState(theme, colorScheme, isDark);
        break;
      case SummaryState.loaded:
        body = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Paragraph'),
                    icon: Icon(Icons.article_rounded),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Bullet Points'),
                    icon: Icon(Icons.format_list_bulleted_rounded),
                  ),
                ],
                selected: {_isBulletMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isBulletMode = newSelection.first;
                  });
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: _preprocessMarkdown(_isBulletMode ? _bulletText! : _paragraphText!),
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                        color: colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                      h1: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        height: 1.5,
                      ),
                      h2: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        height: 1.6,
                      ),
                      h3: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      listBullet: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
                      h2Padding: const EdgeInsets.only(top: 16, bottom: 8),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        break;
      case SummaryState.error:
        body = Center(child: Text(_paragraphText ?? "Error"));
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orbit Insights Deep Dive')),
      body: body,
    );
  }
}
