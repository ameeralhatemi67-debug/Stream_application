# User-generated-content moderation evidence draft

Status: 2026-09-24 repository evidence only. No Play approval or live operations review. For counsel review. P6 acceptance and P6S are open.

Google Play's UGC policy calls for accepted terms before users create/upload UGC, terms that prohibit objectionable content, ongoing moderation, in-app reports, and blocking of users/content appropriate to the app. Public UGC generally needs accessible reporting of users and content and user blocking. [Google Play UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB) [Google Play moderation guidance](https://support.google.com/googleplay/android-developer/answer/12923286?hl=en)

| Control | Repository evidence | Limit to resolve before a Play claim |
| --- | --- | --- |
| Terms/privacy gate | WelcomeScreen calls ConsentDialog before Google sign-in or guest entry; the dialog offers active privacy text and requires an affirmative checkbox. StreamerApplyScreen separately requires agreement to broadcaster terms before application submission. | The consent dialog is a privacy gate, not proven acceptance of UGC conduct terms before each chat/post. Already signed-in users are not forced through a new terms version. Review live terms text, acceptance record and prohibited-content language. |
| Chat report | ChatMessageActionsSheet offers Report message with stable spam, harassment, hate_speech and other reasons. LiveChatController inserts chat_reports; the database validates the message/sender/stream link and report reason. | The action is tied to a chat message. A distinct in-app way to report a live video, broadcaster/profile or other UGC was not established here. Test discovery and access on supported devices. |
| User block | The same action sheet offers Block user. chat_user_blocks is server-owned per blocker; Settings has a blocked-account list and Unblock. Chat SELECT respects the block, with refresh-based cross-device sync. | This is chat blocking, not a global account or video-content block. Cross-device refresh is not push. |
| Moderator action | Chat Moderation admin view lists reports and supports dismiss, delete message and mute/ban actions. Stream owners/moderators can mute via chat controls. chat_messages insert policy and moderation tables enforce mutes/bans. Keyword filtering and rate/slow-mode controls also exist. | Queue response time, staffing, escalation, appeals, evidence retention and real production operation are undefined. Dismissing/deleting a report removes that queue row; an audit record may remain. |
| Safety contact | A localized ban message includes a contact placeholder. | A plainly visible general safety contact or appeal channel for all users was not confirmed. Owner must designate and test one. |
| Live content | Approved broadcasters can enter YouTube IDs or initiate phone RTMP; YouTube playback appears in app. | In-app report/block of the live content itself, takedown scope, YouTube-side removal and private/unlisted access are not proven. The admin remove-from-feed action affects app discovery, not external YouTube media. |

The current server-side controls and local P6 tests are evidence of implementation, not evidence of sustained moderation operations. The latest RESUME block in brief/LEDGER.md says physical-phone, Google OAuth and authorized YouTube ingest acceptance remain open. Any statement that the app complies with Play UGC requirements is **for counsel review**.

## Owner evidence still needed

- Approve and publish bilingual user conduct terms that define prohibited content and require acceptance before the first UGC action. Record version and acceptance, including returning accounts. **For counsel review.**
- Decide and implement/report-test live video, broadcaster/profile and other public UGC paths, including user and content blocking where required. **For counsel review.**
- Provide a staffed safety contact, triage/response rules, escalation and appeal procedure; run dated evidence of an actual test report through the queue without production user data.
- Decide what the app can remove versus what must be reported to YouTube or the broadcaster. Do not promise removal of YouTube-hosted media from the app's admin action alone.
