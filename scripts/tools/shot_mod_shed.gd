extends SceneTree
# 덮인 보드 확장이 스러지는 그림(_mod_shed_draw) — 와펜이 붙은 뒤 한 번도 안 찍혔던 자리.
# 상점에서 보드 확장을 산 순간 판 한복판(BC)에서 부풀며 떠오르다 사라진다.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_mod_shed.gd
#   → shots/art_mods_shed.png — 줄마다 한 장, 칸마다 걸음 k 0.05 · 0.35 · 0.65 · 0.95
#     (맨 끝 칸은 같은 걸음의 옛 도식 — 와펜을 null 로 박아 부른다)
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const KS := [0.05, 0.35, 0.65, 0.95]
const IDS := ["soks", "holl", "pizz", "dnut"]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_msh_g.cfg"
	Save.path = "user://_shot_msh.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.mouse_at = Vector2(-50.0, -50.0)
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


#  걸음을 k 에 붙들어 두고 몇 프레임 그린다. 게임의 _process 가 한 프레임씩 깎아도
#  매 프레임 다시 박으므로 1/60 초 안에서만 흔들린다.
func _at(id: String, k: float) -> Image:
	for i in 4:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.tip_a = 0.0
		g.tip_spot = -1
		g.shake = 0.0
		g.mod_shed = id
		g.mod_shed_t = g.MOD_SHED * (1.0 - k)
		g.queue_redraw()
		await process_frame
	return root.get_texture().get_image()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(30)
	g.stock.clear()
	g.pops.clear()
	#  BC 둘레 200x170 논리 픽셀(물리 400x340)을 칸 하나로 자른다
	var cut := Rect2i(Vector2i(int((g.BC.x - 100.0) * 2.0), int((g.BC.y - 130.0) * 2.0)),
			Vector2i(400, 340))
	var strip := Image.create_empty(cut.size.x * (KS.size() + 1), cut.size.y * IDS.size(),
			false, Image.FORMAT_RGBA8)
	for r in IDS.size():
		var id: String = IDS[r]
		for c in KS.size():
			var img := await _at(id, float(KS[c]))
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, cut, Vector2i(c * cut.size.x, r * cut.size.y))
		#  옛 도식 — 같은 걸음 0.65
		var keep = g._mod_art(id)
		g._mod_tex[id] = null
		var old := await _at(id, 0.65)
		old.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(old, cut, Vector2i(KS.size() * cut.size.x, r * cut.size.y))
		g._mod_tex[id] = keep
	g.mod_shed_t = 0.0
	strip.save_png("res://shots/art_mods_shed.png")
	print("  찍음")
	quit(0)
