# Game Design Document
# Re-Leaf: Idle Fantasy

> "Healing the world, one pixel at a time."

**Version:** Implementation sync - 2026-07-07
**Status:** Current Godot implementation
**Engine:** Godot 4.7 project configuration
**Main scene:** `res://src/main_menu.tscn`
**Design note:** This document describes what is currently realized in the game. It intentionally syncs the GDD to the existing implementation, not the implementation to the older GDD.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Implemented Feature Set](#2-implemented-feature-set)
3. [Core Loop](#3-core-loop)
4. [Resources and Economy](#4-resources-and-economy)
5. [Grid and Tile Interaction](#5-grid-and-tile-interaction)
6. [Flora](#6-flora)
7. [Progression: Skill Tree](#7-progression-skill-tree)
8. [Mythical Creatures and Bestiary](#8-mythical-creatures-and-bestiary)
9. [Heart Tree and Ending](#9-heart-tree-and-ending)
10. [Opening Tutorial](#10-opening-tutorial)
11. [UI and Presentation](#11-ui-and-presentation)
12. [Art and Assets](#12-art-and-assets)
13. [Audio](#13-audio)
14. [Scope Summary](#14-scope-summary)
15. [Not Implemented From Earlier Design](#15-not-implemented-from-earlier-design)
16. [Glossary](#16-glossary)

---

## 1. Overview

**Re-Leaf: Idle Fantasy** is a finite idle/incremental forest restoration game. The player tends a barren isometric garden, earns **Dewdrops** from magical flora, spends those Dewdrops to clear land, plants stronger flora tiers, unlocks skill upgrades, discovers gentle mythical creatures, and eventually restores the **Heart Tree**.

**Genre:** Idle / Incremental
**Perspective:** Isometric 2D, pixel art
**Tone:** Calm, restorative, gentle fantasy
**Runtime:** Not currently enforced or measured by the implementation
**Session structure:** Main menu, new game, continue from save, and exit

**One-line pitch:** Plant flora, earn Dewdrops, heal an isometric wasteland tile by tile, discover mythical creatures, and restore the Heart Tree.

---

## 2. Implemented Feature Set

The current build includes:

- Main menu with **New Game**, **Continue**, and **Exit**.
- A 16x16 isometric grid with 256 tiles.
- One starter clear tile at grid position `(8, 8)`.
- One currency: **Dewdrops**.
- Passive Dewdrop income from planted flora.
- Per-flora Tap Bars that fill when the player taps a planted flora.
- Tile clearing, seed planting, right-click plant selling, and replanting through sell-then-plant.
- Five flora tiers.
- Five production skill branches, four purchases per tier.
- Four global skill types: tap harvest, tap speed, clear discount, and offline cap.
- Seed unlocks when a tier's four production upgrades are purchased.
- Six mythical creatures with arrival overlays and bestiary entries.
- Heart Tree luminance tied to cleared tile count.
- Ending screen when the Kirin has arrived and all barren tiles have been cleared.
- Save/load, autosave, save-on-quit, and capped offline passive progress.
- Procedural pixel art generated in code for tiles, flora, creatures, icons, Luma, the Heart Tree, and the menu backdrop.

---

## 3. Core Loop

The implemented loop is:

```text
Plant flora
  -> flora passively produce Dewdrops
  -> optionally tap flora to fill Tap Bars and harvest bonus Dewdrops
  -> spend Dewdrops to clear barren tiles
  -> spend Dewdrops to plant unlocked flora tiers
  -> spend Dewdrops on Skill Tree upgrades
  -> completing a tier branch unlocks the next tier seed
  -> planting a new tier can summon a creature
  -> clearing all land after Kirin arrives triggers the ending
```

The loop is intentionally simple. Tile position does not affect production, and there are no adjacency bonuses or spatial combo systems.

---

## 4. Resources and Economy

### 4.1 Currency

There is exactly one currency: **Dewdrops**.

- **Sources:** Passive flora production, Tap Bar harvests, and selling planted flora.
- **Sinks:** Clearing barren tiles, planting seeds, and buying Skill Tree upgrades.
- **Starting amount:** 10 Dewdrops.
- **Display:** The HUD uses compact human-readable values: decimals below 1,000, `K` for thousands, and `M` for millions.

### 4.2 Passive Production

Every planted flora produces Dewdrops per second. Production is calculated from the flora tier's base production and that tier's production skill level.

```text
flora production = tier base production * (1 + 0.25 * tier skill level)
```

### 4.3 Tap Bar

Each flora tracks its own tap count.

- Base Tap Bar length: 15 taps.
- Tap Speed upgrades reduce the required taps by 3 per level.
- Minimum Tap Bar length: 5 taps.
- When the bar fills, the player receives a bonus Dewdrop harvest.

```text
tap harvest = tier base production * 10 * (1 + 0.5 * tap harvest level)
```

Tap Bars only fill from direct tapping. They do not fill from time passing or offline progress.

### 4.4 Offline Progress

The game saves to `user://re_leaf_save.json`.

- Autosave interval: 30 seconds.
- The game also saves on quit notification.
- On load, passive income is calculated for time away.
- Base offline cap: 30 minutes.
- Offline Cap upgrades add 30 minutes per level.
- Offline progress uses passive production only.

### 4.5 Clearing Cost

Clearing cost is polynomial and uses the current cleared tile count.

```text
clear cost = 3 + (2 * cleared_count) + (1.2 * cleared_count * cleared_count)
```

Clear Discount upgrades reduce this cost by 15% per level.

---

## 5. Grid and Tile Interaction

### 5.1 Layout

- The garden is a **16x16 isometric grid** for a total of 256 tiles.
- The project viewport is configured at 1280x720.
- The grid is rendered in one scene without camera movement.
- The starter tile is `(8, 8)`.
- All tiles start barren except the starter tile, which starts clear.

### 5.2 Tile States

Each tile is in one of three states:

```text
Barren -> Clear -> Planted
```

- **Barren:** Dead land. Can be cleared if the player has at least one planted flora and enough Dewdrops.
- **Clear:** Healed empty land. Can open the seed radial menu.
- **Planted:** Holds one flora. Can be tapped for Tap Bar progress.

### 5.3 Clearing

Clicking a barren tile attempts to clear it. The current implementation does **not** require adjacency to existing clear or planted tiles. Any barren tile can be cleared if the player can afford the cost and has at least one flora planted.

Hovering a barren tile shows the current clear price as an inline Dewdrop indicator next to the tile. The price uses the same polynomial clearing formula and Clear Discount upgrades as the actual clearing action, and changes color based on whether the tile can currently be cleared.

Clearing a tile:

- Spends Dewdrops.
- Changes the tile state to clear.
- Increments cleared tile count.
- Updates Heart Tree luminance.
- Plays a small visual pop animation on the tile.

### 5.4 Planting

Clicking a clear tile opens a radial seed menu at that tile. The menu shows currently unlocked flora tiers. Choosing an affordable seed plants that flora on the tile.

### 5.5 Selling and Replanting

Right-clicking a planted tile sells the flora for 50% of that flora's seed cost. The tile returns to clear state. This is the current replanting path: sell the old flora, then plant a new seed.

---

## 6. Flora

A **Flora** is a magical plant placed on a clear tile. It passively produces Dewdrops and has a Tap Bar.

| Tier | Flora | Production / sec | Seed Cost | Identity |
|------|-------|------------------|-----------|----------|
| 1 | Mossling | 0.15 | 5 | Small moss with tiny sprouts |
| 2 | Glowcap | 0.6 | 30 | Luminous mushroom |
| 3 | Bamboo | 2.0 | 150 | Bamboo stalk cluster |
| 4 | Willowweep | 7.0 | 600 | Weeping willow |
| 5 | Heartbloom | 22.0 | 2500 | Heart-shaped restoration flower |

Higher tiers strictly outproduce lower tiers. A flora's tier is fixed after planting. There is no per-flora leveling system.

The earlier cosmetic skin system is not implemented.

---

## 7. Progression: Skill Tree

The Skill Tree is a full-screen overlay opened from the HUD. All upgrades cost Dewdrops.

### 7.1 Production Branches

There are five production branches, one per flora tier.

- Each branch has four purchases.
- Each purchase adds +25% production for that tier.
- Purchases are sequential: the next node in the row becomes buyable after the previous one is purchased.
- Completing all four purchases in a tier branch unlocks the next tier's seed, up to Tier 5.

| Branch | Cost Per Node | Max Purchases | Effect |
|--------|---------------|---------------|--------|
| Tier 1 | 40 | 4 | +25% Tier 1 production per purchase |
| Tier 2 | 200 | 4 | +25% Tier 2 production per purchase |
| Tier 3 | 800 | 4 | +25% Tier 3 production per purchase |
| Tier 4 | 3000 | 4 | +25% Tier 4 production per purchase |
| Tier 5 | 12000 | 4 | +25% Tier 5 production per purchase |

### 7.2 Branch Availability

Tier 1's branch is always available. Higher tier branches are gated by the matching tier creature arriving:

- Tier 2 branch: Fawn arrival.
- Tier 3 branch: Mythical Panda arrival.
- Tier 4 branch: White Stag arrival.
- Tier 5 branch: Kirin arrival.

This means seed unlock and branch availability are separate:

- Buying four Tier 1 production upgrades unlocks Tier 2 seeds.
- Planting Tier 2 flora can summon the Fawn.
- Fawn arrival makes the Tier 2 production branch available.

### 7.3 Global Skills

Global skills are implemented as always-visible, always-available upgrade rows. They are **not** creature-gated in the current build.

| Skill | Max Level | Cost Per Level | Effect |
|-------|-----------|----------------|--------|
| Tap Harvest+ | 3 | 150 | +50% tap harvest per level |
| Tap Speed+ | 2 | 200 | -3 taps needed per level |
| Clear Discount | 2 | 200 | -15% clear cost per level |
| Offline Cap+ | 2 | 300 | +30 minutes offline cap per level |

Total implemented upgrade purchases: 20 production purchases + 9 global purchases = 29.

---

## 8. Mythical Creatures and Bestiary

Mythical Creatures are story and progression milestones. Each discovered creature appears in the Bestiary and can also gate a production branch.

### 8.1 Creature Roster and Triggers

| Creature | Trigger Type | Trigger Value | Notes |
|----------|--------------|---------------|-------|
| Owl-Spirit | Lifetime Dewdrops | 25 | Arrives once total earned Dewdrops reaches 25. |
| Jade Rabbit | Planted tier | 1 | Arrives after the player has planted any Tier 1 flora. |
| Fawn | Planted tier | 2 | Arrives after the player has planted any Tier 2 flora. |
| Mythical Panda | Planted tier | 3 | Arrives after the player has planted any Tier 3 flora. |
| White Stag | Planted tier | 4 | Arrives after the player has planted any Tier 4 flora. |
| Kirin | Planted tier | 5 | Arrives after the player has planted any Tier 5 flora. Required for ending. |

The implementation checks creature triggers in bestiary order and emits at most one creature arrival per check. Because the Jade Rabbit is triggered by planting the first Mossling while the player starts below 25 lifetime Dewdrops, the Jade Rabbit can arrive before the Owl-Spirit in normal play.

### 8.2 Arrival Overlay

When a creature arrives, a full-screen overlay appears:

- Darkened background.
- Large creature sprite.
- Creature name.
- "has arrived" subtitle.
- Lore text.
- Floating particles.
- "tap to continue" dismissal after the animation finishes.

### 8.3 Bestiary

The Bestiary is a full-screen overlay opened from the HUD. It shows all six creatures in fixed display order.

- Discovered creatures show sprite, name, arrival status, and lore.
- Undiscovered creatures show a dark silhouette and a hint.
- The progress label shows discovered count out of six.

---

## 9. Heart Tree and Ending

The Heart Tree is the restoration goal and visual progress marker.

### 9.1 Heart Tree Luminance

Heart Tree luminance is calculated from cleared tiles:

```text
luminance = cleared_count / 256
```

The Heart Tree uses two procedural sprites: a base sprite and a glow sprite. As luminance rises, the base sprite becomes more visible and the glow alpha increases.

In the current layout, the Heart Tree is placed near the upper area of the isometric grid to avoid blocking plants, rather than occupying the exact center tile.

### 9.2 Ending Trigger

The ending triggers when both conditions are true:

- Kirin has arrived.
- No tile remains barren.

When triggered, the game sets `is_ended` and displays a simple ending screen:

```text
The forest is whole again.
Thank you, Luma.
```

---

## 10. Opening Tutorial

The tutorial runs when `tutorial_done` is false.

Implemented tutorial sequence:

1. Input is locked.
2. Luma appears near the starter tile.
3. A speech bubble says: "I weep for this barren land... Let my tears heal one tile."
4. After a short pause, Luma fades and exits.
5. Input unlocks.
6. A speech bubble asks the player to tap the green tile to plant the first Mossling.
7. The player plants a Mossling from the seed menu.
8. The Jade Rabbit may arrive from the Tier 1 plant trigger; the tutorial waits for this arrival overlay to finish.
9. The tutorial asks the player to tap the Mossling to fill its Tap Bar.
10. After the first tap, the tutorial explains passive production.
11. The final message says: "The forest awaits healing. Good luck, little spirit."
12. `tutorial_done` is set to true.

The current tutorial uses visible text bubbles. It does not yet teach the Skill Tree or tile clearing through a dedicated guided step.

---

## 11. UI and Presentation

### 11.1 Main Menu

The game starts on a custom procedural pixel-art main menu with:

- **New Game:** Deletes the existing save, resets runtime state, and enters the game.
- **Continue:** Enters the game if a save file exists; disabled when no save file exists.
- **Exit:** Quits the application.

### 11.2 HUD

The in-game HUD is a top bar. It contains:

- Dewdrop icon.
- Dewdrop counter.
- Passive income per second.
- Skill Tree icon button.
- Bestiary icon button.
- MENU button that returns to the main menu.

There is no implemented settings screen.

### 11.3 Tile Menu

Clicking a clear tile opens a circular radial seed menu at that tile. It shows available unlocked tiers as flora sprites. Unaffordable seeds are greyed out. Clicking outside the menu closes it.

### 11.4 Overlays

Implemented overlays:

- Skill Tree.
- Bestiary.
- Creature arrival.
- Ending screen.

Skill Tree and Bestiary cover the game with dark full-screen backgrounds and scrollable content.

---

## 12. Art and Assets

The game currently uses procedural pixel art generated in code by `SpriteGen`.

Generated sprites include:

- Barren and clear tiles.
- Five flora sprites.
- Six creature sprites.
- Heart Tree and Heart Tree glow.
- Dewdrop icon.
- Luma.
- Skill, bestiary, and settings icons.
- Particle texture.
- Main menu backdrop and pixel text.

The implementation does not depend on imported art assets. Visual feedback includes hover highlights, tile clear pop animation, flora bobbing, tap flash, harvest bounce, HUD label flash, and arrival overlay particles.

---

## 13. Audio

Audio is not implemented in the current project.

There are no realized music layers, ambient soundscape layers, SFX players, audio bus setup, settings controls, or audio assets in the current repository.

---

## 14. Scope Summary

| Dimension | Current Implementation |
|-----------|------------------------|
| Grid | 16x16 isometric grid, 256 tiles |
| Starter tile | `(8, 8)`, starts clear |
| Currency | Dewdrops |
| Flora tiers | 5 |
| Flora | Mossling, Glowcap, Bamboo, Willowweep, Heartbloom |
| Creatures | 6 |
| Production upgrades | 20 purchases |
| Global upgrades | 9 purchases |
| Total skill purchases | 29 |
| Save system | JSON save in `user://re_leaf_save.json` |
| Offline progress | Implemented, capped |
| Main menu | New Game, Continue, Exit |
| Settings | Not implemented |
| Audio | Not implemented |
| Ending | Kirin arrived + all tiles cleared |

---

## 15. Not Implemented From Earlier Design

These older design items are not realized in the current build and should not be treated as current requirements:

- 6x6 grid.
- 90-minute measured pacing.
- Heart Tree occupying the exact center of the grid.
- Strict creature arrival order where Owl-Spirit always arrives first.
- Creature-gated global skills.
- Free starter seed.
- Textless or nearly textless tutorial.
- Guided tutorial steps for Skill Tree and clearing.
- Cosmetic flora skin system.
- Settings menu.
- Reactive ambient soundscape.
- Tap or harvest sound effects.
- Imported art asset pipeline.
- External `CONTEXT.md` or `docs/adr/0001-polynomial-economy.md` files.

---

## 16. Glossary

- **Dewdrops:** The single currency.
- **Passive Production:** Dewdrops generated by planted flora over time.
- **Tap Bar:** Per-flora tap progress that yields a bonus harvest when full.
- **Barren Tile:** Dead tile that can be cleared with Dewdrops.
- **Clear Tile:** Empty healed tile that can receive a seed.
- **Planted Tile:** Tile containing a flora.
- **Flora:** A magical plant that produces Dewdrops.
- **Tier:** Flora strength category from 1 to 5.
- **Seed:** Purchasable planting option in the radial tile menu.
- **Skill Tree:** Upgrade overlay for production and global upgrades.
- **Production Branch:** Four sequential purchases that improve one flora tier.
- **Global Skill:** Upgrade affecting tapping, clearing, or offline progress.
- **Seed Unlock:** Completing four production purchases in a tier unlocks the next tier seed.
- **Mythical Creature:** A discovered creature tied to Dewdrop or planted-tier triggers.
- **Bestiary:** Creature collection and story-progress overlay.
- **Heart Tree:** Visual restoration goal whose luminance tracks cleared tiles.
- **Luma:** The small guardian spirit used in the tutorial and menu presentation.
- **Ending:** The game-over state reached when Kirin has arrived and all tiles are healed.
