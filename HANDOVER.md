# Nudge Stitch Design Parity — Session Handover

**Date:** 2026-05-12
**Branch:** `feat/stitch-design-parity`
**Latest commit:** `b967db9` "Social Universe v3: priority sizing, counter-rotated labels, white pill FAB"
**Latest TestFlight build:** `1.3.4 (6)` — pushed to GitHub, not yet built in Codemagic at handover time
**Repo:** https://github.com/Nudge-Lab-ae/Nudge

---

## TL;DR for whoever picks this up

The user (Shay Duncombe, founder of Nudge Lab) has been pushing a substantial design-parity effort to bring the Nudge Flutter app in line with the Stitch mockups at `../stitch_nudge_mock_up_v4/`. We're on a feature branch (`feat/stitch-design-parity`) that has **NOT** been merged to main. The user is non-technical on Windows, with an iPhone. Builds are pushed via **Codemagic** (cloud CI) to TestFlight; the user installs from there.

**Standing rules — DO NOT VIOLATE:**

1. **Never push to `main`** without the user's explicit per-action approval. Feature branch only.
2. **"Phase 10 / Future Relationship Insights"** is OUT of scope. User will initiate it separately.
3. **Banned design pattern:** the purple+blue NUDGE wordmark gradient (`AppColors.primaryGradientLight/Dark`). The canonical wordmark is the **near-black gradient** (`[Color(0xFF1A1A1A), Color(0xFF666666)]` for light mode, `[Color(0xFFE7E1DE), Color(0xFF968DA1)]` for dark mode) with `Alignment.bottomCenter → Alignment.topCenter`. This pattern is in `lib/widgets/gradient_text.dart` callers across many screens.
4. **Walkthrough is opt-in only** — fires from the info button on Social Universe, NOT auto-triggered after profile completion.
5. **Goals onboarding flow** sits BETWEEN `CompleteProfileScreen` and `DashboardScreen`, gated by SharedPreferences key `onboarding_goals_completed_v1`. User picks AT MOST 4 goals from the canonical `kOnboardingGoals` list in `lib/screens/onboarding/onboarding_goals_screen.dart`.

---

## Critical environment context

| Thing | Value / Path |
|---|---|
| Working directory | `C:\Users\Shay Duncombe\OneDrive\Documents\Claude\projects\nudge\` |
| Flutter app | `Nudge/` subfolder (cloned from GitHub) |
| Canonical Stitch mockups | `stitch_nudge_mock_up_v4/` (user cleaned this up; only canonical "_final" / "_final_v2" / "_updated_*" / "_brighter_glow_2" versions remain) |
| Flutter version installed locally | 3.41.9 (Dart 3.11.5) at `$env:USERPROFILE\flutter\bin\flutter.bat` |
| `gh` CLI | NOT installed — use plain `git` over HTTPS |
| iOS Bundle ID | `com.nudge--shay` |
| Apple Developer access | User has login; some App Store Connect roles may be limited (Analytics-only view in their primary screen) but they can generate API keys → Admin role somewhere |
| App Store Connect API Key (Codemagic) | Already configured under integration name `Nudge AppStoreConnect`. Issuer ID `7b573db2-d29f-4ad0-8951-c4f70e4022a0`, Key ID `624WJQ75CP`. The `.p8` file lives locally on the user's machine. |
| Codemagic workflow | Set up with pre-build script that injects `lib/firebase_options.dart` and `ios/GoogleService-Info.plist` (+ `ios/Runner/GoogleService-Info.plist`) from encrypted env vars `FIREBASE_OPTIONS_DART` and `GOOGLE_SERVICE_INFO_PLIST`. |
| Firebase Project | `nudge-965c2`. iOS GoogleService-Info.plist values + the generated `lib/firebase_options.dart` are gitignored on purpose. |

---

## Codemagic / TestFlight build flow

1. Push branch → Codemagic UI → **Builds → Start new build** → branch `feat/stitch-design-parity`.
2. Build runs ~15 min, uploads to App Store Connect.
3. **Apple's TestFlight rule:** only ONE build per marketing version (`1.3.4`) can be in Beta App Review at a time. The user is in the **internal** "Nudge Testers" group as `shaday.duncombe@gmail.com` (shown truncated as `shay@gmail.com` in some App Store Connect tables), so internal install works immediately — no Beta Review wait.
4. After upload completes, the user goes to **App Store Connect → TestFlight → Nudge Testers → Builds → + Add Build → select the new build → Add**. Build appears in their TestFlight app within ~5 min.
5. **Pull-to-refresh on iPhone TestFlight** is the reliable way to see new builds; push notifications lag for hours sometimes.
6. To see the new onboarding flow, the user must **delete the app and reinstall** (iOS Firebase Auth keychain persists across reinstalls, but local state like SharedPreferences is wiped). Even with delete+reinstall, the Firebase Auth token may persist — user might still skip welcome/register flow.

### Versioning protocol

- `CFBundleVersion` (build number) must be unique within a marketing version. We've been bumping `+N` in `pubspec.yaml` each push.
- `CFBundleShortVersionString` (marketing version `1.3.4`) is shared across builds of the same train. If Apple closes the train, bump to `1.3.5+1`.
- **Current state:** `version: 1.3.4+6`. Next push: `+7` or bump to `1.3.5+1`.

---

## What's been done (cumulative, across all sessions on this branch)

### Phase 0 — Token reconciliation (commit `5d5ba87`)
Fixed `darkSurfaceContainerLow` (was `#3B3834`, now `#1D1B19` per mockup). Added Material 3 inverse / tint tokens. Added `Radii` constants class. Fixed self-referencing `AppTheme.lightUniverseBackground` initializers. — `lib/theme/app_theme.dart`

