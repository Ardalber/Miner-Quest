extends CanvasLayer
## Interface : barre du haut, messages, forge, menu et croix directionnelle tactile.

const GOLD := Color(0.95, 0.75, 0.3)
const TEXT := Color(1.0, 0.93, 0.8)

var game: Node2D
var root: Control
var floor_label: Label
var pick_label: Label
var res_labels := {}
var forge_btn: Button
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var descend_btn: Button
var dpad: Control
var forge_panel: Control
var forge_list: VBoxContainer
var title_panel: Control
var title_stats: Label
var continue_btn: Button
var resume_btn: Button
var new_btn: Button
var new_armed := false


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top_bar()
	_build_toast()
	_build_descend()
	_build_dpad()
	_build_forge()
	_build_title()


# ---------- Construction ----------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var panel := _box(Color(0.15, 0.1, 0.07, 0.96), GOLD, 2, 12)
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _box(Color(0.38, 0.25, 0.13), GOLD, 2, 8))
	t.set_stylebox("hover", "Button", _box(Color(0.48, 0.32, 0.17), GOLD, 2, 8))
	t.set_stylebox("pressed", "Button", _box(Color(0.27, 0.17, 0.09), GOLD, 2, 8))
	t.set_stylebox("disabled", "Button", _box(Color(0.22, 0.19, 0.17), Color(0.4, 0.35, 0.3), 2, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	t.set_color("font_color", "Label", TEXT)
	return t


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var sb := _box(Color(0.08, 0.05, 0.04, 0.88), GOLD, 0, 0)
	sb.border_width_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	bar.add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	rows.add_child(top)
	floor_label = Label.new()
	floor_label.add_theme_color_override("font_color", GOLD)
	top.add_child(floor_label)
	pick_label = Label.new()
	pick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_label.clip_text = true
	top.add_child(pick_label)
	forge_btn = _button("Forge", open_forge)
	top.add_child(forge_btn)
	top.add_child(_button("Menu", open_menu))

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 26)
	rows.add_child(res_row)
	for res in ["copper", "iron", "gold"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		var icon := Panel.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var isb := _box(GameData.RESOURCES[res]["color"], Color(0, 0, 0, 0.5), 2, 10)
		icon.add_theme_stylebox_override("panel", isb)
		item.add_child(icon)
		var lbl := Label.new()
		item.add_child(lbl)
		var name_lbl := Label.new()
		name_lbl.text = GameData.RESOURCES[res]["name"]
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
		name_lbl.add_theme_font_size_override("font_size", 18)
		item.add_child(name_lbl)
		res_row.add_child(item)
		res_labels[res] = lbl


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.offset_left = -320
	toast_panel.offset_right = 320
	toast_panel.offset_top = 112
	toast_panel.visible = false
	root.add_child(toast_panel)
	toast_label = Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_panel.add_child(toast_label)


func _build_descend() -> void:
	descend_btn = _button("Descendre", func(): game.try_descend())
	descend_btn.add_theme_font_size_override("font_size", 28)
	descend_btn.anchor_left = 1.0
	descend_btn.anchor_right = 1.0
	descend_btn.anchor_top = 1.0
	descend_btn.anchor_bottom = 1.0
	descend_btn.offset_left = -250
	descend_btn.offset_right = -24
	descend_btn.offset_top = -110
	descend_btn.offset_bottom = -30
	descend_btn.visible = false
	root.add_child(descend_btn)


func _build_dpad() -> void:
	dpad = Control.new()
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 20
	dpad.offset_right = 20 + 3 * 92
	dpad.offset_top = -(3 * 92) - 24
	dpad.offset_bottom = -24
	dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad.visible = DisplayServer.is_touchscreen_available()
	root.add_child(dpad)
	var dirs := [[Vector2i.UP, Vector2(1, 0)], [Vector2i.LEFT, Vector2(0, 1)],
		[Vector2i.RIGHT, Vector2(2, 1)], [Vector2i.DOWN, Vector2(1, 2)]]
	for entry in dirs:
		var d: Vector2i = entry[0]
		var cell: Vector2 = entry[1]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = _arrow_texture(d)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.position = cell * 92
		b.size = Vector2(86, 86)
		b.modulate = Color(1, 1, 1, 0.8)
		b.button_down.connect(func(): game.touch_dir = d)
		b.button_up.connect(func():
			if game.touch_dir == d:
				game.touch_dir = Vector2i.ZERO)
		dpad.add_child(b)


func _arrow_texture(d: Vector2i) -> ImageTexture:
	var s := 40
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in s:
		for x in s:
			# triangle pointant vers le haut, puis tourné selon la direction
			var u := float(x) / s - 0.5
			var v := float(y) / s - 0.5
			var p := Vector2(u, v)
			if d == Vector2i.DOWN:
				p = Vector2(u, -v)
			elif d == Vector2i.LEFT:
				p = Vector2(v, u)
			elif d == Vector2i.RIGHT:
				p = Vector2(v, -u)
			if p.y > -0.3 and p.y < 0.25 and absf(p.x) < (p.y + 0.3) * 0.75:
				img.set_pixel(x, y, TEXT)
	return ImageTexture.create_from_image(img)


func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0, 0, 0, 0.65)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	root.add_child(o)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	return o


func _build_forge() -> void:
	forge_panel = _overlay()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	forge_panel.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Forge : améliorer la pioche"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	forge_list = VBoxContainer.new()
	forge_list.add_theme_constant_override("separation", 10)
	box.add_child(forge_list)
	box.add_child(_button("Fermer", close_forge))


func _build_title() -> void:
	title_panel = _overlay()
	title_panel.color = Color(0.02, 0.01, 0.01, 0.82)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	title_panel.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "MINER QUEST"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.05))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 19)
	info.text = "Explore la grotte, mine le cuivre, le fer et l'or, fouille les coffres " \
		+ "et améliore ta pioche à la forge. Trouve l'escalier pour descendre d'un étage.\n\n" \
		+ "Clavier : flèches ou ZQSD pour avancer et miner, Entrée pour descendre, F pour la forge.\n" \
		+ "Téléphone : croix directionnelle et bouton Descendre."
	box.add_child(info)
	title_stats = Label.new()
	title_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_stats.add_theme_color_override("font_color", GOLD)
	box.add_child(title_stats)
	resume_btn = _button("Reprendre", _on_resume)
	box.add_child(resume_btn)
	continue_btn = _button("Continuer la partie", _on_continue)
	box.add_child(continue_btn)
	new_btn = _button("Nouvelle partie", _on_new)
	box.add_child(new_btn)


