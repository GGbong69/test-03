extends SceneTree
# 동전 한 장을 크게 — 말림 단계별로. 무엇이 이상한지 눈으로 가린다.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_stk.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_stk_g.cfg"
	Save.path = "user://_shot_stk.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _run() -> void:
	for i in 12:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	var pick := {}
	var norm := {}
	for it in GameData.items():
		if String(it.get("n", "")) == "더 사일런트":
			pick = it
		if norm.is_empty() and String(it.get("aim", "")) == "" \
				and String(it.get("c", "")) != "":
			norm = it
	print("조준 장: %s · c '%s' · v '%s' · k '%s' · rarity %s"
			% [pick.get("n", "?"), pick.get("c", ""), pick.get("v", ""),
			pick.get("k", ""), pick.get("rarity", "")])
	print("보통 장: %s · c '%s' · v '%s' · k '%s'"
			% [norm.get("n", "?"), norm.get("c", ""), norm.get("v", ""),
			norm.get("k", "")])
	g.state = g.S.TITLE
	g._new_run()
	#  2026-09-18 — **네 등급을 한 줄에 세운다.** 실루엣이 등급마다 갈리므로
	#  (원반 · 원반 · 물린 원 · 플라크) 말림도 넷을 다 봐야 한다. 플라크의
	#  말림은 활꼴이 아니라 볼록 다각형 자르기라 여기서만 새는지가 보인다.
	g.owned = []
	for rr in GameData.RARITIES:
		for it2 in GameData.items():
			if String(it2.get("rarity", "")) == String(rr):
				g.owned.append(it2.duplicate())
				break
	if g.owned.size() < 2:
		g.owned = [pick.duplicate(), norm.duplicate()]
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	for i in 80:
		await process_frame
	var nm := PackedStringArray()
	for o in g.owned:
		nm.append("%s(%s)" % [o.get("n", "?"), o.get("rarity", "?")])
	print("랙: %s" % ", ".join(nm))
	g.rar_t = 0.0        # 등급 맥동을 못박는다 — 두 장을 같은 자리에서 뜬다
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/stk_rack.png")
	#  든 채 — 말림이 제일 깊은 순간
	#  **시계를 먼저 세운다.** 여태 이 두 장이 빈 판만 찍고 있었다: 손 상태를
	#  손으로 밀어 넣어도 다음 프레임의 _process 가 「누른 적이 없다」를 보고
	#  곧장 놓아 버려, 찍을 때는 든 것이 없었다(2026-09-18). 배움 말상자도
	#  같이 닫는다 — 랙을 덮으면 무엇을 들었는지가 안 보인다.
	g.set_process(false)
	g._tutor_close()
	g.tutor_out = 0.0
	g.hand_st = g.H.CARRY
	g.hand_src = 1
	g.hand_i = 0
	g.hand_m = Vector2(320.0, 150.0)
	g.peel_t = 0.0
	g.rar_t = 0.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/stk_peel.png")
	print("말림 %.2f" % g._peel_now())
	#  플라크의 말림 — 볼록 자르기(_plq_seg · _plq_fold)가 게임에서 실제로
	#  도는 **유일한 자리**다. 2026-09-18 이전에는 원반의 자(_peel_y, 반지름
	#  기준)로 접는 선을 잡는 바람에 접는 선이 판 밖(14.85 대 반높이 11.04)에
	#  떨어져 **레전더리만 한 픽셀도 안 말렸다** — 그 길이 통째로 죽어 있던
	#  것을 그림으로 못 봤다. 손 안의 정착 말림(0.28)에서 찍는다.
	if g.owned.size() >= 4:
		g.hand_i = 3
		g.peel_t = 1.0
		g.rar_t = 0.0
		g.queue_redraw()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/stk_peel_plq.png")
		print("플라크 말림 %.2f · %s"
				% [g._peel_now(), g.owned[3].get("n", "?")])
	quit(0)
