import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/location_picker_modal.dart';

class OrgBranchVenue {
  String branchName;
  String city;
  String address;
  LatLng coordinates;

  OrgBranchVenue({
    required this.branchName,
    required this.city,
    required this.address,
    required this.coordinates,
  });
}

/// Step 4: Location & Official Contact Information (With Main Campus Card & Safe Phone Placeholders)
class ApplyStep4Location extends StatefulWidget {
  final String selectedCity;
  final TextEditingController venueController;
  final TextEditingController phoneController;
  final String preferredContact;
  final bool isOrganization;
  final LatLng? selectedCoordinates;
  final List<OrgBranchVenue> orgBranches;
  final Function(String city) onCityChanged;
  final Function(String contact) onContactPrefChanged;
  final Function(LatLng coordinates) onCoordinatesSelected;
  final Function(OrgBranchVenue branch) onAddBranch;
  final Function(int index) onRemoveBranch;

  const ApplyStep4Location({
    super.key,
    required this.selectedCity,
    required this.venueController,
    required this.phoneController,
    required this.preferredContact,
    this.isOrganization = false,
    this.selectedCoordinates,
    this.orgBranches = const [],
    required this.onCityChanged,
    required this.onContactPrefChanged,
    required this.onCoordinatesSelected,
    required this.onAddBranch,
    required this.onRemoveBranch,
  });

  static const Map<String, String> cityOptions = {
    'khobar': 'Al Khobar (الخبر)',
    'dhahran': 'Dhahran (الظهران)',
    'dammam': 'Dammam (الدمام)',
    'ahsa': 'Al-Ahsa (الأحساء)',
    'jubail': 'Jubail (الجبيل)',
    'riyadh': 'Riyadh (الرياض)',
    'other': 'Other KSA Region',
  };

  @override
  State<ApplyStep4Location> createState() => _ApplyStep4LocationState();
}

class _ApplyStep4LocationState extends State<ApplyStep4Location> {
  String? _phoneValidationError;

  @override
  void initState() {
    super.initState();
    _validatePhone(widget.phoneController.text);
  }

