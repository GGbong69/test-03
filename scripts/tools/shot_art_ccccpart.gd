extends SceneTree
# 얼굴이 없던 동전 열 장이 게임에 붙은 모습 — 전 · 후를 같은 화면에서 찍는다.
#   godot --path . --quit-after 2400 --script scripts/tools/shot_art_ccccpart.gd
#   → shots/artc_col_<old|new>_<쪽>.png   컬렉션 동전 탭(열 장이 든 두 쪽)
#     shots/artc_shop_<old|new>_<묶음>.png  상점 — 테이블에 누운 다섯 장 + 위 동전 슬롯에
#                                          낀 같은 다섯 장(두 묶음)
#     shots/artc_cells.json                컬렉션 칸 · 동전 슬롯에서 열 장이 앉은 자리
#                                          (640x360 좌표 — 뒤 시트가 두 배로 잘라 붙인다)
#   그다음 python scripts/tools/shot_art_ccccpart_sheet.py 가 전·후를 한 판에 붙인다.
#
#  「전」 은 얼굴 캐시(_coin_tex)에 열 장을 null 로 못 박아 만든다 — 그림이 없던
#  때와 같은 길(_icon_item 이 아무것도 안 그리고 조건 기호만 남는다)을 탄다.
#  옛 판을 따로 체크아웃하지 않아도 같은 배치·같은 글꼴에서 견줄 수 있다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const IDS := ["c11", "c16", "c17", "c18", "c19", "c31", "c39", "c40", "c41", "c47"]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_artc_g.cfg"
	Save.path = "user://_shot_artc.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		_pin()
		await process_frame


#  커서는 매 프레임 화면 밖에 못 박는다 — 얹힘·툴팁이 끼면 그림이 가려진다.
func _pin() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	g.mouse_at = Vector2(-50.0, -50.0)
	g.tip_a = 0.0
	g.tip_spot = -1
	g.tip_slot = -1
	g.tip_title = ""
	g.queue_redraw()


#  툴팁은 mouse_at 이 아니라 **OS 커서**(_cursor → get_local_mouse_position)를
#  본다 — 창이 뜬 자리에 진짜 커서가 있으면 mouse_at 을 못 박아도 툴팁이 선다.
#  찍는 두 프레임만 게임의 _process 를 멈추고 툴팁을 걷는다(물건은 이미 앉았다).
func _shot(nm: String, frames := 4) -> void:
	await _wait(frames)
	g.set_process(false)
	g._tip_clear()
	await _wait(2)
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	g.set_process(true)


func _faces(on: bool) -> void:
	for id in IDS:
		if on:
			g._coin_tex.erase(id)
		else:
			g._coin_tex[id] = null


func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it
	return {}


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)

	#  ── 컬렉션 — 열 장이 든 쪽만 ──────────────────────
	var cells := {}
	var pages := {}
	var all: Array = GameData.items()
	for k in all.size():
		var id := String(all[k].id)
		if IDS.has(id):
			var pg: int = k / g.COL_PAGE
			var i: int = k % g.COL_PAGE
			pages[pg] = true
			var c: Vector2 = g._col_cell(i).get_center() + Vector2(0.0, -11.0)
			cells[id] = {"page": pg, "x": c.x, "y": c.y}
	g.state = g.S.COLLECT
	g.collect_tab = 0
	for on in [false, true]:
		_faces(on)
		for pg in pages.keys():
			g.collect_page = int(pg)
			await _shot("artc_col_%s_%d" % ["new" if on else "old", int(pg)], 6)

	#  ── 상점 테이블 · 동전 슬롯 — 다섯 장씩 두 묶음 ─────────
	g.state = g.S.TITLE
	g._new_run()
	await _wait(20)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	for b in 2:
		var batch: Array = IDS.slice(b * 5, b * 5 + 5)
		g.stock.clear()
		for id in batch:
			g.stock.append({"type": "item", "d": _item(id), "cost": 4, "sold": false})
		g._drop_roll()
		g._drop_settle()
		g.owned.clear()
		for id in batch:
			g.owned.append(_item(id).duplicate())
		for k in batch.size():
			var sc: Vector2 = g._slot_rect(k).get_center() + Vector2(0.0, g.PANEL.chip_dy)
			cells[batch[k]]["slot"] = {"b": b, "x": sc.x, "y": sc.y}
		await _wait(40)
		for on in [false, true]:
			_faces(on)
			await _shot("artc_shop_%s_%d" % ["new" if on else "old", b], 8)
	var fa := FileAccess.open("res://shots/artc_cells.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(cells))
	fa.close()
	print("  찍음 — 열 장 %d쪽" % pages.size())
	quit(0)
