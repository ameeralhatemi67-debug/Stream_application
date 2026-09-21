# Scheme A runtime design

## Scheme A contract, selected 2026-09-21

The runtime source is `project/lib/core/theme/app_theme.dart`, matching `brief/assets/design_options/tokens_A.json`. This section supersedes the older graphite, coral, Inter and Tajawal specifications. The screen sketches below are historical layout references, not evidence of current functionality.

| Role | Token / value |
| --- | --- |
| Canvas and cards | bg / surface `#FFFFFF` |
| Alternate surface | surfaceAlt `#ECF6EF` |
| Borders | border `#D9DDDE`, borderStrong `#737B7D` |
| Text | primary `#202B2B`, secondary `#485554`, muted `#586563` |
| Primary, accent, live | `#17643F` |
| Success / warning / danger | `#22613D` / `#7C5012` / `#9D3044` |
| Media / onMedia | `#243536` / `#FFFFFF` |
| Disabled fill | `#E5E8E7` |

IBM Plex Sans and IBM Plex Sans Arabic are bundled in `project/assets/fonts/`, including OFL licenses. No runtime font download. Body is 15, title 21, display 30, caption 12. Arabic line heights are 1.8 for body, 1.6 for title and 1.5 for display. Latin line height is 1.4.

Cards, buttons and inputs use radius 12; chips use 999. Spacing tokens are 4, 8, 12, 16, 24 and 32; screen inset is 18. Cards have no shadow. Forms and settings should use a centered content width no greater than 720. Compact is below 600, medium below 900, expanded starts at 900. Use directional padding and native RTL.

`AppLogo` renders the owner's supplied `project/assets/logo/colored.svg`; `black.svg` is the monochrome variant. Preserve all supplied assets. The concept logo in the original token JSON is superseded by these supplied assets.

Gradients are only `AppGradients.brand` and `soft`, top-start to bottom-end. Brand stops are `#17643F` and `#327044` with white text; soft stops are `#D7EDDC` and `#B8DBB9` with primary text. Allowed on primary buttons, logo tiles, welcome hero and small status accents, at most two visible. Never on app bars, navigation, list cards, dialogs, inputs or body backgrounds. Contrast must pass at both stops. Media controls use opaque or adequately dark scrims with onMedia text.

Verification is in `project/test/theme_contrast_test.dart` and `layout_sweep_test.dart`. Widget evidence does not establish real-device streaming or release readiness.

---
