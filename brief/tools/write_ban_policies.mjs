// Mechanical generation of per-command restrictive policies. No credentials.
import { writeFileSync } from 'node:fs';
const tables = ['profiles', 'broadcaster_applications', 'affiliation_requests', 'chat_messages', 'streamer_custom_placeholders'];
let sql = `-- P1.5: restrictive guards combine with every existing permissive policy.
-- Existing owner/admin checks remain necessary; these policies grant no access.
begin;
revoke execute on function public.is_current_user_banned() from public, anon;
grant execute on function public.is_current_user_banned() to authenticated;
`;
for (const table of tables) {
  for (const command of ['insert', 'update', 'delete']) {
    const condition = 'not public.is_current_user_banned()';
    sql += `\ncreate policy ${table}_${command}_not_banned on public.${table}\nas restrictive for ${command} to authenticated\n`;
    if (command !== 'insert') sql += `using (${condition})\n`;
    if (command !== 'delete') sql += `with check (${condition})\n`;
    sql = sql.trimEnd() + ';\n';
  }
}
for (const command of ['insert', 'update', 'delete']) {
  const condition = "bucket_id <> 'streamer-assets' or not public.is_current_user_banned()";
  sql += `\ncreate policy streamer_assets_${command}_not_banned on storage.objects\nas restrictive for ${command} to authenticated\n`;
  if (command !== 'insert') sql += `using (${condition})\n`;
  if (command !== 'delete') sql += `with check (${condition})\n`;
  sql = sql.trimEnd() + ';\n';
}
sql += '\ncommit;\n';
writeFileSync('supabase/migrations/20260920093000_enforce_bans_on_writes.sql', sql);
