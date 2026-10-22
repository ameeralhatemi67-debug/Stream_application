// Design-system tokens. The names come from the original Canopy layout
// system; every value is Hidayah Gold (the default design; the Hedayah skin,
// ADR-016, changes chosen widgets at run time rather than these values).
import 'package:flutter/material.dart';
import 'hidayah_gold.dart';

export 'app_palette.dart';

abstract final class Canopy {
  static const transparent = Color(0x00000000);
  static const broadcastGlass = Color(0xD90B1117);
  static const cinemaBubble = Color(0x14FFFFFF);
  static const forestDeep = HidayahGold.s950;
  static const canopy900 = HidayahGold.s800;
  static const canopy800 = HidayahGold.g800;
  static const brandGreen = HidayahGold.g700; // AppTheme.primary / accent
  static const leaf = HidayahGold.g700; // last label-safe gradient stop
  static const fresh = HidayahGold.g400; // decorative only
  static const sketchBright = HidayahGold.g300; // decorative only
  static const mist = HidayahGold.g200;
  static const mint = HidayahGold.g100; // AppTheme.surfaceAlt
  static const dawn = HidayahGold.g50; // AppTheme.bg
  static const paper = Color(0xFFFFFFFF); // AppTheme.surface
  static const ink = HidayahGold.s900; // AppTheme.textPrimary
  static const slate = HidayahGold.s700; // AppTheme.textSecondary
  static const haze = HidayahGold.s600; // AppTheme.textMuted (12px and up)
  static const hairline = HidayahGold.hairline; // AppTheme.border
  static const hairlineStrong = HidayahGold.s500; // AppTheme.borderStrong
  static const liveCrimson =
      HidayahGold.live; // live signal and destructive only
  static const majlisGold = HidayahGold.g500; // ornament only
  static const warning = HidayahGold.warning;
  static const infoTeal = HidayahGold.info;
  static final warningTint =
      Color.alphaBlend(warning.withValues(alpha: .1), paper);
  static final errorTint =
      Color.alphaBlend(liveCrimson.withValues(alpha: .1), paper);
  static final modalBarrier = forestDeep.withValues(alpha: .4);
  static const shadowTint = HidayahGold.g900;
}

/// Gradients. Extend the existing AppGradients (keep `brand`, `soft`, `mediaScrim`).
abstract final class CanopyGradients {
  static const edgeFade = LinearGradient(colors: [
    Canopy.transparent,
    Canopy.paper,
    Canopy.paper,
    Canopy.transparent
  ], stops: [
    0,
    .04,
    .96,
    1
  ]);
  /// The hero panel. It used to drift with [progress]; the night band is
  /// lit from the top and holds still.
  static LinearGradient panelAt(double progress) => panel;

  static const latticeFade = RadialGradient(
      colors: [Canopy.paper, Canopy.transparent],
      stops: [0, CanopyTexture.fadeStop]);
  static final heroTextScrim = Canopy.forestDeep.withValues(alpha: .68);
  static final entryTextScrim = Canopy.forestDeep.withValues(alpha: .32);
  static const pill = HidayahGradients.minted; // ink text on gold

  static const pillWide = HidayahGradients.meter; // meters and decorative bars only

  static const panel = HidayahGradients.night; // text goes on white cards above it

  static const canopy = HidayahGradients.night; // pair with scrim for text

  static const dawn = HidayahGradients.ivory;

  static const avatarFallback = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [HidayahGold.g200, HidayahGold.g100],
  );
  static const skeleton = LinearGradient(
    colors: [Canopy.mint, Canopy.dawn, Canopy.mint],
  );
  static const liveSignal = HidayahGradients.live; // LIVE badge only; label-safe

  /// Text may sit only where this is at least 0.75 opaque (bottom ~40%).
  static const scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .45, 1],
    colors: [Color(0x000B1117), Color(0x730B1117), Color(0xD10B1117)],
  );

  static const ring = HidayahGradients.ring;

  /// The same sweep as [ring], in the live crimson family: the ring that
  /// spins around an account while it is broadcasting.
  static const liveRing = SweepGradient(
    colors: [
      Color(0xFF8A1F33),
      Color(0xFFC2343F),
      Color(0xFFF2B5C0),
      Color(0xFF8A1F33)
    ],
  );

  /// Chat moderators: a violet sweep, clearly apart from the gold ring that
  /// admins and broadcasters wear.
  static const moderatorRing = SweepGradient(
    colors: [
      Color(0xFF3F3485),
      Color(0xFF7A6BC4),
      Color(0xFFD6D0F0),
      Color(0xFF3F3485)
    ],
  );
}

