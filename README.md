# TrinketTracker

An extended fork of [Trinket Cooldown Tracker](https://www.curseforge.com/wow/addons/trinket-cooldown-tracker) by Naíxx.

The original addon shows two movable cooldown icons for your equipped trinkets. This fork keeps that and adds a few quality-of-life features.

## What's new in this fork

- **Consumable tracking** — extra movable buttons for Potion of Recklessness, Health Potion, Light's Potential Potion and Healthstone (only shown when you have one in your bags). Each can be toggled independently, and each shows how many uses you have left — charges for items that have them, stack count otherwise. Buttons that have variants cover all of them: the Healthstone button also handles Demonic Healthstone, so it keeps working (and reads its charges) for warlocks specced into Pact of Gluttony, and the Light's Potential button handles both quality versions of the potion.
- **Ready alert** — plays the raid-warning sound the moment a shown trinket comes off cooldown. Toggle in the config menu.
- **More responsive updates** — listens for `BAG_UPDATE` and `SPELL_UPDATE_COOLDOWN` in addition to the original's events, so icons refresh promptly when you swap items or use consumables.

## Usage

`/trinket` opens the config window:

- Lock / unlock positions (drag icons when unlocked)
- Scale slider
- Per-button visibility toggles for both trinket slots and the tracked consumables
- "Play Sound When Trinket Ready" toggle

Settings are saved per character.

## Credits

- Original addon: **Naíxx** — <https://www.curseforge.com/wow/addons/trinket-cooldown-tracker>
- Fork extensions: **Christian Isaman**