  void _validatePhone(String val) {
    // Strip whitespace automatically
    final cleaned = val.replaceAll(RegExp(r'\s+'), '');
    if (cleaned != widget.phoneController.text) {
      widget.phoneController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    if (cleaned.isEmpty) {
      setState(() => _phoneValidationError = null);
      return;
    }

    // Check for invalid letters / characters
    final hasInvalidChars = RegExp(r'[^0-9+]').hasMatch(cleaned);
    if (hasInvalidChars) {
      setState(() => _phoneValidationError = 'Invalid characters. Numbers only.');
      return;
    }

    // Saudi phone formats:
    // 1. 05XXXXXXXX (10 digits starting with 05)
    // 2. 9665XXXXXXXX (12 digits starting with 9665)
    // 3. +9665XXXXXXXX (13 chars starting with +9665)
    final isValid05 = RegExp(r'^05[0-9]{8}$').hasMatch(cleaned);
    final isValid966 = RegExp(r'^9665[0-9]{8}$').hasMatch(cleaned);
    final isValidPlus966 = RegExp(r'^\+9665[0-9]{8}$').hasMatch(cleaned);

    if (isValid05 || isValid966 || isValidPlus966) {
      setState(() => _phoneValidationError = null);
    } else {
      if (cleaned.startsWith('05') && cleaned.length < 10) {
        setState(() => _phoneValidationError = 'Too short: 05X XXX XXXX (10 digits required)');
      } else if (cleaned.startsWith('+9665') && cleaned.length < 13) {
        setState(() => _phoneValidationError = 'Too short: +966 5X XXX XXXX (13 chars required)');
      } else if (cleaned.startsWith('9665') && cleaned.length < 12) {
        setState(() => _phoneValidationError = 'Too short: 966 5X XXX XXXX (12 digits required)');
      } else {
        setState(() => _phoneValidationError = 'Must be a valid Saudi number (e.g. 05X XXX XXXX or +966 5X XXX XXXX)');
      }
    }
  }

  Future<void> _openMapPinpoint({Function(LocationPickerResult res)? onResult}) async {
    final result = await LocationPickerModal.show(
      context: context,
      initialCity: widget.selectedCity,
      initialLocation: widget.selectedCoordinates,
    );

    if (result != null) {
      if (onResult != null) {
        onResult(result);
      } else {
        setState(() {
          widget.venueController.text = result.suggestedAddress;
          widget.onCityChanged(result.city);
          widget.onCoordinatesSelected(result.coordinates);
        });
      }
    }
  }

  void _showAddBranchDialog() {
    final branchNameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String branchCity = widget.selectedCity;
    LatLng branchCoord = const LatLng(26.2172, 50.1971);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          title: Text('design_ui.add_additional_campus_branch'.tr(),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: branchNameCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Branch / Campus Name *',
                      hintText: 'e.g. Dammam North Campus',
                      filled: true,
                      fillColor: AppTheme.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addressCtrl,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Branch Address / Description *',
                            hintText: 'e.g. King Fahd Road, Dammam',
                            filled: true,
                            fillColor: AppTheme.surfaceAlt,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                          foregroundColor: AppTheme.danger,
                        ),
                        icon: const Icon(Icons.pin_drop_rounded),
                        tooltip: 'Pinpoint Branch on Map',
                        onPressed: () async {
                          final res = await LocationPickerModal.show(
                            context: context,
                            initialCity: branchCity,
                            initialLocation: branchCoord,
                          );
                          if (res != null) {
                            setDialogState(() {
                              addressCtrl.text = res.suggestedAddress;
                              branchCity = res.city;
                              branchCoord = res.coordinates;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('design_ui.cancel'.tr(), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: AppTheme.onMedia),
              onPressed: () {
                if (branchNameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('design_ui.please_enter_a_branch_name_and_address'.tr())),
                  );
                  return;
                }
                widget.onAddBranch(
                  OrgBranchVenue(
                    branchName: branchNameCtrl.text.trim(),
                    city: branchCity,
                    address: addressCtrl.text.trim(),
                    coordinates: branchCoord,
                  ),
                );
                Navigator.of(ctx).pop();
              },
              child: Text('design_ui.add_branch'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCampusSection() {
    final cityName = ApplyStep4Location.cityOptions[widget.selectedCity] ?? widget.selectedCity;
    final addressText = widget.venueController.text.trim();

    if (widget.isOrganization) {
      //  Structured Main Campus / HQ Card for Organizations
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: AppTheme.danger),
                          const SizedBox(width: 4),
                          Text(
                            'wizard_steps.step4_hq_badge'.tr(),
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.pin_drop_rounded, size: 15),
                  label: Text('wizard_steps.step4_pinpoint_btn'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _openMapPinpoint(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.venueController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'wizard_steps.step4_venue_org_label'.tr(),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: 'e.g. Al-Rakah HQ Campus, Innovation Auditorium',
                prefixIcon: const Icon(Icons.apartment_rounded, color: AppTheme.danger),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
            if (addressText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$cityName • $addressText',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else {
      //  Standard Individual Broadcaster Location Input
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: widget.venueController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'wizard_steps.step4_venue_ind_label'.tr(),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: 'e.g. Al-Rakah HQ Campus, Innovation Auditorium',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.danger),
                filled: true,
                fillColor: AppTheme.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.danger, width: 1.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.pin_drop_rounded, color: AppTheme.danger),
              tooltip: 'wizard_steps.step4_pinpoint_btn'.tr(),
              onPressed: () => _openMapPinpoint(),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isOrganization ? 'wizard_steps.step4_title_org'.tr() : 'wizard_steps.step4_title_ind'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step4_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // City Dropdown
          Text(
            'map.select_city'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.selectedCity,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceAlt,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: ApplyStep4Location.cityOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) widget.onCityChanged(val);
                },
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Main Campus Section (Card for Org, Input for Individual)
          _buildMainCampusSection(),
          const SizedBox(height: AppTheme.spaceMd),

          // Organization Additional Campus / Branches Section
          if (widget.isOrganization) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Additional Campus Branches (${widget.orgBranches.length})',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: Text('design_ui.add_branch'.tr(), style: const TextStyle(fontSize: 11)),
                  onPressed: _showAddBranchDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.orgBranches.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.orgBranches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final br = widget.orgBranches[idx];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: AppTheme.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                br.branchName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                br.address,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          onPressed: () => widget.onRemoveBranch(idx),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          //  Safe Saudi Phone Number Placeholder (+966 / 05) with Validation
          TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            onChanged: _validatePhone,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Phone / WhatsApp Number (Saudi format) *',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: '05X XXX XXXX or +966 5X XXX XXXX',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.danger),
              suffixIcon: widget.phoneController.text.isNotEmpty
                  ? (_phoneValidationError == null
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : const Icon(Icons.error_outline_rounded, color: AppTheme.danger))
                  : null,
              filled: true,
              fillColor: AppTheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: widget.phoneController.text.isNotEmpty
                      ? (_phoneValidationError == null ? Colors.green.withValues(alpha: 0.5) : AppTheme.danger)
                      : AppTheme.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: _phoneValidationError == null ? Colors.green : AppTheme.danger,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_phoneValidationError != null) ...[
            const SizedBox(height: 4),
            Text(
              _phoneValidationError!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text('design_ui.accepts_05xxxxxxxx_9665xxxxxxxx_or_9665xxxxxxxx_without_spaces_e_'.tr(),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),

          // Preferred Contact Channel
          Text('design_ui.preferred_admin_contact_method'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildContactOption(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  value: 'whatsapp',
                  isSelected: widget.preferredContact == 'whatsapp',
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: _buildContactOption(
                  icon: Icons.phone_callback_outlined,
                  label: 'Phone Call',
                  value: 'phone',
                  isSelected: widget.preferredContact == 'phone',
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: _buildContactOption(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: 'email',
                  isSelected: widget.preferredContact == 'email',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => widget.onContactPrefChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.danger.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.danger : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.danger : AppTheme.textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
