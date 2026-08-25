import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/stream_privacy_models.dart';

/// Overlay reflecting this viewer's own relationship to a private stream
/// (AppProvider.localViewerAccessState) -- a small non-blocking VIP badge, a
/// dark waiting-room overlay while knocking, or an unauthorized notice.
/// Renders nothing for notApplicable/admitted (public stream, or already
/// let in), so it's a no-op overlay for every stream that isn't private.
class PrivateStreamViewerGate extends StatelessWidget {
  final ViewerAccessState accessState;
  final VoidCallback onRequestToJoin;

  const PrivateStreamViewerGate({
    super.key,
    required this.accessState,
    required this.onRequestToJoin,
  });

  @override
  Widget build(BuildContext context) {
    switch (accessState) {
      case ViewerAccessState.notApplicable:
      case ViewerAccessState.admitted:
        return const SizedBox.shrink();
      case ViewerAccessState.vipPreApproved:
        return const Positioned(
          top: 12,
          right: 12,
          child: _VipBadge(),
        );
      case ViewerAccessState.knocking:
        return const Positioned.fill(child: _WaitingRoomOverlay());
      case ViewerAccessState.denied:
        return Positioned.fill(
          child: _UnauthorizedOverlay(onRequestToJoin: onRequestToJoin),
        );
    }
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: Colors.black87, size: 14),
          SizedBox(width: 5),
          Text(
            'VIP Invited',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRoomOverlay extends StatelessWidget {
  const _WaitingRoomOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.accentAmber,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const Text(
              '🔒',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const Text(
              'Waiting for host to admit you...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This is a private broadcast',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnauthorizedOverlay extends StatelessWidget {
  final VoidCallback onRequestToJoin;

  const _UnauthorizedOverlay({required this.onRequestToJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppTheme.accentRed, size: 40),
              const SizedBox(height: AppTheme.spaceMd),
              const Text(
                'This broadcast is private',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Contact the host for access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              ElevatedButton(
                onPressed: onRequestToJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Request to Join',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
