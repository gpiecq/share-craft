# Changelog

## [2.0.4] - 2026-03-20

### Fixes
- Cross-locale enchanting recipe search (FR player can now find EN player's enchantments and vice versa)
- Profession filter in Guild tab now matches across locales (e.g. "Enchanting" = "Enchantement")
- Duplicate profession entries in Guild dropdown when members use different game languages
- Profession names displayed in the local client's language everywhere (Guild tab, Members tab, tooltips, CSV export)
- Enchanting recipes now grouped by spellID in Guild tab results (prevents duplicates across locales)

### Technical
- New profession cross-locale mapping system (spell ID based, EN + FR hardcoded + GetSpellInfo for any locale)
- SC:BuildProfessionMap(), SC:SameProfession(), SC:GetLocalProfName() in Data.lua
- FindRecipeDetails and FindLocalRecipe now search across locale-variant profession names

## [2.0.3] - 2026-03-01

### Fixes
- Addon marked as outdated (updated Interface version to 20505 for Anniversary Edition)

## [2.0.2] - 2026-03-01

### Fixes
- Addon marked as outdated (updated Interface version to 11508 for Anniversary Edition)
- Changelog translated to English

## [2.0.1] - 2026-02-26

### Fixes
- Missing enchanting recipe descriptions (fallback via GetCraftDescription)
- Game crash/disconnect during guild sync (addon message flooding)
- Duplicate addon messages received by WoW client (deduplication)
- Repeated DATA responses to the same player (60s request cooldown)
- Chunk buffer timeout too short for large transfers (60s → 180s)
- Unlearned professions still shared to guild (auto-cleanup via GetProfessions)

### Technical
- Global outgoing message queue (QueueMessage/ProcessQueue)
- SendHello only broadcasts own data (relay removed)
- Message interval: 0.2s → 0.5s
- Sync completion message after `/sc sync`
- Release zip packaged with root folder (CurseForge compatible)

## [2.0.0] - 2026-02-24

### Added
- Guild recipe sharing via addon GUILD channel
- Hash-based protocol (HELLO/REQUEST/DATA/DATACHUNK/PRIVACY) with chunking
- "Guild" tab: search by player, profession and recipe
- "Members" tab: synced players list with recipe count and date
- Guild CSV export (same columns + "Last scan")
- Per-profession privacy system (opt-in by default)
- Minimap button
- Enriched tooltip: hovering an item shows guild crafters
- Full FR/EN localization (UI, messages, CSV headers, parsing patterns)

### Technical
- New files: GuildDB.lua, Comm.lua
- Shared SC.L table in Data.lua for localization
- SavedVariables: ShareCraftGuildDB (guild data, shared across characters)
- New commands: `/sc sync`, `/sc privacy`

## [1.0.1] - 2026-02-21

### Added
- Enchanting support (separate CraftFrame API in TBC)
- Export CSV button on Enchanting window
- Excel and Google Sheets guide in README

### Fixes
- Replaced extension filter with category filter (TBC headers are by category, not extension)
- Fixed Wowhead links (tbc instead of classic)
- Fixed GitHub Action permissions for release creation
- Fixed zip format (files at root for Windows extraction)

## [1.0.0] - 2026-02-21

### Initial release
- Automatic recipe scan when opening a profession
- CSV export with `;` separator
- Item stats (Armor, Strength, Agility, Stamina, Intellect, Spirit)
- Levels (ilvl, required level)
- 1 row per reagent for pivot tables
- Automatic Wowhead links
- Category filter
- Export CSV button on profession window
- ElvUI-compatible interface
- Commands: /sc, /sc debug, /sc scan
