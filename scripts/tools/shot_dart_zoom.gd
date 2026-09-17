extends SceneTree
# 다트 네 자루를 **실제 자리의 크기 · 각 · 바탕**으로 한 판에 깐다 — 검토용 확대판의 원본.
#   godot --path . --quit-after 600 --script scripts/tools/shot_dart_zoom.gd -- <꼬리표>
#   → shots/art_dart_zoom_<꼬리표>.png (1280x720, 한 논리 px = 화면 2px)
#
# 줄마다 한 자리다. 판 전체 게임을 안 띄우므로 몇 초 만에 돈다.
#   1  벽(dl 26 · GRIP.tilt ± 흔들림)   C_BG 바탕 · 고른 자루(+3) · 어둡게 물러난 자루(dim 0.26)
#   2  테이블(dl 23.2 · 흩뿌린 각 · 구름)  펠트 바탕 · 흐린 것(dim 0.55 · 알파 0.72)
#   3  컬렉션(dl 15 · −0.62)            어두운 바탕
#   4  제목 판(dl 16 · 네 각)            어두워진 크림 · 검정 · 빨강 · 초록 칸
#   5  2D 판 받침(dl 4 · 6 · 9 · 12)     판 크림 칸
const IDS := ["std", "hvy", "lgt", "mag"]
var busy := false
var tag := "new"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		tag = String(ua[0])


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var src := "extends \"res://scripts/game.gd\"\n" \
			+ "var tool_draw: Callable\n" \
			+ "func _ready() -> void:\n\tpass\n" \
			+ "func _process(_d: float) -> void:\n\tpass\n" \
			+ "func _physics_process(_d: float) -> void:\n\tpass\n" \
			+ "func _unhandled_input(_e: InputEvent) -> void:\n\tpass\n" \
			+ "func _draw() -> void:\n\ttool_draw.call(self)\n"
	var scr := GDScript.new()
	scr.source_code = src
	scr.reload()
	var n := Node2D.new()
	n.set_script(scr)
	n.set("tool_draw", Callable(self, "_sheet"))
	root.add_child(n)
	for f in 6:
		n.queue_redraw()
		await process_frame
	var p := "res://shots/art_dart_zoom_%s.png" % tag
	root.get_texture().get_image().save_png(p)
	print("  찍음 ", p)
	quit(0)


func _sheet(s) -> void:
	s.draw_rect(Rect2(0, 0, 640, 360), Color("14111f"))
	var tilt: float = float(s.GRIP.tilt)
	# ── 1 벽 ──
	s.draw_rect(Rect2(0, 0, 640, 70), s.C_BG)
	for i in IDS.size():
		var x := 40.0 + float(i) * 150.0
		s._icon_dart(Vector2(x, 18.0), 26.0, IDS[i], 0.0, tilt + 0.06)
		s._icon_dart(Vector2(x + 70.0, 18.0), 29.0, IDS[i], 0.0, tilt - 0.08)
		s._icon_dart(Vector2(x + 20.0, 50.0), 26.0, IDS[i], 0.26, tilt)
	# ── 2 테이블 ──
	s.draw_rect(Rect2(0, 72, 640, 76), Color("1b3126"))
	for i in IDS.size():
		var x := 30.0 + float(i) * 156.0
		s._icon_dart(Vector2(x, 110.0), 23.2, IDS[i], 0.0, 0.5, 1.0, false, 0.0)
		s._icon_dart(Vector2(x + 50.0, 110.0), 23.2, IDS[i], 0.0, 2.2, 1.0, false, 0.5)
		s._icon_dart(Vector2(x + 100.0, 110.0), 23.2, IDS[i], 0.55, -0.9, 0.72, false, 1.1)
	# ── 3 컬렉션 ──
	s.draw_rect(Rect2(0, 150, 320, 60), Color("0c0a14"))
	for i in IDS.size():
		s._icon_dart(Vector2(40.0 + float(i) * 80.0, 180.0), 15.0, IDS[i], 0.0, -0.62)
	# ── 4 제목 판 칸 ──
	var cells := [Color("6b665c"), Color("1a1724"), Color("5a2a2a"), Color("234a30")]
	for b in cells.size():
		var bx := 320.0 + float(b) * 80.0
		s.draw_rect(Rect2(bx, 150, 80, 60), cells[b])
		for i in IDS.size():
			s._icon_dart(Vector2(bx + 12.0 + float(i) * 18.0, 180.0), 16.0, IDS[i],
					0.0, [-0.62, -0.25, -0.95, -0.45][i])
	# ── 5 판 받침 크기 ──
	s.draw_rect(Rect2(0, 212, 640, 148), Color("e8dfc8"))
	var dls := [4.0, 6.0, 9.0, 12.0]
	for j in dls.size():
		for i in IDS.size():
			s._icon_dart(Vector2(30.0 + float(j) * 150.0 + float(i) * 30.0, 250.0),
					dls[j], IDS[i], 0.0, 0.8)
	s.draw_rect(Rect2(0, 290, 640, 70), Color("1a1724"))
	for j in dls.size():
		for i in IDS.size():
			s._icon_dart(Vector2(30.0 + float(j) * 150.0 + float(i) * 30.0, 325.0),
					dls[j], IDS[i], 0.0, -2.3)
