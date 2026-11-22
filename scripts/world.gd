extends Node2D
## Dessin de la grotte, du mineur, de la lumière de la lampe et des effets.

const TS := GameData.TILE
const STONE_COLOR := Color(0.36, 0.29, 0.24)
const BEDROCK_COLOR := Color(0.16, 0.13, 0.17)
const FLOOR_COLOR := Color(0.2, 0.15, 0.12)

var game: Node2D
var particles: Array = []
var floats: Array = []
var font: Font
var time := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font


func clear_effects() -> void:
	particles.clear()
	floats.clear()


func spawn_chips(t: Vector2i, color: Color, n: int) -> void:
	var c := Vector2(t) * TS + Vector2(TS, TS) * 0.5
	for i in n:
		particles.append({
			"p": c + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
			"v": Vector2(randf_range(-70, 70), randf_range(-110, -20)),
			"life": randf_range(0.35, 0.7),
			"c": color,
		})


func float_text(t: Vector2i, text: String, color: Color, line := 0) -> void:
	floats.append({
		"p": Vector2(t) * TS + Vector2(TS * 0.5, 2 - line * 14),
		"text": text, "c": color, "life": 1.3,
	})


func _process(delta: float) -> void:
	time += delta
	for p in particles:
		var v: Vector2 = p["v"]
		v.y += 300.0 * delta
		p["v"] = v
		p["p"] = p["p"] + v * delta
		p["life"] = p["life"] - delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	for f in floats:
		f["p"] = f["p"] + Vector2(0, -24.0 * delta)
		f["life"] = f["life"] - delta
	floats = floats.filter(func(f): return f["life"] > 0.0)


func _draw() -> void:
	if game == null or game.w == 0:
		return
	var cam: Vector2 = game.player_pos()
	var view: Vector2 = get_viewport_rect().size / game.camera.zoom
	var x0 := maxi(0, int((cam.x - view.x * 0.5) / TS) - 1)
	var x1 := mini(game.w - 1, int((cam.x + view.x * 0.5) / TS) + 1)
	var y0 := maxi(0, int((cam.y - view.y * 0.5) / TS) - 1)
	var y1 := mini(game.h - 1, int((cam.y + view.y * 0.5) / TS) + 1)
	var radius := float(game.light_radius)
	var center := cam / TS - Vector2(0.5, 0.5)
	var flicker := 1.0 + sin(time * 7.0) * 0.02 + sin(time * 13.0) * 0.015

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var k: int = y * game.w + x
			if game.seen[k] == 0:
				continue
			var pos := Vector2(x * TS, y * TS)
			_draw_tile(game.map[k], x, y, pos, k)
			var b := 0.2
			if game.lit[k] == 1:
				var d := Vector2(x, y).distance_to(center) / ((radius + 1.0) * flicker)
				b = clampf(1.0 - d * d * 0.85, 0.2, 1.0)
			draw_rect(Rect2(pos, Vector2(TS, TS)), Color(0.02, 0.01, 0.0, 1.0 - b))

	_draw_player(cam)

	for p in particles:
		var col: Color = p["c"]
		col.a = clampf(p["life"] * 2.5, 0.0, 1.0)
		draw_rect(Rect2(p["p"] - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	for f in floats:
		var col: Color = f["c"]
		col.a = clampf(f["life"] * 1.5, 0.0, 1.0)
		var pos: Vector2 = f["p"] - Vector2(60, 0)
		draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 4, Color(0, 0, 0, col.a))
		draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)


# ---------- Cases ----------

func _h(x: int, y: int, s: int) -> float:
	var n := x * 374761393 + y * 668265263 + s * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _draw_tile(tile: int, x: int, y: int, pos: Vector2, k: int) -> void:
	match tile:
		GameData.FLOOR:
			_floor(pos, x, y)
		GameData.STONE:
			_stone(pos, x, y, STONE_COLOR)
		GameData.BEDROCK:
			_stone(pos, x, y, BEDROCK_COLOR)
		GameData.COPPER, GameData.IRON, GameData.GOLD:
			_ore(tile, pos, x, y)
		GameData.CHEST:
			_floor(pos, x, y)
			_chest(pos, false)
		GameData.OPENED:
			_floor(pos, x, y)
			_chest(pos, true)
		GameData.STAIRS:
			_floor(pos, x, y)
			_stairs(pos)
	if game.damage.has(k):
		_cracks(pos, x, y, float(game.damage[k]) / float(GameData.BLOCKS[tile]["hp"]))


