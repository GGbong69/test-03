extends SceneTree
# 다트 네 자루(표준 · 무거운 · 가벼운 · 자석)의 그림이 게임 곳곳에 선 모습을 한 번에 찍는다.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_art_datadart.gd -- new
#   godot --path . --quit-after 4000 --script scripts/tools/shot_art_datadart.gd -- old
#   → shots/art_dart_<자리>_<꼬리표>.png   (꼬리표를 안 주면 new)
#
# 자리는 다트가 2D·3D 로 서는 곳 전부다.
#   collect  컬렉션 다트 탭(dl 15)
#   wall     판 왼쪽 벽에 꽂힌 자루(dl 26) — 넷을 섞어 꽂는다
#   title    제목 판에 꽂힌 자루(dl 16) — 크림 · 검정 · 빨강 · 초록 칸 위
#   shop     상점 테이블에 누운 자루(dl ≈ 23) — 넷을 한 번에 깐다
#   wall     … 같은 장에 판에 꽂힌 3D 자루도 넷을 섞어 꽂는다(board3d 는 이 장을 자른다)
#   fly      나는 3D 자루 넷 — 막 떠난 때 · 판 앞(가로 넷 × 세로 둘)
#   cups     새 런 화면의 3D 다트통(기본 · 무쇠 · 깃털 · 자석)을 한 장에
#   sheet    크기(dl 8~38) · 각 · 구름(spin) · 바탕 여섯 · 2D 통 받침을 한 판에
#
# 옛 그림과 나란히 보려면 바꾸기 전에 old 로, 바꾼 뒤 new 로 찍고
# scripts/tools/art_datadart_cmp.py 를 돌린다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const IDS := ["std", "hvy", "lgt", "mag"]
var g = null
var busy := false
var tag := "new"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		tag = String(ua[0])
	Save.gpath = "user://_shot_ad_g.cfg"
	Save.path = "user://_shot_ad.cfg"
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


#  커서는 매 프레임 화면 밖에 못 박는다 — 올린 자루가 뽑혀 나오거나 툴팁이 뜨면
#  같은 자리를 두 번 찍어도 그림이 갈린다.
func _pin() -> void:
	g.mouse_at = Vector2(-50.0, -50.0)
	g.tip_a = 0.0
	g.tip_spot = -1
	if g.has_method("_tutor_close"):
		g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false


func _wait(n: int) -> void:
	for i in n:
		_pin()
		await process_frame


