extends SceneTree
# 간판을 본다 — 판 고르기(첫 판 · 하나 깬 뒤 · 깨고 건너뛴 뒤)와 보스 카드.
#  보스 카드가 **제약의 얼굴**이 된 뒤로(2026-09-18) 이 도구가 그 그림의
#  before/after 를 찍는 자다. 찍을 것 다섯 — 누운 보스 카드(라운드 1) ·
#  선 보스 카드 · 겹치기(명판 둘) · 무효 · 이긴 보스(두 동강).
#   godot --path . --quit-after 1800 --script scripts/tools/shot_signs.gd
#   → shots/sign_1..3.png · shots/sign_stage.png · sign_boss_*.png
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
	#  **게임의 _process 를 끈다.** 켜 두면 _tip_update 가 매 프레임
	#  _cursor() — 창이 있으면 **진짜 OS 커서** — 를 다시 읽어 우리가 박아 둔
	#  툴팁 자리를 지운다. 그래서 얹힌 카드가 안 얹힌 모습으로 찍혔다.
	#  그림은 queue_redraw 로 따로 나므로 꺼도 다 그려진다(2026-09-18).
	g.set_process(false)


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
#  얹어 둘 판 카드. 게임이 쓰는 문(_tip_hit → _tip_build)을 그대로 지나야
#  얹힘이 증명된다 — 손으로 tip_mark 를 박으면 그 자리가 실제로 잡히는지를
#  안 재고 그림만 만드는 셈이다.
var stand_i := -1


func _hold() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	if stand_i >= 0:
		g.mouse_at = _stand_at()
		g._tip_build(g._tip_hit(g.mouse_at))
		g.tip_a = 1.0


func _stand_at() -> Vector2:
	return g._row_rect(stand_i, GameData.legs_per_round()).get_center()


func _shot(nm: String) -> void:
	for i in 3:
		g.leg_t = 9.0
		g.mouse_at = _stand_at() if stand_i >= 0 else Vector2(-50.0, -50.0)
		_hold()
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _leg(no: int, skipped: Array) -> void:
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g._open_leg()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
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
	#  ── 보스 카드 ──────────────────────────────────
	#  ① 누운 보스 카드(라운드 1). **여기서 문장과 이름이 읽혀야** 이번
	#     일감이 성립한다 — 보스는 라운드 1·2 에서 누워 있다.
	_leg(1, [])
	await _wait(60)
	var bn: int = g._round_boss()
	var mfs: Array = GameData.modifiers()
	g.boss_mods[bn] = PackedStringArray([String(mfs[3].id)])   # dead 부채꼴
	await _shot("sign_boss_flat")
	#  ② 얹힌 보스 카드 — 테가 달아오른다
	stand_i = GameData.leg_idx(bn)
	await _wait(10)
	await _shot("sign_boss_hov")
	stand_i = -1
	#  ③ 선 보스 카드
	_leg(bn, [])
	await _wait(60)
	await _shot("sign_stage")
	#  ④ 겹치기 — 명판 둘, 이름 줄 없음
	g.boss_mods[bn] = PackedStringArray([String(mfs[3].id), String(mfs[9].id)])
	await _shot("sign_boss_two")
	#  ⑤ 무효 — 흐린 글리프 + 대각선 + 맨 목표
	g.boss_mods[bn] = PackedStringArray([String(mfs[5].id)])   # tgt 문턱
	g.boss_void[bn] = true
	await _shot("sign_boss_void")
	g.boss_void.erase(bn)
	#  맥동 세 프레임 — 딜이 끝난 뒤부터 센다
	for dt in [0.0, 0.55, 1.1]:
		g.leg_t = g._deal_time() + dt
		g.swap_live = false
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png(
			"res://shots/sign_boss_beat.png")
	print("  찍음")
	quit(0)