func _floor(pos: Vector2, x: int, y: int) -> void:
	draw_rect(Rect2(pos, Vector2(TS, TS)), FLOOR_COLOR)
	for i in 3:
		var p := pos + Vector2(_h(x, y, i) * (TS - 3), _h(x, y, i + 7) * (TS - 3))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.27, 0.21, 0.17))


func _stone(pos: Vector2, x: int, y: int, base: Color) -> void:
	draw_rect(Rect2(pos, Vector2(TS, TS)), base)
	draw_rect(Rect2(pos, Vector2(TS, 4)), base.lightened(0.15))
	draw_rect(Rect2(pos + Vector2(0, TS - 4), Vector2(TS, 4)), base.darkened(0.35))
	for i in 4:
		var p := pos + Vector2(2 + _h(x, y, i) * (TS - 8), 5 + _h(x, y, i + 11) * (TS - 13))
		draw_rect(Rect2(p, Vector2(4, 3)), base.darkened(0.25))
		draw_rect(Rect2(p, Vector2(4, 1)), base.lightened(0.08))


func _ore(tile: int, pos: Vector2, x: int, y: int) -> void:
	_stone(pos, x, y, STONE_COLOR)
	var col: Color = GameData.BLOCKS[tile]["color"]
	for i in 5:
		var p := pos + Vector2(6 + _h(x, y, i + 20) * (TS - 12), 7 + _h(x, y, i + 30) * (TS - 14))
		var r := 2.0 + _h(x, y, i + 40) * 2.5
		draw_circle(p, r + 1.0, col.darkened(0.5))
		draw_circle(p, r, col)
		draw_circle(p - Vector2(r, r) * 0.35, r * 0.4, col.lightened(0.5))
	if tile == GameData.GOLD:
		var s := sin(time * 3.0 + x * 1.7 + y * 2.3)
		if s > 0.6:
			var c := pos + Vector2(8 + _h(x, y, 60) * 16, 8 + _h(x, y, 61) * 16)
			var l := (s - 0.6) * 10.0
			draw_line(c - Vector2(l, 0), c + Vector2(l, 0), Color(1, 1, 0.85), 1.0)
			draw_line(c - Vector2(0, l), c + Vector2(0, l), Color(1, 1, 0.85), 1.0)


func _chest(pos: Vector2, opened: bool) -> void:
	var gold := Color(0.95, 0.75, 0.25)
	var body := Rect2(pos + Vector2(5, 13), Vector2(22, 14))
	draw_rect(Rect2(pos + Vector2(4, 26), Vector2(24, 3)), Color(0, 0, 0, 0.35))
	if opened:
		draw_rect(Rect2(pos + Vector2(5, 5), Vector2(22, 8)), Color(0.4, 0.23, 0.1))
		draw_rect(body, Color(0.5, 0.3, 0.13))
		draw_rect(Rect2(body.position + Vector2(2, 1), Vector2(18, 5)), Color(0.1, 0.06, 0.03))
	else:
		draw_rect(body, Color(0.56, 0.34, 0.15))
		draw_rect(Rect2(pos + Vector2(5, 9), Vector2(22, 7)), Color(0.46, 0.27, 0.11))
		draw_rect(Rect2(pos + Vector2(5, 15), Vector2(22, 2)), gold)
		draw_rect(Rect2(pos + Vector2(14, 14), Vector2(4, 6)), gold)
		draw_rect(Rect2(pos + Vector2(15, 16), Vector2(2, 2)), Color(0.2, 0.12, 0.05))
	draw_rect(Rect2(body.position, Vector2(2, body.size.y)), gold.darkened(0.2))
	draw_rect(Rect2(body.position + Vector2(20, 0), Vector2(2, body.size.y)), gold.darkened(0.2))


