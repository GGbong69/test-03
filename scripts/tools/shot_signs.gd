extends SceneTree
# 판 고르기의 칠한 간판을 본다 — 첫 판 · 하나 깬 뒤 · 깨고 건너뛴 뒤(보스 앞).
# 이어서 간판 색 시안(sign_pal)마다 판 고르기와 제약 카드 화면을 한 장씩 찍는다.
#   godot --path . --quit-after 1800 --script scripts/tools/shot_signs.gd
#   → shots/sign_1..3.png · shots/signpal_{leg,boss,stage}_<n>.png
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_sign_g.cfg"
	Save.path = "user://_shot_sign.cfg"
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
		_hold()


#  세울 제약 카드. 선다는 판정은 툴팁(tip_a · tip_mark)을 읽고 툴팁은 진짜
#  마우스를 읽는다 — 커서를 옮기는 대신 _drop_update 가 읽기 직전에 매 프레임
#  툴팁 자리를 그 카드로 박는다. 설명 띠도 매 프레임 걷는다 — 떠 있는 동안은
#  딜 시계가 멎어 카드가 반쯤 미끄러진 채로 찍힌다.
var stand_i := -1


func _hold() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	if stand_i >= 0 and stand_i < g.stage_pick.size():
		g.tip_a = 1.0
		g.tip_mark = g._stage_rect(stand_i)


func _shot(nm: String) -> void:
	for i in 3:
		_hold()
		g.leg_t = 9.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _leg(no: int, skipped: Array) -> void:
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g._open_leg()


#  시안 수. 시안 표가 없던 때의 game.gd 에서도 돈다(하나로 친다).
func _pal_n() -> int:
	return g.SIGN_PALS.size() if "sign_pal" in g else 1


func _pal(n: int) -> void:
	if "sign_pal" in g:
		g.sign_pal = n


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	_pal(0)
	_leg(1, [])
	await _shot("sign_1")
	_leg(2, [])
	await _shot("sign_2")
	_leg(3, [2])
	await _shot("sign_3")
	#  딜 중 — 조각이 미끄러져 오는 동안에도 다각형이 안 깨지는가
	_leg(2, [])
	for t in [0.05, 0.15, 0.30]:
		for k in 2:
			g.leg_t = t
			g.swap_live = false
			g._tutor_close()
			g.queue_redraw()
			await process_frame
	#  시안마다 판 고르기 — 작은 판 깨짐 · 큰 판 섬 · 보스 누움
	#  보스 앞 — 작은 판 깨짐 · 큰 판 건너뜀(가라앉음) · 보스 섬
	for p in _pal_n():
		_pal(p)
		_leg(2, [])
		await _shot("signpal_leg_%d" % p)
		_leg(3, [2])
		await _shot("signpal_boss_%d" % p)
	#  제약 카드는 보스 판에서만 깔린다. 한 번만 깔고 시안만 바꿔 찍는다 —
	#  다시 깔면 뽑힌 제약이 달라져 나란히 못 본다.
	for lv in range(1, 30):
		if GameData.is_boss(lv):
			g.leg_no = lv
			break
	_pal(0)
	g._open_stage()
	await _wait(60)
	#  가운데 카드를 세운다
	stand_i = mini(1, g.stage_pick.size() - 1)
	await _wait(40)
	for p in _pal_n():
		_pal(p)
		await _shot("signpal_stage_%d" % p)
	#  딜 중 — 제약 간판도 미끄러져 오는 동안 안 깨지는가
	stand_i = -1
	for p in _pal_n():
		_pal(p)
		for t in [0.05, 0.2, 0.4]:
			g.stage_t = t
			g.swap_live = false
			g.queue_redraw()
			await process_frame
	print("  찍음 %d" % _pal_n())
	quit(0)