### Phase 1 — Walkthrough flow (commit `f140cc8`)
Built 5-page PageView walkthrough at `lib/screens/walkthrough/`:
- `walkthrough_screen.dart` (scaffold + footer + dots)
- `pages/welcome_page.dart`
- `pages/three_circles_page.dart`
- `pages/star_sizes_page.dart`
- `pages/movement_page.dart`
- `pages/how_to_use_page.dart`

### Phase 1.5 v1 — Walkthrough refinements (commit `a6ee330`)
Per user feedback after first install: removed Got It! CTA, expanded three-circle legend cards (multi-line), removed NUDGE wordmark from movement page, replaced banned gradients with near-black, forced light theme on walkthrough.

### Phase 1.5 v2 — Onboarding + walkthrough trigger (commit `98cfebe`)
Built `lib/screens/onboarding/onboarding_goals_screen.dart`. Removed walkthrough auto-trigger; only fires from info button on Social Universe. **AT THIS POINT goals were BEFORE register.**

### Social Universe v1 — Full redesign (commit `eba452a`)
Rewrote `lib/screens/social_universe/social_universe_immersive.dart` from scratch matching `social_universe_brighter_glow_2`: dark starfield background, 3 orbit rings (280/480/680px), central YOU avatar with user's Firebase photo, contacts plotted on rings color-coded by `computedRing`, top app bar with NUDGE wordmark + info button, FAB bottom-right. Kept the underlying `lib/widgets/social_universe.dart` widget untouched (still used by dashboard).

### Phase 1.5 v3 — Goals reorder + brand cleanup (commit `cc3acf8`)
- Goals list reduced from 6 mockup options to **4 canonical goals** in `kOnboardingGoals`.
- **Goals moved to AFTER complete-profile** (welcome → register → complete profile → goals → dashboard). Gated by SharedPreferences `onboarding_goals_completed_v1`.
- Welcome screen: removed purple glow halo from logo, "nourished" recast as italic near-black accent.
- NUDGE wordmark gradient swap on login_screen, register_screen, feedback_management_screen, import_contacts_screen.
- Top error banner: removed fixed 80/120px height, uses minHeight constraint so long messages wrap fully (`lib/widgets/message_widget.dart`).
- Social Universe: pinch-zoom via `InteractiveViewer`, slow orbital rotation (90s/cycle), dark bottom nav (Universe active + Nudges/Groups/Contacts wired to routes), FAB lifted to `bottom: 96`.

### NUDGE wordmark sweep round 2 (commit `3f7c746`)
Replaced remaining banned gradient instances on:
- `analytics_screen.dart` (was 3-color gradient with RobotoMono)
- `complete_profile_screen.dart` (was 2-color gradient with RobotoMono)
- `search_screen.dart` (was plain white text on flat purple AppBar — now near-black wordmark on neutral)
- `set_goals_screen.dart` loading state (same as search)
All now use the canonical near-black gradient via `GradientText` widget. Splash screen was deliberately left alone.

