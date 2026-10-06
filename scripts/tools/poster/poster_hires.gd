extends SceneTree
#  포스터 원화 — 게임 화면을 인쇄 해상도로 뽑는다(2026-10-06 「지금 게임에 포스터가 필요 하거든?」).
#  창 대신 SubViewport 에 게임을 단다. 논리 640x360 은 그대로 두고(size_2d_override)
#  기기 픽셀만 키우므로 그리는 선 · 글자가 그 배율로 또렷하다.
#  창이 있어야 돈다:  godot --path . --script scripts/tools/poster/poster_hires.gd -- <배율> <장면>
#  결과: outputs/poster/hires_<장면>_<배율>x.png
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var vp: SubViewport = null
var busy := false
var scale_k := 12
var scene := "title"


func _initialize() -> void:
	Save.gpath = "user://_poster_g.cfg"
	Save.path = "user://_poster.cfg"
	Save.wipe()
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		scale_k = int(a[0])
	if a.size() > 1:
		scene = String(a[1])
	vp = SubViewport.new()
	vp.size = Vector2i(640 * scale_k, 360 * scale_k)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	vp.add_child(g)
	seed(20261006)


func _process(_d: float) -> bool:
	if g != null:
		g.hover_live = false
		g.tip_pin = {}
		g.tip_a = 0.0
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _shot() -> Image:
	g.queue_redraw()
	for k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _run() -> void:
	await _wait(10)
	DisplayServer.window_set_size(Vector2i(640, 360))
	g.crt = 0.0
	g.warp = 0.0
	g.vhs = 0.0
	g.dot = 0.0
	g._crt_apply()
	var img: Image = await _shot()
	DirAccess.make_dir_recursive_absolute("res://outputs/poster")
	var p := "res://outputs/poster/hires_%s_%dx.png" % [scene, scale_k]
	img.save_png(p)
	print("saved ", p, " ", img.get_size())
	quit(0)
