extends SceneTree
#  등장 연출을 눈으로 본다 — 첫 착지의 소리·빛 (2026-09-20)
#
#  찍는 것 넷:
#    land_rank.png  — 등급 넷이 한 테이블에. **선 상태**(맥동만)와 견준다
#    land_leg.png   — 레전더리가 앉은 그 프레임(부풂 x3.20 · 바닥 빛 · 비네트)
#    land_leg2.png  — 0.55초 뒤. 부풂이 2.2초 맥동으로 **이어 붙었는가**
#    land_pack.png  — 봉투가 뜯기는 원이 ef86c6 인가(레전더리가 들었을 때만)
#
#  보는 것: 바닥 빛이 값표·창구·툴팁을 안 가리는가 · 비네트가 640x360 에서
#  가운데를 안 흐리는가 · 번짐이 실루엣 밖으로만 나가는가.
#
#   godot --path . --quit-after 1500 --script scripts/tools/shot_land.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_land_g.cfg"
	Save.path = "user://_shot_land.cfg"
	Save.wipe()
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


static func _item_by(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it
	return {}


static func _first_of(rar: String) -> String:
	for it in GameData.items():
		if String(it.get("rarity", "")) == rar:
			return String(it.id)
	return ""


#  물건을 손수 깔고 떨어뜨린다. 게임이 까는 길 그대로다.
func _lay(ids: Array) -> void:
	g.stock.clear()
	for id in ids:
		var d := _item_by(String(id))
		if d.is_empty():
			continue
		g.stock.append({"type": "item", "d": d,
				"cost": int(d.get("cost", 0)), "sold": false})
	#  ⚠ **앞 딜링의 연출을 먼저 지운다.** 안 지우면 비네트가 아직 서 있어
	#  _until(leg_vig>=0.95)가 그 자리에서 참이 되고, 정작 이번 레전더리는
	#  아직 공중이라 **부풂 0 짜리 그림**이 찍힌다(2026-09-20 실측).
	g.leg_vig = 0.0
	g.leg_vig_up = false
	g.leg_cue_t = -1.0
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	g.shake = 0.0
	#  드러냄은 **장 하나당 런에 한 번**이라, 같은 l02 를 두 번 세우는
	#  이 도구는 기록을 비운 뒤 굴려야 둘째 그림에도 한 벌이 든다.
	g.leg_fx_seen.clear()
	g._drop_roll()


#  ⚠ **프레임 수로 기다리면 안 된다.** 창이 뜨는 첫 프레임들은 60fps 가
#  아니라, 25프레임이 0.417초가 아니라 1초 너머가 된다 — 실제로 처음에
#  그렇게 찍어서 부풂이 이미 0 으로 식은 그림을 얻었다(2026-09-20).
#  **상태로 잡는다**: 조건이 참이 되는 그 프레임에 찍는다.
func _until(fn: Callable, n := 400) -> bool:
	for i in n:
		await process_frame
		if fn.call():
			return true
	return false


func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  찍었다 — %s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 필요하다")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	#  배움 띠는 이 그림이 재는 것이 아니고 화면 위쪽을 통째로 가린다 — 재운다.
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_i = 0
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g._open_shop()
	await _wait(20)
	g.tutor_q.clear()
	g.tutor_id = ""

	var c0 := _first_of("common")
	var u0 := _first_of("uncommon")
	var r0 := _first_of("rare")

	# ── ① 등급 넷이 한 테이블에 ────────────────────────
	#  레전더리를 **마지막 칸**에 두어 넷이 다 앉은 뒤 그 하나만 터지게 한다
	#  (t0 0.24 라 앞 셋은 이미 앉아 있다). 한 그림에 네 등급이 다 선다.
	_lay([c0, u0, r0, "l02"])
	await _until(func(): return float(g.drop[3].get("lg", 0.0)) > 0.5)
	print("  ① 레전더리 부풂 %.2f · 레어 부풂 %.2f · 비네트 %.2f"
			% [float(g.drop[3].get("lg", 0.0)),
					float(g.drop[2].get("lg", 0.0)), float(g.leg_vig)])
	await _shot("land_rank")

	# ── ② 레전더리가 앉은 그 프레임 ────────────────────
	#  비네트가 봉우리에 선 프레임을 고른다(착지 + vig_in 0.10). 그때
	#  부풂은 1 − 0.10/0.55 = 0.82 라 **둘이 같은 그림에 든다.**
	_lay(["l02", c0, c0, c0])
	await _until(func(): return float(g.leg_vig) >= 0.95)
	print("  ② 부풂 %.2f · 비네트 %.2f · 흔들림 %.2f"
			% [float(g.drop[0].get("lg", 0.0)), float(g.leg_vig),
					float(g.shake)])
	await _shot("land_leg")

	# ── ③ 부풂이 다 식은 뒤 — 선 상태로 이어 붙었는가 ──
	await _until(func(): return float(g.drop[0].get("lg", 0.0)) <= 0.0)
	await _wait(6)
	print("  ③ 이어 붙은 뒤 부풂 %.2f · 비네트 %.2f (맥동만 남는다)"
			% [float(g.drop[0].get("lg", 0.0)), float(g.leg_vig)])
	await _shot("land_leg2")

	# ── ④ 팩 — 봉투가 ef86c6 로 터지는가 ───────────────
	var bs := GameData.boosters()
	if not bs.is_empty():
		g._boost_deal(bs[bs.size() - 1])
		g.boost_spill = []
		for rr in ["legendary", "rare", "uncommon", "common"]:
			var id := "l02" if String(rr) == "legendary" else _first_of(String(rr))
			g.boost_spill.append({"type": "item", "d": _item_by(id)})
		#  뜯기는 한가운데(rise 0.34 + tear 0.15)에서 찍는다
		g.boost_t = float(g.BOOST.rise) + float(g.BOOST.tear) * 0.5
		await _shot("land_pack")

	print("끝")
	quit(0)
