# Rummage

One macro per item type that always uses the best item in your bags. Type `/rum`, drag an icon onto an action slot, and that slot keeps pointing at the right item as your bags change.

Built for **World of Warcraft: Forever** (Interface 16001). It only uses standard bag, tooltip and macro APIs, so it should also work on other clients that have them.

## Categories

| Category | Macro | Picks |
| --- | --- | --- |
| `food` | SmartFood | Buff food by your stat priority, read from the Well Fed text |
| `plainfood` | SmartPlainFood | Food without a buff that restores the most health |
| `drink` | SmartDrink | The drink (water, juice, conjured water) that restores the most mana |
| `fooddrink` | SmartFoodDrink | Off by default. The SmartPlainFood and SmartDrink picks in one macro |
| `flask` | SmartFlask | Flasks and elixirs by your stat priority |
| `scroll` | SmartScroll | Stat scrolls by your stat priority, used on yourself |
| `healthpotion` | SmartHealthPotion | The potion that restores the most health |
| `manapotion` | SmartManaPotion | The potion that restores the most mana |
| `bandage` | SmartBandage | The bandage that heals the most, used on yourself |
| `quest` | SmartQuestItem | The usable quest item for the quest that matters most right now |

Every category skips items above your level. Percent-based potions are valued against your current maximum.

### Quest items

The quest log attaches a usable item to some quests (the one the objective tracker shows a button for). SmartQuestItem always points at the most relevant of those in your bags, in this order: the super-tracked quest, quests on the current map, tracked quests, everything else in the log, then bag items that start a quest. Items for quests you have already completed drop to the bottom unless the quest still needs the item to turn in. The macro follows quest log, tracking, super-tracking and zone changes.

### Food

Food is split in two macros, so you can eat to heal up without spending buff food:

- **SmartPlainFood** eats food that gives no buff, the one that restores the most health first. It never touches Well Fed food.
- **SmartFood** eats buff food only. Rummage reads the Well Fed text of every food item in your bags and ranks by the stats you care about:
  - Food with your top-priority stat wins. Among those, the largest amount wins.
  - If you carry nothing with a listed stat, buff food with any other stat comes next.
- Drinks that only restore mana are ignored; they have their own `drink` macro.

Pick your preferred buff in the `/rum` window, or set the whole order by command:

```
/rummage food haste crit mastery stamina
/rummage food any
```

Words accepted: `stamina sta stam spirit spi strength str agility agi intellect int haste crit critical mastery mast versatility vers hit expertise exp ap attackpower sp spellpower healing heal armor mp5 hp5 health mana`.

### Flasks and elixirs

Same priority mechanism as food, with its own list (`/rummage flask str agi int`). Until you set one, the default follows your class and talents (based on the Icy Veins WoW Forever guides):

| Class / role | Default order starts with |
| --- | --- |
| Warrior, Retribution/Protection Paladin, Enhancement Shaman, Feral Druid | Strength, Attack Power, Agility |
| Rogue, Hunter | Agility, Attack Power |
| Mage | Spell Power, Spirit, Intellect |
| Warlock | Spell Power, Stamina, Intellect |
| Priest, and Holy/Restoration/Balance/Elemental hybrids | Spell Power, Healing, Intellect/MP5, Spirit |

Hybrids without a talent tree yet get a mixed list (druids lead with casting). Stamina, Health and Armor are always on the list as a last resort. Elixirs that only give stats your class gets nothing from (Strength or Agility on a mage, Intellect or Spirit on a rogue) are skipped instead of wasted, and show as "no use to your class". Add the stat to your priority if you want them used anyway. Battle and guardian elixirs are not told apart yet: the macro uses the single best match, so keep the other elixir type on a separate slot if you use both.

### Scrolls

SmartScroll picks among stat scrolls (Stamina, Intellect, Spirit, Strength, Agility, Protection) with the same mechanism and class defaults as flasks, under its own priority (`/rummage scroll str sta`). The highest rank of a matching scroll wins, and scrolls your class gets nothing from are skipped. A scroll buffs your target if you have one, so the macro always uses it on you (`/use [@player]`). It does not check whether the buff is already on you yet.

### Drinks

SmartDrink uses whatever you sit down and drink that restores the most mana: water, juice, conjured water, and food that restores mana as well. Mana potions are not drinks and stay on SmartManaPotion. No priority to set.

### Food and drink in one slot

