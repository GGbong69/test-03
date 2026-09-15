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
	var gv: Dictionary = g.GIVE
	var tot: float = float(gv.take) + float(gv.look) + float(gv.set) + float(gv.fling)
	#  give_t 로 잰다. 내 프레임 수로 세면 렌더가 늦는 만큼 앞서 나가서
	#  마지막 두 장을 놓친다(실측). 끝나면 give_t 가 0 이 되므로 그 뒤는
	#  _give_live 로 가른다 — 뿌리고 난 뒤가 이 연출의 절반이다.
	var marks := [0.30, 0.58, 0.80, 0.93]
	var done := 0
	while g._give_live() and done < marks.size():
		await process_frame
		if g.give_t >= tot * float(marks[done]):
			await _shot("give_%d" % (done + 1))
			print("%d  t %.2f  h %.1f  u %.0f" % [done + 1, g.give_t, it.h, it.u])
			done += 1
	while g._give_live():
		await process_frame
	await _shot("give_5")
	print("5  뿌린 직후  u %.0f  vu %+.0f vw %+.0f" % [it.u, it.vu, it.vw])
	for k in 30:
		await process_frame
	await _shot("give_6")
	print("끝 · 손 %d · u %.0f (준 자리 %.0f)" % [g.give_side, it.u, g.give_from.x])
	quit(0)
