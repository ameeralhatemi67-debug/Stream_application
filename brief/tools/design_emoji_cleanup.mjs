import fs from 'node:fs';
import path from 'node:path';
function* walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())yield*walk(p);else if(/\.(dart|json)$/.test(p))yield p;}}
const overlay='project/lib/features/live_stream/presentation/widgets/floating_reactions_overlay.dart';
fs.appendFileSync(overlay,"\nconst liveReactionGlyphs = <String, String>{'heart': '❤️', 'clap': '👏', 'hand': '✋', 'fire': '🔥', 'idea': '💡', 'scholar': '🎓'};\n");
const live='project/lib/features/live_stream/presentation/live_broadcast_screen.dart';
let s=fs.readFileSync(live,'utf8');
s=s.replace(/_buildReactionFabIcon\('[^']+', '(clap|heart|idea|fire|scholar)'\)/g,(_,type)=>`_buildReactionFabIcon(liveReactionGlyphs['${type}']!, '${type}')`);
s=s.replace("const Text('✋', style: TextStyle(fontSize: 13))","const Icon(Icons.pan_tool_outlined, size: 13)");
s=s.replace('message.badges.map((b) => b.emoji).join()',"message.badges.map((b) => context.locale.languageCode == 'ar' ? b.labelAr : b.labelEn).join(', ')");
fs.writeFileSync(live,s);
const model='project/lib/features/live_stream/models/chat_message_model.dart';
s=fs.readFileSync(model,'utf8').replace("import 'package:flutter/foundation.dart';","import 'package:flutter/material.dart';");
for(const [name,icon] of Object.entries({speaker:'mic',organization:'business',admin:'admin_panel_settings',moderator:'shield',verified:'verified'}))s=s.replace(new RegExp(`${name}\\('[^']+',`),`${name}(Icons.${icon},`);
s=s.replace('final String emoji;','final IconData icon;').replace('this.emoji','this.icon');fs.writeFileSync(model,s);
const chat='project/lib/features/live_stream/presentation/widgets/live_chat_widget.dart';s=fs.readFileSync(chat,'utf8');
s=s.replace('return Text(badge.emoji, style: const TextStyle(fontSize: 11));','return Icon(badge.icon, size: 13, color: AppTheme.primary, semanticLabel: isAr ? badge.labelAr : badge.labelEn);');
s=s.replace('isAdminBadge ? const Color(0xFFD4AF37) : const Color(0xFF22D3EE)','isAdminBadge ? AppTheme.warning : AppTheme.primary');
s=s.replace("'${badge.emoji} ${isAr ? badge.labelAr : badge.labelEn}'",'isAr ? badge.labelAr : badge.labelEn');fs.writeFileSync(chat,s);
for(const f of [...walk('project/lib'),...walk('project/assets/i18n')]){
 if(f.replaceAll('\\','/')===overlay)continue;
 s=fs.readFileSync(f,'utf8').replace(/[\p{Extended_Pictographic}\p{Emoji_Presentation}\uFE0F\u200D]/gu,'');
 // Remove leftover leading whitespace in text after deleting a decorative glyph.
 s=s.replace(/(['"]) +(?=[A-Za-z\u0600-\u06FF])/g,'$1');
 fs.writeFileSync(f,s);
}
// Flat scrims are constant and no longer need runtime constructors.
for(const f of ['project/lib/core/widgets/floating_stream_mini_player.dart','project/lib/features/admin/presentation/admin_hub_screen.dart','project/lib/features/profile/presentation/widgets/vod_grid_tile.dart']){
 s=fs.readFileSync(f,'utf8').replace(/(?<!const )BoxDecoration\(\s*color: AppTheme.media,\s*\)/g,'const BoxDecoration(color: AppTheme.media)');fs.writeFileSync(f,s);
}
