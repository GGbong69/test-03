extends SceneTree
# 보드 확장 와펜 열두 장이 게임에 붙은 모습 — 컬렉션 · 상점 테이블(누움) · 스테이지 앞치마 ·
# 던지는 중 명판 · 크게 본 판. 옛 도식(미니 다트판)도 같은 자리에서 찍어 둔다(*_old).
#   godot --path . --quit-after 6000 --script scripts/tools/shot_art_datamods.gd
#   → shots/art_mods_*.png
#   python scripts/tools/mod_try.py --oldnew   ← 옛 · 새를 나란히 놓는다(shots/art_mods_oldnew.png)
#
# 옛 도식은 _mod_tex 에 null 을 박아 부른다 — _icon_mod 는 텍스처가 없으면 옛 도식을
# 그리므로, 같은 프레임 같은 배치에서 그림만 바뀐다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var tex := {}

#  크게 본 판. 게임을 통째로 물려받아 _icon_mod 를 그대로 부르되, 게임의 준비 ·
#  매 프레임 · 입력은 비운다 — 판만 그리는 캔버스다.
const SHEET_SRC := """
extends "res://scripts/game.gd"
var ids: Array = []
var tx: Dictionary = {}
var page := 0

func _ready() -> void:
	pass

func _process(_d: float) -> void:
	pass

func _unhandled_input(_e: InputEvent) -> void:
	pass

func _art(on: bool) -> void:
	for id in ids:
		_mod_tex[id] = tx[id] if on else null

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), C_BG)
	if page == 0:
		_art(true)
		for i in ids.size():
			_icon_mod(Vector2(29.0 + 52.0 * i, 34.0), 22.0, ids[i], 0.0)
		_art(false)
		for i in ids.size():
			_icon_mod(Vector2(29.0 + 52.0 * i, 88.0), 22.0, ids[i], 0.0)
		_art(true)
		draw_rect(Rect2(0.0, 118.0, 640.0, 92.0), Color(0.086, 0.157, 0.122))
		for i in ids.size():
			var c := Vector2(29.0 + 52.0 * i, 160.0)
			_mod_art_shadow(tx[ids[i]], c + TBL.light * 3.35, TBL.mod_r, Color(0, 0, 0, 0.34))
			_icon_mod(c - Vector2(0.0, 2.0), TBL.mod_r, ids[i], 0.0, TBL.flat)
		for i in ids.size():
			_icon_mod(Vector2(29.0 + 52.0 * i, 236.0), 13.0, ids[i], 0.0)
		for i in ids.size():
			_icon_mod(Vector2(29.0 + 52.0 * i, 272.0), 9.0, ids[i], 0.0)
		for i in ids.size():
			_icon_mod(Vector2(29.0 + 52.0 * i, 312.0), 13.0, ids[i], 0.55)
	else:
		for on in [true, false]:
			_art(on)
			for i in ids.size():
				var row: int = i / 6 + (0 if on else 2)
				_icon_mod(Vector2(56.0 + 105.0 * (i % 6), 46.0 + 89.0 * row), 38.0, ids[i], 0.0)
		_art(true)
"""


