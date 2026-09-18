extends SceneTree

#  등급 표식을 **눈으로** 대는 자 (2026-09-18).
#
#  레전더리는 저울로는 영원히 안 뜬다(가중치 0) — 팩으로만 온다. 그래서
#  개발자 모드의 길(rank_rack · rank_mat · rank_table)로 세워 놓고 찍는다.
#  「사진은 상점당 0.5% 라 눈으로 보려면 길이 따로 있어야 한다」(restock_fix)와
#  같은 이유다.
#
#  **전·후를 같은 자리에서 뜬다.** dev 의 rank_off 하나로 새 테 한 벌을
#  통째로 끄고 같은 프레임을 다시 찍는다 — 「정말 나아졌나」를 재는 유일한 길이다.
#
#    godot --path . --quit-after 900 --script scripts/tools/shot_rank.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false
var Dev = null


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	Dev = load("res://scripts/dev.gd")


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  배움 말상자와 커서를 치운다 — 랙을 덮으면 등급이 안 보인다.
#  rar_t 를 0 으로 못박아 전·후 두 장이 같은 맥동에서 찍히게 한다.
func _quiet() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	g.mouse_at = Vector2(-50.0, -50.0)
	g.tip_a = 0.0
	g.tip_spot = -1
	g.rar_t = 0.0


func _shot(nm: String) -> void:
	for i in 6:
		g._process(1.0 / 60.0)
	_quiet()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  %s" % nm)