# ---------- Mise à jour ----------

func refresh() -> void:
	if floor_label == null:
		return
	floor_label.text = "Étage %d" % game.floor_num
	var pick: Dictionary = GameData.PICKAXES[game.pick_level]
	pick_label.text = pick["name"]
	pick_label.add_theme_color_override("font_color", pick["color"])
	for res in res_labels:
		res_labels[res].text = str(game.inv[res])
	descend_btn.visible = game.playing and game.on_stairs()
	var can_up: bool = game.can_upgrade()
	forge_btn.text = "Forge !" if can_up else "Forge"
	forge_btn.modulate = Color(1.3, 1.15, 0.7) if can_up else Color.WHITE
	if forge_panel.visible:
		_fill_forge()


func toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.6)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func(): toast_panel.visible = false)


func is_modal_open() -> bool:
	return forge_panel.visible or title_panel.visible


func on_escape() -> void:
	if forge_panel.visible:
		close_forge()
	elif title_panel.visible and resume_btn.visible:
		_on_resume()
	elif not title_panel.visible and game.playing:
		open_menu()


# ---------- Forge ----------

func open_forge() -> void:
	if not game.playing:
		return
	game.touch_dir = Vector2i.ZERO
	_fill_forge()
	forge_panel.visible = true


func close_forge() -> void:
	forge_panel.visible = false


func _fill_forge() -> void:
	for c in forge_list.get_children():
		c.queue_free()
	var ores := ["le cuivre", "le cuivre et le fer", "le cuivre, le fer et l'or"]
	for i in GameData.PICKAXES.size():
		var pick: Dictionary = GameData.PICKAXES[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s  (force %d)" % [pick["name"], pick["power"]]
		name_lbl.add_theme_color_override("font_color", pick["color"])
		text.add_child(name_lbl)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size", 17)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = "Mine %s." % ores[pick["tier"]]
		if i > game.pick_level:
			detail.text += "  Coût : %s" % GameData.cost_text(pick["cost"])
		text.add_child(detail)
		row.add_child(text)
		if i == game.pick_level:
			var lbl := Label.new()
			lbl.text = "Équipée"
			lbl.add_theme_color_override("font_color", GOLD)
			row.add_child(lbl)
		elif i < game.pick_level:
			var lbl := Label.new()
			lbl.text = "Déjà forgée"
			lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
			row.add_child(lbl)
		elif i == game.pick_level + 1:
			var b := _button("Forger", func(): game.upgrade_pickaxe())
			b.disabled = not game.can_afford(pick["cost"])
			row.add_child(b)
		else:
			var lbl := Label.new()
			lbl.text = "Verrouillée"
			lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
			row.add_child(lbl)
		forge_list.add_child(row)


# ---------- Écran titre et menu ----------

func show_title(has_save: bool) -> void:
	continue_btn.visible = has_save
	resume_btn.visible = false
	_reset_new_btn()
	title_stats.text = _stats_text() if has_save else ""
	title_panel.visible = true


func open_menu() -> void:
	game.touch_dir = Vector2i.ZERO
	game.save_game()
	continue_btn.visible = false
	resume_btn.visible = true
	_reset_new_btn()
	title_stats.text = _stats_text()
	title_panel.visible = true


func _stats_text() -> String:
	return "Étage %d · record : étage %d · coffres ouverts : %d" % [game.floor_num, game.deepest, game.chests_opened]


func _reset_new_btn() -> void:
	new_armed = false
	new_btn.text = "Nouvelle partie"


func _on_resume() -> void:
	title_panel.visible = false


func _on_continue() -> void:
	title_panel.visible = false
	game.continue_game()


func _on_new() -> void:
	if (game.playing or game.has_save()) and not new_armed:
		new_armed = true
		new_btn.text = "Confirmer : effacer la partie en cours ?"
		return
	title_panel.visible = false
	game.new_game()
