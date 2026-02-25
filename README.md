# ClarityRPG ⚔️

> On-chain RPG character stats on the Stacks blockchain — create your hero, level up, equip gear, and battle — all verifiable on-chain forever.

ClarityRPG is an open-source, fully on-chain RPG character system built in Clarity on Stacks. Every hero, stat point, level, piece of equipment, and battle result lives permanently on the blockchain. No centralized game server can wipe your progress, nerf your character, or shut down your account. Your hero is yours — forever.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Character Classes](#character-classes)
- [Stats System](#stats-system)
- [Leveling System](#leveling-system)
- [Equipment System](#equipment-system)
- [Battle System](#battle-system)
- [Contract Reference](#contract-reference)
- [Getting Started](#getting-started)
- [Creating Your Hero](#creating-your-hero)
- [Leveling Up](#leveling-up)
- [Equipping Gear](#equipping-gear)
- [Battling](#battling)
- [Guilds](#guilds)
- [Leaderboard](#leaderboard)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Traditional RPGs store your character on a company's server. When the game shuts down, your hero disappears. When a patch nerfs your class, you have no recourse. When a developer bans your account, years of progress vanish overnight.

ClarityRPG puts your character on-chain. Every stat, every level, every item, every battle result is a permanent on-chain record. The rules of the game are written in Clarity — open source, auditable, and immutable. No developer can secretly change the damage formula, inflate item drop rates, or delete your character.

Your hero is an on-chain identity. Build them, trade their gear as NFTs, battle other players, and leave a legacy that outlasts any game server.

---

## Features

- ⚔️ **On-chain character creation** — mint your hero with a chosen class and name
- 📈 **Stat system** — Strength, Dexterity, Intelligence, Vitality, Luck — all on-chain
- 🏆 **Leveling system** — earn XP through battles and quests, level up to allocate stat points
- 🎒 **Equipment slots** — Weapon, Armor, Helmet, Boots, Accessory — each modifies base stats
- ⚔️ **PvP battle system** — challenge other heroes, results determined by on-chain stats and randomness
- 🛡️ **Guild system** — form or join guilds, pool resources, compete in guild rankings
- 🎲 **On-chain randomness** — battle outcomes use block hash seeded randomness
- 🏅 **Achievement system** — unlock permanent on-chain badges for milestones
- 🪙 **SIP-010 token rewards** — earn ClarityRPG Gold (CGOLD) tokens for victories
- 🧪 **Full Clarinet test suite**

---

## How It Works

```
Player                          ClarityRPG Contract
  │                                     │
  │── create-hero (name, class) ───────►│
  │◄─ hero-id returned ─────────────────│
  │                                     │
  │── battle (opponent hero-id) ────────►│
  │   [contract uses block hash         │
  │    + stats to resolve outcome]      │
  │◄─ win / loss + XP reward ───────────│
  │                                     │
  │── level-up ─────────────────────────►│
  │── allocate-stat-points ─────────────►│
  │                                     │
  │── equip-item (item-id, slot) ───────►│
  │◄─ stats updated with item bonus ────│
  │                                     │
  │── get-hero (hero-id) ───────────────►│
  │◄─ full hero sheet returned ──────────│
```

---

## Architecture

ClarityRPG uses two contracts — the core RPG contract for character logic, and a SIP-010 token contract for the in-game CGOLD reward currency.

```
┌───────────────────────────────────────────────────────────────┐
│                      clarityrpg.clar                          │
│                                                               │
│  ┌──────────────────────┐   ┌──────────────────────────────┐ │
│  │      Hero Map        │   │        Stats Map             │ │
│  │  hero-id → {         │   │  hero-id → {                 │ │
│  │    name,             │   │    strength,                 │ │
│  │    class,            │   │    dexterity,                │ │
│  │    owner,            │   │    intelligence,             │ │
│  │    level,            │   │    vitality,                 │ │
│  │    xp,               │   │    luck,                     │ │
│  │    xp-to-next,       │   │    unallocated-points        │ │
│  │    created-at,       │   │  }                           │ │
│  │    battle-count,     │   └──────────────────────────────┘ │
│  │    win-count,        │                                     │
│  │    status            │   ┌──────────────────────────────┐ │
│  │  }                   │   │      Equipment Map           │ │
│  └──────────────────────┘   │  hero-id → {                 │ │
│                             │    weapon,                   │ │
│  ┌──────────────────────┐   │    armor,                    │ │
│  │     Item Map         │   │    helmet,                   │ │
│  │  item-id → {         │   │    boots,                    │ │
│  │    name,             │   │    accessory                 │ │
│  │    slot,             │   │  }                           │ │
│  │    stat-bonus-type,  │   └──────────────────────────────┘ │
│  │    stat-bonus-value, │                                     │
│  │    rarity,           │   ┌──────────────────────────────┐ │
│  │    owner             │   │      Battle Log Map          │ │
│  │  }                   │   │  battle-id → {               │ │
│  └──────────────────────┘   │    hero1, hero2,             │ │
│                             │    winner, loser,            │ │
│  ┌──────────────────────┐   │    xp-awarded,               │ │
│  │     Guild Map        │   │    block-height              │ │
│  │  guild-id → {        │   │  }                           │ │
│  │    name, leader,     │   └──────────────────────────────┘ │
│  │    members,          │                                     │
│  │    guild-xp          │                                     │
│  │  }                   │                                     │
│  └──────────────────────┘                                     │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│                    cgold-token.clar                           │
│              SIP-010 in-game reward currency                  │
└───────────────────────────────────────────────────────────────┘
```

---

## Character Classes

Choose your class at creation. Classes determine your base stat distribution and passive bonuses. Class cannot be changed after creation.

| Class | STR | DEX | INT | VIT | LCK | Passive Bonus |
|---|---|---|---|---|---|---|
| ⚔️ **Warrior** | 8 | 5 | 3 | 7 | 2 | +20% physical damage |
| 🏹 **Ranger** | 4 | 9 | 4 | 5 | 3 | +15% critical hit chance |
| 🔮 **Mage** | 2 | 4 | 10 | 4 | 5 | +25% spell damage |
| 🗡️ **Rogue** | 5 | 8 | 3 | 4 | 5 | +30% first strike chance |
| 🛡️ **Paladin** | 6 | 3 | 5 | 9 | 2 | +25% damage reduction |
| 🌿 **Druid** | 3 | 5 | 8 | 6 | 3 | +20% healing after battle |

Each class starts at **Level 1** with **25 base stat points** distributed as above, plus **3 unallocated points** to spend immediately.

---

## Stats System

Every hero has five core stats. Stats affect battle outcomes, XP gain, and item eligibility.

| Stat | Abbreviation | Effect |
|---|---|---|
| **Strength** | STR | Physical attack power, carry weight for equipment |
| **Dexterity** | DEX | Attack speed, dodge chance, critical hit rate |
| **Intelligence** | INT | Spell power, XP gain bonus, magic resistance |
| **Vitality** | VIT | Max HP, damage reduction, survival in long battles |
| **Luck** | LCK | Critical multiplier, item drop rate, rare event chance |

### Derived Stats

Calculated automatically from base stats plus equipment bonuses:

| Derived Stat | Formula |
|---|---|
| Max HP | `(VIT × 10) + (STR × 2) + level × 5` |
| Attack Power | `(STR × 3) + (DEX × 1) + weapon-bonus` |
| Magic Power | `(INT × 4) + accessory-bonus` |
| Defense | `(VIT × 2) + armor-bonus + helmet-bonus` |
| Speed | `(DEX × 2) + boots-bonus` |
| Crit Chance | `(LCK × 0.5) + (DEX × 0.3)` % |

---

## Leveling System

Heroes gain XP by winning battles, completing quests, and logging achievements.

### XP Requirements

| Level | XP Required | Stat Points Awarded |
|---|---|---|
| 1 → 2 | 100 XP | 3 points |
| 2 → 3 | 250 XP | 3 points |
| 3 → 4 | 500 XP | 4 points |
| 4 → 5 | 900 XP | 4 points |
| 5 → 10 | +500 per level | 5 points |
| 10 → 20 | +1000 per level | 5 points |
| 20 → 50 | +2500 per level | 6 points |
| 50+ | +5000 per level | 7 points |

### XP Sources

| Source | XP Awarded |
|---|---|
| Win a PvP battle | 50 + (opponent level × 5) XP |
| Lose a PvP battle | 10 XP (participation reward) |
| Draw a battle | 25 XP |
| Guild quest completion | 75–500 XP depending on difficulty |
| Achievement unlocked | 25–200 XP depending on achievement |

---

## Equipment System

Heroes have five equipment slots. Each item provides a stat bonus to the equipped hero.

### Equipment Slots

| Slot | Stat Affected | Example Items |
|---|---|---|
| ⚔️ Weapon | Attack Power, STR or DEX | Iron Sword, Frost Staff, Shadow Dagger |
| 🛡️ Armor | Defense, VIT | Chainmail, Mage Robes, Leather Vest |
| 🪖 Helmet | Defense, INT | Iron Helm, Wizard Hat, Hood of Shadows |
| 👟 Boots | Speed, DEX | Swiftboots, Ironclad Greaves, Shadow Steps |
| 💍 Accessory | LCK, Magic Power | Lucky Charm, Mana Crystal, Ring of Power |

### Item Rarity

| Rarity | Stat Bonus Range | Drop Chance |
|---|---|---|
| Common | +1 to +3 | 60% |
| Uncommon | +4 to +7 | 25% |
| Rare | +8 to +12 | 10% |
| Epic | +13 to +20 | 4% |
| Legendary | +21 to +35 | 1% |

Items are stored as on-chain records owned by a principal. They can be traded, gifted, or listed on NFT marketplaces as SIP-009 tokens.

---

## Battle System

ClarityRPG uses a turn-based battle resolution system computed entirely on-chain. No off-chain randomness oracle is needed — battles use a combination of hero stats and block hash as a deterministic seed.

### Battle Resolution

```
1. Calculate effective stats for both heroes (base + equipment)
2. Determine first strike using Speed + LCK check against block hash
3. First striker deals damage: Attack Power minus opponent Defense
4. Check for critical hit using Crit Chance
5. Second striker responds
6. Repeat until one hero reaches 0 HP
7. Winner receives XP + CGOLD reward
8. Loser receives consolation XP
9. Battle logged permanently on-chain
```

### Battle Formula

```
damage = max(1, attacker-attack-power - defender-defense)
crit   = (block-hash-derived-roll < crit-chance) → damage × 2
```

Heroes recover full HP between battles — HP is not persistent state, it is derived fresh each battle from current stats and equipment.

### Cooldown

Each hero has a **battle cooldown of 10 blocks (~100 minutes)**. This prevents spam attacks and gives opponents a fair window to respond to challenges.

---

## Contract Reference

### Public Functions

#### `create-hero`
Mint a new hero. One hero per address by default (configurable).

```clarity
(define-public (create-hero
  (name (string-utf8 32))
  (class (string-ascii 16)))
```

| Parameter | Description |
|---|---|
| `name` | Your hero's name (max 32 characters) |
| `class` | One of: `"warrior"`, `"ranger"`, `"mage"`, `"rogue"`, `"paladin"`, `"druid"` |

---

#### `allocate-stat-points`
Spend unallocated stat points earned from leveling up.

```clarity
(define-public (allocate-stat-points
  (hero-id uint)
  (strength uint)
  (dexterity uint)
  (intelligence uint)
  (vitality uint)
  (luck uint))
```

The sum of all allocated values must equal the hero's current unallocated points.

---

#### `battle`
Challenge another hero to a PvP battle.

```clarity
(define-public (battle
  (attacker-id uint)
  (defender-id uint))
```

---

#### `equip-item`
Equip an owned item to a hero slot.

```clarity
(define-public (equip-item
  (hero-id uint)
  (item-id uint)
  (slot (string-ascii 16)))
```

---

#### `unequip-item`
Remove an item from a hero slot and return it to inventory.

```clarity
(define-public (unequip-item
  (hero-id uint)
  (slot (string-ascii 16)))
```

---

#### `level-up`
Level up a hero once they have reached the required XP threshold.

```clarity
(define-public (level-up (hero-id uint)))
```

---

#### `create-guild`
Create a new guild. Creator becomes the guild leader.

```clarity
(define-public (create-guild
  (name (string-utf8 32))
  (motto (string-utf8 128)))
```

---

#### `join-guild`
Join an existing guild by guild ID.

```clarity
(define-public (join-guild
  (hero-id uint)
  (guild-id uint))
```

---

### Read-Only Functions

```clarity
;; Get full hero sheet
(define-read-only (get-hero (hero-id uint)))

;; Get a hero's current stats (base + equipment bonuses)
(define-read-only (get-effective-stats (hero-id uint)))

;; Get a hero's equipped items
(define-read-only (get-equipment (hero-id uint)))

;; Get item details
(define-read-only (get-item (item-id uint)))

;; Get battle log entry
(define-read-only (get-battle (battle-id uint)))

;; Get hero win/loss record
(define-read-only (get-battle-record (hero-id uint)))

;; Get guild details and member list
(define-read-only (get-guild (guild-id uint)))

;; Get leaderboard entry for a hero
(define-read-only (get-leaderboard-entry (hero-id uint)))

;; Get total hero count
(define-read-only (get-hero-count))

;; Check if a hero is on battle cooldown
(define-read-only (is-on-cooldown (hero-id uint)))

;; Get hero's unallocated stat points
(define-read-only (get-unallocated-points (hero-id uint)))
```

---

### Error Codes

| Code | Constant | Description |
|---|---|---|
| `u500` | `err-hero-not-found` | Hero ID does not exist |
| `u501` | `err-not-hero-owner` | Caller does not own this hero |
| `u502` | `err-invalid-class` | Class string is not valid |
| `u503` | `err-invalid-slot` | Equipment slot string is not valid |
| `u504` | `err-item-not-found` | Item ID does not exist |
| `u505` | `err-not-item-owner` | Caller does not own this item |
| `u506` | `err-slot-occupied` | Equipment slot already has an item |
| `u507` | `err-slot-empty` | No item in this slot to unequip |
| `u508` | `err-on-cooldown` | Hero is on battle cooldown |
| `u509` | `err-self-battle` | Cannot battle your own hero |
| `u510` | `err-insufficient-xp` | Not enough XP to level up |
| `u511` | `err-insufficient-stat-points` | Not enough unallocated points |
| `u512` | `err-stat-point-mismatch` | Allocated points do not match available |
| `u513` | `err-hero-limit-reached` | Address already has maximum heroes |
| `u514` | `err-guild-not-found` | Guild ID does not exist |
| `u515` | `err-already-in-guild` | Hero is already a member of a guild |
| `u516` | `err-name-too-long` | Name exceeds maximum length |
| `u517` | `err-item-class-mismatch` | Item cannot be equipped by this class |

---

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) — Clarity development toolchain
- [Hiro Wallet](https://wallet.hiro.so/) — for testnet/mainnet play
- Node.js v18+ — for helper scripts
- STX for gas fees

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/clarityrpg.git
cd clarityrpg

# Install dependencies
npm install

# Verify contracts compile
clarinet check

# Run the test suite
clarinet test
```

---

## Creating Your Hero

```clarity
;; Create a Mage named "Zephyros"
(contract-call? .clarityrpg create-hero
  u"Zephyros"
  "mage")
```

Returns `(ok u1)` — your hero ID is `1`.

Your hero starts at **Level 1** with class base stats, 3 unallocated stat points, 0 XP, and empty equipment slots.

### Allocate your starting stat points

```clarity
;; Put all 3 starting points into Intelligence
(contract-call? .clarityrpg allocate-stat-points
  u1   ;; hero-id
  u0   ;; STR
  u0   ;; DEX
  u3   ;; INT — all 3 here
  u0   ;; VIT
  u0)  ;; LCK
```

---

## Leveling Up

Earn XP through battles and allocate new stat points as you level:

```clarity
;; Level up once XP threshold is reached
(contract-call? .clarityrpg level-up u1)

;; Spend the new stat points
(contract-call? .clarityrpg allocate-stat-points
  u1
  u0   ;; STR
  u0   ;; DEX
  u2   ;; INT
  u1   ;; VIT
  u0)  ;; LCK
```

---

## Equipping Gear

```clarity
;; Equip item #42 (a Frost Staff) to the weapon slot
(contract-call? .clarityrpg equip-item u1 u42 "weapon")

;; Unequip boots
(contract-call? .clarityrpg unequip-item u1 "boots")
```

Effective stats are recalculated instantly after equipping or unequipping.

---

## Battling

```clarity
;; Challenge hero #7 with your hero #1
(contract-call? .clarityrpg battle u1 u7)

;; Check the battle result
(contract-call? .clarityrpg get-battle u1)

;; Check your updated hero record
(contract-call? .clarityrpg get-hero u1)
```

The contract resolves the battle in the same transaction using on-chain stats and block hash randomness. Winner, loser, damage dealt, and XP awarded are all logged permanently on-chain.

---

## Guilds

```clarity
;; Create a guild
(contract-call? .clarityrpg create-guild
  u"The Satoshi Knights"
  u"We hodl. We battle. We conquer.")

;; Join a guild with your hero
(contract-call? .clarityrpg join-guild u1 u3)

;; Get guild info and members
(contract-call? .clarityrpg get-guild u3)
```

---

## Leaderboard

All hero records are permanently on-chain. Query any hero to see their full sheet:

```clarity
(contract-call? .clarityrpg get-leaderboard-entry u1)
```

| Field | Description |
|---|---|
| `hero-name` | Hero's name |
| `class` | Hero class |
| `level` | Current level |
| `wins` | Total PvP wins |
| `losses` | Total PvP losses |
| `win-rate` | Win percentage |
| `total-xp` | Lifetime XP earned |
| `guild` | Current guild name |

---

## Project Structure

```
clarityrpg/
├── contracts/
│   ├── clarityrpg.clar             # Main RPG character contract
│   └── cgold-token.clar            # SIP-010 CGOLD reward token
├── tests/
│   ├── clarityrpg_test.ts          # Full character system tests
│   └── cgold-token_test.ts         # Token tests
├── scripts/
│   ├── create-hero.ts              # CLI: create a new hero
│   ├── battle.ts                   # CLI: initiate a battle
│   ├── equip.ts                    # CLI: equip an item
│   ├── level-up.ts                 # CLI: level up a hero
│   ├── allocate-stats.ts           # CLI: allocate stat points
│   └── hero-sheet.ts               # CLI: print full hero sheet
├── deployments/
│   ├── devnet.yaml
│   ├── testnet.yaml
│   └── mainnet.yaml
├── settings/
│   └── Devnet.toml
├── Clarinet.toml
├── package.json
└── README.md
```

---

## Testing

```bash
# Run all tests
clarinet test

# Run with coverage report
clarinet test --coverage

# Open interactive Clarinet console
clarinet console
```

### Test coverage includes

- Hero creation with all 6 classes
- Base stat distribution correct per class
- Stat point allocation — valid and invalid inputs
- Over-allocation rejected
- Battle resolution — win, loss, draw outcomes
- Self-battle rejected
- Battle cooldown enforced and released after 10 blocks
- XP awarded correctly after each battle outcome
- Level up triggers at correct XP threshold
- New stat points awarded on level up
- Equip item to each of the 5 slots
- Unequip item from each slot
- Equip rejected if slot already occupied
- Equip rejected if item class mismatch
- Effective stats recalculate after equip and unequip
- Guild creation, joining, and member tracking
- Leaderboard updates after each battle
- All error codes triggered and verified

---

## Roadmap

- [x] Hero creation with 6 classes
- [x] Full 5-stat system with derived stats
- [x] XP and leveling with stat point allocation
- [x] Equipment system with 5 slots and rarity tiers
- [x] PvP battle system with on-chain randomness
- [x] Guild system
- [x] CGOLD SIP-010 reward token
- [ ] Web UI — hero dashboard and battle arena
- [ ] PvE quest system — solo dungeons with on-chain loot drops
- [ ] Item crafting — combine materials into gear
- [ ] Hero NFTs — export your hero as a SIP-009 NFT tradeable on marketplaces
- [ ] Equipment NFTs — trade gear between players on open marketplaces
- [ ] Seasonal tournaments — bracket competitions with STX prize pools
- [ ] Integration with WitStac — answer trivia to earn bonus XP
- [ ] Integration with RockPaperStacks — pre-battle wager mini-game
- [ ] Guild wars — guild vs guild battle events
- [ ] On-chain lore — heroes can write permanent lore entries to their character sheet
- [ ] Mobile-friendly hero viewer

---

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`clarinet test`)
5. Open a pull request with a clear description

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting.

---

## License

ClarityRPG is open source under the [MIT License](./LICENSE).

---

Built with ❤️ on [Stacks](https://stacks.co) — Bitcoin's smart contract layer.