func _save(nm: String) -> void:
	var p := "res://shots/art_dart_%s_%s.png" % [nm, tag]
	root.get_texture().get_image().save_png(p)
	print("  찍음 ", p)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return

	# ── 컬렉션 ──────────────────────────────────────────
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	g.collect_tab = 2
	g.collect_page = 0
	await _wait(8)
	_save("collect")

	# ── 제목 판 ─────────────────────────────────────────
	#  칸 색마다 한 자루씩. 반지름 비율은 판 R 에 곱한다 — 불 · 트리플 · 크림 싱글 · 더블.
	g.state = g.S.TITLE
	await _wait(10)
	var bc: Vector2 = g.BC
	var rr: float = g.R
	var spots := [
		[0.03, -1.30], [0.31, -0.55], [0.46, 0.55], [0.61, -0.10],
		[0.80, 2.60], [0.97, 1.95], [0.61, 3.40], [0.25, 2.10],
		[0.46, -2.45], [0.97, -1.05], [0.80, 1.20], [0.33, 4.30],
	]
	for f in 6:
		g.ttl_stuck.clear()
		g.ttl_fly.clear()
		for i in spots.size():
			var sp: Array = spots[i]
			var p: Vector2 = bc + Vector2(cos(float(sp[1])), sin(float(sp[1]))) * rr * float(sp[0])
			var u := Vector2(0.0, -1.0).rotated((float(i % 3) - 1.0) * 0.35)
			g.ttl_stuck.append({"p": p, "u": u, "id": IDS[i % 4],
					"rot": g._ttl_rot(u), "t": 2.0})
		_pin()
		g.queue_redraw()
		await process_frame
	_save("title")
	g.ttl_stuck.clear()

	# ── 벽에 꽂힌 자루 ──────────────────────────────────
	g._new_run()
	await _wait(20)
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	await _wait(6)
	for i in g.remaining.size():
		g.remaining[i] = GameData.darts()[i % 4].duplicate()
	g.darts.clear()
	#  판에 꽂힌 3D 자루도 같은 판에서 찍는다 — 넷을 한 바퀴 두 번
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.3
		var r := 18.0 + 11.0 * float(i)
		g.darts.append({"p": bc + Vector2(cos(a), sin(a)) * r,
				"id": IDS[i % 4], "rot": 0.3 * float(i % 3) - 0.3})
	for f in 30:
		g.grip_t = 9.0
		_pin()
		g.queue_redraw()
		await process_frame
	_save("wall")

	# ── 나는 3D 자루 — 종류마다 한 장, 2x2 로 붙인다 ─────────
	#  게임의 _process 를 끄고 fly_t 를 못 박는다(돌게 두면 꽂혀 버린다).
	#  bd_fly 는 FLY 를 벗어나야 지워지므로 종류를 바꿀 때마다 한 번 내려놓는다.
	g.darts.clear()
	g.set_process(false)
	var fsc: int = int(root.get_texture().get_image().get_width() / 640)
	var fr := Rect2i(140 * fsc, 0, 360 * fsc, 320 * fsc)
	var fts := [0.07, 0.12]
	var fly := Image.create(fr.size.x * IDS.size(), fr.size.y * fts.size(), false,
			Image.FORMAT_RGBA8)
	for fi in IDS.size():
		for ti in fts.size():
			g.state = g.S.PICK
			g.queue_redraw()
			await process_frame
			await process_frame
			g.cur_dart = {"id": IDS[fi]}
			g.aim = bc + Vector2(26.0, -34.0)
			g.fly_rot = 0.12
			g.fly_t = float(fts[ti])
			g.state = g.S.FLY
			for f in 4:
				_pin()
				g.queue_redraw()
				await process_frame
			var fimg: Image = root.get_texture().get_image()
			fimg.convert(Image.FORMAT_RGBA8)
			fly.blit_rect(fimg, fr, Vector2i(fi * fr.size.x, ti * fr.size.y))
	fly.save_png("res://shots/art_dart_fly_%s.png" % tag)
	print("  찍음 res://shots/art_dart_fly_%s.png" % tag)
	g.state = g.S.PICK
	g.set_process(true)

	# ── 상점 테이블 ─────────────────────────────────────
	g.darts.clear()
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	g.stock.clear()
	for i in 6:
		g.stock.append({"type": "dart", "d": GameData.darts()[[0, 1, 2, 3, 2, 3][i]],
				"cost": 5, "sold": false})
	g._drop_roll()
	g._drop_settle()
	await _wait(60)
	_save("shop")

	# ── 새 런 · 3D 통 ───────────────────────────────────
	#  넘기기(_pack_step)로 옮겨 가며 찍으면 통이 미끄러진 끝에 자루가 한 뭉치로 쏠린
	#  채 찍혀서, 몇 자루는 앞 자루 뒤에 숨는다(깃털 통에 깃이 한 장만 보였다).
	#  2026-09-17 검토에서 쟀다 — 옛 코드도 쏠림 0.2~0.3 으로 같다. 물리 탓이지 그림
	#  탓이 아니다. 여기는 그림을 보는 판이라 cup_probe 처럼 그 다트통을 보인 채
	#  통을 다시 세우고 가만히 가라앉힌 뒤 찍는다.
	g._open_newrun()
	await _wait(60)
	var st: Rect2 = g._cup_stage()
	var sc: int = int(root.get_texture().get_image().get_width() / 640)
	var cw: int = int(st.size.x) * sc
	var ch: int = int(st.size.y) * sc
	var want := ["std", "hvy", "lgt", "mag"]
	var packs := GameData.packs()
	var sheet := Image.create(cw * want.size(), ch, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("221d33"))
	for wi in want.size():
		var pi := -1
		for k in packs.size():
			if String(packs[k].get("dart_id", "std")) == want[wi]:
				pi = k
				break
		g._pack_view(pi)
		g._cup3_close()
		g._cup3_open()
		await _wait(200)
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(int(st.position.x) * sc, int(st.position.y) * sc, cw, ch),
				Vector2i(wi * cw, 0))
	sheet.save_png("res://shots/art_dart_cups_%s.png" % tag)
	print("  찍음 res://shots/art_dart_cups_%s.png" % tag)

	# ── 한 판짜리 미리보기 ──────────────────────────────
	#  게임 장면을 걷고, game.gd 를 물려받은 빈 노드 하나에 그린다. 물려받는
	#  것은 그리기 함수와 상수뿐이다 — _ready · _process 는 비워 둔다.
	g.queue_free()
	await process_frame
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
	for f in 4:
		n.queue_redraw()
		await process_frame
	_save("sheet")
	quit(0)


