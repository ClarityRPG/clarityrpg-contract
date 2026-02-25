;; title: clarityrpg
;; version: 1.0.0
;; summary: On-chain RPG character system on Stacks - create heroes, level up, equip gear, and battle.
;; description: ClarityRPG stores every hero, stat, level, item, and battle result permanently on-chain.
;;              No centralized server. Your hero is forever yours.

;; ============================================================
;; TRAITS
;; ============================================================

;; ============================================================
;; ERROR CODES
;; ============================================================

(define-constant err-hero-not-found           (err u500))
(define-constant err-not-hero-owner           (err u501))
(define-constant err-invalid-class            (err u502))
(define-constant err-invalid-slot             (err u503))
(define-constant err-item-not-found           (err u504))
(define-constant err-not-item-owner           (err u505))
(define-constant err-slot-occupied            (err u506))
(define-constant err-slot-empty               (err u507))
(define-constant err-on-cooldown              (err u508))
(define-constant err-self-battle              (err u509))
(define-constant err-insufficient-xp          (err u510))
(define-constant err-insufficient-stat-points (err u511))
(define-constant err-stat-point-mismatch      (err u512))
(define-constant err-hero-limit-reached       (err u513))
(define-constant err-guild-not-found          (err u514))
(define-constant err-already-in-guild         (err u515))
(define-constant err-name-too-long            (err u516))
(define-constant err-item-class-mismatch      (err u517))

;; ============================================================
;; CONSTANTS
;; ============================================================

;; Battle cooldown in blocks (~100 minutes on Stacks)
(define-constant battle-cooldown-blocks u10)

;; Maximum heroes per address
(define-constant max-heroes-per-address u1)

;; XP awarded per battle outcome
(define-constant xp-win-base   u50)
(define-constant xp-loss       u10)
(define-constant xp-draw       u25)

;; Stat points awarded on level-up
(define-constant stat-points-per-level u3)

;; ============================================================
;; DATA VARS
;; ============================================================

;; Global ID counters
(define-data-var hero-nonce   uint u0)
(define-data-var item-nonce   uint u0)
(define-data-var battle-nonce uint u0)
(define-data-var guild-nonce  uint u0)

;; Utility counter (for testing - increment / decrement)
(define-data-var test-counter int 0)

;; ============================================================
;; DATA MAPS
;; ============================================================

;; --- Hero core data ---
(define-map heroes uint {
  name:          (string-utf8 32),
  class:         (string-ascii 16),
  owner:         principal,
  level:         uint,
  xp:            uint,
  xp-to-next:    uint,
  created-at:    uint,
  battle-count:  uint,
  win-count:     uint,
  loss-count:    uint,
  status:        (string-ascii 8),    ;; "active" | "retired"
  last-battle:   uint,                ;; block height of last battle
  guild-id:      (optional uint)
})

;; --- Hero stats ---
(define-map hero-stats uint {
  strength:          uint,
  dexterity:         uint,
  intelligence:      uint,
  vitality:          uint,
  luck:              uint,
  unallocated-points: uint
})

;; --- Equipment slots per hero ---
(define-map hero-equipment uint {
  weapon:    (optional uint),
  armor:     (optional uint),
  helmet:    (optional uint),
  boots:     (optional uint),
  accessory: (optional uint)
})

;; --- Items ---
(define-map items uint {
  name:            (string-utf8 32),
  slot:            (string-ascii 16),
  stat-bonus-type: (string-ascii 16),  ;; "strength" | "dexterity" | "intelligence" | "vitality" | "luck"
  stat-bonus-value: uint,
  rarity:          (string-ascii 16),  ;; "common" | "uncommon" | "rare" | "epic" | "legendary"
  owner:           principal
})

;; --- Battle log ---
(define-map battles uint {
  hero1:       uint,
  hero2:       uint,
  winner:      uint,
  loser:       uint,
  xp-awarded:  uint,
  block-height: uint
})

;; --- Guilds ---
(define-map guilds uint {
  name:     (string-utf8 32),
  motto:    (string-utf8 128),
  leader:   principal,
  guild-xp: uint,
  member-count: uint
})

;; --- Tracks how many heroes an address has created ---
(define-map address-hero-count principal uint)

