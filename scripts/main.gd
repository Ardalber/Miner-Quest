extends Node2D
## Logique du jeu : déplacements, minage, coffres, étages, pioches et sauvegarde.

const MOVE_TIME := 0.12
const MINE_TIME := 0.22
const SAVE_PATH := "user://miner_quest_save.json"
const TS := GameData.TILE

var world: Node2D
var camera: Camera2D
var hud: CanvasLayer

var floor_num := 1
var deepest := 1
var chests_opened := 0
var inv := {"copper": 0, "iron": 0, "gold": 0}
var pick_level := 0
var light_radius := 4

var w := 0
var h := 0
var map := PackedByteArray()
var seen := PackedByteArray()
var lit := PackedByteArray()
var damage := {}

var player := Vector2i.ZERO
var facing := Vector2i.DOWN
var move_from := Vector2.ZERO
var move_t := 1.0
var swing := 0.0
var cooldown := 0.0
var touch_dir := Vector2i.ZERO
var playing := false
var dirty := false
var save_timer := 0.0
var stairs_hint_shown := false


func _ready() -> void:
	randomize()
	world = preload("res://scripts/world.gd").new()
	world.game = self
	add_child(world)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()

	var has_save := load_game()
	if not has_save:
		floor_num = 1
		_enter_floor()
	hud.refresh()
	if "--demo" in OS.get_cmdline_user_args():
		new_game()
	else:
		hud.show_title(has_save)


func _update_zoom() -> void:
	var vp := get_viewport_rect().size
	var z := minf(vp.x, vp.y) / (12.0 * TS)
	camera.zoom = Vector2(z, z)


# ---------- Parties ----------

func new_game() -> void:
	floor_num = 1
	deepest = 1
	chests_opened = 0
	inv = {"copper": 0, "iron": 0, "gold": 0}
	pick_level = 0
	light_radius = 4
	_enter_floor()
	playing = true
	hud.refresh()
	hud.toast("Étage 1 : mine du cuivre et trouve l'escalier pour descendre !")
	save_game()


func continue_game() -> void:
	playing = true
	hud.refresh()


func _enter_floor() -> void:
	var data := CaveGenerator.generate(floor_num)
	w = data["w"]
	h = data["h"]
	map = data["map"]
	seen = PackedByteArray()
	seen.resize(w * h)
	lit = PackedByteArray()
	lit.resize(w * h)
	damage.clear()
	player = data["start"]
	facing = Vector2i.DOWN
	move_t = 1.0
	stairs_hint_shown = false
	update_fov()
	world.clear_effects()


func try_descend() -> void:
	if not playing or not on_stairs():
		return
	floor_num += 1
	deepest = maxi(deepest, floor_num)
	_enter_floor()
	hud.refresh()
	var msg := "Étage %d" % floor_num
	if floor_num == 2:
		msg += " : le fer devient plus fréquent."
	elif floor_num == 3:
		msg += " : de l'or brille dans les parois !"
	hud.toast(msg)
	save_game()


func on_stairs() -> bool:
	return w > 0 and map[idx(player)] == GameData.STAIRS


# ---------- Entrées ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		hud.on_escape()
		return
	if not playing or hud.is_modal_open():
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			try_descend()
		KEY_F:
			hud.open_forge()


func _key_dir() -> Vector2i:
	if touch_dir != Vector2i.ZERO:
		return touch_dir
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		return Vector2i.UP
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		return Vector2i.DOWN
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		return Vector2i.LEFT
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _process(delta: float) -> void:
	cooldown -= delta
	if move_t < 1.0:
		move_t = minf(1.0, move_t + delta / MOVE_TIME)
	swing = maxf(0.0, swing - delta * 5.0)
	if playing and not hud.is_modal_open():
		var d := _key_dir()
		if d != Vector2i.ZERO and cooldown <= 0.0:
			_act(d)
	camera.position = player_pos()
	save_timer += delta
	if dirty and save_timer > 5.0:
		save_game()
	world.queue_redraw()


func player_pos() -> Vector2:
	var target := Vector2(player) * TS + Vector2(TS, TS) * 0.5
	if move_t >= 1.0:
		return target
	var t := move_t * move_t * (3.0 - 2.0 * move_t)
	return move_from.lerp(target, t)


# ---------- Actions ----------

func _act(d: Vector2i) -> void:
	facing = d
	var t := player + d
	if not in_bounds(t):
		return
	var k := idx(t)
	var tile: int = map[k]
	match tile:
		GameData.FLOOR, GameData.OPENED, GameData.STAIRS:
			move_from = player_pos()
			move_t = 0.0
			player = t
			cooldown = MOVE_TIME
			dirty = true
			update_fov()
			hud.refresh()
			if tile == GameData.STAIRS and not stairs_hint_shown:
				stairs_hint_shown = true
				hud.toast("Un escalier ! Appuie sur « Descendre » (ou Entrée).")
		GameData.CHEST:
			_open_chest(k, t)
			cooldown = 0.35
		GameData.BEDROCK:
			hud.toast("Cette roche est indestructible.")
			cooldown = 0.5
		_:
			_mine(k, t, tile)


