extends SceneTree
#  동전의 죽음을 박자마다 굽는다.                        (2026-09-19)
#
#  **시계를 손으로 감는다**(g.set_process(false)). 창을 띄우고 프레임을
#  그냥 세면 한 프레임이 0.03초씩 들쭉날쭉이라 **언 흰 실루엣(0.045초)이
#  샘플 사이로 통째로 빠진다** — shot_smash 가 실제로 한 번 놓친 자리고,
#  이 연출은 그 한 수가 전부라 여기서도 같은 길을 쓴다.
#
#  창이 필요하다(--headless 를 뺀다):
#    godot --path . --quit-after 900 --script scripts/tools/shot_wreck.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

#  볼 자리(초). 꽂힘·언 프레임 → 날림 초입 → 한창 → 가라앉음 → 끝.
const AT := [0.033, 0.067, 0.117, 0.200, 0.300, 0.400, 0.550]


func _initialize() -> void:
	Save.gpath = "user://_shot_wr_g.cfg"
	Save.path = "user://_shot_wr.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _find(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return (it as Dictionary).duplicate(true)
	return {}


func _hold(ids: Array) -> void:
	g.owned.clear()
	g.sealed = -1
	for id in ids:
		var it := _find(String(id))
		it["bought"] = g.leg_no
		g.owned.append(it)
	g._panel_reset()
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0


#  손으로 감는 한 프레임. 게임의 _process 가 시체에 주는 그 줄만 민다.
#  **정산 시계도 같이 민다** — 내역 줄이 실제로 서야 왼쪽 띠가 표(좌변
#  190)와 10px 밖에 안 떨어진 그 자리를 진짜로 견줄 수 있다. 저쪽 층은
#  한 글자도 안 건드리고 값만 밀어 준다.
func _step(d: float) -> void:
	g._wreck_tick(d)
	if g.state == g.S.CLEAR:
		g.clear_t += d


func _reel(nm: String, ats: Array) -> void:
	var t := 0.0
	var fd := 1.0 / 60.0
	for k in ats.size():
		var want: float = float(ats[k])
		while t + fd * 0.5 < want:
			_step(fd)
			t += fd
		await _shot("%s_%d" % [nm, k])


func _run() -> void:
	g.set_process(false)
	g.leg_no = 7
	g.state = g.S.CLEAR
	g.clear_t = 0.0
	g.gold = 42
	g.total = 1200
	g.target = 900
	#  내역 세 줄 — 큰 벌(x0 190)이 서는 쪽이다. 왼쪽 띠가 그 표와
	#  10px 밖에 안 떨어져 있어 여기가 제일 먼저 부딪히는 자리다.
	g.clear_gold_detail = [{"n": "판 클리어", "v": 5}, {"n": "이자", "v": 3},
			{"n": "남은 다트", "v": 2}]

	#  ── ① 선반 여섯. 「최악」이다 ────────────────────
	_hold(["c03", "c06", "c30", "r09", "l03", "c04"])
	g.wreck_seed += 1
	g.wreck_snd_from = g.wreck.size()
	g._wreck_add(0, g.owned[0], "boom", 2)
	g._wreck_add(1, g.owned[1], "boom", 10)
	g._wreck_add(2, g.owned[2], "rdec", 0)
	g._wreck_add(3, g.owned[3], "save", 0)
	g._wreck_add(4, g.owned[4], "perish", 0)
	g._wreck_add(5, g.owned[5], "spent", 0)
	g.owned.clear()
	g._panel_reset()
	await _reel("wreck_six", AT)

	#  ── ② 굴려서 졌다 · 굴렸는데 남았다 — 나란히 ────
	_hold(["c03", "c06"])
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0
	g.wreck_seed += 1
	g._wreck_add(0, g.owned[0], "boom", 2)
	g._wreck_safe(1, g.owned[1], 10)
	g.owned.clear()
	await _reel("wreck_pair", [0.050, 0.120, 0.250, 0.400, 0.620])

	#  ── ③ 「남았다」만. 조용한 쪽이 혼자 설 때 ────────
	_hold(["c06", "c03"])
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0
	g.wreck_seed += 1
	g._wreck_safe(0, g.owned[0], 10)
	g._wreck_safe(1, g.owned[1], 2)
	await _reel("wreck_safe", [0.010, 0.080, 0.200, 0.500])

	#  ── ④ 판 중 소진 — 슬롯 자리다 ──────────────────
	#  **지우기까지 실제 경로 그대로 한다.** 안 지우면 owned 가 셋인 채라
	#  시체가 네 번째 칸에 서고, 정작 봐야 할 것 — 가운데가 죽어 뒷 동전이
	#  그 칸으로 당겨졌을 때 시체가 **산 동전 위에 안 서는가** — 가 그림에
	#  안 나온다. 그대로 두었던 첫 벌이 조각과 「다 썼다」를 멀쩡한 이웃에
	#  얹고도 초록이었다(2026-09-19).
	g.state = g.S.PICK
	_hold(["c04", "c34", "c03"])
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0
	g.wreck_seed += 1
	g._wreck_add(1, g.owned[1], "spent", 0)
	g.owned.remove_at(1)
	g._panel_pull(1)
	await _reel("wreck_slot", [0.040, 0.150, 0.300])

	#  ── ⑤ 모션 끄기 — **리롤과 일부러 다르다** ────────
	#  _smash_at 의 모션 끄기는 아무것도 안 낸다(조각도 먼지도). 여기서는
	#  리롤 조각이 장식이고 이것은 **정보**라 정지 그림이 그대로 들고
	#  있어야 한다 — 부서진 것은 잔해 + 낱말 + 수, 남은 것은 흐린 동전 +
	#  고리 + 낱말 + 수. 그 **다름**을 눈으로 확인하는 자리다.
	g.motion_off = true
	g.state = g.S.CLEAR
	g.clear_t = 0.0
	_hold(["c03", "c06", "c30", "r09"])
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0
	g.wreck_seed += 1
	g._wreck_add(0, g.owned[0], "boom", 2)
	g._wreck_safe(1, g.owned[1], 10)
	g._wreck_add(2, g.owned[2], "perish", 0)
	g._wreck_add(3, g.owned[3], "save", 0)
	g.owned.clear()
	g._panel_reset()
	await _reel("wreck_motionoff", [0.020, 0.300])
	g.motion_off = false

	quit(0)
