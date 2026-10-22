import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_skin.dart';

/// Lessons's stroke icons (24 px grid, 1.8 stroke), the set the reviewed
/// prototype uses. Directional ones mirror in right-to-left layouts.
enum TGlyph {
  search, bell, bookmark, gear, languages, map, pin, calendar, clock, user, users, check, x, plus, minus,
  chevron, chevronDown, arrow, arrowEnd, share, play, mic, book, chat, mosque, chart, shield, key, phone,
  eye, list, grid, edit, trash, upload, flag, star, sun, sunLow, sunrise, sunset, moon, globe, sparkle,
  info, alert, history, link, copy, send, nav, filter, logout, refresh, inbox, whatsapp, lock, repeat,
  radio, file, target, car, access, home, compass
}

const _paths = <TGlyph, String>{
  TGlyph.search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  TGlyph.bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  TGlyph.bookmark: '<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>',
  TGlyph.gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
  TGlyph.languages: '<path d="m5 8 6 6"/><path d="m4 14 6-6 2-3"/><path d="M2 5h12"/><path d="M7 2h1"/><path d="m22 22-5-10-5 10"/><path d="M14 18h6"/>',
  TGlyph.map: '<path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15"/><path d="M15 6v15"/>',
  TGlyph.pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  TGlyph.calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  TGlyph.clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  TGlyph.user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  TGlyph.users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
  TGlyph.check: '<path d="M20 6 9 17l-5-5"/>',
  TGlyph.x: '<path d="M18 6 6 18M6 6l12 12"/>',
  TGlyph.plus: '<path d="M12 5v14M5 12h14"/>',
  TGlyph.minus: '<path d="M5 12h14"/>',
  TGlyph.chevron: '<path d="m9 18 6-6-6-6"/>',
  TGlyph.chevronDown: '<path d="m6 9 6 6 6-6"/>',
  TGlyph.arrow: '<path d="M19 12H5M12 19l-7-7 7-7"/>',
  TGlyph.arrowEnd: '<path d="M5 12h14M12 5l7 7-7 7"/>',
  TGlyph.share: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.59 13.51 6.83 3.98M15.41 6.51l-6.82 3.98"/>',
  TGlyph.play: '<path d="M7 4v16l13-8z" fill="#000"/>',
  TGlyph.mic: '<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10v1a7 7 0 0 1-14 0v-1M12 18v4"/>',
  TGlyph.book: '<path d="M2 4h6a4 4 0 0 1 4 4v13a3 3 0 0 0-3-3H2z"/><path d="M22 4h-6a4 4 0 0 0-4 4v13a3 3 0 0 1 3-3h7z"/>',
  TGlyph.chat: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  TGlyph.mosque: '<path d="M2 21h20"/><path d="M4 21V9l1.5-3L7 9v12"/><path d="M9 21v-7h12v7"/><path d="M9.5 14c0-3.2 5.5-4.4 5.5-8 0 3.6 5.5 4.8 5.5 8"/><path d="M14 21v-3a1 1 0 0 1 2 0v3"/>',
  TGlyph.chart: '<path d="M3 3v18h18"/><path d="M7 16v-5M12 16V8M17 16v-8"/>',
  TGlyph.shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
  TGlyph.key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>',
  TGlyph.phone: '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/>',
  TGlyph.eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  TGlyph.list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
  TGlyph.grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  TGlyph.edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  TGlyph.trash: '<path d="M3 6h18M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>',
  TGlyph.upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m17 8-5-5-5 5M12 3v12"/>',
  TGlyph.flag: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/>',
  TGlyph.star: '<path d="m12 2 3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"/>',
  TGlyph.sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>',
  TGlyph.sunLow: '<circle cx="12" cy="13" r="4"/><path d="M12 5v1M4.93 8.93l.7.7M3 13h1M20 13h1M18.36 9.64l.7-.7M2 20h20"/>',
  TGlyph.sunrise: '<path d="M17 18a5 5 0 0 0-10 0"/><path d="M12 2v7M4.22 10.22l1.42 1.42M1 18h2M21 18h2M18.36 11.64l1.42-1.42M23 22H1M8 6l4-4 4 4"/>',
  TGlyph.sunset: '<path d="M17 18a5 5 0 0 0-10 0"/><path d="M12 9V2M4.22 10.22l1.42 1.42M1 18h2M21 18h2M18.36 11.64l1.42-1.42M23 22H1M16 5l-4 4-4-4"/>',
  TGlyph.moon: '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
  TGlyph.globe: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
  TGlyph.sparkle: '<path d="M12 3l1.9 5.6 5.6 1.9-5.6 1.9L12 18l-1.9-5.6-5.6-1.9 5.6-1.9z"/>',
  TGlyph.info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
  TGlyph.alert: '<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>',
  TGlyph.history: '<path d="M3 3v5h5"/><path d="M3.05 13A9 9 0 1 0 6 5.3L3 8"/><path d="M12 7v5l4 2"/>',
  TGlyph.link: '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  TGlyph.copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
  TGlyph.send: '<path d="m22 2-7 20-4-9-9-4z"/><path d="M22 2 11 13"/>',
  TGlyph.nav: '<path d="m3 11 19-9-9 19-2-8z"/>',
  TGlyph.filter: '<path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4"/>',
  TGlyph.logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
  TGlyph.refresh: '<path d="M21 12a9 9 0 1 1-2.64-6.36L21 8"/><path d="M21 3v5h-5"/>',
  TGlyph.inbox: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
  TGlyph.whatsapp: '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8z"/>',
  TGlyph.lock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  TGlyph.repeat: '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  TGlyph.radio: '<circle cx="12" cy="12" r="2"/><path d="M16.24 7.76a6 6 0 0 1 0 8.49M7.76 16.24a6 6 0 0 1 0-8.49M19.07 4.93a10 10 0 0 1 0 14.14M4.93 19.07a10 10 0 0 1 0-14.14"/>',
  TGlyph.file: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/>',
  TGlyph.target: '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
  TGlyph.car: '<path d="M5 17h14v-5l-2-5H7l-2 5z"/><circle cx="7.5" cy="17.5" r="1.5"/><circle cx="16.5" cy="17.5" r="1.5"/><path d="M5 12h14"/>',
  TGlyph.access: '<circle cx="12" cy="4" r="1.5"/><path d="M12 7v6h5l2 5"/><path d="M9 10.5A5 5 0 1 0 15 18"/>',
  TGlyph.home: '<path d="m3 10 9-7 9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
  TGlyph.compass: '<circle cx="12" cy="12" r="10"/><path d="m16.24 7.76-2.12 6.36-6.36 2.12 2.12-6.36z"/>',
};

