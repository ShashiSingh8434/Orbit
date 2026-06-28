import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class SlideToSignInButton extends StatefulWidget {
  final VoidCallback onSignIn;
  final bool isLoading;

  const SlideToSignInButton({
    super.key,
    required this.onSignIn,
    required this.isLoading,
  });

  @override
  State<SlideToSignInButton> createState() => SlideToSignInButtonState();
}

class SlideToSignInButtonState extends State<SlideToSignInButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isFinished = false;
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springController.addListener(() {
      setState(() {
        _dragPosition = _springAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double maxWidth) {
    if (widget.isLoading || _isFinished) return;

    setState(() {
      _dragPosition += details.delta.dx;
      if (_dragPosition < 0) _dragPosition = 0;
      if (_dragPosition > maxWidth - 56) {
        _dragPosition = maxWidth - 56; // 56 is ball size
      }
    });
  }

  void _onPanEnd(DragEndDetails details, double maxWidth) {
    if (widget.isLoading || _isFinished) return;

    if (_dragPosition > (maxWidth - 56) * 0.8) {
      // Trigger sign in
      setState(() {
        _dragPosition = maxWidth - 56;
        _isFinished = true;
      });
      widget.onSignIn();
    } else {
      // Snap back
      _springAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      );
      _springController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(SlideToSignInButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading && _isFinished) {
      // Reset if it stopped loading (e.g. failed login or dialog closed)
      _isFinished = false;
      _springAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      );
      _springController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const ballSize = 56.0;

        return Container(
          height: ballSize,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ballSize / 2),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              // Filled track background when sliding
              Container(
                width: _dragPosition + ballSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(50),
                  borderRadius: BorderRadius.circular(ballSize / 2),
                ),
              ),

              // Text
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: ballSize * 0.5),
                  child: Opacity(
                    // Fade out text as we drag
                    opacity: (1.0 - (_dragPosition / (maxWidth - ballSize)))
                        .clamp(0.0, 1.0),
                    child: Text(
                      'Slide to Sign in',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Draggable Ball
              Positioned(
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (d) => _onPanUpdate(d, maxWidth),
                  onPanEnd: (d) => _onPanEnd(d, maxWidth),
                  child: Container(
                    width: ballSize,
                    height: ballSize,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Image.asset(
                                  AppConstants.googleImgPath,
                                  width: 22,
                                  height: 22,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
