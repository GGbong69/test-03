extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  모드 둘 — 눈으로 보는 마지막 관문
#
#   godot --path . --quit-after 2400 --script scripts/tools/mode_shots.gd
#
#  수로 재는 것은 qa_chalpick · qa_endless · qa_over 가 이미 한다. 여기는
#  **글자가 겹치는가 · 띠가 비는가 · 깎인 수가 칸에 드는가**를 본다 —
#  자리 계산이 맞아도 잉크가 겹치는 것은 사람 눈으로만 걸린다.
#
#  ⚠ **이 도구는 창을 진짜로 띄운다.** 사람의 커서가 창 위에 있으면 얹힘과
#  툴팁이 같이 찍혀 그림이 코드가 아니라 손 자리를 찍는다. 찍는 프레임만
#  게임 시계를 멈추고 얹힘을 지운다(_shot).
#  ⚠ **hover_live 를 끄는 것으로 막지 마라** — 그것을 끄면 손가락 길
#  (_hold_ok)이 켜져 길게 누른 것처럼 툴팁이 제 혼자 선다(game.gd 4275).
#
#  찍는 것
#    mode_lock        잠긴 챌린지 탭 + 「완주 0 / 1」
#    mode_chal        열린 챌린지 탭의 일곱 줄
#    mode_chal_tip    줄 하나의 툴팁(제약 / 보상 두 줄 · 태그 하나)
#    mode_over        갈라진 완주 화면 두 줄
#    mode_over_arm    「무한 런」을 겨눈 채
#    mode_endless_leg 무한 구간의 판 선택 — 깎인 목표
#    mode_endless     무한 구간의 판 — 분모 없는 상단바 · 한 바퀴 도는 진행 칸
#    mode_mark        「목표물」이 걸린 판 — 뽑힌 칸만 밝다
#    mode_mark_out    그 런을 나온 제목 — 판이 고르게 밝다(안 따라 나온다)
#
#  진짜 저장은 안 건드린다 — 제 대역에 심고 그 위에서 찍는다.
# ══════════════════════════════════════════════════════════

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_mode_shots.cfg"
	Save.wipe()
	#  배움 쪽지가 화면을 가린다 — 전부 배운 것으로 두고 찍는다.
	for r in GameData.rows("tutor"):
		Save.teach(String(r.get("id", "")))
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


func _calm() -> void:
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_t = 0.0
	g.tutor_out = 0.0
	g.pops.clear()


func _shot(nm: String, note := "", keep_tip := false) -> void:
	_calm()
	if not keep_tip:
		g.tip_a = 0.0
		g.tip_title = ""
		g.tip_pin = {}
	#  시계를 멈춘 뒤 두 프레임을 흘린다 — 멈추기 전에 돈 _process 가
	#  세운 얹힘이 한 프레임 남는다.
	g.set_process(false)
	for i in 2:
		g.ui_hot = ""
		g.mouse_at = Vector2(-99.0, -99.0)
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	g.set_process(true)
	print("저장: %-18s %s" % [nm + ".png", note])


func _run() -> void:
	await _wait(6)
	g._autoplay = false

	# ── ① 잠긴 챌린지 탭 ──────────────────────────────
	g._open_newrun()
	await _wait(40)
	await _shot("mode_lock", "완주 %d / 1" % mini(Save.stat("wins"), 1))

	# ── ② 열린 챌린지 탭 ──────────────────────────────
	Save.bump("wins")
	Save.unlock("chal:blind")         # 깬 표시 한 줄이 서는 그림도 같이 본다
	g._open_newrun()
	await _wait(40)
	g._click(g._nr_tab(1).get_center())
	await _wait(10)
	await _shot("mode_chal", "일곱 줄 · 고른 것 %s" % GameData.challenge)

	#  줄 하나를 **핀으로 붙잡는다.** _cursor() 는 진짜 마우스를 읽으므로
	#  mouse_at 만 밀어서는 툴팁이 안 선다 — 핀 갈래는 얹힘이 빈손일 때
	#  서는 길이라 여기에 딱 맞는다.
	g.tip_pin = {"k": "chal", "i": 4, "st": g.state}
	g.tip_pin_at = g._chal_row(4).get_center()
	for i in 40:
		g._process(1.0 / 60.0)
		await process_frame
	await _shot("mode_chal_tip", "툴팁 · %s" % g.tip_title, true)
	g.tip_pin = {}

	# ── ③ 갈라진 완주 화면 ────────────────────────────
	#  ⚠ 완주 갈래를 **진짜로 밟는다** — state 를 손으로 박으면 endless_ok
	#  가 서는 자리를 안 지나 그림이 설계를 안 찍는다.
	GameData.challenge = "empty"
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	g.leg_no = GameData.legs_n()
	g._open_leg()
	g._begin_leg()
	g._swap_skip()                    # 판 갈이 중에는 _draw 가 화면을 안 그린다
	g.target = GameData.target_of(g.leg_no)
	g.total = g.target
	g.darts_left = 3
	g._finish_leg()
	g.run_unlocked = [{"k": "다트통", "n": "선금"}]
	await _wait(40)
	await _shot("mode_over", "완주 %s · 갈래 %s" % [str(g.won), str(g.endless_ok)])
	g.endless_arm = true
	g.endless_arm_t = 0.2
	await _shot("mode_over_arm", "무한 런 겨눔")
	g.endless_arm = false

	# ── ④ 무한 구간 ───────────────────────────────────
	GameData.challenge = ""
	GameData.endless = true
	g.leg_no = 61                     # 라운드 21 — 맨 목표가 아홉 자리다
	g._open_leg()
	await _wait(40)
	await _shot("mode_endless_leg", "라운드 %d · 목표 %s"
			% [GameData.round_of(61), GameData.big(g._target_at(61))])
	g._begin_leg()
	g._swap_skip()
	await _wait(40)
	await _shot("mode_endless", "상단바 R%d · 진행 칸 한 바퀴"
			% GameData.round_of(61))

	# ── ⑤ 「목표물」이 걸린 판 ─────────────────────────
	GameData.endless = false
	GameData.challenge = "mark"
	g._new_run()
	g.leg_no = 1
	g._open_leg()
	g._begin_leg()
	g._swap_skip()
	await _wait(40)
	await _shot("mode_mark", "뽑힌 칸 %d" % g.mark_sec)
	#  ⚠ **판 밖까지 따라 나오는가.** mark_sec 을 되돌리는 자리가 _start_leg
	#  하나뿐이고 _draw_aim 은 state 를 안 보고 매 프레임 불려서, 목표물
	#  런을 끝내고 나온 제목 화면의 다트판이 스무 칸 중 열아홉이 검게 깔린
	#  채였다. **이 그림에서 판이 고르게 밝아야 한다.** 2026-09-20
	g._newrun_leave()
	g.state = g.S.TITLE
	await _wait(40)
	await _shot("mode_mark_out", "목표물 런을 나온 제목 — 판이 고르다 (칸 %d)"
			% g.mark_sec)

	GameData.challenge = ""
	quit()
