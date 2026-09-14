extends SceneTree
# 열넷의 통을 한 장에 모아 붙인다. 통은 다트통의 얼굴이라 **나란히 놓고**
# 봐야 "저건 아까 그 통" 이 서는지 알 수 있다 — 한 장씩 보면 다 달라 보인다.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_cups.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.path = "user://_shot_cups.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 통은 화면이 있어야 선다")
		quit(0)
		return
	g._open_newrun()
	await _wait(60)
	var st: Rect2 = g._cup_stage()
	var sc: int = int(root.get_texture().get_image().get_width() / 640)
	var cw: int = int(st.size.x) * sc
	var ch: int = int(st.size.y) * sc
	var cols := 5
	var packs := GameData.packs()
	var rows: int = int(ceil(float(packs.size()) / float(cols)))
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("221d33"))
	for pi in packs.size():
		g._pack_view(pi)
		g._cup3_close()
		g._cup3_open()
		await _wait(90)
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var src := Rect2i(int(st.position.x) * sc, int(st.position.y) * sc, cw, ch)
		sheet.blit_rect(img, src, Vector2i((pi % cols) * cw, int(pi / cols) * ch))
		print("  %2d %-10s %s" % [pi, packs[pi].get("id", ""),
				packs[pi].get("name", "")])
	sheet.save_png("res://shots/cups_all.png")
	print("\nshots/cups_all.png · %dx%d · 칸 %dx%d"
			% [sheet.get_width(), sheet.get_height(), cw, ch])
	quit(0)
