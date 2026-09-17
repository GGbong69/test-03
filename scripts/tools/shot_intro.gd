extends SceneTree
# 인트로를 박자마다 찍는다 — 어둠 · 램프 깜빡임 · 세 발 · 180 · 네온 · E · 가라앉음 · 제목.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_intro.gd
#  도구 실행에서는 인트로가 저절로 안 튼다(_intro_wanted). 여기서 직접 열고,
#  게임의 _process 를 끈 채 1/60 초씩 손으로 민다 — 찍는 박자가 매번 같다.
const Save = preload("res://scripts/save.gd")
const AT := [0.30, 0.52, 1.20, 1.75, 2.70, 2.93, 3.25, 3.90, 4.08, 4.40, 5.05, 5.50, 6.00]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_in_g.cfg"
	Save.path = "user://_shot_in.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._intro_begin()
	g.set_process(false)
	var clock := 0.0
	var k := 0
	var dt := 1.0 / 60.0
	while k < AT.size():
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(dt)
		clock += dt
		await process_frame
		if clock >= float(AT[k]):
			await process_frame
			root.get_texture().get_image().save_png("res://shots/intro_%02d.png" % k)
			k += 1
	print("  찍음 — state %d" % int(g.state))
	quit(0)
