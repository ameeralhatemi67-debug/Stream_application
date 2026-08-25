import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/models/terms_and_conditions_model.dart';

/// Full-screen paging reader for the platform's 3 legal documents (Terms of
/// Service, Broadcaster Code of Conduct, Privacy Policy), letting the user
/// move between all 3 without backing out to Settings between each one.
class LegalDocumentReaderScreen extends StatefulWidget {
  final TermsAndConditionsModel terms;
  final int initialDocumentIndex;

  const LegalDocumentReaderScreen({
    super.key,
    required this.terms,
    this.initialDocumentIndex = 0,
  });

  @override
  State<LegalDocumentReaderScreen> createState() =>
      _LegalDocumentReaderScreenState();
}

class _LegalDocumentReaderScreenState
    extends State<LegalDocumentReaderScreen> {
  late int _currentIndex = widget.initialDocumentIndex.clamp(0, 2);

  void _goTo(int index) => setState(() => _currentIndex = (index + 3) % 3);

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final docs = <({String title, String content})>[
      (
        title: 'settings.view_terms'.tr(),
        content: widget.terms.getLocalizedTerms(langCode),
      ),
      (
        title: 'settings.view_guidelines'.tr(),
        content: widget.terms.getLocalizedGuidelines(langCode),
      ),
      (
        title: 'settings.view_privacy'.tr(),
        content: widget.terms.getLocalizedPrivacy(langCode),
      ),
    ];
    final doc = docs[_currentIndex];

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        title: Text(doc.title),
        backgroundColor: AppTheme.darkBgBase,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: SelectableText(
          doc.content,
          style: const TextStyle(
            color: AppTheme.textSecondaryDark,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.darkBorderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _goTo(_currentIndex - 1),
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                  label: Text('settings.legal_reader_previous'.tr()),
                ),
              ),
              Text(
                '${_currentIndex + 1} / 3',
                style: const TextStyle(
                    color: AppTheme.textMutedDark, fontSize: 11),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _goTo(_currentIndex + 1),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  iconAlignment: IconAlignment.end,
                  label: Text('settings.legal_reader_next'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
