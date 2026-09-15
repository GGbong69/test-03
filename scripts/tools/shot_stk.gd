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
	g.owned = [pick.duplicate(), norm.duplicate()]
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	for i in 80:
		await process_frame
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
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/stk_peel.png")
	print("말림 %.2f" % g._peel_now())
	quit(0)
