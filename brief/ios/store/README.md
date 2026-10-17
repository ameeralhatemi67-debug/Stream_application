# iOS App Store listing pack

Draft: 2026-10-17. Derived from store/listing_draft_ar_en.md, store/data_safety.md, store/reviewer_access.md and store/screenshot_shot_list.md, adjusted to D3's iOS viewer scope. Nothing has been entered into App Store Connect.

**Not ready to submit:** no native iOS build/device evidence; paid enrollment is deferred; W11 ESC-2 Apple deletion revocation and ESC-3 legal delivery/disclosures are open. Screenshots and review credentials are owner/Mac tasks. These drafts do not promote feature evidence beyond E0/E1.

| Item | Draft / setting |
|---|---|
| English / Arabic fields | listing_en.md / listing_ar.md |
| Data disclosure | privacy_answers.md; reconcile with the shipped privacy manifest/report |
| Age questionnaire | age_rating.md; owner must confirm actual content frequencies |
| Review instructions | app_review_notes.md; no credentials in repo |
| Screenshot plan | screenshots.md, both requested iPhone size classes and languages |
| App / bundle | Hadayah Live / منصة هدايه; sa.hadayah.streamerapp |
| Version / build source | project/pubspec.yaml currently 1.0.0+1; use the actual uploaded build |
| Device / minimum OS | iPhone only; iOS 15.0 |
| Category / primary language | Education; Arabic proposed from the Android draft, owner selects in Connect |
| Copyright | 2026 <owner-confirmed rights holder>; do not invent an entity or SKU |
| Support URL | https://stream-application-ten.vercel.app/about.html — BLOCKED by ESC-3 |
| Privacy URL | https://stream-application-ten.vercel.app/privacy.html — BLOCKED by ESC-3 |
| Public deletion URL | https://stream-application-ten.vercel.app/delete-account.html — old branding, ESC-3 |
| Optional marketing URL | https://stream-application-ten.vercel.app |
| Support contact | AppIdentity.supportEmail; owner maintains the inbox |

## Measured field limits

| Language | Name /30 chars | Subtitle /30 chars | Promotion /170 chars | Description /4000 chars | Keywords /100 UTF-8 bytes |
|---|---:|---:|---:|---:|---:|
| English | 12 | 28 | 119 | 1016 | 68 |
| Arabic | 10 | 29 | 119 | 941 | 75 |

The counts exclude headings and surrounding blank lines. Keywords are limited in bytes in Apple's current reference; Arabic was measured in UTF-8. Description is plain text. A first version has no What's New field, so the Android release notes were not copied.

## Scope adjustments and owner acceptance

- Omitted phone publishing, OBS setup, channel connection, locked-screen/background survival, push delivery and native HTTPS invitations. Do not add those claims unless their own evidence and release scope change.
- Scheduled content can be saved and displayed in Saudi time; this copy does not promise an iOS push reminder.
- Organization pages are described only for participating organizations. Before pasting, enable/confirm the intended hosted visibility/pilots and review fixture, or remove that paragraph in both languages. No hosted flag was changed here.
- Confirm every advertised viewer action on the native build, EN/AR layout, YouTube playback and Maps. Complete ESC-2/ESC-3, paid Apple activation, review access and the final privacy report before submission.
- Preserve the viewer release's feature gates if Track B source is added. An experimental publisher must not be advertised or shipped without its required E3 pass.

Sources: [Apple app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [platform metadata limits](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [app privacy](https://developer.apple.com/app-store/app-privacy-details/), [age definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), retrieved 2026-10-17. Recheck at the eventual submission date.