func _mine(k: int, t: Vector2i, tile: int) -> void:
	var block: Dictionary = GameData.BLOCKS[tile]
	var pick: Dictionary = GameData.PICKAXES[pick_level]
	if int(pick["tier"]) < int(block["tier"]):
		hud.toast("Le %s est trop dur : il faut au moins une pioche en %s." % [
			String(block["name"]).to_lower(), GameData.TIER_NAMES[block["tier"]]])
		cooldown = 0.6
		return
	swing = 1.0
	cooldown = MINE_TIME
	var dmg: int = int(damage.get(k, 0)) + int(pick["power"])
	world.spawn_chips(t, block["color"], 4)
	if dmg < int(block["hp"]):
		damage[k] = dmg
		return
	damage.erase(k)
	map[k] = GameData.FLOOR
	dirty = true
	world.spawn_chips(t, block["color"], 12)
	if block.has("res"):
		var n := randi_range(block["min"], block["max"])
		if pick_level >= 3 and randf() < 0.5:
			n += 1
		inv[block["res"]] += n
		world.float_text(t, "+%d %s" % [n, block["name"]], block["color"])
	update_fov()
	hud.refresh()


func _open_chest(k: int, t: Vector2i) -> void:
	map[k] = GameData.OPENED
	chests_opened += 1
	var gains := {}
	var rolls := 2 + (1 if randf() < 0.35 else 0)
	var weights := GameData.ore_weights(floor_num + 1)
	for i in rolls:
		var ore := GameData.pick_weighted(weights)
		var res: String = GameData.BLOCKS[ore]["res"]
		@warning_ignore("integer_division")
		var n := randi_range(2, 4) + floor_num / 2
		gains[res] = int(gains.get(res, 0)) + n
	var parts := PackedStringArray()
	var line := 0
	for res in gains:
		inv[res] += gains[res]
		var res_name: String = GameData.RESOURCES[res]["name"]
		parts.append("%d %s" % [gains[res], res_name.to_lower()])
		world.float_text(t, "+%d %s" % [gains[res], res_name], GameData.RESOURCES[res]["color"], line)
		line += 1
	var msg := "Coffre : " + ", ".join(parts)
	if light_radius < 8 and randf() < 0.2:
		light_radius += 1
		update_fov()
		msg += ", et une mèche de lanterne (+1 lumière) !"
	world.spawn_chips(t, Color(1.0, 0.8, 0.3), 14)
	hud.toast(msg)
	hud.refresh()
	save_game()


# ---------- Forge ----------

func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if int(inv[res]) < int(cost[res]):
			return false
	return true


func can_upgrade() -> bool:
	var next := pick_level + 1
	return next < GameData.PICKAXES.size() and can_afford(GameData.PICKAXES[next]["cost"])


func upgrade_pickaxe() -> void:
	if not can_upgrade():
		return
	pick_level += 1
	var pick: Dictionary = GameData.PICKAXES[pick_level]
	var cost: Dictionary = pick["cost"]
	for res in cost:
		inv[res] -= cost[res]
	hud.refresh()
	hud.toast("Tu as forgé une %s !" % String(pick["name"]).to_lower())
	save_game()


# ---------- Vision ----------

func update_fov() -> void:
	lit.fill(0)
	var r := light_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r + r:
				continue
			var t := player + Vector2i(dx, dy)
			if in_bounds(t) and _line_of_sight(player, t):
				var k := idx(t)
				lit[k] = 1
				seen[k] = 1


func _line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		if x == b.x and y == b.y:
			return true
		if (x != a.x or y != a.y) and not is_transparent(map[y * w + x]):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


func is_transparent(tile: int) -> bool:
	return tile == GameData.FLOOR or tile == GameData.OPENED or tile == GameData.STAIRS or tile == GameData.CHEST


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h


func idx(t: Vector2i) -> int:
	return t.y * w + t.x


# ---------- Sauvegarde ----------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if not playing:
		return
	var data := {
		"floor": floor_num, "deepest": deepest, "chests": chests_opened, "inv": inv,
		"pick": pick_level, "light": light_radius, "w": w, "h": h,
		"map": Marshalls.raw_to_base64(map), "seen": Marshalls.raw_to_base64(seen),
		"px": player.x, "py": player.y,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	dirty = false
	save_timer = 0.0


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var lw := int(d.get("w", 0))
	var lh := int(d.get("h", 0))
	var lmap := Marshalls.base64_to_raw(String(d.get("map", "")))
	var lseen := Marshalls.base64_to_raw(String(d.get("seen", "")))
	if lw <= 0 or lh <= 0 or lmap.size() != lw * lh or lseen.size() != lw * lh:
		return false
	floor_num = int(d.get("floor", 1))
	deepest = int(d.get("deepest", floor_num))
	chests_opened = int(d.get("chests", 0))
	var linv: Dictionary = d.get("inv", {})
	for res in inv:
		inv[res] = int(linv.get(res, 0))
	pick_level = clampi(int(d.get("pick", 0)), 0, GameData.PICKAXES.size() - 1)
	light_radius = clampi(int(d.get("light", 4)), 3, 8)
	w = lw
	h = lh
	map = lmap
	seen = lseen
	lit = PackedByteArray()
	lit.resize(w * h)
	damage.clear()
	player = Vector2i(int(d.get("px", 1)), int(d.get("py", 1)))
	move_t = 1.0
	stairs_hint_shown = true
	update_fov()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()