func _stairs(pos: Vector2) -> void:
	var hole := Rect2(pos + Vector2(4, 4), Vector2(24, 24))
	draw_rect(hole, Color(0.04, 0.02, 0.02))
	for i in 4:
		draw_rect(Rect2(pos + Vector2(6 + i * 2, 6 + i * 5), Vector2(20 - i * 4, 3)),
			Color(0.55, 0.44, 0.34).darkened(i * 0.2))
	var glow := 0.5 + 0.5 * sin(time * 3.0)
	draw_rect(hole, Color(1.0, 0.8, 0.35, 0.5 + glow * 0.5), false, 1.5)


func _cracks(pos: Vector2, x: int, y: int, ratio: float) -> void:
	var c := pos + Vector2(TS, TS) * 0.5
	var n := 1 + int(ratio * 5.0)
	for i in n:
		var a := _h(x, y, i + 50) * TAU
		var l := (0.25 + ratio * 0.25) * TS
		var mid := c + Vector2.from_angle(a + 0.4) * l * 0.5
		draw_polyline(PackedVector2Array([c, mid, c + Vector2.from_angle(a) * l]), Color(0, 0, 0, 0.75), 1.5)


# ---------- Mineur ----------

func _draw_player(c: Vector2) -> void:
	var f: Vector2i = game.facing
	draw_set_transform(c + Vector2(0, 13), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

	var bob := 0.0
	if game.move_t < 1.0:
		bob = -absf(sin(game.move_t * PI)) * 2.0
	var o := c + Vector2(0, bob)

	if f == Vector2i.UP:
		_draw_pick(o, f)
	# jambes
	draw_rect(Rect2(o + Vector2(-6, 6), Vector2(5, 7)), Color(0.22, 0.18, 0.15))
	draw_rect(Rect2(o + Vector2(1, 6), Vector2(5, 7)), Color(0.22, 0.18, 0.15))
	# corps : chemise et salopette
	draw_rect(Rect2(o + Vector2(-7, -3), Vector2(14, 11)), Color(0.75, 0.3, 0.22))
	draw_rect(Rect2(o + Vector2(-5, 0), Vector2(10, 8)), Color(0.22, 0.42, 0.68))
	draw_rect(Rect2(o + Vector2(-5, -3), Vector2(2, 4)), Color(0.22, 0.42, 0.68))
	draw_rect(Rect2(o + Vector2(3, -3), Vector2(2, 4)), Color(0.22, 0.42, 0.68))
	# casque puis visage
	draw_circle(o + Vector2(0, -11), 6.5, Color(0.95, 0.76, 0.2))
	draw_circle(o + Vector2(0, -7), 5.5, Color(0.95, 0.76, 0.56))
	draw_rect(Rect2(o + Vector2(-8, -12), Vector2(16, 2)), Color(0.8, 0.6, 0.12))
	if f != Vector2i.UP:
		var ex := f.x * 2
		draw_circle(o + Vector2(-2 + ex, -7), 0.9, Color.BLACK)
		draw_circle(o + Vector2(2 + ex, -7), 0.9, Color.BLACK)
		# lampe frontale
		draw_circle(o + Vector2(f.x * 4, -13), 2.4, Color(1, 1, 0.8))
		draw_circle(o + Vector2(f.x * 4, -13), 4.5, Color(1, 0.95, 0.6, 0.25))
		_draw_pick(o, f)


func _draw_pick(o: Vector2, f: Vector2i) -> void:
	var pick: Dictionary = GameData.PICKAXES[game.pick_level]
	var col: Color = pick["color"]
	var base := Vector2(f).angle()
	var ang: float = base - 1.1 * (1.0 - game.swing)
	var hand := o + Vector2(f) * 4.0 + Vector2(0, 1)
	var dir := Vector2.from_angle(ang)
	var tip := hand + dir * 13.0
	var perp := dir.orthogonal()
	draw_line(hand, tip, Color(0.5, 0.32, 0.15), 2.5)
	draw_line(tip - perp * 6.0 - dir, tip + perp * 6.0 - dir, col, 3.5)
	draw_line(tip + perp * 6.0 - dir, tip + perp * 7.5 - dir * 3.0, col, 2.5)
	draw_line(tip - perp * 6.0 - dir, tip - perp * 7.5 - dir * 3.0, col, 2.5)
