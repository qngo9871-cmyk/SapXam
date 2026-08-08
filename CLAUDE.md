# Sập Xám — Vietnamese 13-Card Poker

Native SwiftUI iOS app for Sập Xám (a.k.a. Xập Xám Chướng / Mậu Binh — the Vietnamese branch
of the Chinese-poker / Pusoy family). Forked from `~/Projects/SamLoc/`'s scaffolding
(XcodeGen, bilingual `Localization.swift`, StoreKit 2 IAP pattern, onboarding/rules
structure) but **all game logic is net-new** — this is a poker-hand-arrangement game, not a
shedding game like Sâm Lốc, and shares no gameplay code with it. Bundle
`com.quyenngo.sapxam`. Built 2026-08-08.

**Status: 🟢 App record created, full ASC metadata + IAP + pricing + screenshots pushed and
verified live (2026-08-08). Blocked only on: uploading the real build, ticking the IAP into
the version (web UI only), the App Privacy nutrition label, and actual submission — all
human/web-UI steps. See "Live in ASC now" below for exact verified values.**

## What this is

- 2-4 players (you + AI), 13 cards dealt to everyone at once from a standard 52-card deck
  (`Core/Card.swift`, reused byte-for-byte from SamLoc) — no draws, no discards.
- Arrange your 13 cards into **Back** (5 cards), **Middle** (5 cards), **Front** (3 cards).
  Back must rank ≥ Middle must rank ≥ Front, or you "foul" and auto-lose all three hands
  against every opponent that round.
- Full 5-card poker evaluator (high card → straight flush, with correct kicker tie-breaks)
  for Back/Middle, and a reduced 3-card evaluator (high card / pair / trips only — no
  3-card straights or flushes) for Front, sharing one ordinal `HandCategory` scale so a
  3-card hand can be compared directly against a 5-card hand when checking the foul rule.
- Special "tới trắng" instant-win hands, detected on the raw 13-card deal before any
  arranging, in priority order:

  | Hand | Vietnamese | Pattern | Multiplier |
  |---|---|---|---|
  | 1 | Rồng Cuốn | 13-card straight, single suit | ×24 |
  | 2 | Sảnh Rồng | 13-card straight, mixed suits | ×12 |
  | 3 | Lục Phé Bôn | six pairs + 1 kicker | ×6 |
  | 4 | Ba Cái Thùng | all 3 hands are flushes | ×3 |
  | 5 | Ba Cái Sảnh | all 3 hands are straights | ×3 |

  If any player is dealt one of these, the round resolves immediately (no arranging phase
  for anyone that round): the special hand wins its multiplier against every opponent
  without it; two players both holding specials compare by priority (higher wins the
  multiplier *difference*, equal priority is a push). This "special hand ends the round for
  everyone" simplification is a deliberate design call, not something pulled verbatim from
  a single source — documented here so it's easy to revisit.
- Scoring: each of your 3 sub-hands is compared head-to-head against the corresponding
  sub-hand of every opponent (full round-robin, not just vs. you) — +1 unit per hand won,
  -1 per hand lost, plus a +3 "scoop" bonus for winning all 3 against one specific opponent.
  No fixed round count; the player ends the match whenever they want.
- 3-tier AI (Easy/Normal/Hard) with **Hard gated behind StoreKit 2 non-consumable IAP**
  `com.quyenngo.sapxam.pro`, same house pattern as SamLoc. Free tier: Easy + Normal AI,
  full rules, no ads.
- True bilingual in-app UI (EN/VI) via the same manual bundle-swap `LocalizationManager`
  used across this portfolio — hand-translated Vietnamese, not machine-translated. Flagged
  for review: `hand.twoPair` = "Thú (Hai Đôi)" and `hand.threeOfAKind` = "Sám Chi (Bộ Ba)" —
  these are the terms found in research but the developer (a Vietnamese speaker) should
  double check they match their own dialect/community's usage before shipping.

## Special-hand ruleset sources and regional variation

