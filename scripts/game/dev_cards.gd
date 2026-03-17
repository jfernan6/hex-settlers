## Development card constants and deck factory.
## Standard Catan deck: 25 cards total.

enum Type {
	KNIGHT,          # Move robber, steal. 14 in deck.
	ROAD_BUILDING,   # Place 2 free roads.  2 in deck.
	YEAR_OF_PLENTY,  # Take any 2 resources. 2 in deck.
	MONOPOLY,        # Steal all of one resource type. 2 in deck.
	VP,              # +1 victory point instantly. 5 in deck.
}

const COUNTS: Dictionary = {
	Type.KNIGHT:         14,
	Type.ROAD_BUILDING:   2,
	Type.YEAR_OF_PLENTY:  2,
	Type.MONOPOLY:        2,
	Type.VP:              5,
}

const NAMES: Dictionary = {
	Type.KNIGHT:         "Knight",
	Type.ROAD_BUILDING:  "Road Building",
	Type.YEAR_OF_PLENTY: "Year of Plenty",
	Type.MONOPOLY:       "Monopoly",
	Type.VP:             "Victory Point",
}

const SHORT_NAMES: Dictionary = {
	Type.KNIGHT:         "KN",
	Type.ROAD_BUILDING:  "RB",
	Type.YEAR_OF_PLENTY: "YP",
	Type.MONOPOLY:       "MO",
	Type.VP:             "VP",
}

const TOTAL_CARDS: int = 25


## Returns a freshly shuffled 25-card deck as an Array of Type ints.
static func make_deck() -> Array:
	var deck: Array = []
	for card_type in COUNTS:
		for _i in range(COUNTS[card_type]):
			deck.append(card_type)
	deck.shuffle()
	print("[DEVCARDS] Deck created: %d cards  [OK]" % deck.size())
	return deck


## Human-readable summary of a hand (Array of Type ints).
static func hand_summary(hand: Array) -> String:
	var counts: Dictionary = {}
	for card in hand:
		counts[card] = counts.get(card, 0) + 1
	var parts: Array = []
	for t in [Type.KNIGHT, Type.ROAD_BUILDING, Type.YEAR_OF_PLENTY, Type.MONOPOLY, Type.VP]:
		if counts.get(t, 0) > 0:
			parts.append("%s×%d" % [SHORT_NAMES[t], counts[t]])
	return ", ".join(parts) if parts.size() > 0 else "none"