;; ============================================================
;; PRIVATE HELPERS
;; ============================================================

;; Return base stats for a given class
(define-private (get-class-base-stats (class (string-ascii 16)))
  (if (is-eq class "warrior")
    (some { strength: u8, dexterity: u5, intelligence: u3, vitality: u7, luck: u2 })
  (if (is-eq class "ranger")
    (some { strength: u4, dexterity: u9, intelligence: u4, vitality: u5, luck: u3 })
  (if (is-eq class "mage")
    (some { strength: u2, dexterity: u4, intelligence: u10, vitality: u4, luck: u5 })
  (if (is-eq class "rogue")
    (some { strength: u5, dexterity: u8, intelligence: u3, vitality: u4, luck: u5 })
  (if (is-eq class "paladin")
    (some { strength: u6, dexterity: u3, intelligence: u5, vitality: u9, luck: u2 })
  (if (is-eq class "druid")
    (some { strength: u3, dexterity: u5, intelligence: u8, vitality: u6, luck: u3 })
  none))))))
)

;; Calculate XP required to reach (level + 1) from level
(define-private (xp-for-next-level (level uint))
  (if (<= level u0) u100
  (if (is-eq level u1) u100
  (if (is-eq level u2) u250
  (if (is-eq level u3) u500
  (if (is-eq level u4) u900
  (if (<= level u9)  (+ u900  (* (- level u4) u500))
  (if (<= level u19) (+ u3400 (* (- level u9) u1000))
  (if (<= level u49) (+ u13400 (* (- level u19) u2500))
  (+ u88400 (* (- level u49) u5000))))))))))
)

;; Stat points awarded when leveling up to a new level
(define-private (stat-points-for-level (new-level uint))
  (if (<= new-level u4)  u3
  (if (<= new-level u19) u5
  (if (<= new-level u49) u6
  u7)))
)

;; Validate that a slot string is one of the five valid slots
(define-private (is-valid-slot (slot (string-ascii 16)))
  (or
    (is-eq slot "weapon")
    (is-eq slot "armor")
    (is-eq slot "helmet")
    (is-eq slot "boots")
    (is-eq slot "accessory")
  )
)

;; Get the item currently in a given slot (returns optional uint)
(define-private (get-slot-item (equip { weapon: (optional uint), armor: (optional uint), helmet: (optional uint), boots: (optional uint), accessory: (optional uint) }) (slot (string-ascii 16)))
  (if (is-eq slot "weapon")    (get weapon equip)
  (if (is-eq slot "armor")     (get armor equip)
  (if (is-eq slot "helmet")    (get helmet equip)
  (if (is-eq slot "boots")     (get boots equip)
  (if (is-eq slot "accessory") (get accessory equip)
  none)))))
)

;; Set a specific slot in equipment record
(define-private (set-slot-item
    (equip { weapon: (optional uint), armor: (optional uint), helmet: (optional uint), boots: (optional uint), accessory: (optional uint) })
    (slot (string-ascii 16))
    (item-id (optional uint)))
  (if (is-eq slot "weapon")
    (merge equip { weapon: item-id })
  (if (is-eq slot "armor")
    (merge equip { armor: item-id })
  (if (is-eq slot "helmet")
    (merge equip { helmet: item-id })
  (if (is-eq slot "boots")
    (merge equip { boots: item-id })
  (merge equip { accessory: item-id })))))
)

;; Derive the total stat bonus from equipped items for a given stat type
(define-private (equipment-bonus-for-stat (hero-id uint) (stat-name (string-ascii 16)))
  (let (
    (equip (default-to { weapon: none, armor: none, helmet: none, boots: none, accessory: none }
            (map-get? hero-equipment hero-id)))
    (weapon-bonus    (get-item-bonus-if-match (get weapon equip) stat-name))
    (armor-bonus     (get-item-bonus-if-match (get armor equip) stat-name))
    (helmet-bonus    (get-item-bonus-if-match (get helmet equip) stat-name))
    (boots-bonus     (get-item-bonus-if-match (get boots equip) stat-name))
    (accessory-bonus (get-item-bonus-if-match (get accessory equip) stat-name))
  )
  (+ weapon-bonus armor-bonus helmet-bonus boots-bonus accessory-bonus))
)

