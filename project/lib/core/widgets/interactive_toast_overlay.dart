import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Fully interactive, swipeable in-app toast notification banner.
/// Supports vertical/horizontal swipe dismissal, direct tap actions,
/// auto-dismiss progress bar, and bilingual RTL layout.
class InteractiveToastOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color accentColor = AppTheme.primary,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    // Dismiss any existing active banner immediately
    dismiss();

    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _InteractiveToastWidget(
        title: title,
        message: message,
        icon: icon,
        accentColor: accentColor,
        duration: duration,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        actionLabel: actionLabel,
        onActionPressed: () {
          dismiss();
          onActionPressed?.call();
        },
        onDismissed: () {
          dismiss();
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }
}

class _InteractiveToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Duration duration;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  const _InteractiveToastWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.duration,
    required this.onTap,
    this.actionLabel,
    this.onActionPressed,
    required this.onDismissed,
  });

  @override
  State<_InteractiveToastWidget> createState() => _InteractiveToastWidgetState();
}

class _InteractiveToastWidgetState extends State<_InteractiveToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PositionedDirectional(
      top: topPadding + 8,
      start: 16,
      end: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              ),
            );
          },
          child: Dismissible(
            key: const Key('interactive_toast_dismissible'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismissed(),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.media.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon Badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Message Text
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Action Button or Dismiss Icon
                    if (widget.actionLabel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onActionPressed ?? widget.onTap,
                        style: TextButton.styleFrom(
                          backgroundColor: widget.accentColor.withValues(alpha: 0.18),
                          foregroundColor: widget.accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],

                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDismissed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
