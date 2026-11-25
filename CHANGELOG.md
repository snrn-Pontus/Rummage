# Rummage changelog

## Unreleased

- **Brazilian Portuguese (ptBR) clients.** Every category now recognises items on a ptBR client; before, only quest items from the quest log were found. `Locale.lua` rewrites ptBR tooltips into the English wording the parsers use, and item names are matched in both languages.
- Numbers with thousands separators or decimals are read correctly (`2.000`, `1,050`, `874.8 health`, which used to be read as 8).
- Items that begin a quest are picked up again: they have no "Use:" line, which the check required.
- Rejuvenation potions count as healing potions too (still ranked after pure ones), and mana regeneration ("8 mana every 5 sec") is no longer read as a drink or potion amount; "critical hit" counts as Crit.
- Seated food and drinks with a buff whose ptBR tooltip never says "well fed" ("Também aumenta em 10 o Espírito") go to SmartFood, as their English versions do.

## 0.5.0 — Rummage bar

- **SmartScroll** (#1): stat scrolls (Stamina, Intellect, Spirit, Strength, Agility, Protection) by your stat priority, with the same class and talent defaults as flasks. The highest rank wins, scrolls your class gets nothing from are skipped, and the macro always uses the scroll on yourself.
- "Any (strongest)" now really means any: scrolls and elixirs your class gets nothing from are no longer skipped when that is your first choice.
- **Rummage bar:** an AutoBar-style bar with one button per category you carry something for, each using the same best item as its Smart macro. It grows and shrinks with your bags, shows counts and cooldowns, and can be moved, locked, turned vertical or scaled. Toggle it in the `/rum` window, on the settings page, or with `/rum bar`.
- **SmartFoodDrink** (optional): one macro that eats your plain food and drinks your drink in the same click, to save an action slot (one bar button instead of two). Off by default; turn it on in the `/rum` window, the settings page or with `/rummage fooddrink on`. It replaces SmartPlainFood and SmartDrink while it is on.
- **Tooltip wording from WoW Forever is read correctly.** These used to count as having no stats, or the wrong ones:
  - "Spell Damage" food (Spotted Yellowtail, Nightfin Soup) and "spell damage by up to 35" elixirs and flasks now count as Spell Power.
  - "Healing Power" teas and "healing done by spells and effects" elixirs count as the new **Healing** stat, which casters and healers rank right after Spell Power.
  - Percent stats ("1% Critical Strike chance", "5% Hit Chance") and two stats sharing one amount ("Strength and Stamina by 18") are read.
  - "Regenerate 20 health every 5 sec" is the new **Health/5** stat instead of maximum health.
  - Elixirs that only work against one creature type (Demonslaying) or for one spell school (Shadow Power) are no longer ranked as general Attack Power or Spell Power.
- Food that restores "2% of your health per second for 25 sec" (Harvest food, Refreshing Red Apple) is ranked by its whole heal instead of a single tick.
- Blessed Sunfruit and similar food ("Also increases your Strength") count as buff food, so `SmartPlainFood` no longer eats them.
- `SmartDrink` uses buff drinks (teas, smoothies) only after every plain drink is gone.

## 0.4.0 — Plain food

- **Buff food and plain food are separate macros.** `SmartFood` now only uses buff food (Well Fed), by your stat priority as before. The new `SmartPlainFood` eats food without a buff, most health first, so healing up between pulls no longer spends buff food. Saved food priorities and `/rummage food <stats>` are unchanged.
- **Fixed macros not updating until `/reload`.** A bag item's tooltip read before the client had loaded the item or its "Use:" spell text was cached for the whole session, so freshly looted bandages, potions or food of a kind you had not carried since login could be ignored (for example after running out). Incomplete tooltips are no longer cached; Rummage requests the missing data and rescans when it arrives.

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
