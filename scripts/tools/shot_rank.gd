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

	#  ③ 누운 자세 — 밴드·박음·물림·플라크를 한 테이블에서.
	print("\n③ 테이블 — 네 등급 (누운 자세)")
	Dev._run(g, {"t": "act", "a": "rank_table"})
	g._drop_settle()
	await _shot("rank_table")

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
	print("\n⑤ 깨짐 — 플라크가 제 모양으로 타일링되는가")
	Dev._run(g, {"t": "act", "a": "rank_table"})
	g._drop_settle()
	var ti := -1
	for j in mini(g.drop.size(), g.stock.size()):
		if String(g.stock[j].type) == "item" \
				and String(g.stock[j].d.get("rarity", "")) == "legendary":
			ti = j
			break
	if ti >= 0:
		g.smash_snd_n = 0
		g.smash_snd_t = 0.0
		g.smash_n = 0
		g.drop[ti].u = g._chute_dock_u(g.Z_SELL, g.drop[ti].w) + g.drop[ti].hw
		g.drop[ti].vu = -2600.0
		g._smash_at(ti)
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

	print("\n찍음: shots/rank_rack · rank_mat · rank_table · rank_table_off"
			+ " · rank_smash\n")
	quit(0)
