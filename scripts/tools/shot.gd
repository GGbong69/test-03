extends SceneTree

# 화면을 png 로 뽑는다. "에러 없음" 은 "보기에 맞다" 가 아니다 —
# 오토플레이가 통과한 프레임이 실제로 어떻게 보이는지는 눈으로만 알 수 있다.
# 헤드리스로는 못 돈다 — 렌더러가 있어야 뷰포트가 그려진다.

var g: Node2D = null
var frames := 0
var shots := 0
const PLAN := [
	["shop", 40],
	["stage", 40],
]


func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/main.tscn")
	g = scn.instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		# 상점으로 보낸다. 낙하를 즉시 감아 정착 상태를 찍는다.
		g.gold = 24
		g._open_shop()
		g._drop_settle()
	if frames == 50:
		_save("shot_shop.png")
	if frames == 55:
		g._open_stage()
	if frames == 110:
		_save("shot_stage.png")
		return true
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://" + name)
	print("저장: ", name, "  ", img.get_width(), "x", img.get_height())
