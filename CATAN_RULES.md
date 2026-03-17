# Settlers of Catan — Complete Rules Reference
# Used during development to verify correct implementation

---

## Board Composition

| Tile Type   | Count | Resource  |
|-------------|-------|-----------|
| Forest      | 4     | Lumber    |
| Hills       | 3     | Brick     |
| Pasture     | 4     | Wool      |
| Fields      | 4     | Grain     |
| Mountains   | 3     | Ore       |
| Desert      | 1     | none      |
| **Total**   | **19**|           |

Number tokens on non-desert tiles: 2×(3,4,5,6,8,9,10,11) + 1×(2,12) = 18 tokens
Robber starts on the Desert tile.

Harbors (ports) around the board edge — 9 total:
- 4 generic harbors: 3:1 trade rate (any resource)
- 5 specific harbors: 2:1 trade rate (one specific resource each: Lumber, Brick, Wool, Grain, Ore)

---

## Initial Placement (Setup Phase)

**THIS WAS INCORRECTLY IMPLEMENTED — fixed after user report.**

### Correct Setup:

**Round 1** — forward order (P1 → P2 → P3 → P4):
1. Current player places 1 settlement on any valid vertex (distance rule applies)
2. Current player IMMEDIATELY places 1 road on any edge adjacent to that settlement
3. Advance to next player

**Round 2** — SNAKE/reverse order (P4 → P3 → P2 → P1):
1. Current player places 1 settlement
2. Current player IMMEDIATELY places 1 road adjacent to that settlement
3. After placing the 2nd settlement: player receives 1 resource card per adjacent non-desert terrain tile
4. Advance to previous player

After all players complete round 2, Player 1 begins the main game in ROLL phase.

For 2 players: P1 → P2 → P2 → P1 (4 settlements + 4 roads total)
For 3 players: P1 → P2 → P3 → P3 → P2 → P1
For 4 players: P1 → P2 → P3 → P4 → P4 → P3 → P2 → P1

**Distance rule:** No settlement may be placed within 1 edge of any other settlement (i.e., adjacent vertices must be empty).

---

## Turn Structure

Each turn has three phases in order:

1. **Roll** — roll 2d6
   - Result 7: activate robber (see Robber section)
   - Any other result: all players collect resources from adjacent tiles

2. **Trade** (optional, before or after building)
   - Maritime trade with bank (4:1, or port rates)
   - Player-to-player trade (offer any resources, negotiate)
   - May trade multiple times

3. **Build** (optional, in any order)
   - Place roads
   - Place settlements
   - Upgrade settlements to cities
   - Buy development cards
   - Play one development card (not same turn it was purchased)

---

## Building Costs

| Build        | Lumber | Brick | Wool | Grain | Ore |
|-------------|--------|-------|------|-------|-----|
| Road        | 1      | 1     |      |       |     |
| Settlement  | 1      | 1     | 1    | 1     |     |
| City        |        |       |      | 2     | 3   |
| Dev Card    |        |       | 1    | 1     | 1   |

---

## Piece Limits Per Player

| Piece       | Limit |
|-------------|-------|
| Roads       | 15    |
| Settlements | 5     |
| Cities      | 4     |

(Cities replace settlements — upgrading frees up a settlement piece)

---

## Resource Production

When the dice roll matches a tile's number token:
- All players with a settlement adjacent to that tile receive 1 resource card
- All players with a city adjacent to that tile receive 2 resource cards
- The tile with the robber produces NOTHING regardless of the roll

---

## Robber

Activated by either rolling 7 OR playing a Knight development card.

**Step 1 — Discard rule (rolling 7 ONLY, not Knight):**
Any player holding 8 or more resource cards must discard half (rounded down).

**Step 2 — Move robber:**
Active player moves the robber token to any terrain hex tile (may not stay on current tile).
The selected tile produces no resources while the robber is there.

