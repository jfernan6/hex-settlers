extends CanvasLayer

## God Mode overlay panel — toggle with F4.
## Lets the developer freely give resources, build anything, force dice, switch players.
## All actions use signals so main.gd stays authoritative.

signal give_resource(res: int, amount: int)
signal build_free(type: String)          # "settlement" | "road" | "city" | "dev_card"
signal give_dev_card(card_type: int)     # DevCards.Type int
signal force_roll(number: int)
signal switch_player(player_idx: int)
signal instant_win()
signal panel_closed()

const DevCards = preload("res://scripts/game/dev_cards.gd")
const PlayerData = preload("res://scripts/player/player.gd")

var _panel: PanelContainer
var _player_label: Label
var _font_size: int = 13     # set from viewport in _build_ui()

const RES_NAMES := ["Lumber", "Brick", "Wool", "Grain", "Ore"]
const RES_COLORS := [
	Color(0.20, 0.60, 0.15),  # Lumber — green
	Color(0.75, 0.25, 0.08),  # Brick  — orange-red
	Color(0.50, 0.80, 0.20),  # Wool   — light green
	Color(0.90, 0.80, 0.10),  # Grain  — yellow
	Color(0.50, 0.50, 0.55),  # Ore    — grey-blue
]


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Scale everything from viewport size so it looks right on any resolution
	var vp: Vector2  = get_viewport().get_visible_rect().size
	var pw: float    = maxf(300.0, vp.x * 0.19)
	var ph: float    = maxf(500.0, vp.y * 0.88)
	_font_size       = int(maxf(12.0, vp.x * 0.010))

	# --- Outer panel ---
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.0
	_panel.anchor_right  = 0.0
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = 12.0
	_panel.offset_top    = 12.0
	_panel.offset_right  = pw + 12.0
	_panel.offset_bottom = ph + 12.0

	var style := StyleBoxFlat.new()
	style.bg_color         = Color(0.07, 0.08, 0.11, 0.96)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color     = Color(0.80, 0.65, 0.10)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(290, 0)
	scroll.add_child(vbox)

	# === HEADER ===
	var hdr := _lbl("  GOD MODE  ", _font_size + 8)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.modulate = Color(1.0, 0.80, 0.10)
	vbox.add_child(hdr)

	_player_label = _lbl("Player: —", _font_size)
	_player_label.modulate = Color(0.70, 0.70, 0.70)
	vbox.add_child(_player_label)
	vbox.add_child(_sep())

	# === RESOURCES ===
	vbox.add_child(_section("Resources"))
	for r in range(5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var lbl := _lbl(RES_NAMES[r], 12)
		lbl.modulate = RES_COLORS[r]
		lbl.custom_minimum_size = Vector2(52, 0)
		row.add_child(lbl)
		row.add_child(_rbtn("-1",  func(): give_resource.emit(r, -1)))
		row.add_child(_rbtn("+1",  func(): give_resource.emit(r,  1)))
		row.add_child(_rbtn("+5",  func(): give_resource.emit(r,  5)))
		row.add_child(_rbtn("+10", func(): give_resource.emit(r, 10)))
		vbox.add_child(row)

	vbox.add_child(_sep())

	# === BUILD (FREE) ===
	vbox.add_child(_section("Build Free"))
	vbox.add_child(_wbtn("Place Settlement",  func(): build_free.emit("settlement")))
	vbox.add_child(_wbtn("Place Road",        func(): build_free.emit("road")))
	vbox.add_child(_wbtn("Upgrade to City",   func(): build_free.emit("city")))
	vbox.add_child(_wbtn("Draw Dev Card",     func(): build_free.emit("dev_card")))
	vbox.add_child(_sep())

	# === DEV CARDS ===
	vbox.add_child(_section("Give Dev Card"))
	var dc_row1 := HBoxContainer.new()
	dc_row1.add_child(_rbtn("Knight",   func(): give_dev_card.emit(DevCards.Type.KNIGHT)))
	dc_row1.add_child(_rbtn("Road Bld", func(): give_dev_card.emit(DevCards.Type.ROAD_BUILDING)))
	dc_row1.add_child(_rbtn("YoP",      func(): give_dev_card.emit(DevCards.Type.YEAR_OF_PLENTY)))
	vbox.add_child(dc_row1)
	var dc_row2 := HBoxContainer.new()
	dc_row2.add_child(_rbtn("Monopoly", func(): give_dev_card.emit(DevCards.Type.MONOPOLY)))
	dc_row2.add_child(_rbtn("VP Card",  func(): give_dev_card.emit(DevCards.Type.VP)))
	vbox.add_child(dc_row2)
	vbox.add_child(_sep())

	# === FORCE DICE ROLL ===
	vbox.add_child(_section("Force Dice Roll"))
	var dice_grid := GridContainer.new()
	dice_grid.columns = 6
	for n in range(2, 13):
		dice_grid.add_child(_rbtn(str(n), func(v=n): force_roll.emit(v)))
	vbox.add_child(dice_grid)
	vbox.add_child(_sep())

	# === GAME CONTROL ===
	vbox.add_child(_section("Game Control"))
	var sw_row := HBoxContainer.new()
	sw_row.add_child(_rbtn("→ P1", func(): switch_player.emit(0)))
	sw_row.add_child(_rbtn("→ P2", func(): switch_player.emit(1)))
	sw_row.add_child(_rbtn("→ P3", func(): switch_player.emit(2)))
	sw_row.add_child(_rbtn("→ P4", func(): switch_player.emit(3)))
	vbox.add_child(sw_row)
	vbox.add_child(_wbtn("Instant Win (10 VP)", func(): instant_win.emit()))

	vbox.add_child(_sep())
	vbox.add_child(_wbtn("Close  [F4]", func(): panel_closed.emit()))


# ---------------------------------------------------------------
# Public
# ---------------------------------------------------------------

func set_player_name(name: String, color: Color) -> void:
	if _player_label:
		_player_label.text = "Player: %s" % name
		_player_label.modulate = color


# ---------------------------------------------------------------
# Widget helpers
# ---------------------------------------------------------------

func _section(title: String) -> Label:
	var l := _lbl(title, _font_size + 1)
	l.modulate = Color(0.80, 0.70, 0.25)
	return l


func _lbl(text: String, size: int = -1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size if size > 0 else _font_size)
	return l


func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = Color(0.30, 0.28, 0.15)
	return s


## Small resource button (compact) — uses viewport-scaled font
func _rbtn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _font_size)
	b.custom_minimum_size = Vector2(0, int(_font_size * 2.2))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


## Wide action button — uses viewport-scaled font
func _wbtn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", _font_size + 2)
	b.custom_minimum_size = Vector2(0, int((_font_size + 2) * 2.4))
	b.pressed.connect(cb)
	return b