;; If item-id-opt exists and the item's stat-bonus-type matches, return its bonus value
(define-private (get-item-bonus-if-match (item-id-opt (optional uint)) (stat-name (string-ascii 16)))
  (match item-id-opt
    item-id
      (match (map-get? items item-id)
        item
          (if (is-eq (get stat-bonus-type item) stat-name)
            (get stat-bonus-value item)
            u0)
        u0)
    u0)
)

;; Pseudo-random number - NOT cryptographically secure, used for battle resolution.
;; Takes an explicit block-seed (block-height passed from caller) to avoid
;; serializing builtin keywords inside private functions.
(define-private (pseudo-random (seed uint) (bh uint) (range uint))
  (let (
    (block-seed (buff-to-uint-be (unwrap-panic (as-max-len? (sha256 (concat
        (unwrap-panic (to-consensus-buff? seed))
        (unwrap-panic (to-consensus-buff? bh))
    )) u32))))
  )
  (mod block-seed range))
)

;; Compute effective attack power for a hero: (STR * 3) + (DEX * 1) + weapon-bonus
(define-private (effective-attack (hero-id uint))
  (let (
    (stats (default-to { strength: u0, dexterity: u0, intelligence: u0, vitality: u0, luck: u0, unallocated-points: u0 }
            (map-get? hero-stats hero-id)))
  )
  (+ (* (get strength stats) u3) (get dexterity stats) (equipment-bonus-for-stat hero-id "strength")))
)

;; Compute effective defense for a hero: (VIT * 2) + armor + helmet bonus
(define-private (effective-defense (hero-id uint))
  (let (
    (stats (default-to { strength: u0, dexterity: u0, intelligence: u0, vitality: u0, luck: u0, unallocated-points: u0 }
            (map-get? hero-stats hero-id)))
  )
  (+ (* (get vitality stats) u2) (equipment-bonus-for-stat hero-id "vitality")))
)

;; Compute max HP: (VIT * 10) + (STR * 2) + level * 5
(define-private (effective-hp (hero-id uint))
  (let (
    (hero  (default-to { name: u"", class: "", owner: tx-sender, level: u1, xp: u0, xp-to-next: u100, created-at: u0, battle-count: u0, win-count: u0, loss-count: u0, status: "active", last-battle: u0, guild-id: none }
            (map-get? heroes hero-id)))
    (stats (default-to { strength: u0, dexterity: u0, intelligence: u0, vitality: u0, luck: u0, unallocated-points: u0 }
            (map-get? hero-stats hero-id)))
  )
  (+ (* (get vitality stats) u10) (* (get strength stats) u2) (* (get level hero) u5)))
)

;; ============================================================
;; PUBLIC FUNCTIONS
;; ============================================================

;; --- create-hero ---
;; Mint a new hero with a chosen class. One hero per address by default.
(define-public (create-hero
    (name  (string-utf8 32))
    (class (string-ascii 16)))
  (let (
    (caller      tx-sender)
    (hero-count  (default-to u0 (map-get? address-hero-count caller)))
    (base-stats  (unwrap! (get-class-base-stats class) err-invalid-class))
    (new-id      (+ (var-get hero-nonce) u1))
  )
  ;; Enforce one-hero-per-address limit
  (asserts! (< hero-count max-heroes-per-address) err-hero-limit-reached)

  ;; Store hero core record
  (map-set heroes new-id {
    name:         name,
    class:        class,
    owner:        caller,
    level:        u1,
    xp:           u0,
    xp-to-next:   (xp-for-next-level u1),
    created-at:   block-height,
    battle-count: u0,
    win-count:    u0,
    loss-count:   u0,
    status:       "active",
    last-battle:  u0,
    guild-id:     none
  })

  ;; Store hero stats with 3 unallocated starting points
  (map-set hero-stats new-id {
    strength:          (get strength base-stats),
    dexterity:         (get dexterity base-stats),
    intelligence:      (get intelligence base-stats),
    vitality:          (get vitality base-stats),
    luck:              (get luck base-stats),
    unallocated-points: u3
  })

  ;; Initialize empty equipment slots
  (map-set hero-equipment new-id {
    weapon:    none,
    armor:     none,
    helmet:    none,
    boots:     none,
    accessory: none
  })

  ;; Update counters
  (var-set hero-nonce new-id)
  (map-set address-hero-count caller (+ hero-count u1))

  (ok new-id))
)