### Social Universe v3 — Latest, commit `b967db9`
- Star labels + dots **counter-rotate** by the inverse of the orbit angle so they stay upright while their positions translate around the centre.
- **Priority-driven star sizing** per "Star Sizes Matter" walkthrough copy: priority 1 → 24px, priority 5 → 8px, VIP +2 boost, CDI ±2 within tier.
- **FAB redesigned** from dark glass-card to white 48px pill with solid purple "N" (no logo gradient), matching `dashboard_consistent_titles` pill button reference.
- **Bottom nav** now fully opaque `#1A1816`, extends to screen bottom with safe-area inset filled by the dark colour (no light strip above home indicator).
- Contacts without `computedRing` filtered out before plotting.

---

## What's STILL PENDING — start here

### 1. Bouncing NUDGE logo: bounce twice then stop (task #38)
**User feedback exactly:** "the nudge logo should only animate bounce twice when you open the app and after that stop"

**I haven't found the source yet.** Probably one of:
- `lib/screens/splash_screen.dart` — boot-state logo
- `lib/screens/welcome_screen.dart` — logo image (but I removed the glow, didn't see a bounce)
- `lib/screens/walkthrough/pages/how_to_use_page.dart` has a `touch_app` icon bouncing repeatedly via `_bounceController..repeat(reverse: true)` — could be what they mean if they consider this the "logo"

**Suggested approach:**
1. Grep for `AnimationController` + `.repeat(` in screens with NUDGE branding.
2. Found candidate: replace `.repeat(reverse: true)` with a `.forward()` cycle counter (e.g. listen for `AnimationStatus.completed`, increment counter, only restart twice).
3. Reasonable pattern:
   ```dart
   int _bounceCount = 0;
   _bounceController = AnimationController(vsync: this, duration: ...);
   _bounceController.addStatusListener((status) {
     if (status == AnimationStatus.completed) {
       _bounceCount++;
       if (_bounceCount < 2) {
         _bounceController.reverse();
       }
     } else if (status == AnimationStatus.dismissed && _bounceCount < 2) {
       _bounceController.forward();
     }
   });
   _bounceController.forward();
   ```

### 2. Bulk redesign of remaining screens (tasks #27–32)
Each is a large file with intricate business logic. The user wants visual parity with Stitch v4 canonical mockups but realistically each takes 4–8 hours of focused work. The session ran out of time after only doing the brand-consistency sweep across screens — actual layout restructuring per mockup was NOT done.

Order by user-facing impact:

| Task | Screen file | Lines | Canonical mockup |
|---|---|---|---|
| #27 | `lib/screens/dashboard/dashboard_screen.dart` | 1841 | `dashboard_consistent_titles` (light) + `dashboard_dark_mode_3` (dark) |
| #28 | `lib/screens/contacts/contacts_list_screen.dart` | 1888 | `contacts_final_alignment` |
| #29 | `lib/screens/groups/groups_list_screen.dart` | 3090 | `groups_final_color_harmony` (preferred) or `groups_final_alignment` |
| #30 | `lib/screens/settings/settings_screen.dart` | (large) | `settings_final_refined_2` |
| #31 | `lib/screens/notifications/notifications_screen.dart` | 2752 | `nudges_*` variants (check `stitch_nudge_mock_up_v4/` for current canonicals) |
| #32 | `lib/screens/feedback/feedback_forum_screen.dart` + `feature_requests` | 700+ | `feedback_support_final_refined` + `feature_requests_final_refined` |

**Recommended scoping:** do ONE screen per session as a focused effort. Don't attempt all in one go — last session burned hours trying and only achieved a brand sweep. Pick the most-visited (dashboard) first.

### 3. Goal selections persistence (deferred from Phase 1.5 v2)
Picked goals are written to SharedPreferences key `onboarding_goals_picked_v1` but **not yet** transferred to the User document in Firestore. Follow-up: in `_resolveAuthRoute` or after `_markGoalsCompleted`, push the goals list into `apiService.updateUser({'goals': picked})` or add a `goals: List<String>` field to the User model.

### 4. (Cosmetic, low priority) `withOpacity` deprecation warnings
Flutter 3.41 deprecated `withOpacity` in favour of `withValues(alpha: x)`. There are ~60+ info-level warnings across the codebase. Build still works; can be swept in a separate cleanup commit.

---

## Codebase conventions (don't violate these)

### State management
- **Provider 6.1.2** (not Riverpod). Use `Consumer`, `StreamProvider`, `ChangeNotifier`.

### Theming
- **Always use `Theme.of(context).colorScheme.*` for colors**, never hardcode (unless explicitly matching a Stitch hex like the `_spaceBackground = #1A1816`).
- **Plus Jakarta Sans** for headlines (use `GoogleFonts.plusJakartaSans(...)`); **Be Vietnam Pro** for body.
- **Material 3 ColorScheme** is the source of truth; `lib/theme/app_theme.dart` defines `lightTheme()` and `darkTheme()`.
- Card radii: prefer `Radii.lg` (32) for cards per mockup, `Radii.md` (16) for tighter elements, `Radii.pill` (9999) for stadium shapes.

### Navigation
- Named routes via `MaterialApp.routes` in `lib/main.dart`.
- `navigatorKey` is global in main.dart for push from anywhere (used by FCM notifications).
- After signing in: SplashScreen / LoginScreen push directly to `/dashboard`, **bypassing AuthWrapper**. This means **AuthWrapper-only gates won't fire** for existing users — be aware. (This is why walkthrough was invisible in the first round; the goals gate works only because we route through CompleteProfileScreen.)

### NUDGE wordmark
- **Always near-black gradient** via `GradientText` widget with these exact gradient colors:
  ```dart
  gradient: LinearGradient(
    colors: themeProvider.isDarkMode  // or Theme.of(context).brightness == Brightness.dark
        ? const [Color(0xFFE7E1DE), Color(0xFF968DA1)]
        : const [Color(0xFF1A1A1A), Color(0xFF666666)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ),
  ```
- Never use `AppColors.primaryGradient*` for the wordmark.

### Background colors per mockup
- Walkthrough + onboarding goals: `Color(0xFFFAF9F6)` (warm cream) — forced via `Theme(data: AppTheme.lightTheme(), ...)` wrapper so they look light regardless of system theme.
- Social Universe: `Color(0xFF1A1816)` (near-black starfield).
- Dashboard / lists / settings: `Theme.of(context).colorScheme.surface` (cream in light, near-black in dark).

---

## Memory references (auto-loaded each session)

In `C:\Users\Shay Duncombe\.claude\projects\C--Users-Shay-Duncombe-OneDrive-Documents-Claude-projects-nudge\memory\`:

- `project_nudge_repo_guardrails.md` — never push to main without approval
- `project_nudge_phase_scope.md` — Phase 10 out of scope, per-pair greenlighting
- `project_nudge_testflight_prereqs.md` — bundle ID, Codemagic recommendation
- `feedback_scope_disambiguation.md` — walkthrough vs onboarding never to be conflated
- `feedback_no_unilateral_scope_cuts.md` — deliver every item user lists; ask before deferring

The `MEMORY.md` index file pulls these in automatically.

---

## How to resume

1. **Open this folder** in Claude Code: `C:\Users\Shay Duncombe\OneDrive\Documents\Claude\projects\nudge\`
2. **Pull latest:** `git -C Nudge pull origin feat/stitch-design-parity`
3. **Read this file** + the memory references above.
4. **Check current state:** `git -C Nudge log --oneline -10` to see commits; `git -C Nudge status` to see anything pending.
5. **Trigger Codemagic** to build `1.3.4 (6)` if not done yet — the user needs to test the Social Universe v3 fixes (counter-rotated labels, priority sizing, white pill FAB, fully dark nav).
6. **First task:** find and fix the bouncing logo (task #38). Likely a quick edit once you locate it.
7. **Then:** pick ONE screen from tasks #27–32 (dashboard recommended) and do a focused redesign session. Don't try to do all at once.

---

## Open questions the user hasn't answered yet

None outstanding — they answered everything asked so far.

---

## Things to flag if they come up

- If the user asks to "push to main" or "open a PR to main" — **stop and ask explicitly**. The repo guardrail memory captures this.
- If they ask about "future relationship insights" — that's Phase 10, out of scope unless they explicitly initiate.
- If they ask about cloning random repos from URLs (e.g. shortened or third-party redirected links) — push back; only fetch from canonical GitHub sources directly. Last session they nearly cloned an unrelated repo via an Instagram link with `mcp_token` parameters; the safety classifier blocked the second clone correctly.

---

**End of handover. Good luck.**