Short on action slots? **SmartFoodDrink** eats your plain food and drinks your drink in one click (food and drink are off the global cooldown, so both go through). It uses the same items SmartPlainFood and SmartDrink would, and only one of them when you carry just food or just drink. It is off by default: tick it in the `/rum` window or settings, or type `/rummage fooddrink on`. Turning it on turns off the separate SmartPlainFood and SmartDrink macros; turning it off turns them back on.

### Potions and bandages

No priority to set; the strongest item wins. Potions that restore both health and mana (Rejuvenation) come after every pure health or mana potion, so one button does not spend the other half; they are used once the pure potions run out. Healthstones are left alone because they do not share the potion cooldown. The bandage macro targets you (`/use [@player]`).

## The window

`/rum` opens the Rummage window. Each row is one category:

- the icon of the item it currently uses (question mark if none), with its count and cooldown. It dims like an action button when the item cannot be used right now. Drag it, or click it, and drop on any action slot, including Backhand paddles. Hover it to see every candidate in ranked order.
- a checkbox to stop or resume updating that macro.
- for food, flasks and scrolls, two dropdowns: **Preferred buff** (the stat you want, for example Haste) and **If none, then** (the fallback when you carry no food with it). "Any (strongest)" ranks purely by amount. The full order is shown next to them; **Default** restores the built-in list.

Press Escape or **Close** to hide it.

## The bar

Next to the macros, Rummage can show its own bar: one button per category you carry something for, each using that category's current pick (the same item its Smart macro uses). Buttons appear and disappear as your bags change, so the bar only ever holds what you can actually use. Each button shows the item's count and cooldown, dims when it cannot be used, and its tooltip is the item's tooltip plus how many other candidates you carry. Disabled categories are left off.

It is on by default. While unlocked it has a dark background and a small blue handle at its top-left corner: drag the handle to move it, then lock it. Options are in the settings page and under `/rum bar`:

```
/rummage bar                     show or hide the bar
/rummage bar lock|unlock         lock it, or show the drag handle
/rummage bar vertical|horizontal change its direction
/rummage bar empty               also show categories with nothing in your bags
/rummage bar scale 1.2           resize it (0.5 to 2)
/rummage bar reset               move it back to the default spot
```

Like the macros, the bar can only change outside combat: an item you run out of mid-fight stays on its (dimmed) button until the fight ends, and the bar cannot be moved or reconfigured in combat.

## Settings page

**Settings > AddOns > Rummage** (or `/rum config`) has the same controls: the current item's icon to drag onto a slot, the on/off checkbox per category, the preferred buff and fallback as click-to-cycle buttons (left-click next, right-click previous), a Default button, and a debug toggle. It uses cycle buttons instead of dropdowns on purpose; see the gamepad note below.

## Commands

Everything in the window also has a command, mostly for macros and keybinds:

```
/rummage                        open or close the window
/rummage status                 print what each macro currently uses
/rummage list food              every food in bags, ranked, with parsed stats
/rummage <category> <stats...>  set that category's stat priority (food, flask, scroll)
/rummage <category> reset       back to the default priority
/rummage <category> on|off      stop or resume updating that macro
/rummage pickup <category>      put that macro on the cursor
/rummage scan                   rescan bags now
/rummage debug                  toggle debug output
```

`/rum` is a shortcut for `/rummage`.

## How it works and its limits

- Macros cannot be changed in combat, so a bag change during a fight is applied when the fight ends. Running out of one potion type mid-fight therefore leaves the macro on the empty item until combat ends; carry a stack.
- Stats and amounts are parsed from tooltip text in English. Other locales fall back to "any item, most health first" until their patterns are added. Items whose tooltip cannot be parsed can be listed under `OVERRIDES` in `Categories/Food.lua` or `Categories/Flask.lua`.
- The macro uses `#showtooltip`, so the slot shows the chosen item's icon and count.
- The macro is created per character when possible, and account-wide if the per-character slots are full.

## Gamepad note

Forever hangs when the Settings window is closed with the controller after the gamepad cursor has visited addon-created controls, and Blizzard's standard settings list triggers that by itself. The Rummage settings page is therefore a canvas built once at login from plain checkboxes and buttons, never handed to the gamepad cursor, and it opens no dropdown menus. With a controller, use the mouse on that page, or the `/rum` window, which lives outside Settings.

## Adding a category

Each file in `Categories/` registers one category with `Rummage.RegisterCategory`. A category names its macro, gives a cheap `Prefilter` on item class, a `Classify` function that turns tooltip lines into a candidate, and a `Rank` function that sorts candidates. Categories with `statAliases` get a per-character priority; `MacroBody` overrides the macro text. `Categories/Stats.lua` holds the shared stat vocabulary and parser.

## License

MIT.
