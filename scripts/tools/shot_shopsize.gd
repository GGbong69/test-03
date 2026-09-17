extends SceneTree
# 테이블 위 물건 크기 점검 — 여섯 갈래를 한 줄로 세운 사진 한 장과,
# 매물 6~9개를 물리로 떨어뜨린 상점 여러 판.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_shopsize.gd
#
# 판마다 재는 것 (창이 없어도 잰다 — 사진만 건너뛴다)
#   겹침      충돌 원끼리 파고든 최대 깊이(면px). 0.5 넘으면 실패
#   트레이    벽 밖으로 나간 물건 수
#   표적      _shop_hit 로 2px 격자를 훑어 가장 작게 잡히는 물건의 면적
#   윗끝      _obj_box 윗변이 카운터(TBL.fy) 위로 올라간 물건 수
#   빗변      _obj_box 가 창구 빗변을 넘은 물건 수
#   값        값표끼리 겹친 쌍 · 앞 레일(TBL.ny) 밑으로 내려간 값 · 몸통에 덮인 값
#
# game.gd 의 배율 상수를 안 읽는다 — 배율을 넣기 전 코드에서도 똑같이 돌아
# 전·후 사진을 같은 자리에서 뜬다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const ROLLS := 60
const SHOTS := 5
const RSEED := 20260917
var g = null
var busy := false
var fails := 0


func _initialize() -> void:
	Save.gpath = "user://_shot_size_g.cfg"
	Save.path = "user://_shot_size.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _quiet() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	g.mouse_at = Vector2(-50.0, -50.0)
	g.tip_a = 0.0
	g.tip_spot = -1


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-26s %s" % ["통과" if ok else "실패", name, detail])
	if not ok:
		fails += 1


# 갈래 여섯에서 고르게 뽑는다. 실제 저울은 사진·팩이 드물어 60판에 한 번도
# 안 뜨므로, 크기 점검은 갈래를 고르게 섞는다.
func _stock(n: int) -> void:
	g.stock.clear()
	var pools := {
		"item": GameData.items().duplicate(),
		"mod": GameData.mods().duplicate(),
		"dart": GameData.darts().slice(1),
		"cons": GameData.candies().duplicate(),
		"fix": GameData.fixtures().duplicate(),
		"boost": GameData.boosters().duplicate(),
	}
	var kinds := ["item", "item", "mod", "dart", "cons", "fix", "boost"]
	while g.stock.size() < n:
		var k: String = kinds[randi() % kinds.size()]
		var pool: Array = pools[k]
		if pool.is_empty():
			continue
		var d: Dictionary = pool[randi() % pool.size()]
		pool.erase(d)
		g.stock.append({"type": k, "d": d, "cost": 3 + randi() % 12, "sold": false})
	# 팩에서 쏟은 것 — 값 대신 「고르기」 가 7 더 밑에 선다. 가장 낮은 글줄이다.
	if randf() < 0.4:
		for j in 2:
			var s: Dictionary = g.stock[randi() % n]
			s["pack"] = true
			s.cost = 0


func _measure() -> Dictionary:
	var pen := 0.0
	var oob := 0
	var drop: Array = g.drop
	for a in drop.size():
		var A: Dictionary = drop[a]
		if A.gone:
			continue
		if A.u < g.DROP.u_lo + A.hw - 0.01 or A.u > g.DROP.u_hi - A.hw + 0.01 \
				or A.w < g.DROP.w_lo - 0.01 or A.w > g.DROP.w_hi + 0.01:
			oob += 1
		for b in range(a + 1, drop.size()):
			var B: Dictionary = drop[b]
			for ia in int(A.nb):
				for ib in int(B.nb):
					pen = maxf(pen, A.r + B.r
							- g._drop_sub(A, ia).distance_to(g._drop_sub(B, ib)))
	var area := []
	area.resize(drop.size())
	area.fill(0)
	var y := 100.0
	while y < 270.0:
		var x := 1.0
		while x < 640.0:
			var hi: int = g._shop_hit(Vector2(x, y))
			if hi >= 0:
				area[hi] += 4
			x += 2.0
		y += 2.0
	var mn := 1 << 30
	for i in area.size():
		mn = mini(mn, area[i])
	var top := 0
	var rim := 0
	var tmin := 999.0
	for i in drop.size():
		var bx: Rect2 = g._obj_box(i)
		tmin = minf(tmin, bx.position.y)
		if bx.position.y < g.TBL.fy:
			top += 1
		var e: float = g._chute_edge(bx.end.y)
		if bx.position.x < e or bx.end.x > 640.0 - e:
			rim += 1
	# 값표 — _bills_draw 의 자리 잡기를 그대로 돈다(그리지는 않는다).
	var z: Array = g._z_order()
	var order := z.duplicate()
	order.reverse()
	var placed := []
	var low := 0
	var covered := 0
	var lowest := 0.0
	for i in order:
		var r: Rect2 = g._bill_place(i, z, placed)
		if g._bill_block(i, r, z, placed) > 0:
			covered += 1
		placed.append(r)
		lowest = maxf(lowest, r.end.y)
		if r.end.y > g.TBL.ny:
			low += 1
	var clash := 0
	for a in placed.size():
		for b in range(a + 1, placed.size()):
			if (placed[a] as Rect2).intersects(placed[b]):
				clash += 1
	return {"pen": pen, "oob": oob, "area": mn, "top": top, "tmin": tmin,
			"rim": rim, "clash": clash, "low": low, "covered": covered,
			"lowest": lowest}


