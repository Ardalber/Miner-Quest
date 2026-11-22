class_name CaveGenerator
extends RefCounted
## Génère un étage de grotte : galeries naturelles (automate cellulaire),
## escalier le plus loin possible du départ, coffres dans les recoins et filons.


static func generate(floor_num: int) -> Dictionary:
	for attempt in 200:
		var result := _try(floor_num)
		if not result.is_empty():
			return result
	return _try(floor_num, true)


static func _try(floor_num: int, force := false) -> Dictionary:
	var w: int = mini(64, 32 + floor_num * 2)
	var h: int = mini(48, 24 + floor_num * 2)
	var size := w * h

	# 1. Bruit aléatoire puis lissage : donne des galeries organiques.
	var g := PackedByteArray()
	g.resize(size)
	for y in h:
		for x in w:
			var border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			g[y * w + x] = 1 if border or randf() < 0.46 else 0
	for it in 5:
		var n := PackedByteArray()
		n.resize(size)
		for y in h:
			for x in w:
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					n[y * w + x] = 1
					continue
				var c := 0
				for j in range(-1, 2):
					for i in range(-1, 2):
						c += g[(y + j) * w + x + i]
				n[y * w + x] = 1 if c >= 5 else 0
		g = n

	# 2. On garde seulement la plus grande zone connectée.
	var region := PackedInt32Array()
	region.resize(size)
	region.fill(-1)
	var best := -1
	var best_size := 0
	var rid := 0
	for k in size:
		if g[k] != 0 or region[k] >= 0:
			continue
		var count := 0
		var stack: Array[int] = [k]
		region[k] = rid
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			count += 1
			for nb in neighbors4(cur, w, h):
				if g[nb] == 0 and region[nb] < 0:
					region[nb] = rid
					stack.push_back(nb)
		if count > best_size:
			best_size = count
			best = rid
		rid += 1
	if best_size < size * 0.33 and not force:
		return {}

	var map := PackedByteArray()
	map.resize(size)
	var floors: Array[int] = []
	for k in size:
		var x := k % w
		@warning_ignore("integer_division")
		var y := k / w
		if x == 0 or y == 0 or x == w - 1 or y == h - 1:
			map[k] = GameData.BEDROCK
		elif g[k] == 0 and region[k] == best:
			map[k] = GameData.FLOOR
			floors.append(k)
		else:
			map[k] = GameData.STONE
	if floors.size() < 2:
		return {}

	# 3. Départ au hasard, escalier sur la case la plus éloignée.
	var start: int = floors.pick_random()
	var dist := bfs(map, w, h, start)
	var stairs := start
	for k in floors:
		if dist[k] > dist[stairs]:
			stairs = k
	if dist[stairs] < 18 and not force:
		return {}
	map[stairs] = GameData.STAIRS

	# 4. Coffres, de préférence dans les recoins.
	var chest_count := mini(8, 3 + floor_num / 2)
	var nooks: Array[int] = []
	var others: Array[int] = []
	for k in floors:
		if k == stairs or dist[k] < 5:
			continue
		var walls := 0
		for nb in neighbors8(k, w, h):
			if map[nb] != GameData.FLOOR and map[nb] != GameData.STAIRS:
				walls += 1
		if walls >= 5:
			nooks.append(k)
		else:
			others.append(k)
	nooks.shuffle()
	others.shuffle()
	var spots := nooks + others
	var placed := 0
	for k in spots:
		if placed >= chest_count:
			break
		var near_chest := false
		for nb in neighbors8(k, w, h):
			if map[nb] == GameData.CHEST:
				near_chest = true
		if near_chest:
			continue
		map[k] = GameData.CHEST
		placed += 1

	# 5. Filons de minerai, surtout le long des galeries.
	var weights := GameData.ore_weights(floor_num)
	var exposed: Array[int] = []
	var buried: Array[int] = []
	for k in size:
		if map[k] != GameData.STONE:
			continue
		var touches_floor := false
		for nb in neighbors4(k, w, h):
			if map[nb] == GameData.FLOOR:
				touches_floor = true
		if touches_floor:
			exposed.append(k)
		else:
			buried.append(k)
	for v in roundi(exposed.size() * 0.07):
		_vein(map, w, h, exposed.pick_random(), GameData.pick_weighted(weights), randi_range(1, 4))
	if not buried.is_empty():
		for v in roundi(buried.size() * 0.02):
			_vein(map, w, h, buried.pick_random(), GameData.pick_weighted(weights), randi_range(2, 5))

	return {"w": w, "h": h, "map": map, "start": Vector2i(start % w, start / w)}


static func _vein(map: PackedByteArray, w: int, h: int, k: int, ore: int, length: int) -> void:
	var cur := k
	for s in length:
		if map[cur] == GameData.STONE:
			map[cur] = ore
		var nbs := neighbors4(cur, w, h)
		var next: int = nbs.pick_random()
		if map[next] == GameData.BEDROCK:
			break
		cur = next


static func bfs(map: PackedByteArray, w: int, h: int, start: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	dist[start] = 0
	var queue: Array[int] = [start]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for nb in neighbors4(cur, w, h):
			if dist[nb] < 0 and map[nb] == GameData.FLOOR:
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist


static func neighbors4(k: int, w: int, h: int) -> Array[int]:
	var out: Array[int] = []
	var x := k % w
	@warning_ignore("integer_division")
	var y := k / w
	if x > 0:
		out.append(k - 1)
	if x < w - 1:
		out.append(k + 1)
	if y > 0:
		out.append(k - w)
	if y < h - 1:
		out.append(k + w)
	return out


static func neighbors8(k: int, w: int, h: int) -> Array[int]:
	var out: Array[int] = []
	var x := k % w
	@warning_ignore("integer_division")
	var y := k / w
	for j in range(-1, 2):
		for i in range(-1, 2):
			if i == 0 and j == 0:
				continue
			var nx := x + i
			var ny := y + j
			if nx >= 0 and ny >= 0 and nx < w and ny < h:
				out.append(ny * w + nx)
	return out
