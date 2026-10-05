# Rummage changelog

## 0.3.0 — Cooldowns in the window

- The `/rum` window icons show the item's cooldown sweep and dim like native action buttons when the item cannot be used right now (#2).

## 0.2.0 — Class-aware elixirs

- **Class-aware flask/elixir defaults.** Without a saved priority, `SmartFlask` now ranks by your class and talent tree (melee: Strength/Agility and Attack Power; casters: Spell Power, then Spirit/Intellect), after the Icy Veins WoW Forever guides.
- Elixirs that only give stats your class cannot use are skipped instead of wasted, unless you list that stat in your own priority.
- Rejuvenation-style potions (health and mana) now rank after pure health and mana potions in `SmartHealthPotion` and `SmartManaPotion`, and are used once those run out.
- Mana-over-time elixirs (Mageblood: "regenerate 3 mana every 5 seconds") are now read as Mana/5 instead of maximum Mana.

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
