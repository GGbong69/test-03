extends SceneTree

# 새 3D 상점 씬을 한 장 찍는다.
#     godot --script scripts/tools/shot_shop3d.gd

var g = null
var frames := 0

func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/shop3d.tscn")
	g = scn.instantiate()
	root.add_child(g)
	# 배경 — 씬의 WorldEnvironment 가 비어 있으면 여기서 채운다
	var we: WorldEnvironment = g.get_node_or_null("Env")
	if we != null and we.environment == null:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.10, 0.07, 0.09)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.45, 0.44, 0.52)
		env.ambient_light_energy = 0.55
		we.environment = env

func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var img := root.get_texture().get_image()
		img.save_png("res://shots/shop3d.png")
		print("저장: shop3d.png  ", img.get_width(), "x", img.get_height())
		quit()
	return false