;; --- allocate-stat-points ---
;; Spend unallocated stat points. Total allocated must equal unallocated balance.
(define-public (allocate-stat-points
    (hero-id     uint)
    (str-pts     uint)
    (dex-pts     uint)
    (int-pts     uint)
    (vit-pts     uint)
    (lck-pts     uint))
  (let (
    (hero  (unwrap! (map-get? heroes hero-id) err-hero-not-found))
    (stats (unwrap! (map-get? hero-stats hero-id) err-hero-not-found))
    (total-allocated (+ str-pts dex-pts int-pts vit-pts lck-pts))
    (available (get unallocated-points stats))
  )
  (asserts! (is-eq (get owner hero) tx-sender) err-not-hero-owner)
  (asserts! (<= total-allocated available) err-insufficient-stat-points)
  (asserts! (is-eq total-allocated available) err-stat-point-mismatch)

  (map-set hero-stats hero-id {
    strength:          (+ (get strength stats) str-pts),
    dexterity:         (+ (get dexterity stats) dex-pts),
    intelligence:      (+ (get intelligence stats) int-pts),
    vitality:          (+ (get vitality stats) vit-pts),
    luck:              (+ (get luck stats) lck-pts),
    unallocated-points: u0
  })
  (ok true))
)

;; --- level-up ---
;; Level up hero once XP threshold is reached.
(define-public (level-up (hero-id uint))
  (let (
    (hero  (unwrap! (map-get? heroes hero-id) err-hero-not-found))
    (stats (unwrap! (map-get? hero-stats hero-id) err-hero-not-found))
    (current-level (get level hero))
    (new-level     (+ current-level u1))
    (pts-awarded   (stat-points-for-level new-level))
  )
  (asserts! (is-eq (get owner hero) tx-sender) err-not-hero-owner)
  (asserts! (>= (get xp hero) (get xp-to-next hero)) err-insufficient-xp)

  (map-set heroes hero-id (merge hero {
    level:      new-level,
    xp-to-next: (xp-for-next-level new-level)
  }))
  (map-set hero-stats hero-id (merge stats {
    unallocated-points: (+ (get unallocated-points stats) pts-awarded)
  }))
  (ok new-level))
)

;; --- equip-item ---
;; Equip an owned item to a hero slot.
(define-public (equip-item
    (hero-id uint)
    (item-id uint)
    (slot    (string-ascii 16)))
  (let (
    (hero   (unwrap! (map-get? heroes hero-id)  err-hero-not-found))
    (item   (unwrap! (map-get? items  item-id)   err-item-not-found))
    (equip  (default-to { weapon: none, armor: none, helmet: none, boots: none, accessory: none }
             (map-get? hero-equipment hero-id)))
  )
  (asserts! (is-eq (get owner hero) tx-sender)  err-not-hero-owner)
  (asserts! (is-eq (get owner item) tx-sender)  err-not-item-owner)
  (asserts! (is-valid-slot slot)                 err-invalid-slot)
  (asserts! (is-eq (get slot item) slot)         err-item-class-mismatch)
  (asserts! (is-none (get-slot-item equip slot)) err-slot-occupied)

  (map-set hero-equipment hero-id (set-slot-item equip slot (some item-id)))
  (ok true))
)

;; --- unequip-item ---
;; Remove an item from a hero slot.
(define-public (unequip-item
    (hero-id uint)
    (slot    (string-ascii 16)))
  (let (
    (hero  (unwrap! (map-get? heroes hero-id) err-hero-not-found))
    (equip (default-to { weapon: none, armor: none, helmet: none, boots: none, accessory: none }
            (map-get? hero-equipment hero-id)))
  )
  (asserts! (is-eq (get owner hero) tx-sender) err-not-hero-owner)
  (asserts! (is-valid-slot slot)               err-invalid-slot)
  (asserts! (is-some (get-slot-item equip slot)) err-slot-empty)

  (map-set hero-equipment hero-id (set-slot-item equip slot none))
  (ok true))
)