func _names() -> String:
	var out := PackedStringArray()
	for o in g.owned:
		out.append("%s(%s)" % [o.get("n", "?"), o.get("rarity", "?")])
	return ", ".join(out)


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍는다")
		quit(0)
		return
	for i in 8:
		g._process(1.0 / 60.0)
	g.gold = 99
	g.leg_no = 4
	g._open_shop()
	_quiet()

	#  ① 선 자세 — 네 등급을 한 줄에. r=19 라 밴드·박음·물림이 다 사는
	#     가장 큰 선 자세다.
	print("\n① 랙 — 네 등급")
	Dev._run(g, {"t": "act", "a": "rank_rack"})
	print("  %s" % _names())
	await _shot("rank_rack")

	#  ② 재질이 등급과 만나는 셋. 회귀가 나면 여기서 난다.
	print("\n② 랙 — 재질x등급 (금테x희귀 · 도트x레어 · 빈인쇄x레전더리)")
	Dev._run(g, {"t": "act", "a": "rank_mat"})
	print("  %s" % _names())
	await _shot("rank_mat")

	#  ②-b 레전더리 다섯 — **각자 고유 실루엣**(2026-09-18).
	#     랙 다섯 = 정확히 한 판이라 정사각·마름모·가로·세로·늘어짐이
	#     한 줄에 선다. 보는 것 둘: 다섯이 서로 다른가 · 다섯이 **같은
	#     등급으로** 보이는가(겹테 2 · 홀로 온 바퀴 · 옆면 두께).
	print("\n②-b 랙 — 레전더리 다섯의 고유 실루엣")
	Dev._run(g, {"t": "act", "a": "form_leg"})
	print("  %s" % _names())
	await _shot("form_leg")

	#  ②-c 레어 변형 다섯 — **한 가족으로 보이면서 서로 세어지게 달라야** 한다.
	print("\n②-c 랙 — 레어 변형 다섯 (고름·축·쏠림·쌍·매끈)")
	Dev._run(g, {"t": "act", "a": "form_var"})
	print("  %s" % _names())
	await _shot("form_var")

	#  ③ 누운 자세 — 밴드·박음·물림·플라크를 한 테이블에서.
	print("\n③ 테이블 — 네 등급 (누운 자세)")
	Dev._run(g, {"t": "act", "a": "rank_table"})
	g._drop_settle()
	await _shot("rank_table")

	#  ③-b 누운 테이블은 **사용자가 실제로 고르는 자리**다(rx 22.04).
	#     모양이 가장 크게 보이는 곳이고, 툴팁 없이 갈려야 하는 곳이다.
	print("\n③-b 테이블 — 레전더리 다섯 (누운 자세)")
	Dev._run(g, {"t": "act", "a": "form_leg_table"})
	g._drop_settle()
	await _shot("form_leg_table")

	print("\n③-c 테이블 — 레어 변형 다섯 (누운 자세 · 골 폭 5.73 · 깊이 2.20)")
	Dev._run(g, {"t": "act", "a": "form_var_table"})
	g._drop_settle()
	await _shot("form_var_table")

	#  ④ 같은 테이블을 **새 테 없이** 한 번 더. 전·후가 같은 자리에 선다.
	print("\n④ 같은 테이블 — 등급 테 끔 (전·후 비교)")
	Dev._run(g, {"t": "act", "a": "rank_off"})
	g._drop_settle()
	await _shot("rank_table_off")
	Dev._run(g, {"t": "act", "a": "rank_off"})

	#  말림은 여기서 안 찍는다 — 든 채로 프레임을 돌리면 손이 놓아 버려
	#  빈 판만 나온다. 볼록 자르기(_plq_seg · _plq_fold)는 **qa_rank 가
	#  수로 잰다**(접는 선 아래로 한 점도 안 새는가). 그림보다 그쪽이 확실하다.

	#  ⑤ 깨짐 — **레전더리는 팩으로 테이블에 온다**(legend_probe 가 그 길을
	#     돈다). 동전은 _shard_cut 의 기본 가지라 갈래를 안 내면 플라크도
	#     부채꼴로 잘린다 — 언 한 프레임이 흰 실루엣 구실을 하는데 그
	#     실루엣이 **원으로 되돌아간다.** 여기서 그것을 눈으로 잡는다.
	#  2026-09-18 — **다섯을 한꺼번에 깬다.** 어제는 판 하나에 대해서만 돌던
	#  길이라, 다섯이 제 모양으로 타일링되는지는 한 장으로 본 적이 없었다.
	print("\n⑤ 깨짐 — 판 다섯이 제 모양으로 타일링되는가")
	Dev._run(g, {"t": "act", "a": "form_leg_table"})
	g._drop_settle()
	var ti := -1
	var legs := []
	for j in mini(g.drop.size(), g.stock.size()):
		if String(g.stock[j].type) == "item" \
				and String(g.stock[j].d.get("rarity", "")) == "legendary":
			legs.append(j)
			if ti < 0:
				ti = j
	if ti >= 0:
		g.smash_snd_n = 0
		g.smash_snd_t = 0.0
		g.smash_n = 0
		#  **자리를 안 옮긴다.** 다섯을 같은 구멍으로 밀면 흰 실루엣 다섯이
		#  한 점에 겹쳐 한 덩어리가 된다 — 제자리에서 깨야 다섯이 각자
		#  제 모양으로 타일링된 것이 보인다. vu 만 준다(_smash_at 은 세기를
		#  vu 로 재고 자리는 안 본다).
		for j in legs:
			g.drop[j].vu = -2600.0
			g._smash_at(int(j))
		#  언 프레임(t < 0)에서 찍는다 — 조각이 태어난 자리에서 원물건 모양을
		#  빈틈없이 타일링한 채 흰색으로 서 있는 그 한 컷이다.
		g._process(1.0 / 60.0)
		_quiet()
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/rank_smash.png")
		print("  rank_smash · 조각 %d" % g.shards.size())
		for k in 14:
			g._process(1.0 / 60.0)
		_quiet()
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/rank_smash2.png")
		print("  rank_smash2 · 조각 %d" % g.shards.size())
	else:
		print("  테이블에서 레전더리를 못 찾았다")

	#  ⑥ 레어 변형이 깨질 때도 제 물림을 쥐는가 — _shard_fan 에 _mill_f 를
	#     곱했는지가 여기서 갈린다(안 곱하면 언 프레임이 매끈한 원이 된다).
	print("\n⑥ 깨짐 — 레어 변형이 제 물림으로 타일링되는가")
	Dev._run(g, {"t": "act", "a": "form_var_table"})
	g._drop_settle()
	var rs := []
	for j in mini(g.drop.size(), g.stock.size()):
		if String(g.stock[j].type) == "item" \
				and String(g.stock[j].d.get("rarity", "")) == "rare":
			rs.append(j)
	if not rs.is_empty():
		g.smash_snd_n = 0
		g.smash_snd_t = 0.0
		g.smash_n = 0
		for j in rs:
			g.drop[j].vu = -2600.0
			g._smash_at(int(j))
		g._process(1.0 / 60.0)
		_quiet()
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/form_smash.png")
		print("  form_smash · 조각 %d" % g.shards.size())

	#  ⑦ **작은 자리 — 몸 채움이 살아 있는가** (2026-09-19)
	#     법선 오프셋이 깎은 모서리를 뒤집어 다각형이 자기교차가 되면 고닷의
	#     삼각분할이 빈 배열을 돌려주고 **판이 통째로 안 그려진다**. 터지는
	#     자리가 **r < 12.11 전 구간**이라 큰 자리(테이블 22.04 · 랙 19 ·
	#     컬렉션 13)에서는 멀쩡해 보인다 — 위 여섯 장으로는 영원히 안 보인다.
	#     실제로 망가지던 소비자 둘을 그래서 따로 찍는다:
	#       · **런 정보 12**(30677) — 몸 색이 사라지고 턱 색이 판을 먹었다
	#       · **툴팁 미니 8**(21779) — 같은 자리
	print("\n⑦ 작은 자리 — 런 정보 12 · 툴팁 미니 8 (몸 채움이 사는가)")
	#  툴팁 미니 8 — 레전더리를 테이블에 올려 놓고 커서를 그 위에 둔다.
	#  **_quiet() 를 안 부른다** — 그 함수가 커서를 치우고 tip_a 를 0 으로
	#  못박으므로, 툴팁을 찍는 장에서 부르면 툴팁이 없는 장이 나온다.
	#  게임 제 손으로 _tip_update 가 돌아야 tip_chip 이 찬다.
	Dev._run(g, {"t": "act", "a": "form_leg_table"})
	g._drop_settle()
	var tj := -1
	for j in mini(g.drop.size(), g.stock.size()):
		if String(g.stock[j].type) == "item" \
				and String(g.stock[j].d.get("rarity", "")) == "legendary":
			tj = j
			break
	if tj >= 0:
		#  **_tip_update 는 mouse_at 이 아니라 _cursor() 를 본다**(3669) — 창이
		#  있으면 진짜 커서 자리를 읽는다. 그래서 커서를 실제로 옮긴다.
		#  논리 640x360 을 창 1280x720 으로 늘여 그리므로 창 좌표는 두 배다.
		var mp: Vector2 = g._p2s(g.drop[tj].u, g.drop[tj].w, g.drop[tj].h)
		Input.warp_mouse(mp * 2.0)
		for k in 40:
			g.mouse_at = mp
			g._tutor_close()
			g.tutor_out = 0.0
			g.swap_live = false
			g._process(1.0 / 60.0)
		g.rar_t = 0.0
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/form_small_tip.png")
		print("  form_small_tip · %s · 툴팁 짙기 %.2f (동전 r=8)"
				% [g.stock[tj].d.get("n", "?"), g.tip_a])
	else:
		print("  테이블에서 레전더리를 못 찾았다")
	#  런 정보 12 — **보유 탭(ri3)** 이 동전 다섯을 r=12 로 편다.
	Dev._run(g, {"t": "act", "a": "form_leg"})
	print("  랙: %s" % _names())
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	for t in g.RI_TABS.size():
		g.runinfo_tab = t
		for k in 3:
			g._process(1.0 / 60.0)
		_quiet()
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/form_small_ri%d.png" % t)
		print("  form_small_ri%d · 런 정보 탭 %d" % [t, t])

	print("\n찍음: shots/rank_rack · rank_mat · form_leg · form_var ·"
			+ " rank_table · form_leg_table · form_var_table ·"
			+ " rank_table_off · rank_smash · form_smash ·"
			+ " form_small_ri0~3 · form_small_tip\n")
	quit(0)