func _initialize() -> void:
	Save.gpath = "user://_shot_am_g.cfg"
	Save.path = "user://_shot_am.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.mouse_at = pin
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _hold(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = pin
		g.tip_a = 0.0
		g.tip_spot = -1
		g.queue_redraw()
		await process_frame


func _snap(nm: String) -> Image:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/%s.png" % nm)
	return img


func _art(on: bool) -> void:
	for md in GameData.mods():
		var id := String(md.id)
		g._mod_tex[id] = tex[id] if on else null


func _leg(mods: Array) -> void:
	g.set_process(true)
	g.mods_own = mods
	g._board_bake()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _hold(16)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var ids := []
	for md in GameData.mods():
		var id := String(md.id)
		ids.append(id)
		var t: Texture2D = g._mod_art(id)
		tex[id] = t
		print("  %s %s" % [id, "없음" if t == null else "%s %dx%d" % [t.get_class(), t.get_width(), t.get_height()]])

	#  ── 크게 본 판 ────────────────────────────────────────
	var gs := GDScript.new()
	gs.source_code = SHEET_SRC
	var err := gs.reload()
	if err == OK:
		var sh := Node2D.new()
		sh.set_script(gs)
		sh.ids = ids
		sh.tx = tex
		root.add_child(sh)
		for pg in 2:
			sh.page = pg
			for f in 4:
				sh.queue_redraw()
				await process_frame
			_snap("art_mods_sheet_%d" % pg)
		sh.queue_free()
		await _wait(2)
	else:
		print("  판 스크립트 오류 %d" % err)

	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)

	#  ── 컬렉션 ────────────────────────────────────────────
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	g.collect_tab = 1
	g.collect_page = 0
	for on in [true, false]:
		_art(on)
		await _hold(6)
		_snap("art_mods_collect" + ("" if on else "_old"))
	_art(true)

	#  ── 상점 테이블 — 넉 장씩 세 번, 마지막은 동전 · 사진과 섞어 ──
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	var ms: Array = GameData.mods()
	var batches := [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]]
	for b in batches.size():
		g.stock.clear()
		for k in batches[b]:
			g.stock.append({"type": "mod", "d": ms[k], "cost": 12, "sold": false})
		g._drop_roll()
		g._drop_settle()
		await _wait(40)
		await _hold(20)
		_snap("art_mods_shop_%d" % b)
		if b == 0:
			_art(false)
			await _hold(4)
			_snap("art_mods_shop_0_old")
			_art(true)
	g.stock.clear()
	var its: Array = GameData.items()
	g.stock.append({"type": "mod", "d": ms[0], "cost": 12, "sold": false})
	g.stock.append({"type": "item", "d": its[2], "cost": 6, "sold": false})
	g.stock.append({"type": "mod", "d": ms[10], "cost": 12, "sold": false})
	g.stock.append({"type": "fix", "d": GameData.fixtures()[0], "cost": 15, "sold": false})
	g.stock.append({"type": "item", "d": its[6], "cost": 6, "sold": false})
	g._drop_roll()
	g._drop_settle()
	await _wait(40)
	await _hold(20)
	_snap("art_mods_shop_mix")

	#  ── 스테이지 앞치마 — 산 보드 확장을 거는 선반 ──────────
	for lg in range(1, 30):
		if GameData.is_boss(lg):
			g.leg_no = lg
			break
	g.mods_own = ids.slice(0, 6)
	g._open_leg()
	await _hold(40)
	_snap("art_mods_apron")
	g.mods_own = ids.slice(6, 12)
	await _hold(6)
	_snap("art_mods_apron_b")

	#  ── 던지는 중 명판 — 열두 장을 한 줄로 오려 붙인다 ────────
	var strip: Image = null
	var k := 0
	for id in ids:
		await _leg([id])
		var img: Image = _snap("art_mods_play_%s" % id) if k == 0 else root.get_texture().get_image()
		var r: Rect2 = g._modplate_rect()
		var sc: float = float(img.get_width()) / 640.0
		#  명판은 이름 길이만큼 왼쪽으로 는다 — 오른쪽 끝에 맞춰 같은 폭으로 자른다
		var cut := Rect2i(Vector2i(Vector2(640.0 - 100.0, r.position.y - 4.0) * sc),
				Vector2i(Vector2(100.0, r.size.y + 8.0) * sc))
		if strip == null:
			strip = Image.create_empty(cut.size.x * 6, cut.size.y * 2, false, img.get_format())
		strip.blit_rect(img, cut, Vector2i((k % 6) * cut.size.x, (k / 6) * cut.size.y))
		k += 1
	if strip != null:
		strip.save_png("res://shots/art_mods_plate.png")
	print("  찍음")
	quit(0)
