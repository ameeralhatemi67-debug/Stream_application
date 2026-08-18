As the UI/UX & Safety Specialist, your primary focus is establishing the visual identity ("Educational Twitch" theme), crafting responsive discovery layouts, ensuring flawless English/Arabic (LTR/RTL) mirroring, and locking down the universal **"Feature In Progress"** safety system so no unbuilt placeholder ever breaks immersion during a pitch.

# UI/UX, Localization & Safety Specialist Roadmap

## Version 0.1: Design System, Localization Engine & Safety System

### Checkpoint 1.1: Design System, Localization (i18n) & UX Safety Architecture

#### Phase 1.1.1: Research, Design & UX Discovery

- **Task 1:** Research and draft the app's visual style guide based on a minimalist "Educational Twitch" aesthetic (deep dark palette `#0E0E10`, high-contrast text, pastel red `#FF8080` / `rgb(255, 128, 128)` accent color for live feeds).
    
- **Task 2:** Research Flutter localization using `easy_localization` and document layout direction rules for LTR (English with Inter) and RTL (Arabic with Tajawal) mirroring.
    
- **Task 3:** Map out screen layout guidelines and typography scales to ensure seamless text wrapping in both English and Arabic.
    
- **Task 4:** Define the UX specification for the universal **"Feature In Progress"** modal and toast handlers for all placeholder buttons.
    

#### Phase 1.1.2: Design System & Universal Safety Architecture

- **Task 1:** Configure global `MaterialApp` dark theme palette, dark surface styling (`#161619`), custom typography (Inter & Tajawal), and accent colors (`#FF8080`).
    
- **Task 2:** Implement `easy_localization` and set up key translation dictionaries for English (`en.json`) and Arabic (`ar.json`).
    
- **Task 3:** Build the global, reusable `FeatureInProgressModal` bottom-sheet widget with smooth entrance animations and localized copy.
    

#### Phase 1.1.3: Language Switcher & Universal Safety Triggers

- **Task 1:** Build a top-bar Language Switcher widget (`EN` / `عربي`) that dynamically toggles the app locale and flips the layout direction between LTR and RTL.
    
- **Task 2:** Attach `FeatureInProgressModal` triggers to all unbuilt placeholder icons and buttons across the initial navigation shell (e.g., Settings, Bookmarks, User Profile).
    
- **Task 3:** Populate `en.json` and `ar.json` with localized translation keys for all navigation bar titles, dialog messages, and system prompts.
    

## Version 0.2: Discovery Feed & Broadcaster Profile Shell

### Checkpoint 2.1: The Structured Content Discovery Hub

#### Phase 2.1.1: Research, Design & Discovery

- **Task 1:** Research content categorization structures for educational streams (e.g., Mosque Lessons, University Seminars, Public Lectures).
    
- **Task 2:** Design responsive grid card component specifications displaying viewer counts, streamer avatars, category chips, and live badges.
    
- **Task 3:** Define LTR and RTL visual layout specs for top category filter chips and search bars.
    

#### Phase 2.1.2: Discovery Grid & Channel Card Layouts

- **Task 1:** Build a 3-column responsive `GridView.builder` layout for the primary Content Discovery Feed.
    
- **Task 2:** Build reusable `ChannelCard` widgets featuring high-resolution thumbnails, lecturer name, location tag, and a pulsing red "LIVE" badge overlay.
    
- **Task 3:** Build horizontal scrolling category filter chips at the top of the feed with localized labels (e.g., "Islamic Studies" / "الدراسات الإسلامية", "Computer Science" / "علوم الحاسوب").
    

#### Phase 2.1.3: Feed Interactivity & Filter Safety

- **Task 1:** Connect the discovery feed search bar to filter local broadcaster objects in real time by name, category, or location.
    
- **Task 2:** Wire all non-functional advanced filter buttons (e.g., "Date Range", "Academic Level") to trigger the `FeatureInProgressModal`.
    

### Checkpoint 2.2: Broadcaster Profile UI Shell & Layout

#### Phase 2.2.1: Research & Layout Discovery

- **Task 1:** Research `CustomScrollView` and `SliverAppBar` header collapsing animations to display mosque/university cover imagery cleanly.
    
- **Task 2:** Design profile tab structures ("Info", "Past Archives", "Schedule") and define typography hierarchy for lecturer bios and follower stats.
    

#### Phase 2.2.2: Broadcaster Profile UI Shell Setup

- **Task 1:** Build the `BroadcasterProfileScreen` using a `CustomScrollView` with an expanding/collapsing `SliverAppBar` header image.
    
- **Task 2:** Render broadcaster bio details, verified authority badges, upcoming lecture schedules, and localized follower count statistics.
    
- **Task 3:** Implement tabbed navigation views (`TabBar` / `TabBarView`) dividing creator content into `Info` and `Archive` sections.
    

#### Phase 2.2.3: Action Buttons & Secondary Safety Wiring

- **Task 1:** Wire secondary profile action buttons ("Follow", "Enable Reminders", "Share Profile") to active toggle states or trigger the `FeatureInProgressModal`.
    
- **Task 2:** Verify all profile text fields dynamically scale and realign cleanly when switching between English LTR and Arabic RTL modes.
    

## Version 1.0: Universal Safety Audit & RTL Polish

### Checkpoint 4.2: Comprehensive UI Audit, Placeholder Safety & RTL Validation

#### Phase 4.2.1: Research & Audit Checklist Setup

- **Task 1:** Create an exhaustive UI/UX audit checklist for all application screens in both LTR (English) and RTL (Arabic) modes.
    
- **Task 2:** Identify every interactive widget across Map, Feed, Profile, and Live screens to verify placeholder coverage.
    

#### Phase 4.2.2: Universal Placeholder Audit & Localization Review

- **Task 1:** Audit every secondary button across all viewports (e.g., Settings, Filter, Donate, Audio Only, Share).
    
- **Task 2:** Guarantee that _100% of unbuilt buttons_ trigger the `FeatureInProgressModal` displaying localized explanatory copy:
    
    - **EN:** _"Feature In Progress: This capability is scheduled for the Version 2 production release."_
        
    - **AR:** _"الميزة قيد التطوير: هذه الخاصية مجدولة للإطلاق في الإصدار القادم."_
        
- **Task 3:** Verify layout alignment, icon mirroring, padding, and text string completeness across all screens when running in Arabic RTL mode.
    

#### Phase 4.2.3: Final Visual Polish & Pitch Day Styling

- **Task 1:** Standardize all card margins, border radii, and drop shadows to match the "Educational Twitch" aesthetic strictly.
    
- **Task 2:** Perform side-by-side visual validation with Team Lead to confirm pitch-ready consistency across different screen sizes.