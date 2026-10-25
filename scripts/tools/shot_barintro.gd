extends SceneTree
#  바 인트로 촬영(scripts/prologue_bar3d.gd · 2026-10-25) — 실제 게임처럼 scenes/boot.tscn 을 열고(제 저장 자리) 바 인트로를
#  틀어, 정한 때의 스틸을 창 크기 그대로 찍는다. 넘김 뒤 2 초(게임 인트로)까지 돌고 닫는다.
#  영상은 Movie Maker 로 같이 굽는다(틀 · 소리) — 시작 틀 번호를 찍어 두니 그 앞을 잘라 쓴다.
#   godot --path . --resolution 1280x720 --fixed-fps 60 [--write-movie <폴더>/m.png] \
#       --script scripts/tools/shot_barintro.gd -- <스틸 폴더> [때,때,…]
const Save = preload("res://scripts/save.gd")
const TIMES := [1.0, 2.0, 2.8, 4.2, 5.8, 7.4, 9.2, 10.3]
var b: Node = null
var g: Node = null
var f := 0
var drawn := 0
var out := ""
var times: Array = TIMES
var done := {}
var started := false
var ended := false
var last_t := 0.0
var after := 0.0


func _initialize() -> void:
	Save.gpath = "user://_bi_g.cfg"
	Save.path = "user://_bi.cfg"
	Save.prof_fmt = "user://_bi_%d.cfg"
	Save.wipe()
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else OS.get_user_data_dir().path_join("barintro")
	if a.size() > 1:
		times = []
		for s in String(a[1]).split(","):
			times.append(float(s))
	DirAccess.make_dir_recursive_absolute(out)
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)
	RenderingServer.frame_post_draw.connect(_post)


func _process(d: float) -> bool:
	f += 1
	if DisplayServer.get_name() == "headless":
		print("창이 있어야 찍힌다")
		quit(1)
		return false
	if f == 10:
		g = b.game
		g._plg_begin("bar")
		started = true
		print("START_FRAME %d" % drawn)
	if started and not g._plg_live():
		if not ended:
			ended = true
			print("END_FRAME %d" % drawn)
		after += d
		if after > 2.0:
			print("DONE_FRAME %d" % drawn)
			quit(0)
	return false


func _post() -> void:
	drawn += 1
	if not started:
		return
	var t: float = g.plg_t if g._plg_live() else last_t + after
	if g._plg_live():
		last_t = t
	for tt in times:
		var k := "%.2f" % float(tt)
		if t >= float(tt) - 0.001 and not done.has(k):
			done[k] = true
			var im := root.get_texture().get_image()
			im.save_png(out.path_join("still_%s.png" % k))
