extends SceneTree

# 사탕을 손으로 집어 세게 던지고 그 궤적을 몇 장 찍는다.
#     godot --script scripts/tools/shot_candy_throw.gd

var g = null
var frames := 0
var busy := false

func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/main.tscn")
	g = scn.instantiate()
	root.add_child(g)
	g.set_process(false)

func _process(_d: float) -> bool:
	if busy:
		return false
	if g != null:
		g.set_process(false)
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
	frames += 1
	if frames == 10:
		busy = true
		_go()
	return false

func _go() -> void:
	g.gold = 30
	g._open_shop()
	g._drop_settle()
	await process_frame

	var ci := -1
	for i in g.stock.size():
		if g.stock[i].type == "cons":
			ci = i
			break
	print("사탕 자리: ", ci)
	var it: Dictionary = g.drop[ci]
	print("정착 위치 u=", it.u, " w=", it.w)

	# 손으로 세게 후려친다 — 왼쪽으로 강하게. HAND.toss=0.34, toss_cap=210
	# 이라 hand_v 가 커야 한다. _hand_v 는 _hand_update 안에서 마우스
	# 이동으로 갱신되므로, 여기서는 hand_v 를 직접 박고 release 를 부른다.
	g.hand_st = g.H.CARRY
	g.hand_src = 0
	g.hand_i = ci
	g.hand_zone = -1
	it.held = true
	it.h = 0.0
	g.hand_v = Vector2(-900.0, 0.0)     # 왼쪽으로 세게
	g._hand_release(Vector2(200.0, 240.0))
	print("던진 뒤 om=", it.om, " wob=", it.wob, " vu=", it.vu)

	var cum := 0
	for step in [3, 3, 3, 3, 3, 3, 3, 3, 10, 20]:
		for k in step:
			g._drop_update(1.0 / 60.0)
		cum += step
		g.queue_redraw()
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("res://shots/throw_%03d.png" % cum)
		print("저장: throw_%03d.png  psi=%.2f wob=%.2f sleep=%s"
				% [cum, it.psi, it.wob, it.sleep])
	quit()