;; --- battle ---
;; Challenge another hero to a PvP battle. Uses block hash for randomness.
(define-public (battle
    (attacker-id uint)
    (defender-id uint))
  (let (
    (attacker     (unwrap! (map-get? heroes attacker-id) err-hero-not-found))
    (defender     (unwrap! (map-get? heroes defender-id) err-hero-not-found))
    (battle-id    (+ (var-get battle-nonce) u1))

    ;; Stats
    (atk-attack  (effective-attack attacker-id))
    (atk-defense (effective-defense attacker-id))
    (atk-hp      (effective-hp attacker-id))

    (def-attack  (effective-attack defender-id))
    (def-defense (effective-defense defender-id))
    (def-hp      (effective-hp defender-id))

    ;; Simulate: net damage each side deals per round
    (atk-damage  (if (> atk-attack def-defense) (- atk-attack def-defense) u1))
    (def-damage  (if (> def-attack atk-defense) (- def-attack atk-defense) u1))

    ;; Rounds each can survive
    (atk-rounds-survive (/ atk-hp (if (> def-damage u0) def-damage u1)))
    (def-rounds-survive (/ def-hp (if (> atk-damage u0) atk-damage u1)))

    ;; Tie-break via pseudo-random roll seeded by hero IDs
    (coin-flip   (pseudo-random (+ attacker-id defender-id) block-height u2))

    ;; Determine winner / loser IDs
    (attacker-wins
      (if (> atk-rounds-survive def-rounds-survive)
        true
      (if (< atk-rounds-survive def-rounds-survive)
        false
        (is-eq coin-flip u0))))   ;; draw -> coin flip

    (winner-id (if attacker-wins attacker-id defender-id))
    (loser-id  (if attacker-wins defender-id attacker-id))

    (xp-for-winner (+ xp-win-base (* (get level (if attacker-wins defender attacker)) u5)))
  )
  ;; Guard rails
  (asserts! (is-eq (get owner attacker) tx-sender) err-not-hero-owner)
  (asserts! (not (is-eq attacker-id defender-id))  err-self-battle)
  (asserts!
    (>= block-height (+ (get last-battle attacker) battle-cooldown-blocks))
    err-on-cooldown)

  ;; Log battle
  (map-set battles battle-id {
    hero1:        attacker-id,
    hero2:        defender-id,
    winner:       winner-id,
    loser:        loser-id,
    xp-awarded:   xp-for-winner,
    block-height: block-height
  })
  (var-set battle-nonce battle-id)

  ;; Update winner record
  (let ((w-hero (unwrap-panic (map-get? heroes winner-id))))
    (map-set heroes winner-id (merge w-hero {
      xp:           (+ (get xp w-hero) xp-for-winner),
      battle-count: (+ (get battle-count w-hero) u1),
      win-count:    (+ (get win-count w-hero) u1),
      last-battle:  block-height
    }))
  )

  ;; Update loser record
  (let ((l-hero (unwrap-panic (map-get? heroes loser-id))))
    (map-set heroes loser-id (merge l-hero {
      xp:           (+ (get xp l-hero) xp-loss),
      battle-count: (+ (get battle-count l-hero) u1),
      loss-count:   (+ (get loss-count l-hero) u1),
      last-battle:  block-height
    }))
  )

  (ok { battle-id: battle-id, winner: winner-id, loser: loser-id, xp-awarded: xp-for-winner }))
)

;; --- create-guild ---
;; Create a new guild. Caller becomes the guild leader.
(define-public (create-guild
    (name  (string-utf8 32))
    (motto (string-utf8 128)))
  (let (
    (new-id (+ (var-get guild-nonce) u1))
  )
  (map-set guilds new-id {
    name:         name,
    motto:        motto,
    leader:       tx-sender,
    guild-xp:     u0,
    member-count: u1
  })
  (var-set guild-nonce new-id)
  (ok new-id))
)