abstract final class CanopyRadius {
  static const input = 14.0,
      card = 20.0,
      hero = 28.0,
      sheetTop = 28.0,
      dialog = 24.0,
      pill = 999.0,
      orgAvatar = 16.0;
}

abstract final class CanopyShadow {
  static const _t = Canopy.shadowTint;
  static List<BoxShadow> get card => [
        BoxShadow(
            color: _t.withValues(alpha: .06),
            blurRadius: 2,
            offset: const Offset(0, 1)),
        BoxShadow(
            color: _t.withValues(alpha: .45),
            blurRadius: 24,
            spreadRadius: -16,
            offset: const Offset(0, 14)),
      ];
  static List<BoxShadow> get floating => [
        BoxShadow(
            color: _t.withValues(alpha: .45),
            blurRadius: 32,
            spreadRadius: -16,
            offset: const Offset(0, 16))
      ];
  static List<BoxShadow> get pill => [
        BoxShadow(
            color: _t.withValues(alpha: .8),
            blurRadius: 22,
            spreadRadius: -12,
            offset: const Offset(0, 10))
      ];

  /// The 5px lighter tray around feature cards ("double bezel").
  static List<BoxShadow> get bezel =>
      [BoxShadow(color: Canopy.paper.withValues(alpha: .55), spreadRadius: 5)];
}

/// One place for durations and curves. Never use Curves.easeIn on UI.
abstract final class CanopyMotion {
  static const searchDebounce = Duration(milliseconds: 250);
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);
  static const none = Duration.zero;
  static const welcomeEntrance = Duration(milliseconds: 410);
  static Curve welcomeStep(int index) => Interval(
      index * stagger.inMilliseconds / welcomeEntrance.inMilliseconds,
      (index * stagger.inMilliseconds + sheetIn.inMilliseconds) /
          welcomeEntrance.inMilliseconds,
      curve: drawer);
  static const entryLogo = Duration(milliseconds: 400),
      splashNavigation = Duration(milliseconds: 1350),
      accountAlert = Duration(seconds: 6),
      textureCycle = Duration(milliseconds: 10667);
  static const meterRise = Duration(milliseconds: 90),
      meterFall = Duration(milliseconds: 420),
      meterPeak = Duration(milliseconds: 700);
  static const press = Duration(milliseconds: 160);
  static const buttonState = Duration(milliseconds: 200);
  static const followCheck = Duration(milliseconds: 300);
  static const chipIn = Duration(milliseconds: 240);
  static const chipOut = Duration(milliseconds: 140);
  static const toastLifetime = Duration(seconds: 4);
  static const reaction = Duration(milliseconds: 2400);
  static const chatArrival = Duration(milliseconds: 280);
  static const feedStagger = Duration(milliseconds: 45);
  static const contentIn = Duration(milliseconds: 380);
  static const contentStagger = Duration(milliseconds: 70);
  static const count = Duration(milliseconds: 420);
  static const emptyDraw = Duration(milliseconds: 900);
  static const sheetIn = Duration(milliseconds: 320);
  static const sheetOut = Duration(milliseconds: 200);
  static const dialog = Duration(milliseconds: 200);
  static const tabThumb = Duration(milliseconds: 280);
  static const stagger = Duration(milliseconds: 45);
  static const liveRing = Duration(milliseconds: 1800);
  static const shimmer = Duration(milliseconds: 1300);
  static const auditSlowFactor = 4.0;
  static const capsuleCycle = Duration(milliseconds: 4000);
  static const capsuleBloom = Cubic(.64, .04, .41, 1);
  static const holdToEnd = Duration(milliseconds: 1200);
  static const holdRelease = Duration(milliseconds: 200);
  static const toastIn = Duration(milliseconds: 400);
  static const toastOut = Duration(milliseconds: 200);
  static const popoverIn = Duration(milliseconds: 180);
  static const popoverOut = Duration(milliseconds: 120);
  static const cardToPage = Duration(milliseconds: 360);
  static const pagePush = Duration(milliseconds: 280);
  static const navPill = Duration(milliseconds: 320);
  static const bloom = Duration(milliseconds: 420);
  static const gradientDrift = Duration(seconds: 22);
  static const avatarRing = Duration(seconds: 6);
  static const pressScale = 0.97;
  static const gradientDriftDegrees = 14.0;

  /// Use around every non-essential animation.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Star lattice, owner pick: 17% on the lab slider = 0.136 opacity (line-weight factor 0.8).