Researched via web search (pagat.com's Chinese Poker / Pusoy page, Vietnamese-language
gaming sites, Vietnamese Wikipedia's "Mậu binh" article) rather than assumed from generic
Chinese poker rules, since the task specifically asked to pin down the Vietnamese "Xập Xám
Chướng" ruleset. Findings:

- **Names and priority order** (Rồng Cuốn > Sảnh Rồng > Lục Phé Bôn > Ba Cái Thùng > Ba Cái
  Sảnh) were consistent across every Vietnamese-language source checked.
- **Multipliers varied by source.** One detailed source gave the full descending scale used
  in this build (24/12/6/3/3). A separate aggregator-style source gave Lục Phé Bôn, Ba Cái
  Thùng, and Ba Cái Sảnh a flat ×6 instead of the ×6/×3/×3 split used here. Vietnamese
  Wikipedia's Mậu Binh article confirms the hand list and names but gives no multiplier
  values at all. This build picked the most detailed, internally-consistent
  monotonically-decreasing source (24/12/6/3/3) and documents the alternative here rather
  than silently picking one. If real-money-adjacent competitor apps are audited later for
  exact parity, re-verify against 2-3 more sources.
- **Not implemented**: a few sources also mention "Năm Đôi Một Sám" (five pairs + one
  triple) as a distinct sixth special hand between Lục Phé Bôn and Ba Cái Thùng in payout
  rank. The task only asked for the five hands above, so this was left out — flagging in
  case it's expected by players familiar with a stricter ruleset.

## AI arrangement approach (`Core/AIArranger.swift`)

The hard, genuinely new part — no precedent in this portfolio (closest structural analogue
studied for inspiration was SamLoc's `InstantWin.swift`, a dealt-hand pattern detector, but
the actual search problem is new).

1. Rank **every** possible 5-card Back hand (all C(13,5) = 1,287 combinations) by strength.
2. For each Back candidate under consideration, pick the single best possible 5-card Middle
   from the remaining 8 cards via full C(8,5) = 56 enumeration (cheap). Leftover 3 cards
   become Front.
3. Discard any candidate that fouls; keep whichever survivor scores highest on a simple
   additive EV heuristic (`category.rawValue` per hand, front weighted ×1.2, plus a small
   kicker-based tie-break nudge).

**Why it can't just always foul-check-and-hope:** taking the *globally best* 5-card hand as
Back and the *best-of-what's-left* as Middle is mathematically guaranteed never to foul —
proved and then empirically confirmed (see Verification below) — because any 5-card subset
of the leftover 8 cards is itself a valid candidate in the original 1,287-combo pool, so it
can never beat the true best Back; the same argument extended with the 2 best leftover
kickers guarantees Middle ≥ Front too. That guarantee is what Easy (search width 1) relies
on directly. Once the search considers deliberately non-optimal Back candidates to chase
better overall EV (Normal: 10 candidates, Hard: 80 candidates), the guarantee no longer
automatically holds for those specific candidates — so every candidate is explicitly
foul-checked and discarded if it fouls. Since the true-best-Back candidate is always inside
the search window (width ≥ 1) and is always foul-free by the proof above, a valid
arrangement is always found; a "safe fallback" path exists but should be unreachable.

This is a heuristic, not a perfect solver, by design (per the task brief) — it doesn't
account for opponent modeling, doesn't optimize for scoop probability specifically, and the
EV weights are hand-picked, not tuned against real gameplay data.

The "Auto-Arrange" button available to the human player during arrangement always searches
at Hard depth regardless of the match's AI difficulty setting — it's a UX convenience, not
tied to the paywall (the paywall gates the *opponents'* Hard AI, not player assistance).

## Verification

**Compiles and runs**: `xcodegen generate` then
`xcodebuild -project SapXam.xcodeproj -scheme SapXam -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' clean build`
→ `** BUILD SUCCEEDED **`, zero errors, zero warnings (checked by grepping full build
output, not just trusting exit code).

**Ground-truth hand-evaluator test** (`verify_hand_evaluator.swift`, project root) — compiles
directly against the actual shipped `Card.swift`/`HandEvaluator.swift`/`SpecialHand.swift`/
`Arrangement.swift` (not a reimplementation), asserting:
- All 9 hand categories identify correctly (straight flush → high card).
- Full weak-to-strong category ordering holds pairwise (e.g. flush > straight > trips).
- Kicker-based tie-breaks: two-pair top-pair-wins-over-lower-kicker, pair-with-better-kicker,
  flush-with-higher-top-card, and a genuine tie between different-suit equal-rank hands.
- The A-2-3-4-5 wheel straight is recognized.
- The shared 3-card/5-card ordinal scale is correct in both directions (front trips loses to
  a middle/back straight; front trips beats a middle/back two pair).
- Arrangement foul detection (valid vs. fouled) is correct.
- `SpecialHandDetector` correctly flags Rồng Cuốn, Sảnh Rồng, and Lục Phé Bôn on constructed
  hands, and does NOT false-positive on an ordinary scattered hand.

Run via `swiftc` (**not** `swift <files>` script mode — that silently produced zero output
with exit code 0 on this toolchain when given multiple files; a real correctness trap worth
knowing about for future scripts in this portfolio). Full repro command is in the file's
header comment. **Result: 32/32 checks passed.**

Two supplementary empirical checks (not committed as files, but worth re-running if
`AIArranger` changes — commands are straightforward, see the ground-truth test's header for
the `swiftc` pattern):
- 1,500 random 13-card deals × all 3 difficulties → **0 foulded arrangements**, confirming
  the no-foul proof above empirically, not just on paper.
- 300 random deals comparing Easy vs. Hard's EV score → Hard was never worse than Easy, and
  strictly better on 62% of deals — confirms the difficulty tiers meaningfully differ, not
  just theater.

**Visual verification in Simulator** (iPhone 17 Pro, iOS 26): installed and launched via
`xcrun simctl` with `SIMCTL_CHILD_SX_CAPTURE`/`SIMCTL_CHILD_SX_LANG` debug env vars (see
`ContentView.swift`'s `#if DEBUG` block — same pattern as SamLoc's `SL_CAPTURE`/`SL_LANG`,
renamed `SX_*`). Screenshots taken and inspected (not just "it compiled"):
- Arrange screen — empty Back/Middle/Front zones, 13-card tray, Auto-Arrange/Submit buttons.
- Results screen after auto-arranging and submitting — **caught this actually validates the
  scoring engine**: the human's Four of a Kind correctly beat an opponent's Full House, Three
  of a Kind correctly beat Two Pair, and a High Card front hand correctly won on kicker — real
  poker-rule correctness visible in a live rendered screen, not just the unit test.
- Onboarding pages 1-4 (goal, Sảnh Rồng worked example, scoop worked example, no-stakes) —
  **found and fixed a real bug this way**: the special-hand worked-example caption was
  truncating with "…" instead of wrapping, caused by a `Text` sibling to a horizontal
  `ScrollView` picking up the ScrollView's unconstrained intrinsic width. Fixed with
  `.fixedSize(horizontal: false, vertical: true)` + `.frame(maxWidth: .infinity)`.
- Home screen and Rules screen in Vietnamese — translations read naturally, no truncation,
  no layout breaks.

## Differentiators (from ZingPlay Pusoy/Mậu Binh competitor review research)

Baked into product decisions AND onboarding/UI copy, not just claimed in App Store text:
- No coin economy, no forced escalating-stakes tables, no login wall, fully offline —
  stated explicitly on the Home screen ("Fully offline. No coins, no forced tables, no
  login — play at your own pace.") and in onboarding's closing page.
- Arrangement timer is **off by default** ("Practice mode — no timer" shown on the Arrange
  screen); turning it on gives a generous 90 seconds, not the "almost impossible" timer
  ZingPlay reviewers reportedly complain about.
- Onboarding includes actual worked examples (not just prose) for the Sảnh Rồng instant-win
  and the scoop bonus, with real example cards and real arithmetic (+1+1+1+3=+6) shown —
  this was the most-requested clarity fix in the task brief and got dedicated onboarding
  pages, not a rules-sheet footnote.
- Hard AI is a one-time non-consumable IAP, no ads anywhere, and is explicitly documented
  (in-app, in the Upgrade sheet's "Genuinely fair" feature row) as deterministic and never
  weighted against the player — there's no hidden rigging mechanism in `AIArranger` to weight
  against; it's the same search algorithm regardless of who's using it.

## Structure

- `SapXam/Core/` — `Card.swift`, `Localization.swift`, `PurchaseManager.swift` (all reused
  near-verbatim from SamLoc, product ID updated); `HandEvaluator.swift`, `Arrangement.swift`,
  `SpecialHand.swift`, `AIArranger.swift`, `Player.swift`, `GameModel.swift` (all net-new).
- `SapXam/Views/` — `HomeView`, `ArrangeView` (new main gameplay screen — tap-to-place card
  arrangement, no drag-and-drop), `ResultsView` (new scoring screen), `GameContainerView`
  (new — swaps Arrange/Results per round, shows match-end standings), `OnboardingView`,
  `RulesView`, `UpgradeView`, `CardView`.
- `SapXam/{en,vi}.lproj/Localizable.strings` — bilingual UI strings.
- `verify_hand_evaluator.swift` — ground-truth hand-evaluator/special-hand test (see above).
- `make_icon.py` — PIL-generated icon: three fanned playing cards on a navy gradient
  (portfolio-standard bold-single-emblem style, distinct color from SamLoc's green).
- `project.yml` — XcodeGen. Regenerate with `xcodegen generate` after adding/removing files.

## Submission prep — done and verified (2026-08-08)

- **App icon**: `make_icon.py` output confirmed as a real 1024×1024 RGB PNG (not a
  placeholder), correctly wired into `Assets.xcassets/AppIcon.appiconset/` via
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` — verified by a full `xcodegen generate` +
  clean `xcodebuild` Simulator build (`** BUILD SUCCEEDED **`). Navy gradient palette
  (`#081226`→ near-black) is already visually distinct from SamLoc/TienLen's green
  (`#0a2015`) and PhomTaLa's dark red (`#2a0a10`) — no change needed for portfolio
  distinctiveness.
- **`sapxam-legal` companion site**: created, all EN + Vietnamese pages written
  (`index[.html/-vi.html]`, `privacy[.html/-vi.html]`, `terms[.html/-vi.html]`,
  `support[.html/-vi.html]`), content adapted specifically for Sập Xám (special hands, IAP
  terms, FAQ). Pushed to `github.com/qngo9871-cmyk/sapxam-legal` (public repo) with GitHub
  Pages enabled — live at **https://qngo9871-cmyk.github.io/sapxam-legal/**.
- **App Store screenshots**: `capture_shots.py` written (DEBUG `SX_CAPTURE`/`SX_LANG` launch
  args, same pattern as Pallanguzhi's), captures 5 shots × 2 locales (home, hand-arrangement,
  results, special-hand onboarding, paywall) at the correct 1320×2868 marketing size into
  `screenshots/final/{en,vi}/`. **Every one of the 10 output images was opened and visually
  inspected**, not sampled — this caught three real bugs, all fixed and re-verified by
  recapturing the full set:
  1. **Card-rank clipping**: `CardView`'s rank/suit text is centered, and the `-14pt`
     negative-spacing card fan used tighter overlap than the card width could support —
     double-digit ranks ("10") and wide glyphs ("Q") were genuinely clipped by the next
     overlapping card, in both `ArrangeView` and `ResultsView`, not just in the screenshot.
     Fixed by reducing overlap to `-8pt` in both files (matches the already-correct ratio
     `OnboardingView`'s special-hand example row was using).
  2. **DEBUG `isPro` leak**: `PurchaseManager.updateEntitlementStatus()` unconditionally
     forced `isPro = true` in DEBUG builds — the exact same bug shape already caught once in
     this portfolio on Pallanguzhi. Made the Home screenshot show Hard AI unlocked (should be
     🔒 for a real free-tier user) and the paywall screenshot show "You own Sập Xám Pro"
     instead of the actual purchase button. Fixed by excluding the home/upgrade capture
     scenarios from the DEBUG auto-grant (dev convenience for manually testing Hard AI in the
     Simulator is preserved for every other scenario).
  3. **Results screen bottom clipping**: `ResultsView`'s floating "End Match"/"Next Round"
     button bar had no reserved scroll space, so on a 4-player match the last opponent's hand
     and the match-score summary could sit permanently behind the buttons with no way to
     scroll them into view. Fixed with bottom padding on the scroll content sized to the
     button bar.
  4. **Stray system notification in the Home screenshot**: a freshly-erased Simulator fires a
     one-time "Ready for Apple Intelligence" banner shortly after boot, which landed directly
     on the very first capture. Fixed with a throwaway warm-up launch+wait before the real
     capture sequence starts.
  Also added a small DEBUG-only `debugAutoFill` hook (`ArrangeView`/`GameContainerView`) so
  the arrange screenshot shows a filled 13→5/5/3 split instead of an empty tray — cosmetic,
  gated behind `#if DEBUG`, zero effect on real gameplay.
- **`asc_metadata_draft.md`**: written — title, subtitle, keywords, promo text, and full
  EN + natural (non-machine-translated) Vietnamese descriptions, baking in the real
  differentiators (no coins/forced tables/login, offline 3-tier AI, one-time IAP, untimed
  practice mode, worked special-hand examples).
- **Bundle ID registered**: `com.quyenngo.sapxam` registered via
  `~/asc-tools/asc_register_sapxam.py` (id `B53N7HY36B`), confirmed idempotent (ran twice,
  second run correctly found the existing bundle via 409). This script deliberately does
  **not** attempt `POST /v1/apps` (see README gotcha #1) — app-record creation is the next
  step below.
- **Repo**: pushed to `github.com/qngo9871-cmyk/SapXam` (public, matching the rest of this
  portfolio's convention).

## Live in App Store Connect now (2026-08-08, all values GET-verified after push)

App record created by hand in the ASC web UI: **"Sập Xám: 13-Card Poker"**, app id
`6799384925`, bundle `com.quyenngo.sapxam`, version **1.0** (id
`fbcdf4af-a73d-4984-8e30-d069f6706829`, state `PREPARE_FOR_SUBMISSION`). Pushed via
`~/asc-tools/asc_push_sapxam.py`, `asc_push_sapxam_screenshots.py`,
`asc_push_sapxam_review.py`, `asc_upload_sapxam_iap_screenshot.py`, and (earlier this
session) `asc_finalize_sapxam.py`.

- **Copyright + age rating** (via `asc_finalize_sapxam.py`, done before this push):
  `2026 Quyen Ngo`; age rating declaration all `NONE`/`false` → 4+, confirmed via
  `GET /appInfos/{id}/ageRatingDeclaration`.
- **Subtitle** (`appInfoLocalizations`): en-US `"Vietnamese Poker vs. AI"` (24 chars), vi
  `"Mậu Binh 13 Lá Việt Nam"` (23 chars). App name per locale: en-US `Sập Xám: 13-Card
  Poker`, vi `Sập Xám: Mậu Binh`.
- **Category**: primary `GAMES`, subcategory `GAMES_CARD` (Games → Card), confirmed via
  `GET /appInfos/{id}?include=primaryCategory,primarySubcategoryOne`.
- **Keywords/description/promo text** (`appStoreVersionLocalizations`): pushed for en-US
  and vi, full text from `asc_metadata_draft.md`. `whatsNew` deliberately left unset on
  both (first-version STATE_ERROR gotcha).
- **URLs**, verified live via `curl` before pushing: support
  `https://qngo9871-cmyk.github.io/sapxam-legal/support.html` (200), privacy
  `https://qngo9871-cmyk.github.io/sapxam-legal/privacy.html` (200), marketing
  `https://qngo9871-cmyk.github.io/sapxam-legal/` (200). (Draft had guessed
  `privacy-policy.html`, which 404s — the real file is `privacy.html`, corrected before
  pushing.)
- **Pricing**: app base price Free (Tier 0) via `POST /v1/appPriceSchedules`, confirmed
  `customerPrice: 0.0` on the resulting `appPrices` resource.
- **IAP**: `com.quyenngo.sapxam.pro` (non-consumable), created via `POST /v2/inAppPurchases`
  — **verified byte-for-byte against `PurchaseManager.swift:14`'s `productID` string before
  creating**, exact match confirmed. IAP id `6799402934`, state `MISSING_METADATA` (normal
  pre-tick-in, not a bug). Localizations: en-US name "Sập Xám Pro" / desc "Unlock Hard AI,
  card backs, unlimited play" (42 chars), vi name "Sập Xám Pro" / desc "Mở khóa AI Khó, mẫu
  bài, chơi không giới hạn" (44 chars) — both under the 55-char IAP description cap. Price
  $2.99 USD, confirmed via `inAppPurchasePriceSchedules` → price point customerPrice
  `"2.99"`. IAP review screenshot uploaded (`screenshots/final/en/05-upgrade.png`,
  1320×2868, checksum-verified).
- **Screenshots**: 5 per locale × 2 locales (en-US, vi) uploaded to display type
  `APP_IPHONE_67` (1320×2868, the 6.9" bucket), all confirmed `assetDeliveryState: COMPLETE`
  via GET — `01-home, 02-arrange, 03-results, 04-special, 05-upgrade`, same order both
  locales.
- **App Review Information**: contact Quyen Ngo, `qngo9871@gmail.com`, phone
  `+61425409937`, `demoAccountRequired: false`, notes explaining gameplay, the non-gambling
  distinction, the Hard-AI paywall location, and the bilingual UI switch.

## Deferred to a human — do NOT script around these

- **Tick the Pro IAP into version 1.0's own review submission**, from the *version* page in
  the ASC web UI (not the IAP's own page — orphaned-draft trap, portfolio gotcha #10).
- **App Privacy nutrition label** (Data Not Collected — app is fully offline, no accounts).
- **Upload the real build** (archive/export/`altool`) and attach it to version 1.0.
- **Create/submit the `reviewSubmission`** — not touched by any script in this pass.

## Still open (not started)

- **Real-device testing**: only tested in Simulator so far, and this project has no
  `.storekit` configuration file — the StoreKit purchase flow in particular should be
  verified via TestFlight on a real device before assuming it works, per portfolio-wide
  learning that Simulator StoreKit failures aren't always real bugs (and the inverse also
  holds: Simulator success isn't proof of real-device correctness).
- **Gameplay polish not yet done**: `ArrangeView` uses tap-to-select/tap-to-place instead of
  drag-and-drop (functional but less slick); AI-vs-AI round-robin results are computed and
  scored correctly but the results screen only surfaces the human's pairings against each
  opponent, not full 4-player standings detail; no animation/haptics on card placement.
- **Onboarding content review**: the Vietnamese hand-name translations
  (`hand.twoPair`/`hand.threeOfAKind` especially) should get a native-speaker gut-check
  before shipping, per the note above.

## Submitted for review (2026-08-09)

All ASC steps complete: metadata, IAP, screenshots, build (VALID, Distribution-signed), age rating, App Privacy, IAP ticked into version. Submitted via reviewSubmissions API — reused the existing draft submission that already held the IAP (avoided the orphaned-draft trap), attached the version, and confirmed the IAP rode along (moved to WAITING_FOR_REVIEW alongside the version, not left behind). Verified independently via GET: `appStoreState: WAITING_FOR_REVIEW`.
