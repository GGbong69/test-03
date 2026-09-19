extends SceneTree
# 이어하기를 눈으로 본다 — 흐린 줄 · 산 줄 · 겨눈 확정.
#   godot --path . --quit-after 900 --script scripts/tools/shot_resume.gd
#
# 창이 있어야 돈다(--headless 를 빼고 --quit-after 로 감싼다). shot_title 과
# 같은 어법이다 — 게임 시계를 손으로 밀고, 찍는 두 프레임 동안 커서를 다시 박는다.
#
# 보는 것 넷
#   ① 다섯 줄이 프로필 패를 안 먹는가 (y 154~300 · 패 318)
#   ② 이어할 것이 없을 때 「계속하기」가 **흐린가** — 띠도 글자도
#   ③ 있을 때 얹히면 사는가
#   ④ 새 런 확정을 한 번 누르면 **붉게 서는가** (겨눔 채널 넷)
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(4.0, 4.0)        # 찍는 동안 붙들어 둘 커서 자리


func _initialize() -> void:
	#  ⚠ 제 자리를 박는다 — 사람 프로필은 한 글자도 안 건드린다.
	Save.gpath = "user://_shot_rsm_g.cfg"
	Save.path = "user://_shot_rsm.cfg"
	Save.wipe()
	Save.run_drop()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _step(n: int) -> void:
	for i in n:
		g._title_tick(1.0 / 60.0)
		g._set_tick(1.0 / 60.0)
	await process_frame


func _shot(nm: String) -> void:
	g.mouse_at = pin
	g.queue_redraw()
	await process_frame
	g.mouse_at = pin
	g.queue_redraw()
	await process_frame
	g.mouse_at = pin
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  찍음 — %s" % nm)


func _title() -> void:
	g.state = g.S.TITLE
	g.pause_from = -1
	g.ttl_stuck.clear()
	g.ttl_fly.clear()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return

	# ① 이어할 것이 없다 — 「계속하기」가 흐리다
	_title()
	pin = Vector2(4.0, 4.0)
	await _step(30)
	await _shot("rsm_0_none")

	# ② 흐린 줄에 얹혀도 안 산다
	pin = g._menu_rect(g.TTL_RESUME).get_center()
	await _step(30)
	await _shot("rsm_1_none_hover")

	# ③ 런이 서면 줄이 산다
	g._new_run()
	_title()
	pin = g._menu_rect(g.TTL_RESUME).get_center()
	await _step(30)
	await _shot("rsm_2_live_hover")

	# ④ 옆줄에 얹은 평소 모습 — 띠가 한 줄만 서는지 본다
	pin = g._menu_rect(0).get_center()
	await _step(30)
	await _shot("rsm_3_live_start")

	# ⑤ 새 런 화면 — 평소
	g._open_newrun()
	pin = Vector2(4.0, 4.0)
	await _step(30)
	await _shot("rsm_4_newrun")

	# ⑥ 확정을 한 번 누르면 겨눈다 — 붉은 띠 · 굵은 마침표 · 짙어진 글자
	g._click(g._newrun_go().get_center())
	pin = g._newrun_go().get_center()
	await _step(4)
	await _shot("rsm_5_armed")
	print("  겨눔 %s" % g.start_arm)

	# ⑦ 되살린 자리가 그냥 선다 — 「이어서 하는 중」이라는 표시를 안 단다.
	#    이어진 런은 그냥 런이다.
	_title()
	g._run_load()
	pin = Vector2(4.0, 4.0)
	await _wait(30)
	await _shot("rsm_6_resumed")
	print("  되살린 자리 state=%d · 판 %d · %d골드" % [g.state, g.leg_no, g.gold])
	quit(0)