abstract final class CanopyTexture {
  static const starLatticeOpacity = 0.136;
  static const headerLatticeOpacity = 0.06;
  static const starTile = 64.0;

  /// Radial fade toward the content: centre at the top-end corner, transparent at 88%.
  static const fadeRadius = 1.3;
  static const fadeStop = 0.88;
}

/// Window classes. Medium and expanded match AppBreakpoints; large is new.
abstract final class CanopyWindow {
  static const insetCompact = 16.0,
      insetMedium = 24.0,
      insetExpanded = 28.0,
      insetLarge = 36.0;
  static const medium = 600.0,
      expanded = 900.0,
      large = 1280.0,
      contentMax = 1200.0;
  static const phoneShortestSideMax = 600.0,
      paneLandscapeMinWidth = 720.0,
      scholarCardMinWidth = 168.0;
}

abstract final class CanopySize {
  static const contentRise = 12.0,
      contentBlur = 4.0,
      pageShift = 26.0,
      confirmTilt = .12,
      confirmScale = .03;
  static const double adminRail = 280, adminKpiMin = 160;
  static const double shortSurfaceHeight = 400;
  static const double dialogReflowTextScale = 1.6;
  static const wizardForm = 640.0;
  static const wizardRail = 320.0;
  static const wizardMax = 1000.0;
  static const double settingsMax = 1120;
  static const broadcastReadOnlyChatFloor = 180.0;
  static const broadcastChatSheetFraction = .60,
      broadcastChatPreviewFraction = .40;
  static const scholarBanner = 72.0,
      heroCompact = 200.0,
      heroMedium = 260.0,
      heroExpanded = 300.0,
      heroLarge = 340.0,
      heroLandscape = 170.0,
      liveTile = 240.0,
      profilePane = 330.0,
      profilePaneLarge = 360.0,
      profileHeader = 160.0,
      profileAvatar = 42.0,
      navContentGap = 110.0,
      mapListMedium = 420.0,
      mapListExpanded = 380.0,
      mapListPeek = .12,
      mapListHalf = .5,
      mapListFull = .9,
      appBarScaled = 80.0;
  static const target = 48.0,
      icon = 24.0,
      inlineIcon = 20.0,
      buttonRing = 28.0,
      smallAvatar = 22.0,
      avatarRadius = 20.0,
      controlRadius = 24.0,
      cardBanner = 96.0,
      lectureImageWidth = 80.0,
      lectureImageHeight = 64.0,
      avatarOverlap = 12.0,
      verifiedIcon = 12.0,
      toastRise = 24.0,
      toastDisc = 32.0,
      paneMedium = 340.0,
      paneLarge = 400.0,
      entryShortHeight = 600.0,
      welcomeDisplay = 44.0,
      welcomeLogo = 56.0,
      welcomeCardMax = 440.0,
      welcomePanelFraction = .46,
      welcomeHeadlineGapFraction = .10,
      welcomeOverlap = 24.0,
      navBlur = 14.0,
      navPaperAlpha = .78,
      railMedium = 84.0,
      railExpanded = 224.0,
      railLogo = 56.0,
      stateBlur = 3.0,
      galleryDialogHeight = 600.0,
      reactionDrift = 24.0,
      reactionTilt = .2,
      reactionIcon = 28.0,
      reactionRise = 120.0,
      meterHeight = 10.0,
      meterDot = 4.0,
      warningThreshold = .85,
      clippingThreshold = .95,
      stepBar = 6.0,
      skeletonLine = 14.0,
      emptyArtWidth = 112.0,
      emptyArtHeight = 72.0;
  static const organizationMax = 880.0;
  static const textScaleMax = 1.6;
  static const focusWidth = 2.0,
      stroke = 1.0,
      ring = 2.0,
      sheetMax = 520.0,
      dialogCompactMax = 440.0,
      studioMax = 560.0,
      drawerMax = 480.0,
      sheetHeightFraction = .9,
      handleWidth = 40.0,
      handleHeight = 4.0;
  static const glassAlpha = .20,
      glassBorderAlpha = .35,
      highlightAlpha = .28,
      disabledAlpha = .55;
}