;; --- join-guild ---
;; Join an existing guild with your hero.
(define-public (join-guild
    (hero-id  uint)
    (guild-id uint))
  (let (
    (hero  (unwrap! (map-get? heroes hero-id)   err-hero-not-found))
    (guild (unwrap! (map-get? guilds guild-id)  err-guild-not-found))
  )
  (asserts! (is-eq (get owner hero) tx-sender) err-not-hero-owner)
  (asserts! (is-none (get guild-id hero))      err-already-in-guild)

  (map-set heroes hero-id (merge hero { guild-id: (some guild-id) }))
  (map-set guilds guild-id (merge guild {
    member-count: (+ (get member-count guild) u1)
  }))
  (ok true))
)

;; ============================================================
;; READ-ONLY FUNCTIONS
;; ============================================================

;; Get full hero sheet
(define-read-only (get-hero (hero-id uint))
  (map-get? heroes hero-id)
)

;; Get a hero's stats record
(define-read-only (get-hero-stats (hero-id uint))
  (map-get? hero-stats hero-id)
)

;; Get a hero's effective (base + equipment) stats
(define-read-only (get-effective-stats (hero-id uint))
  (match (map-get? hero-stats hero-id)
    stats
      (some {
        strength:     (+ (get strength stats)     (equipment-bonus-for-stat hero-id "strength")),
        dexterity:    (+ (get dexterity stats)    (equipment-bonus-for-stat hero-id "dexterity")),
        intelligence: (+ (get intelligence stats) (equipment-bonus-for-stat hero-id "intelligence")),
        vitality:     (+ (get vitality stats)     (equipment-bonus-for-stat hero-id "vitality")),
        luck:         (+ (get luck stats)         (equipment-bonus-for-stat hero-id "luck")),
        attack-power: (effective-attack hero-id),
        defense:      (effective-defense hero-id),
        max-hp:       (effective-hp hero-id)
      })
    none)
)

;; Get a hero's equipped items
(define-read-only (get-equipment (hero-id uint))
  (map-get? hero-equipment hero-id)
)

;; Get item details
(define-read-only (get-item (item-id uint))
  (map-get? items item-id)
)

;; Get battle log entry
(define-read-only (get-battle (battle-id uint))
  (map-get? battles battle-id)
)

;; Get hero win/loss record
(define-read-only (get-battle-record (hero-id uint))
  (match (map-get? heroes hero-id)
    hero (some {
      battle-count: (get battle-count hero),
      win-count:    (get win-count hero),
      loss-count:   (get loss-count hero)
    })
    none)
)

;; Get guild details
(define-read-only (get-guild (guild-id uint))
  (map-get? guilds guild-id)
)

;; Get leaderboard entry for a hero
(define-read-only (get-leaderboard-entry (hero-id uint))
  (match (map-get? heroes hero-id)
    hero (some {
      hero-name:  (get name hero),
      class:      (get class hero),
      level:      (get level hero),
      wins:       (get win-count hero),
      losses:     (get loss-count hero),
      total-xp:   (get xp hero),
      guild:      (get guild-id hero)
    })
    none)
)

;; Get total hero count
(define-read-only (get-hero-count)
  (var-get hero-nonce)
)

;; Check if a hero is on battle cooldown
(define-read-only (is-on-cooldown (hero-id uint))
  (match (map-get? heroes hero-id)
    hero (< block-height (+ (get last-battle hero) battle-cooldown-blocks))
    false)
)

;; Get a hero's unallocated stat points
(define-read-only (get-unallocated-points (hero-id uint))
  (match (map-get? hero-stats hero-id)
    stats (some (get unallocated-points stats))
    none)
)

;; ============================================================
;; UTILITY FUNCTIONS - Counter (for deployment testing only)
;; ============================================================
;; These functions are NOT part of the core game logic.
;; They expose a simple integer counter to verify that contract
;; calls work correctly after deployment.

;; Get current counter value
(define-read-only (get-counter)
  (var-get test-counter)
)

;; Increment counter by 1
(define-public (increment)
  (begin
    (var-set test-counter (+ (var-get test-counter) 1))
    (ok (var-get test-counter))
  )
)

;; Decrement counter by 1
(define-public (decrement)
  (begin
    (var-set test-counter (- (var-get test-counter) 1))
    (ok (var-get test-counter))
  )
)

;; Reset counter to 0 (convenience helper)
(define-public (reset-counter)
  (begin
    (var-set test-counter 0)
    (ok 0)
  )
)
