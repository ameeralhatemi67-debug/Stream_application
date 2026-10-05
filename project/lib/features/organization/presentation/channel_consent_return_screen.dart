import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../../live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'channel_connections_screen.dart';

/// Landing for Google's consent return link. The return replaces the app's
/// navigation history, so the page stack saved when consent started is
/// rebuilt: the broadcast studio reopens on top of it, or the connections page
/// when consent started there. Without a saved stack the connections page is
/// shown with its own way out.
class ChannelConsentReturnScreen extends StatefulWidget {
  const ChannelConsentReturnScreen({super.key, this.returnStatus, required this.navigatorKey});
  final String? returnStatus;
  final GlobalKey<NavigatorState> navigatorKey;

  /// The current page stack: the base location, then every pushed page.
  static List<String>? currentStack(BuildContext context) {
    final configuration = GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration;
    if (configuration == null || configuration.isEmpty) return null;
    return [configuration.uri.toString(),
      for (final match in configuration.matches)
        if (match is ImperativeRouteMatch) match.matches.uri.toString()];
  }

  @override
  State<ChannelConsentReturnScreen> createState() => _ChannelConsentReturnScreenState();
}

class _ChannelConsentReturnScreenState extends State<ChannelConsentReturnScreen> {
  bool _showConnections = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }
  Future<void> _resume() async {
    final provider = context.read<AppProvider>();
    final saved = await provider.takeChannelConsentReturn();
    if (!mounted) return;
    if (saved == null) { setState(() => _showConnections = true); return; }
    try { await provider.refreshChannelConnections(); } catch (_) {} // Each page reloads on open.
    if (!mounted) return;
    final status = widget.returnStatus;
    final router = GoRouter.of(context);
    final navigatorKey = widget.navigatorKey;
    router.go(saved.stack.first);
    for (final location in saved.stack.skip(1)) {
      await WidgetsBinding.instance.endOfFrame;
      router.push(location);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!saved.studio) {
      router.push(Uri(path: '/channels', queryParameters: {if (status != null) 'status': status}).toString());
      return;
    }
    final root = navigatorKey.currentContext;
    if (root != null && root.mounted) LiveBroadcasterStudioSheet.show(root, consentStatus: status);
  }
  @override
  Widget build(BuildContext context) => _showConnections
      ? ChannelConnectionsScreen(returnStatus: widget.returnStatus)
      : const Scaffold(body: Center(child: HadayahLoadingIndicator()));
}
