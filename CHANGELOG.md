# Rummage changelog

## 0.1.0 — First release

Rummage is part of the SNRN addon family.

- **One macro per item type** that always uses the best item in your bags:
  - `SmartFood` and `SmartFlask`: food and flasks/elixirs by a per-character stat priority read from tooltip text. Food above your level is skipped.
  - `SmartDrink`: the seated drink that restores the most mana.
  - `SmartHealthPotion` and `SmartManaPotion`: largest restore, percent potions valued against your current maximum.
  - `SmartBandage`: largest heal, cast on yourself.
  - `SmartQuestItem`: the usable item of the most relevant quest in your log (super-tracked, on this map, tracked, then the rest), or a bag item that starts a quest.
- **`/rum` window** with one row per category: the current item's icon (drag or click it onto an action slot), an on/off checkbox, and "Preferred buff" / "If none, then" dropdowns for food and flasks. Hovering an icon lists every candidate in ranked order.
- **Settings > AddOns > Rummage** with the same controls, built as a plain canvas with click-to-cycle buttons and no dropdown menus, so Forever's gamepad cursor never touches it.
- Commands under `/rummage` (`/rum`) for status, ranked lists, priorities, on/off, picking up a macro, rescanning and debug output.
