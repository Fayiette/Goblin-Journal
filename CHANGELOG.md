# Changelog

## [1.1.2] - 2026-09-29

- Wealth Goals Context Menu Outside-Click Dismissal:
  - Added transparent click-catcher and mouse-wheel listeners covering UIParent for the Wealth Goals "Manage" context action menu.
  - Clicking anywhere outside the menu or scrolling the mouse wheel immediately closes the popup menu.
  - Clicking the same "Manage" button again toggles the context menu closed.
  - Registered `GoblinJournalActionMenu` with `UISpecialFrames` to support Escape key dismissal.
- Modal Backdrop Overlays & Outside-Click Dismissal:
  - Added `UILib:AttachModalBackdrop` providing a semi-transparent dark backdrop overlay (75% opacity) over the journal frame and a full-screen click-catcher.
  - Clicking outside the modal dialog box (on the darkened backdrop or anywhere on the game screen) closes the modal dialog.
  - Applied modal backdrop overlays to `Edit Goal`, `Delete Wealth Goal`, `Goblin Journal Settings`, `Export Financial Ledger`, `Session Retention Cap`, and `Reset Ledger Data`.
  - Registered unique frame names for each modal in `UISpecialFrames` to ensure Escape key closes the active modal without closing the main frame.
  - Added automatic edit box focus clearing when dismissing modals.
- Centralized Modal Exclusivity & Overlapping UI Prevention:
  - Implemented `UI:CloseAllModals(except)` to ensure only one modal or popup can be active at a time.
  - Closes all modals on view navigation changes (`UI:SetView`) and when closing the main journal frame.
  - Intercepts clicks on underlying header and footer buttons while a modal is active, preventing overlapping windows.

## [1.1.1] - 2026-09-28

- Bottom Zone Navigation Multi-Row Expansion:
  - Fixed zone pill text overlapping caused by unbound FontString in button widget and hardcoded fallback widths.
  - Dynamically calculates pill width based on actual string width plus horizontal padding (16px).
  - Added expandable multi-row zone navigation bar with dedicated "More v" / "Less ^" toggle button positioned before the end of the first row when zones exceed one line.
  - Accommodates 2nd and 3rd rows for characters with many active zones.
  - Implemented downward frame expansion by pinning the frame's TOPLEFT anchor, shifting only the bottom downward by 24px per extra row without displacing top cards, tables, or header.
  - Updated visual mockup prototype with an interactive Zone Density Demo scenario switcher (Few, Many, Extreme zones).

## [1.1.0] - 2026-09-26

- Feature G: WoW Reset Week Accounting View:
  - Added dedicated Tuesday 15:00 UTC weekly financial cycle aligned with standard WoW server resets.
  - Expanded primary navigation to 5 tabs: Day, Week, Month, Session, and Wealth.
  - Displays clean weekly date range header (e.g., "Sep 23, 2026 - Sep 29, 2026") without redundant prefixes.
  - Full 7-Day Performance table with Income, Expense, Net cashflow, and Day-drilldown navigation.
- Feature B: Zone & Dungeon Profitability Tracking:
  - Multi-zone delta tracking capturing gold income and expenditures partitioned by zone name.
  - Bottom Zone Navigation Bar with dynamic segmented pills styled cohesively with primary tabs.
  - Alphabetical zone sorting and automatic pruning of zones with zero financial activity.
  - Added dedicated ZONE column in the Recorded Sessions Ledger table.
- Feature D: Draggable Floating Micro-HUD:
  - Lightweight on-screen HUD displaying real-time Daily (D:) and Session (S:) cashflow.
  - Title bar and drag handle are strictly hidden when locked, appearing only when unlocked.
  - Minimap button Right-Click toggles HUD lock status with audible and chat feedback.
  - Position persistence saved per character and ruleset.
  - Configurable update interval selection (1s, 2s, 5s, 10s, 30s, 60s) in Settings and via /gj interval.
  - Automatic OnUpdate ticker keeps HUD metrics refreshed continuously in the background even while the main journal frame is closed.
- Feature E: Multi-Format Financial Ledger Export System:
  - Built-in export modal supporting both RFC 4180 CSV and Microsoft Excel XML Spreadsheet 2003 formats.
  - Full 21-column schema preserving date, character, ruleset, zone, net, and category breakdowns.
  - Multi-line editbox with one-click Select All (Ctrl+C) for copying directly into Excel or spreadsheets.
- Feature A: Dedicated Goblin Wealth Goals Ledger Page:
  - New "Wealth" navigation tab displaying a financial milestone goals ledger.
  - Inline creation toolbar (+ New Goal: Goal Title, Target Gold, Save Goal).
  - Combined Progress / Target column featuring Blizzard gold coin textures and animated progress bars.
  - Context action menu supporting Goal Editing, Completion / Reopening, and Delete with modal confirmation.
  - Active goal milestone widget integrated into the journal footer.
- Interface Settings Modal:
  - Comprehensive options modal accessible via footer "Settings" button or `/gj settings`.
  - Configurable startup view, minimap button toggle, HUD visibility and locking, and session retention caps.
- Strict Workspace Rules Compliance:
  - Zero emojis across all UI strings, documentation, commit notes, and code.
  - 100% Blizzard coin texture compliance (Zero-GSC rule).
  - Lua 5.1 upvalues consolidation keeping closures well below limits.

## [1.0.1] - 2026-09-26

- Added Session Recording Engine:
  - Middle-Click on Minimap button starts and stops an isolated session recording timer without altering standard daily/monthly gold tallies.
  - Dual-write mirroring captures incoming/outgoing transactions and time-series cash flow deltas during active sessions.
  - Green pulsing tracking border on the minimap button while session recording is active.
- Added Recorded Sessions Ledger View:
  - Accessible via "Session View" navigation tab or Right-Click on the Minimap button.
  - Pure recorded session ledger table listing session timestamps, totals, and net result.
  - Scope filtering preserved (Current Character, Alliance, Horde).
- Added Isolated Session Detail View:
  - Drill into any recorded session to inspect detailed category breakdowns, top hero cards, duration, character/realm, and time window.
  - Disabled "Session View" tab when inspecting individual session details, with clean "Back" navigation.
  - Adaptive Cash Flow Sparkline visualizing incoming (green, upward) and outgoing (red, downward) spikes dynamically scaled across session duration.
  - Gold Rate metric formatted with coin textures and / hr.
- Added Session Retention Cap &amp; FIFO Eviction:
  - Configurable retention cap (50, 100, 200, Unlimited) directly in the Session Ledger header.
  - FIFO eviction automatically discards oldest sessions when exceeding the chosen limit.
  - Modal confirmation prompt warning the player before eviction when selecting a cap lower than current session counts.
- Currency Display Enhancements (Zero-GSC Compliance):
  - Completely replaced text-based currency letters (g, s, c) across all tables, category badges, metric cards, and minimap tooltips with official Blizzard coin textures.

## [1.0.0] - Initial release

- Introduce a lightweight financial ledger for World of Warcraft.
- Track and categorize daily income and expenses, with daily and monthly summaries.
- Add character and faction scopes, ruleset isolation, and interactive ledger navigation.
- Include a draggable minimap button, slash commands, and reset controls.
