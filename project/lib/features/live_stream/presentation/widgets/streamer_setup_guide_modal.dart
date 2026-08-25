import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import 'rtmp_ip_dialog.dart' show StudioMode;

enum _ActionKind { openStudio, pasteClipboard }

class _QuestAction {
  final _ActionKind kind;
  final String label;

  const _QuestAction(this.kind, this.label);
}

class _Quest {
  final String questName;
  final IconData icon;
  final String heading;
  final String body;
  final List<_QuestAction> actions;

  const _Quest({
    required this.questName,
    required this.icon,
    required this.heading,
    required this.body,
    this.actions = const [],
  });
}

/// Gamified multi-step "Streamer Academy" setup guide -- the Info (!) button
/// destination for all 3 Broadcaster Studio modes (V2 redesign). Replaces
/// the old plain numbered-steps dialog with a swipeable story-card carousel
/// (playful, non-technical "quest" copy), a two-tap "paste from clipboard"
/// shortcut that writes straight back into the studio sheet's stream key
/// field via [onStreamKeyPasted], and a direct external link into YouTube
/// Studio. Never asks for a Google account or channel URL -- it only opens
/// YouTube Studio's public dashboard and lets the streamer sign in there
/// themselves.
class StreamerSetupGuideModal extends StatefulWidget {
  final StudioMode mode;
  final ValueChanged<String>? onStreamKeyPasted;

  const StreamerSetupGuideModal({
    super.key,
    required this.mode,
    this.onStreamKeyPasted,
  });

  static Future<void> show(
    BuildContext context, {
    required StudioMode mode,
    ValueChanged<String>? onStreamKeyPasted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => StreamerSetupGuideModal(
        mode: mode,
        onStreamKeyPasted: onStreamKeyPasted,
      ),
    );
  }

  @override
  State<StreamerSetupGuideModal> createState() =>
      _StreamerSetupGuideModalState();
}