**Step 3 — Steal:**
If the new robber tile has opposing settlements/cities adjacent to it, the active player
steals 1 random resource card from one of those opponents (active player's choice of which
opponent, random resource from that opponent's hand).

---

## Trading

### Maritime Trading (with bank)
- **Default rate:** Trade 4 identical resource cards → receive 1 of any resource
- **Generic harbor (3:1):** Trade 3 identical resource cards → 1 of any
- **Specific harbor (2:1):** Trade 2 of the matching resource → 1 of any

### Player Trading
- Only the active player may initiate trades
- Trades must be agreed upon by both parties
- No trading with the bank during opponent's turns
- Players may not give cards for free (must receive something in return)
- NOT YET IMPLEMENTED in Hex Settlers

---

## Development Cards

25 total cards in the deck:

| Card          | Count | Effect |
|---------------|-------|--------|
| Knight        | 14    | Move robber (like rolling 7, but NO discard rule applies); steal from adjacent opponent |
| Victory Point | 5     | Worth 1 VP; kept secret until game end or winning reveal |
| Road Building | 2     | Place 2 free roads immediately |
| Year of Plenty| 2     | Take any 2 resource cards from the bank immediately |
| Monopoly      | 2     | Name 1 resource; all opponents give you ALL their cards of that type |

**Rules:**
- Cost: 1 Ore + 1 Grain + 1 Wool per card
- May NOT play a card on the same turn it was purchased
- Only 1 development card may be played per turn
- VP cards may be kept secret until winning; revealed at game end
- Knights may be played before or after rolling dice

---

## Special Cards (Bonus VP)

### Longest Road
- Awarded to the first player who builds a continuous road network of 5+ roads
- Worth **2 VP**
- If another player surpasses the current holder's road length, they take the card and 2 VP
- Ties: current holder keeps the card
- Minimum to claim: 5 roads
- Forking roads count; only the longest branch matters

### Largest Army
- Awarded to the first player who plays 3+ Knight cards
- Worth **2 VP**
- If another player plays more knights, they take the card and 2 VP
- Minimum to claim: 3 knights played

---

## Victory Points

| Source              | Points |
|--------------------|--------|
| Settlement         | 1 VP   |
| City               | 2 VP   |
| Longest Road       | 2 VP   |
| Largest Army       | 2 VP   |
| Victory Point card | 1 VP each |

**Win condition:** First player to reach **10 VP** during their own turn wins.
VP cards are revealed at the moment of winning (or at game end to count).

---

## Implementation Status Checklist

### Board & Generation
- [x] 19 hex tiles (correct terrain distribution)
- [x] Number tokens (correct distribution: 2×(3-6,8-11) + 1×(2,12))
- [x] Number token pip display (probability dots)
- [x] Hot tile highlighting (6 and 8 in red)
- [x] Robber starts on Desert
- [ ] Harbors/ports (9 total: 4 generic 3:1, 5 specific 2:1) — NOT YET IMPLEMENTED
- [ ] Port trade rates in bank trading — NOT YET IMPLEMENTED

### Setup Phase
- [x] Settlement placement (distance rule enforced)
- [x] Snake order (P1→P2→P2→P1 for 2 players) — FIXED
- [x] Road placement after each setup settlement — FIXED
- [x] Starting resources from 2nd settlement — FIXED
- [ ] Starting resources actually shown visually in HUD — verify

### Turn Structure
- [x] Dice rolling
- [x] Resource collection
- [x] Robber on 7 (with discard rule)
- [x] Build phase (settlements, cities, roads, dev cards)
- [x] End turn / turn cycling

### Resources & Costs
- [x] All 5 resource types (Lumber, Brick, Wool, Grain, Ore)
- [x] Settlement cost (1 each L/B/W/G)
- [x] City cost (2G + 3O)
- [x] Road cost (1L + 1B)
- [x] Dev card cost (1O + 1G + 1W)
- [x] Piece limits (5S, 4C, 15R)
- [ ] Port/harbor trade rates — NOT YET IMPLEMENTED
- [ ] Player-to-player trading — NOT YET IMPLEMENTED

### Robber
- [x] Roll 7 → robber activated
- [x] Discard rule (8+ cards → discard half)
- [x] Move robber to any tile
- [x] Steal resource from adjacent opponent
- [ ] Knight card also activates robber (partial — robber moves but no discard)
  - Actually correct: Knight does NOT trigger discard, only roll-7 does

### Development Cards
- [x] Full 25-card deck (correct distribution)
- [x] Knight (move robber, steal)
- [x] Victory Point (+1 VP instantly)
- [x] Road Building (2 free roads)
- [x] Year of Plenty (2 free resources)
- [x] Monopoly (steal all of one resource)
- [ ] "Cannot play card same turn purchased" — NOT enforced
- [ ] Maximum 1 card per turn — NOT enforced

### Special Cards
- [x] Longest Road (5+ roads → 2 VP, transferred if surpassed)
- [x] Largest Army (3+ knights → 2 VP, transferred if surpassed)

### Victory
- [x] VP from settlements (1 each)
- [x] VP from cities (2 each, net +1 from upgrade)
- [x] VP from Longest Road
- [x] VP from Largest Army
- [x] VP from VP dev cards
- [x] Win at 10 VP
- [x] Game stops immediately when 10 VP reached

### UI / UX
- [x] HUD with resource display
- [x] Dev card count display
- [x] Longest Road / Largest Army holder display
- [x] Settlement/city hover highlights
- [x] Road hover highlights
- [x] Main menu
- [ ] Trading UI — NOT YET IMPLEMENTED
- [ ] Dev card play UI (select which card) — AI handles it internally
- [ ] Port visual indicators on board edge — NOT YET IMPLEMENTED

### AI
- [x] Greedy AI strategy (city > settlement > road > dev card > bank trade)
- [x] Setup vertex selection (highest pip score + distance rule)
- [x] Bank trading (4:1 surplus conversion)
- [x] Robber placement (targets opponent's best tile)
- [ ] Port-aware trading — NOT YET IMPLEMENTED

---

## Known Deviations from Standard Catan

1. **Ports not implemented** — all bank trades at 4:1 (no port bonuses yet)
2. **Player trading not implemented** — only bank trading available
3. **"Same turn" dev card rule not enforced** — can play card bought same turn
4. **1 dev card per turn not enforced** — AI plays one, but UI doesn't restrict humans
5. **Largest Army minimum threshold** — implemented at 3 (correct)
6. **Starting resources** — now correctly given after 2nd setup settlement

---

*Reference: Official Settlers of Catan rules (Catan GmbH). This project is an
independent implementation using original assets — no official Catan content used.*
