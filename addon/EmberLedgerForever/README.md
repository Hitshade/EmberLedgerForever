# EmberLedger: Forever

Version 0.5.0 • by Hitshade • WoW Forever

A compact farming ledger that keeps your current session in view: loot, estimated value, and estimated gold per hour.

## Installation

Extract `EmberLedgerForever-0.5.0.zip` into your WoW Forever client's `Interface/AddOns` folder. The resulting path must be `Interface/AddOns/EmberLedgerForever/EmberLedgerForever.toc`.

For an upgrade, exit the game and replace the existing EmberLedgerForever addon folder. Keep your saved variables in WTF to retain character settings and history. Start the game and enable EmberLedger: Forever in the addon list. This package targets interface 16001; it is not a Retail or Classic Era release.

## Your current session

A session starts automatically on login. The compact tracker shows active time, estimated value, estimated gold/hour, and looted items with quantities and totals. Scroll over the list for more items or drag the lower-right corner to resize. Hover an item for its unit price and price source; click it to set a manual price.

All farming loot is included, from gathered materials and skinned leather to vendor junk and equipment. Confirmed looted coin contributes to the value total. Sales and unrelated wallet changes do not. Estimated gold/hour is gross loot value per active hour, not realized sales or profit.

The Options window contains Pause/Resume, Stop, New and History. Paused and offline time do not inflate active time. Reloading preserves the session state; a new login starts a fresh session and archives the previous nonempty session. Closing the tracker does not pause tracking.

History opens in its own panel and keeps the 20 most recent nonempty sessions per character. Older/Newer switches sessions; scroll over the item list for more rows. Saved sessions retain their recorded prices.

## Pricing

Automatic pricing uses a manual override first, then TSM `dbmarket`, Auctionator data, and vendor value. You can also select TSM, Auctionator or Vendor mode in Options. Market pricing requires a compatible provider with available data; neither provider is required to use the addon. No auction scans or market database are bundled.

Refresh prices updates the unfinished current session. Historical prices stay fixed. Missing item information or unavailable prices can temporarily show as unpriced. Bind-on-pickup and quest items skip market pricing.

## Appearance and controls

Choose Modern, Forever or Classic. Options provides UI scale, background opacity, movement/resizing lock, and minimap-button visibility. The Forever theme uses the game's native bronze frame artwork. Text and borders remain readable when background opacity is reduced.

The minimap button uses bundled libraries: left-click to show/hide the tracker, right-click for Options, and drag to reposition. Compatible broker displays can also show the launcher.

| Command | Action |
| --- | --- |
| `/elf` or `/emberforever` | Show the tracker |
| `/elf options` | Toggle Options |
| `/elf history` | Toggle History |
| `/elf resetpos` | Reset tracker position and scale |
| `/elf debug` | Print diagnostic information |

## Troubleshooting

If loot is missing, check that the session is running, then collect a new item with transfer/vendor windows closed. Include the item name, the exact self-loot chat message, client version, addon version, and `/elf debug` output in a report. For Lua errors, include the full first error and steps to reproduce it.

If values look low, confirm your pricing provider has data and use Refresh prices. Without market data the addon falls back to vendor values. Old saved sessions are snapshots; refreshing current prices does not repair old unpriced history.

If a window is off-screen, use `/elf resetpos`. Disabling the minimap button does not disable slash commands or tracking.

## Scope and credits

Focused on farming sessions: no concentration tracker, profession buff dashboard, or expansion-specific gathering checklist. Settings and session data are per character.

Original code: Mozilla Public License 2.0. Artwork and third-party notices: see LICENSING.md. Includes LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 with upstream notices. Blizzard artwork is referenced from the game client.
