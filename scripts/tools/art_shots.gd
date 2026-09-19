extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

#  그림 표본 판을 찍는다. **이 다섯 장이 최종 판정 자리다** — 수로 맞아도
#  여기서 안 맞으면 수가 틀린 것이다.
#    art_gold   잉크 가운데선과 플라크 상자가 다섯 크기에서 겹치는가
#    art_pack   눈금이 다섯 상태에 다 있는가 · psi 90° 에서 크림프가 남는가
#    art_mod    키라인 밖으로 삐져나온 것이 있는가 · 문턱 8.0 이 무엇을 바꾸나
#    art_all    셋이 한 집으로 보이는가
#    art_*_g    **회색조 40%.** 색을 빼고 작게 만들면 광학 무게가 안 맞는
#               것이 먼저 무너진다. 픽셀을 실제로 섞는 편이 정직해서
#               그리는 쪽이 아니라 여기서 만든다.
#
#   godot --path . --quit-after 900 --script scripts/tools/art_shots.gd

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_art_shots.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 6:
		g._process(1.0 / 60.0)
		g._swap_skip()
	Dev.on = false          # 개발자 판이 표본을 가리면 안 된다
	for pg in [[1, "gold"], [2, "pack"], [3, "mod"], [4, "all"]]:
		Dev.pick["artsheet"] = int(pg[0])
		g.queue_redraw()
		await process_frame
		await process_frame
		var im: Image = root.get_texture().get_image()
		im.save_png("res://shots/art_%s.png" % pg[1])
		_squint(im).save_png("res://shots/art_%s_g.png" % pg[1])
		print("저장: art_%s.png  (칸 %d)" % [pg[1], g.art_cells.size()])
	Dev.pick["artsheet"] = 0
	quit()


#  눈 찌푸리기 — 회색조로 눕히고 40% 로 줄인다. WCAG 상대휘도가 아니라
#  단순 평균이면 붉음이 회색에서 너무 밝게 남아 「색으로 갈린 척」이
#  그대로 통과한다. 선형화해서 섞는다.
func _squint(src: Image) -> Image:
	var im := Image.create(src.get_width(), src.get_height(), false,
			Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var l: float = pow(0.2126 * _lin(c.r) + 0.7152 * _lin(c.g)
					+ 0.0722 * _lin(c.b), 1.0 / 2.2)
			im.set_pixel(x, y, Color(l, l, l, 1.0))
	im.resize(int(src.get_width() * 0.4), int(src.get_height() * 0.4),
			Image.INTERPOLATE_BILINEAR)
	return im


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