const _mirrored = {TGlyph.chevron, TGlyph.arrow, TGlyph.arrowEnd, TGlyph.send, TGlyph.nav};

/// The Hedayah skin's icon for a Lessons glyph, where its set has one
/// (ADR-016). The rest keep their own drawing at the skin's lighter weight.
const _hedayahIcons = <TGlyph, String>{
  TGlyph.search: 'search', TGlyph.bell: 'bell', TGlyph.bookmark: 'bookmark', TGlyph.gear: 'gear',
  TGlyph.languages: 'translate', TGlyph.map: 'map', TGlyph.pin: 'pin', TGlyph.calendar: 'cal',
  TGlyph.clock: 'clock', TGlyph.user: 'user', TGlyph.users: 'users', TGlyph.check: 'check', TGlyph.x: 'close',
  TGlyph.plus: 'plus', TGlyph.share: 'share', TGlyph.mic: 'mic', TGlyph.chat: 'chat', TGlyph.chart: 'bars',
  TGlyph.shield: 'shield', TGlyph.key: 'key', TGlyph.eye: 'eye', TGlyph.list: 'list', TGlyph.edit: 'edit',
  TGlyph.trash: 'trash', TGlyph.globe: 'globe', TGlyph.info: 'info', TGlyph.alert: 'alert', TGlyph.link: 'link',
  TGlyph.copy: 'copy', TGlyph.send: 'send', TGlyph.logout: 'logout', TGlyph.refresh: 'refresh',
  TGlyph.lock: 'lock', TGlyph.home: 'home', TGlyph.compass: 'compass',
};

class TIcon extends StatelessWidget {
  const TIcon(this.glyph, {super.key, this.size = 18, this.color, this.stroke = 1.8, this.semanticLabel});
  final TGlyph glyph;
  final double size, stroke;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF151D24);
    final hedayah = context.isHedayahSkin;
    final asset = hedayah ? _hedayahIcons[glyph] : null;
    final svg = asset != null
        ? SvgPicture.asset('assets/hedayah/icons/$asset.svg',
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
            semanticsLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null)
        : SvgPicture.string(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
            'stroke-width="${hedayah && stroke == 1.8 ? 1.5 : stroke}" stroke-linecap="round" '
            'stroke-linejoin="round">${_paths[glyph]}</svg>',
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
            semanticsLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          );
    if (!_mirrored.contains(glyph) || Directionality.of(context) == TextDirection.ltr) return svg;
    return Transform.flip(flipX: true, child: svg);
  }
}

/// The glyph that stands for each prayer slot, activity type and facility.
TGlyph slotGlyph(String slot) => switch (slot) {
      'fajr' => TGlyph.sunrise,
      'dhuhr' => TGlyph.sun,
      'asr' => TGlyph.sunLow,
      'maghrib' => TGlyph.sunset,
      _ => TGlyph.moon,
    };

TGlyph typeGlyph(String type) => switch (type) {
      'lecture' => TGlyph.mic,
      'talk' => TGlyph.chat,
      _ => TGlyph.book,
    };

TGlyph facilityGlyph(String f) => switch (f) {
      'women' => TGlyph.users,
      'parking' => TGlyph.car,
      'access' => TGlyph.access,
      'interp' => TGlyph.languages,
      _ => TGlyph.star,
    };
