extends SceneTree
# 건네기 세 박자를 굽는다 — 내밀기 · 받기 · 살피기 · 돌려주기.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_give.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_give_g.cfg"
	Save.path = "user://_shot_give.cfg"
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

func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 60
	g.leg_no = 2
	g._open_shop()
	await _wait(70)
	# ① 내미는 예고 — 들고 카운터 위로 올라간 상태를 손으로 만든다
	#  제일 큰 물건을 고른다 — 작은 것은 사진에서 손에 묻혀 안 보인다.
	#  보드 확장·동전을 먼저 고른다 — 제일 크게 그려져서
	#  손과 겹치는 정도가 제일 잘 보이는 것들이다.
	var pick := 0
	for q in g.stock.size():
		if String(g.stock[q].type) == "mod":
			pick = q
			break
		if String(g.stock[q].type) == "item":
			pick = q
	var it: Dictionary = g.drop[pick]
	#  _hand_update 가 진짜 마우스 단추를 보고 손을 놓아 버려서
	#  드래그를 흔내 낼 수 없다. 예고는 그 값을 직접 세워 본다.
	g.npc_reach = 1.0
	g.npc_reach_side = g._npc_side(it.u)
	await _wait(4)
	await _shot("give_0")
	print("내밀기 reach %.2f 손 %d" % [g.npc_reach, g.npc_reach_side])
	g.npc_reach = 0.0
	# ② 건넨다
	g._give_begin(pick, Vector2(it.u, g.TBL.fy))
	var tot: float = float(g.GIVE.take) + float(g.GIVE.look) + float(g.GIVE.back)
	var marks := [0.26, 0.38, 0.50, 0.62, 0.74]
	var done := 0
	var t := 0.0
	while t < tot and done < marks.size():
		await process_frame
		t = g.give_t
		if t >= tot * float(marks[done]):
			await _shot("give_%d" % (done + 1))
			print("%d  t %.2f  h %.1f  w %.1f" % [done + 1, t, it.h, it.w])
			done += 1
	await _wait(20)
	await _shot("give_6")
	print("끝 · 던졌나 %s · vu %.0f vw %.0f" % [g.give_toss, it.vu, it.vw])
	quit(0)