func _run() -> void:
	await _wait(10)
	var win: bool = DisplayServer.get_name() != "headless"
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	_quiet()

	# ── ① 한 줄로 세운 여섯 갈래 ─────────────────────────
	g.stock.clear()
	g.stock.append({"type": "item", "d": GameData.items()[0], "cost": 4, "sold": false})
	g.stock.append({"type": "mod", "d": GameData.mods()[0], "cost": 5, "sold": false})
	g.stock.append({"type": "dart", "d": GameData.darts()[1], "cost": 5, "sold": false})
	g.stock.append({"type": "cons", "d": GameData.candies()[0], "cost": 3, "sold": false})
	g.stock.append({"type": "fix", "d": GameData.fixtures()[0], "cost": 4, "sold": false})
	g.stock.append({"type": "boost", "d": GameData.boosters()[0], "cost": 4, "sold": false})
	g._drop_roll()
	g._drop_settle()
	await _wait(5)
	g.set_process(false)
	var us := [145.0, 215.0, 285.0, 355.0, 425.0, 495.0]
	var ps := [0.3, 0.0, 0.55, 0.0, 0.15, -0.15]
	for f in 8:
		for k in 6:
			var d: Dictionary = g.drop[k]
			d.u = us[k]
			d.w = 62.0
			d.h = 0.0
			d.lift = 0.0
			d.wob = 0.0
			d.wv = 0.0
			d.roll = 0.0
			d.psi = ps[k]
			d.into = true
			d.air = false
			d.sleep = true
		_quiet()
		g.queue_redraw()
		await process_frame
	if win:
		root.get_texture().get_image().save_png("res://shots/shopsize_line.png")
	for k in 6:
		var bx: Rect2 = g._obj_box(k)
		print("  %-6s 화면 %.0f x %.0f px" % [String(g.stock[k].type), bx.size.x, bx.size.y])
	#  손에 든 동전 — 자리 고리(it.r)와 몸통이 같은 크기로 도는가
	g.hand_st = g.H.CARRY
	g.hand_src = 0
	g.hand_i = 0
	g.hand_zone = -1
	g.drop[0].held = true
	g.drop[0].u = 200.0
	g.drop[0].w = 104.0
	for f in 3:
		_quiet()
		g.queue_redraw()
		await process_frame
	if win:
		root.get_texture().get_image().save_png("res://shots/shopsize_carry.png")
	g.drop[0].held = false
	g.hand_st = g.H.NONE
	g.hand_i = -1
	g.set_process(true)

	# ── ② 물리로 떨어뜨린 상점 ─────────────────────────────
	var worst := {"pen": 0.0, "oob": 0, "area": 1 << 30, "top": 0, "tmin": 999.0,
			"rim": 0, "clash": 0, "low": 0, "covered": 0, "lowest": 0.0}
	for r in ROLLS:
		seed(RSEED + r)
		var n: int = 6 + (r % 4)
		_stock(n)
		g._drop_roll()
		g._drop_settle()
		var m := _measure()
		worst.pen = maxf(worst.pen, m.pen)
		worst.oob += m.oob
		worst.area = mini(worst.area, m.area)
		worst.top += m.top
		worst.tmin = minf(worst.tmin, m.tmin)
		worst.rim += m.rim
		worst.clash += m.clash
		worst.low += m.low
		worst.covered += m.covered
		worst.lowest = maxf(worst.lowest, m.lowest)
		if r < SHOTS and win:
			for f in 6:
				_quiet()
				g.queue_redraw()
				await process_frame
			root.get_texture().get_image().save_png("res://shots/shopsize_%d.png" % r)
			print("  판 %d · 매물 %d · 겹침 %.2f · 최소표적 %d · 값 겹침 %d · 덮인 값 %d"
					% [r, n, m.pen, m.area, m.clash, m.covered])
	print("  ── %d판 ──" % ROLLS)
	_say(worst.pen <= 0.5, "물건끼리 안 파고든다", "최대 %.3f 면px" % worst.pen)
	_say(worst.oob == 0, "트레이 안에 앉는다", "밖 %d" % worst.oob)
	_say(worst.area >= 200, "전부 잡힌다", "최소 표적 %d px²" % worst.area)
	_say(worst.rim == 0, "창구 빗변을 안 넘는다", "넘은 것 %d" % worst.rim)
	_say(worst.clash == 0, "값표끼리 안 겹친다", "겹친 쌍 %d" % worst.clash)
	_say(worst.low == 0, "값이 앞 레일 위에 선다",
			"가장 낮은 값 아래끝 %.1f (레일 %.0f)" % [worst.lowest, g.TBL.ny])
	print("  참고 — 박스 윗변이 카운터 위로 %d개 (가장 높은 %.1f · 카운터 %.0f) · 몸통에 덮인 값 %d"
			% [worst.top, worst.tmin, g.TBL.fy, worst.covered])
	print("통과 %d · 실패 %d" % [6 - fails, fails])
	quit(fails)
