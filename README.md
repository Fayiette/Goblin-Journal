# Goblin Journal

Goblin Journal is a lightweight, zero-bloat financial ledger and accounting addon for World of Warcraft (supporting Forever / Camelot Interface 16001 and Standard/Classic clients).

It tracks all incoming and outgoing copper, silver, and gold on a day-by-day and month-by-month basis, classifying transactions into distinct economic categories and displaying daily and monthly net profitability (+/-) in high-contrast profit/loss styling.

---

## Features

- **Automated Event Categorization**: Automatically categorizes transactions without user input:
  - **Incoming**: Auction House, Monsters & Loot, Quest Rewards, Vendor Sales, Trade & Mail, Other/Misc.
  - **Outgoing**: Equipment Repairs, Auction House (Bids & Deposits), Vendor Purchases, Flight & Travel, Class & Profession Training, Trade & Mail, Other/Misc.
- **Net Performance Indicator (+/-)**: Instantly see whether a day or month produced a net surplus (green profit) or a deficit (red loss).
- **Two-Tier Symmetrical Layout**:
  - **Day View**: Top section displays selected day's net profit/loss and itemized income/expense category progress bars. Bottom section displays the **Day-by-Day Monthly Performance** ledger for that selected month, sorted in descending order (only days with actual recorded transactions are shown). Clicking any day row inspects that day.
  - **Month View**: Top section displays selected month's aggregated revenue and expenses. Bottom section displays the **Month-by-Month Annual Performance** ledger for that year (only months with actual recorded transactions are shown, sorted descending). Clicking any month row inspects that month.
- **Locked Frame Geometry**: Frame height remains stable at 615px across Day and Month views with fixed category card heights and ledger tables.
- **Thousand Separators**: Formats all gold values with commas for amounts of 1,000g and above (e.g., `1,420g 50s 0c`).
- **Ruleset Isolation & Faction Scopes (Forever / Camelot Support)**:
  - Automatically detects the active game ruleset (Hardcore, RP, PvP, or Normal/Realm) and partitions transaction records under `GoblinJournalDB.ledger[ruleset]`.
  - Characters playing under different rulesets never contaminate each other's economy.
  - Three scope filter buttons located directly in the header under the close button:
    - **Current Character**: Restricts ledger and summaries strictly to the active logged-in character.
    - **Alliance**: Aggregates transactions from all Alliance characters belonging to the active ruleset.
    - **Horde**: Aggregates transactions from all Horde characters belonging to the active ruleset.
  - An active ruleset badge in the header displays the detected ruleset.
- **Interactive Minimap Button**:
  - Dynamically calculates orbit radius from actual Minimap dimensions to sit flush on the outer rim across all client resolutions and minimap sizes (with LibDBIcon shape support for round, square, and hybrid minimaps).
  - Draggable around the Minimap circumference (persists angle).
  - Hover tooltip displays today's net performance and total income/expense figures.
  - Left-Click toggles the journal window.
  - Right-Click jumps directly to Today's ledger.
- **Zero-Bloat Architecture**: Instead of storing endless transaction receipt logs in SavedVariables, Goblin Journal records only 13 flat integers per calendar day. A full year of heavy gameplay consumes less than 40 KB of disk space and loads in under 1 millisecond.
- **Clean Modular UI Library**: Built using a dedicated UI library (`UILib.lua`) and centralized constants (`Constants.lua`) without hardcoded magic numbers or namespace pollution.

---

## Installation

1. Copy the `Goblin-Journal` directory into your World of Warcraft addons folder:
   ```
   World of Warcraft/_retail_/Interface/AddOns/Goblin-Journal/
   ```
   or for Forever / Camelot / Classic:
   ```
   World of Warcraft/Interface/AddOns/Goblin-Journal/
   ```
2. Ensure the folder is named exactly `Goblin-Journal`.
3. Launch World of Warcraft and make sure `Goblin Journal` is enabled in your AddOns list.

---

## Usage

### Slash Commands
- `/gj` or `/goblin`: Toggles the Goblin Journal ledger window.
- `/gj reset` or `/gj resetall`: Opens the confirmation modal to reset all financial records.

### Minimap Controls
- **Left-Click**: Toggle Goblin Journal window.
- **Right-Click**: Jump to today's ledger entry.
- **Click & Drag**: Move the minimap button around the minimap perimeter.

### Ledger Controls
- **Scope Filters (Current Character / Alliance / Horde)**: Switch aggregation scope under the close button to view individual character data or aggregate across your account's Alliance or Horde characters on the current ruleset.
- **Ruleset Badge**: Displays the active game ruleset (e.g. `[Ruleset: Hardcore]`).
- **Day View / Month View Tabs**: Switch between daily breakdown and annual monthly breakdown.
- **< / > Buttons**: Navigate backwards or forwards by day or month (forward navigation is automatically clamped so you cannot advance past today or the current month).
- **Today / This Month Button**: Quickly snap back to the current day or month.
- **Month Display**: Month View displays full month names (e.g. `September 2026`) in both the top date header and annual ledger rows.
- **Select Button (on table rows)**: Switch the active inspection view to the chosen date or month.
- **Reset All Button (footer)**: Opens a confirmation popup modal before clearing all recorded data for the active scope.

---

## File Architecture

- [Goblin-Journal.toc](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Goblin-Journal.toc): Addon metadata and SavedVariables declaration (`GoblinJournalDB`).
- [Goblin-Journal.xml](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Goblin-Journal.xml): XML script load order.
- [Constants.lua](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Constants.lua): Central configuration, palette colors, dimensions, backdrops, and category definitions.
- [UILib.lua](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/UILib.lua): Reusable UI widget library (thousand separators, card frames, buttons, tabs, progress bars, coin text).
- [Engine.lua](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Engine.lua): Event monitoring state machine, zero-bloat flat integer storage, and dynamic aggregation.
- [Minimap.lua](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Minimap.lua): Draggable minimap button and tooltip summary.
- [UI.lua](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/UI.lua): Symmetrical main ledger interface, navigation, row frame pooling, and slash command bindings.
- [Media/](file:///home/val/linux/wow-FayUtilities/Goblin-Journal/Media/): Custom engraved coin logo textures (`coin.tga`, `coin_64.tga`, `coin.png`, `coin_64.png`).
- [mockup/goblin_journal.html](file:///home/val/linux/wow-FayUtilities/mockup/goblin_journal.html): Visual interactive prototype.

---

## License

MIT License. Author: Fayiette.
