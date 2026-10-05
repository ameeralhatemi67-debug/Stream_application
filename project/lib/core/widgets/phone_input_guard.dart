import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../layout/window_class.dart';
import '../theme/app_theme.dart';

/// Keep the caller's field, controller and callbacks alive during rotation.
class PhoneInputGuard extends StatefulWidget {
  const PhoneInputGuard(
      {super.key, required this.builder, this.showHint = true});
  final Widget Function(BuildContext context, bool readOnly) builder;
  final bool showHint;

  @override
  State<PhoneInputGuard> createState() => _PhoneInputGuardState();
}

class _PhoneInputGuardState extends State<PhoneInputGuard> {
  final _focus = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isPhoneLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focus.hasFocus) _focus.unfocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = context.isPhoneLandscape;
    return Focus(
      focusNode: _focus,
      canRequestFocus: false,
      descendantsAreFocusable: !blocked,
      child: !widget.showHint || !blocked
          ? widget.builder(context, blocked)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                    fit: FlexFit.loose,
                    child: widget.builder(context, blocked)),
                if (blocked && widget.showHint) ...[
                  const SizedBox(height: AppTheme.spaceXs),
                  Text('ds.rotate_to_edit'.tr(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
    );
  }
}
