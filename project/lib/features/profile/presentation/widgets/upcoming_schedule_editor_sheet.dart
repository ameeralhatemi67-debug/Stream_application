import '../../../../core/widgets/phone_input_guard.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_fields.dart';
import '../../../../core/layout/window_class.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/upcoming_schedule.dart';

class UpcomingScheduleEditorSheet extends StatefulWidget {
  const UpcomingScheduleEditorSheet(
      {super.key, required this.streamerId, this.existing});
  final String streamerId;
  final UpcomingSchedule? existing;

  @override
  State<UpcomingScheduleEditorSheet> createState() =>
      _UpcomingScheduleEditorSheetState();
}

class _UpcomingScheduleEditorSheetState
    extends State<UpcomingScheduleEditorSheet> {
  late final TextEditingController _titleEn;
  late final TextEditingController _titleAr;
  late final TextEditingController _descriptionEn;
  late final TextEditingController _descriptionAr;
  late final TextEditingController _tags;
  late bool _special;
  late Set<int> _weekdays;
  late DateTime _date;
  late TimeOfDay _time;
  late String _color;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isPhoneLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).unfocus();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final saudiNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final oneTimeSaudi =
        existing?.oneTimeStartUtc?.toUtc().add(const Duration(hours: 3));
    _special = existing?.isSpecial ?? false;
    _weekdays = existing?.weekdays.toSet() ?? {saudiNow.weekday};
    _date = oneTimeSaudi ??
        DateTime.utc(saudiNow.year, saudiNow.month, saudiNow.day + 1);
    if (existing == null) {
      _time = const TimeOfDay(hour: 17, minute: 0);
    } else {
      final parts = existing.localTime.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _color = existing?.colorKey ?? 'green';
    _titleEn = TextEditingController(text: existing?.titleEn ?? '');
    _titleAr = TextEditingController(text: existing?.titleAr ?? '');
    _descriptionEn = TextEditingController(text: existing?.descriptionEn ?? '');
    _descriptionAr = TextEditingController(text: existing?.descriptionAr ?? '');
    _tags = TextEditingController(text: existing?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _titleEn.dispose();
    _titleAr.dispose();
    _descriptionEn.dispose();
    _descriptionAr.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final saudi = DateTime.now().toUtc().add(const Duration(hours: 3));
    final first = DateTime(saudi.year, saudi.month, saudi.day);
    final chosen = await showDatePicker(
        builder: (context, child) =>
            PhoneInputGuard(showHint: false, builder: (_, blocked) => child!),
        context: context,
        initialEntryMode: context.isPhoneLandscape
            ? DatePickerEntryMode.calendarOnly
            : DatePickerEntryMode.calendar,
        firstDate: first,
        lastDate: DateTime(2100),
        initialDate: _date.isBefore(first) ? first : _date);
    if (chosen != null) setState(() => _date = chosen);
  }

  Future<void> _pickTime() async {
    final chosen = await showTimePicker(
        builder: (context, child) =>
            PhoneInputGuard(showHint: false, builder: (_, blocked) => child!),
        context: context,
        initialTime: _time,
        initialEntryMode: context.isPhoneLandscape
            ? TimePickerEntryMode.dialOnly
            : TimePickerEntryMode.dial);
    if (chosen != null) setState(() => _time = chosen);
  }

  Future<void> _save() async {
    if (_saving) return;
    final en = _titleEn.text.trim();
    final ar = _titleAr.text.trim();
    if (context.locale.languageCode == 'ar' ? ar.isEmpty : en.isEmpty) {
      setState(() => _error = 'upcoming.title_required'.tr());
      return;
    }
    if (!_special && _weekdays.isEmpty) {
      setState(() => _error = 'upcoming.days_required'.tr());
      return;
    }
    final time = '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}';
    final oneTime = _special
        ? DateTime.utc(
                _date.year, _date.month, _date.day, _time.hour, _time.minute)
            .subtract(const Duration(hours: 3))
        : null;
    if (oneTime != null && !oneTime.isAfter(DateTime.now().toUtc())) {
      setState(() => _error = 'upcoming.future_required'.tr());
      return;
    }
    final approvedByLowercase = {
      for (final tag in context.read<AppProvider>().approvedTags)
        tag.toLowerCase(): tag,
    };
    final requestedTags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => approvedByLowercase[t.toLowerCase()] ?? t.toLowerCase())
        .toSet();
    if (requestedTags.length > 5 || requestedTags.any((t) => t.length > 32)) {
      setState(() => _error = 'upcoming.tags_limit'.tr());
      return;
    }
    final provider = context.read<AppProvider>();
    final approved = provider.approvedTags.toSet();
    final pending = requestedTags.where((t) => !approved.contains(t)).toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final tag in pending) {
        await provider.submitPendingTag(tag);
      }
      await provider.saveUpcomingSchedule(UpcomingSchedule(
        id: widget.existing?.id ?? '',
        streamerId: widget.streamerId,
        kind: _special ? 'once' : 'weekly',
        localTime: time,
        weekdays: _special ? const [] : (_weekdays.toList()..sort()),
        oneTimeStartUtc: oneTime,
        titleEn: en,
        titleAr: ar,
        descriptionEn: _descriptionEn.text.trim(),
        descriptionAr: _descriptionAr.text.trim(),
        tags: requestedTags.toList(),
        colorKey: _color,
      ));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (pending.isNotEmpty) {
        messenger.showSnackBar(
            SnackBar(content: Text('upcoming.tags_pending'.tr())));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'upcoming.save_failed'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    Widget pair(Widget en, Widget ar) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >=
                CanopyWindow.medium
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: en),
                const SizedBox(width: AppTheme.spaceLg),
                Expanded(child: ar)
              ])
            : Column(
                children: [en, const SizedBox(height: AppTheme.spaceMd), ar]));
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: context.isPhoneLandscape
              ? 0
              : MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            MediaQuery.sizeOf(context).height * CanopySize.sheetHeightFraction,
        child: CaSheet(
          bareChrome: true,
          title:
              (widget.existing == null ? 'upcoming.add' : 'upcoming.edit').tr(),
          onClose: () => Navigator.pop(context),
          actions: [
            CaButton(
                label: 'upcoming.save'.tr(),
                loading: _saving,
                onPressed: _saving ? null : _save)
          ],
          body:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('upcoming.saudi_time_note'.tr(),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.spaceLg),
            CaSegmentedTabs(
                labels: ['upcoming.weekly'.tr(), 'upcoming.special'.tr()],
                index: _special ? 1 : 0,
                onChanged: (i) => setState(() => _special = i == 1)),
            const SizedBox(height: AppTheme.spaceMd),
            if (_special)
              CaButton(
                  label: localizations.formatMediumDate(_date),
                  icon: CaGlyph.cal,
                  variant: CaButtonVariant.secondary,
                  onPressed: _pickDate)
            else
              Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      CaChip(
                          label: 'upcoming.day_$day'.tr(),
                          selected: _weekdays.contains(day),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _weekdays.add(day);
                              } else {
                                _weekdays.remove(day);
                              }
                            });
                          }),
                  ]),
            const SizedBox(height: AppTheme.spaceMd),
            CaButton(
                label:
                    '${localizations.formatTimeOfDay(_time)} ${'upcoming.saudi_time'.tr()}',
                icon: CaGlyph.clock,
                variant: CaButtonVariant.secondary,
                onPressed: _pickTime),
            const SizedBox(height: AppTheme.spaceLg),
            CaCard(
                child: Column(children: [
              pair(
                  CaInput(
                      label: 'upcoming.title_en'.tr(),
                      controller: _titleEn,
                      maxLength: 120,
                      textDirection: TextDirection.ltr),
                  CaInput(
                      label: 'upcoming.title_ar'.tr(),
                      controller: _titleAr,
                      maxLength: 120,
                      textDirection: TextDirection.rtl)),
              const SizedBox(height: AppTheme.spaceMd),
              pair(
                  CaInput(
                      label: 'upcoming.description_en'.tr(),
                      controller: _descriptionEn,
                      maxLength: 1000,
                      maxLines: 3,
                      textDirection: TextDirection.ltr),
                  CaInput(
                      label: 'upcoming.description_ar'.tr(),
                      controller: _descriptionAr,
                      maxLength: 1000,
                      maxLines: 3,
                      textDirection: TextDirection.rtl)),
            ])),
            const SizedBox(height: AppTheme.spaceLg),
            CaInput(
                label: 'upcoming.tags'.tr(),
                helper: 'upcoming.tags_help'.tr(),
                controller: _tags),
            const SizedBox(height: AppTheme.spaceMd),
            Text('upcoming.color'.tr()),
            Wrap(
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  for (final color in const ['green', 'gold', 'berry', 'slate'])
                    CaChip(
                        label: 'upcoming.color_$color'.tr(),
                        selected: _color == color,
                        onSelected: (_) => setState(() => _color = color)),
                ]),
            if (_error != null)
              Padding(
                  padding:
                      const EdgeInsetsDirectional.only(top: AppTheme.spaceMd),
                  child: Text(_error!,
                      style: const TextStyle(color: Canopy.liveCrimson))),
          ]),
        ),
      ),
    );
  }
}
