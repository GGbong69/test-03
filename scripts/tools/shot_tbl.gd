extends SceneTree
#  진열대 촬영 (2026-10-02) — 상점 한 장 · 양 끝 소품 확대(평소 · 반응) · 판 고르기.
#  shots/tbl_*.png 로. 창이 있어야 돈다:  godot --path . --script scripts/tools/shot_tbl.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_tbl_g.cfg"
	Save.path = "user://_shot_tbl.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261002)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _quiet() -> void:
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(-50, -50)


#  양 끝을 4배로 — 왼쪽 판매 · 오른쪽 구매를 나란히.
func _close(name: String) -> void:
	var im: Image = root.get_texture().get_image()
	var k: float = float(im.get_width()) / 640.0
	var out := Image.create(1296, 600, false, im.get_format())
	out.fill(Color.BLACK)
	for i in 2:
		var x0: float = 0.0 if i == 0 else 480.0
		var part := im.get_region(Rect2i(int(x0 * k), int(80.0 * k), int(160.0 * k), int(150.0 * k)))
		part.resize(640, 600, Image.INTERPOLATE_NEAREST)
		out.blit_rect(part, Rect2i(0, 0, 640, 600), Vector2i(i * 656, 0))
	out.save_png("res://shots/%s.png" % name)


func _hold(n: int, f: Callable) -> void:
	for _i in n:
		f.call()
		await process_frame


func _run() -> void:
	await _wait(10)
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack", "u_cons", "u_sell", "u_reroll", "u_give"]:
		Save.teach(id)
	_quiet()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	await _wait(200)
	_quiet()
	await _wait(30)
	root.get_texture().get_image().save_png("res://shots/tbl_shop.png")
	_close("tbl_close")
	#  반응 — 왼쪽은 팔 것을 댄 때(저울이 기운다), 오른쪽은 산 순간(서랍).
	if not g.owned.is_empty():
		g.sell_sel = 0
	g.buy_sel = 0
	await _hold(40, func():
		g.hand_zone = 0
		g.pay_flash = 0.0)
	var a: Image = root.get_texture().get_image()
	#  서랍은 이제 번쩍임(pay_flash)이 아니라 서랍 곡선(reg_t · _reg_curve)을 탄다 — 연 뒤
	#  0.2 초(다 열려 머무는 틀)에 묶어 둔다(시안 C · 2026-10-02).
	await _hold(6, func():
		g.hand_zone = 1
		g.pay_flash = 0.9
		g.reg_slam = false
		g.reg_t = 0.2)
	var b: Image = root.get_texture().get_image()
	var mix := a.duplicate()
	var w: int = a.get_width() / 2
	mix.blit_rect(b, Rect2i(w, 0, w, a.get_height()), Vector2i(w, 0))
	mix.save_png("res://shots/tbl_lit_full.png")
	var im := Image.create(1296, 600, false, a.get_format())
	im.fill(Color.BLACK)
	var k: float = float(a.get_width()) / 640.0
	for i in 2:
		var src: Image = a if i == 0 else b
		var x0: float = 0.0 if i == 0 else 480.0
		var part := src.get_region(Rect2i(int(x0 * k), int(80.0 * k), int(160.0 * k), int(150.0 * k)))
		part.resize(640, 600, Image.INTERPOLATE_NEAREST)
		im.blit_rect(part, Rect2i(0, 0, 640, 600), Vector2i(i * 656, 0))
	im.save_png("res://shots/tbl_close_lit.png")
	g.hand_zone = -1
	g.pay_flash = 0.0
	g.reg_t = -1.0
	g.leg_no = 2
	g._open_leg()
	await _wait(120)
	_quiet()
	await _wait(30)
	root.get_texture().get_image().save_png("res://shots/tbl_leg.png")
	quit(0)
