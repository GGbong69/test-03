extends SceneTree
# 다트통 무대를 네 갈래로 찍는다. 통 그림만 보는 shot_cups 와 달리 **무대까지**
# 본다 — 카운터·램프·그림자가 통과 어떻게 맞물리는지는 무대 안에서만 보인다.
#
#   godot --path . --quit-after 3000 --script scripts/tools/shot_cupstage.gd
#
# 네 갈래는 qa_cupfx 의 규약 그대로다. 그것이 램프까지 넓어졌으므로
# (STAGE · _cup_lamp_of) 눈으로도 네 갈래가 갈리는지를 여기서 본다.
#
#   잠긴 보통    불 꺼짐 · 아무것도 없다
#   잠긴 히든    불 꺼짐 · 깨진 신호 · 한바탕에만 찬빛
#   연 보통      따뜻한 램프 · 윤
#   연 히든      제 색으로 물든 램프 · 윤 + 후광
#
# 넘기는 도중도 한 장 찍는다 — 램프 세기가 이전 다트통에서 새 다트통으로
# 보간되는 그 사이가 화면에서 가장 오래 보이는 자리다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_cupstage.cfg"
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


func _shot(nm: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("res://shots/stage_%s.png" % nm)
	print("  저장: shots/stage_%s.png  (%s · 램프 %.2f)"
			% [nm, GameData.packs()[g.newrun_pip].get("id", ""), g._cup_lamp_k()])


# 그 다트통으로 **넘겨서** 간다. _pack_view 만으로는 통이 다시 안 서므로
# 물리가 처음 놓인 자리에 굳은 그림을 찍게 된다(cup_probe 주석의 그 함정).
func _goto(pid: String) -> void:
	for k in GameData.packs().size():
		if String(GameData.packs()[g.newrun_pip].get("id", "")) == pid:
			return
		g._pack_step(1)
		await _wait(150)


func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 무대는 화면이 있어야 선다")
		quit(0)
		return
	# ── ① 다 잠근 채로: 잠긴 보통 · 잠긴 히든 ─────────
	Save.wipe()
	g._open_newrun()
	await _wait(120)
	await _shot("1_open_base")        # 기본은 늘 열려 있다
	await _goto("p_mag")
	await _shot("2_shut_plain")       # 잠긴 보통
	await _goto("p_x1")
	await _shot("3_shut_hidden")      # 잠긴 히든 — 깨진 신호
	# ── ② 다 연 채로: 연 보통 · 연 히든 ───────────────
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g.state = g.S.TITLE
	await _wait(4)
	g._open_newrun()
	await _wait(120)
	await _goto("p_adv")
	await _shot("4_open_plain")       # 연 보통 — 선금(발치 플라크)
	await _goto("p_x1")
	await _shot("5_open_hidden")      # 연 히든 — 후광
	# ── ③ 넘기는 도중 ────────────────────────────────
	g._pack_step(1)
	await _wait(14)                   # 0.45초 중 0.23초쯤 — 딱 가운데
	await _shot("6_mid_slide")
	quit(0)
