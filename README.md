# Rummage

One macro per item type that always uses the best item in your bags. Type `/rum`, drag an icon onto an action slot, and that slot keeps pointing at the right item as your bags change.

Built for **World of Warcraft: Forever** (Interface 16001). It only uses standard bag, tooltip and macro APIs, so it should also work on other clients that have them.

## Categories

| Category | Macro | Picks |
| --- | --- | --- |
| `food` | SmartFood | Food by your stat priority, read from the Well Fed text |
| `drink` | SmartDrink | The drink (water, juice, conjured water) that restores the most mana |
| `flask` | SmartFlask | Flasks and elixirs by your stat priority |
| `healthpotion` | SmartHealthPotion | The potion that restores the most health |
| `manapotion` | SmartManaPotion | The potion that restores the most mana |
| `bandage` | SmartBandage | The bandage that heals the most, used on yourself |
| `quest` | SmartQuestItem | The usable quest item for the quest that matters most right now |

Every category skips items above your level. Percent-based potions are valued against your current maximum.

### Quest items

The quest log attaches a usable item to some quests (the one the objective tracker shows a button for). SmartQuestItem always points at the most relevant of those in your bags, in this order: the super-tracked quest, quests on the current map, tracked quests, everything else in the log, then bag items that start a quest. Items for quests you have already completed drop to the bottom unless the quest still needs the item to turn in. The macro follows quest log, tracking, super-tracking and zone changes.

### Food

Rummage reads the Well Fed text of every food item in your bags and ranks by the stats you care about.

- Food with your top-priority stat wins. Among those, the largest amount wins.
- If you carry nothing with a listed stat, food with any other stat comes next, then plain food by health restored.
- Drinks that only restore mana are ignored; they have their own `drink` macro.

Pick your preferred buff in the `/rum` window, or set the whole order by command:

```
/rummage food haste crit mastery stamina
/rummage food any
```

Words accepted: `stamina sta stam spirit spi strength str agility agi intellect int haste crit critical mastery mast versatility vers hit expertise exp ap attackpower sp spellpower armor mp5 health mana`.

### Flasks and elixirs

Same priority mechanism as food, with its own list (`/rummage flask str agi int`). Battle and guardian elixirs are not told apart yet: the macro uses the single best match, so keep the other elixir type on a separate slot if you use both.

### Drinks

SmartDrink uses whatever you sit down and drink that restores the most mana: water, juice, conjured water, and food that restores mana as well. Mana potions are not drinks and stay on SmartManaPotion. No priority to set.

### Potions and bandages

No priority to set; the strongest item wins. Healthstones are left alone because they do not share the potion cooldown. The bandage macro targets you (`/use [@player]`).

## The window

`/rum` opens the Rummage window. Each row is one category:

- the icon of the item it currently uses (question mark if none). Drag it, or click it, and drop on any action slot, including Backhand paddles. Hover it to see every candidate in ranked order.
- a checkbox to stop or resume updating that macro.
- for food and flasks, two dropdowns: **Preferred buff** (the stat you want, for example Haste) and **If none, then** (the fallback when you carry no food with it). "Any (strongest)" ranks purely by amount. The full order is shown next to them; **Default** restores the built-in list.

Press Escape or **Close** to hide it.

## Settings page

**Settings > AddOns > Rummage** (or `/rum config`) has the same controls: the current item's icon to drag onto a slot, the on/off checkbox per category, the preferred buff and fallback as click-to-cycle buttons (left-click next, right-click previous), a Default button, and a debug toggle. It uses cycle buttons instead of dropdowns on purpose; see the gamepad note below.

## Commands

Everything in the window also has a command, mostly for macros and keybinds:

```
/rummage                        open or close the window
/rummage status                 print what each macro currently uses
/rummage list food              every food in bags, ranked, with parsed stats
/rummage <category> <stats...>  set that category's stat priority (food, flask)
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