class _StreamerSetupGuideModalState extends State<StreamerSetupGuideModal> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_Quest> _quests(bool isAr) {
    return switch (widget.mode) {
      StudioMode.obs => _obsQuests(isAr),
      StudioMode.phone => _phoneQuests(isAr),
      StudioMode.local => _localQuests(isAr),
    };
  }

  List<_Quest> _obsQuests(bool isAr) => [
        _Quest(
          questName: isAr ? 'مركز القيادة 🌐' : 'Mission Control 🌐',
          icon: Icons.public_rounded,
          heading: isAr ? 'افتح مركز القيادة' : 'Open Mission Control',
          body: isAr
              ? 'كل شيء يبدأ من استوديو يوتيوب -- مركز قيادتك للبث المباشر. افتحه وابحث عن زر "بدء البث".'
              : 'Everything starts at YouTube Studio -- your mission control for going live. Open it up and find the "Go Live" button.',
          actions: [
            _QuestAction(_ActionKind.openStudio,
                isAr ? '🔗 افتح استوديو يوتيوب' : '🔗 Open YouTube Studio'),
          ],
        ),
        _Quest(
          questName: isAr ? 'تصريح الدخول السري 🗝️' : 'The Secret VIP Pass 🗝️',
          icon: Icons.vpn_key_rounded,
          heading: isAr ? 'احصل على مفتاح بثك السري' : 'Grab Your Secret Stream Key',
          body: isAr
              ? 'مفتاح البث أشبه بتصريح دخول سري للكواليس. يخبر يوتيوب: "هذا البث فعلاً مني!" من استوديو يوتيوب، افتح تبويب "البث" واضغط نسخ بجانب مفتاح البث الافتراضي.'
              : 'Think of your Stream Key like a secret VIP backstage pass. It tells YouTube: "Hey, this video is really from ME!" In YouTube Studio, find the "Stream" tab and click Copy next to Default Stream Key.',
          actions: [
            _QuestAction(_ActionKind.openStudio,
                isAr ? '🔗 افتح استوديو يوتيوب' : '🔗 Open YouTube Studio'),
            _QuestAction(_ActionKind.pasteClipboard,
                isAr ? '📋 الصق من الحافظة' : '📋 Paste Key from Clipboard'),
          ],
        ),
        _Quest(
          questName: isAr ? 'توصيل الأسلاك 💻' : 'Connecting the Wires 💻',
          icon: Icons.cable_rounded,
          heading: isAr ? 'وصّل OBS بيوتيوب' : 'Wire Up OBS Studio',
          body: isAr
              ? 'افتح برنامج OBS على حاسوبك، اذهب إلى الإعدادات > البث، والصق مفتاح البث وعنوان الخادم هناك. هذا يربط كاميراتك مباشرة بيوتيوب.'
              : 'Open OBS Studio on your computer, go to Settings > Stream, and paste your Stream Key and Server URL there. This wires your camera straight to YouTube.',
        ),
        _Quest(
          questName: isAr ? 'جاهز للإقلاع 🎬' : 'Ready for Takeoff 🎬',
          icon: Icons.rocket_launch_rounded,
          heading: isAr ? 'أطلق بثك' : 'Launch Your Broadcast',
          body: isAr
              ? 'اضغط "بدء البث" في OBS أولاً، ثم اضغط "بدء البث المباشر" أدناه لإطلاق بثك للعالم. 3... 2... 1... انطلاق!'
              : 'Press "Start Streaming" in OBS first, then tap Go Live below to launch your broadcast to the world. 3... 2... 1... liftoff!',
        ),
      ];

  List<_Quest> _phoneQuests(bool isAr) => [
        _Quest(
          questName: isAr ? 'تفعيل الحساب ⏳' : 'Account Activation ⏳',
          icon: Icons.hourglass_top_rounded,
          heading: isAr ? 'فعّل قناتك أولاً' : 'Activate Your Channel First',
          body: isAr
              ? 'أول مرة تبث على يوتيوب؟ تحتاج قناتك لتفعيل لمرة واحدة يستغرق 24 ساعة قبل أن يُفتح البث المباشر. إذا بثّيت من قبل، تجاوز هذه الخطوة -- أنت جاهز!'
              : 'First time going live on YouTube? Your channel needs a one-time, 24-hour verification before live streaming unlocks. If you\'ve streamed before, skip ahead -- you\'re already good to go!',
        ),
        _Quest(
          questName: isAr ? 'اضبطه ولا تفكر فيه مجدداً 💾' : 'Set It & Forget It 💾',
          icon: Icons.save_rounded,
          heading: isAr ? 'الصق مفتاح البث مرة واحدة' : 'Paste Your Stream Key Once',
          body: isAr
              ? 'احصل على مفتاح البث من تبويب "البث" في استوديو يوتيوب والصقه هنا مرة واحدة فقط. سنتذكره للمرة القادمة.'
              : 'Grab your Stream Key from YouTube Studio\'s "Stream" tab and paste it once below. We\'ll remember it for next time, so you only ever have to do this once.',
          actions: [
            _QuestAction(_ActionKind.openStudio,
                isAr ? '🔗 افتح استوديو يوتيوب' : '🔗 Open YouTube Studio'),
            _QuestAction(_ActionKind.pasteClipboard,
                isAr ? '📋 الصق من الحافظة' : '📋 Paste Key from Clipboard'),
          ],
        ),
        _Quest(
          questName: isAr ? 'بث مباشر من جوالك 📱' : 'Live from Your Phone 📱',
          icon: Icons.smartphone_rounded,
          heading: isAr ? 'افتح الكاميرا وابدأ' : 'Open Camera & Go',
          body: isAr
              ? 'اضغط "فتح الكاميرا" وسيتحول جوالك بكاميرته وميكروفونه إلى بث مباشر فوري. بدون حاسوب، بدون OBS -- أنت فقط، مباشرة.'
              : 'Tap Open Camera and your phone\'s own camera and microphone become the broadcast. No laptop, no OBS -- just you, live.',
        ),
      ];

  List<_Quest> _localQuests(bool isAr) => [
        _Quest(
          questName: isAr ? 'نفس شبكة الغرفة 📶' : 'Same Room Network 📶',
          icon: Icons.wifi_rounded,
          heading: isAr ? 'اتصل بنفس شبكة الواي فاي' : 'Join the Same Wi-Fi',
          body: isAr
              ? 'هذا الوضع يبث عبر شبكة الواي فاي المحلية مباشرة -- بدون إنترنت. فقط تأكد أن جوالك وحاسوبك على نفس الشبكة.'
              : 'This mode streams straight over your local Wi-Fi -- no internet needed. Just make sure your phone and your laptop are connected to the same network.',
        ),
        _Quest(
          questName: isAr ? 'وصّل وابدأ ⚡' : 'Plug & Play ⚡',
          icon: Icons.bolt_rounded,
          heading: isAr ? 'أدخل عنوان الحاسوب' : 'Enter the Laptop IP',
          body: isAr
              ? 'ابحث عن عنوان IP المحلي لحاسوبك (يبدأ عادة بـ 192.168...)، اكتبه أدناه، واضغط بث. أنت تبث محلياً خلال ثوانٍ.'
              : 'Find your laptop\'s local IP address (usually starts with 192.168...), type it in below, and tap Stream. You\'re broadcasting locally in seconds.',
        ),
      ];

  Future<void> _openYoutubeStudio() async {
    final uri = Uri.parse('https://studio.youtube.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pasteFromClipboard(bool isAr) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;

    if (text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr
              ? 'الحافظة فارغة أو النص قصير جداً ليكون مفتاح بث.'
              : 'Clipboard is empty or too short to be a stream key.'),
        ),
      );
      return;
    }

    widget.onStreamKeyPasted?.call(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAr ? 'تم لصق مفتاح البث ✓' : 'Stream key pasted ✓'),
        backgroundColor: AppTheme.accentPink,
      ),
    );
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final quests = _quests(isAr);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: screenHeight * 0.72,
          padding: EdgeInsets.only(
            left: AppTheme.spaceLg,
            right: AppTheme.spaceLg,
            top: AppTheme.spaceMd,
            bottom: bottomInset > 0 ? bottomInset + AppTheme.spaceMd : AppTheme.spaceLg,
          ),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface1.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isAr, quests),
              const SizedBox(height: AppTheme.spaceMd),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: quests.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                  },
                  itemBuilder: (context, i) => _buildQuestCard(quests[i], isAr),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildDots(quests.length),
              const SizedBox(height: AppTheme.spaceMd),
              _buildNavRow(quests.length, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr, List<_Quest> quests) {
    final quest = quests[_currentPage];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? '✨ أكاديمية البث' : '✨ STREAMER ACADEMY',
                style: const TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isAr
                    ? 'المستوى ${_currentPage + 1} من ${quests.length}: ${quest.questName}'
                    : 'Level ${_currentPage + 1} of ${quests.length}: ${quest.questName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryDark),
          tooltip: isAr ? 'إغلاق' : 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildQuestCard(_Quest quest, bool isAr) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.darkBorderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8080), Color(0xFFFF5274)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentRed.withValues(alpha: 0.42),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(quest.icon, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                quest.heading,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                quest.body,
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (quest.actions.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceLg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quest.actions.map((action) {
                    return OutlinedButton(
                      onPressed: switch (action.kind) {
                        _ActionKind.openStudio => _openYoutubeStudio,
                        _ActionKind.pasteClipboard => () => _pasteFromClipboard(isAr),
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRed,
                        side: const BorderSide(color: AppTheme.accentRed),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                      ),
                      child: Text(
                        action.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.accentRed.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            width: active ? 26 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              color: active ? null : const Color(0xFF2C2F3E),
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFFFF8080), Color(0xFFFF5274)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavRow(int count, bool isAr) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == count - 1;

    return Row(
      children: [
        Expanded(
          child: isFirst
              ? const SizedBox.shrink()
              : OutlinedButton(
                  onPressed: () => _goToPage(_currentPage - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryDark,
                    side: const BorderSide(color: AppTheme.darkBorderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    isAr ? '◀ الخطوة السابقة' : '◀ Previous Step',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        if (!isFirst) const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: ElevatedButton(
            onPressed: isLast
                ? () => Navigator.of(context).pop()
                : () => _goToPage(_currentPage + 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Text(
              isLast
                  ? (isAr ? '🚀 فهمت، لنبدأ البث!' : "🚀 Got It, Let's Stream!")
                  : (isAr ? 'التحدي التالي ▶' : 'Next Quest ▶'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
