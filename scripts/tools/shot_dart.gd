extends SceneTree

# 자루를 눈으로 본다. 꽂힌 그림 한 장과 나는 그림 셋을 찍는다.
# 헤드리스로는 못 돈다 — 3D 무대가 렌더러 없으면 안 열린다.
#
#     godot --script scripts/tools/shot_dart.gd

var g = null
var frames := 0
var busy := false

# 나는 동안의 세 시점(초). fly_time 이 0.2 다.
const FLY_AT := [0.03, 0.10, 0.175]


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
		_shots()
	return false


func _stick() -> void:
	g.state = g.S.AIM_V
	g.darts.clear()
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.4
		var r := 10.0 + 19.0 * float(i)
		g.darts.append({
			"p": g.BC + Vector2(cos(a), sin(a)) * r,
			"id": "std",
			"rot": 0.35 * float(i) - 0.7,
		})


func _shots() -> void:
	_stick()
	g.queue_redraw()
	await process_frame
	await process_frame
	_save("shot_dart3.png")

	# 나는 그림. 꽂힌 자루는 비워 첫 발처럼 둔다.
	g.darts.clear()
	g.cur_dart = {"id": "std"}
	g.state = g.S.FLY
	g.aim = g.BC + Vector2(26.0, -34.0)
	g.fly_rot = 0.12
	for i in FLY_AT.size():
		g.fly_t = FLY_AT[i]
		g.queue_redraw()
		await process_frame
		await process_frame
		_save("shot_fly%d.png" % i)
	quit()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name, "  ", img.get_width(), "x", img.get_height())