#  바탕 여섯 · 크기 일곱 · 각 · 구름 · 통 받침.
func _sheet(s) -> void:
	s.draw_rect(Rect2(0, 0, 640, 360), Color("14111f"))
	# ── 위: 크기 사다리. 눕힌 자루(촉이 오른쪽) ──
	var dls := [8.0, 11.0, 15.0, 19.0, 23.0, 30.0, 38.0]
	var xs := [18.0, 52.0, 94.0, 146.0, 208.0, 286.0, 384.0]
	for j in dls.size():
		for i in IDS.size():
			var dl: float = dls[j]
			s._icon_dart(Vector2(xs[j] + dl, 22.0 + float(i) * 30.0), dl, IDS[i],
					0.0, 1.0304)
	# 오른쪽 위: 구름(spin) 네 단계 · dl 23
	for i in IDS.size():
		for q in 4:
			s._icon_dart(Vector2(488.0 + float(q) * 40.0, 36.0 + float(i) * 30.0), 17.0,
					IDS[i], 0.0, -0.62 + 1.6, 1.0, true, float(q) * PI / 8.0)
	# ── 아래: 바탕 여섯 칸 · 칸마다 네 자루(dl 16) 를 네 각으로 ──
	var bgs := [Color("14111f"), Color("e8dfc8"), Color("d8483d"), Color("479a58"),
			Color("1b3126"), Color("221d33")]
	var y0 := 134.0
	for b in bgs.size():
		var bx := float(b) * 106.0 + 2.0
		s.draw_rect(Rect2(bx, y0, 104.0, 98.0), bgs[b])
		for i in IDS.size():
			var rot: float = [-0.62, 0.0, 0.9, -2.2][i]
			s._icon_dart(Vector2(bx + 16.0 + float(i) * 24.0, y0 + 30.0), 16.0, IDS[i],
					0.0, rot)
			s._icon_dart(Vector2(bx + 16.0 + float(i) * 24.0, y0 + 74.0), 11.0, IDS[i],
					0.0, [2.6, -1.3, 0.4, 1.9][i])
	# ── 맨 아래: 2D 통 받침(렌더러 없는 자리) · 흐림(dim) ──
	for i in IDS.size():
		s.draw_set_transform(Vector2(-80.0 + float(i) * 160.0, 180.0))
		s._cup_body(160.0, 0.0, false, Color("7a7192"))
		s._cup_darts(160.0, IDS[i], 5, 0.0, 0.0)
		s._cup_body(160.0, 0.0, true, Color("7a7192"))
	s.draw_set_transform(Vector2.ZERO)
