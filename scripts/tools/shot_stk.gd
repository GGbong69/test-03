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
	quit(0)
