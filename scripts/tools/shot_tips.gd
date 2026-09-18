extends SceneTree
# 툴팁 문구 촬영 — 설명 글을 고칠 때 게임이 **그린 그대로** 읽는 대표 스무 장.
#   긴 동전(패턴 조건 + 성장 · 조준 · 조건 끝에서 접힘) · 골드만 주는 동전 · 골드 곁줄 ·
#   짝 · 홀 · 도넛(세 줄) · 사진(쓰는 때 태그) · 사탕 · 다트 · 제약 카드 · 뱃지(건너뛰기 ·
#   쌓인 뱃지) · 다트통 줄글(새 런) · 리그 줄 · 상점의 거절 곁줄
#
#   godot --path . --quit-after 6000 --script scripts/tools/shot_tips.gd -- tips
#   → shots/<앞말>_<장면>.png (앞말은 -- 뒤 낱말, 없으면 tips)
#
# 툴팁은 진짜 OS 커서(_cursor)를 읽어 매 프레임 새로 세운다 — 게임의 _process 를 끄고
# 시계는 _tick 으로 손으로 밀며, 찍는 동안 매 프레임 _tip_build · tip_a = 1 을 박는다
# (shot_text_b 와 같은 길). 툴팁 판과 대상 사각만 잘라 둔다(창 1280x720 = 게임 640x360 의
# 두 배라 잘라도 글자가 선다). 다트통 줄글은 툴팁이 아니라 새 런 화면이라 화면째 찍는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var tip := {}           # 박아 둘 툴팁 대상. 비면 툴팁을 끈다
var pre := "tips"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		pre = String(ua[0])
	Save.gpath = "user://_shot_tips_g.cfg"
	Save.path = "user://_shot_tips.cfg"
	Save.wipe()
	#  다트통 · 리그를 다 연다 — 잠긴 다트통은 줄글 대신 해금 조건을 그린다
	for p in GameData.packs():
		var pid := String(p.get("id", ""))
		Save.unlock("pack:" + pid)
		for l in GameData.leagues():
			Save.unlock(GameData.league_key(String(l.get("id", "")), pid))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		_pin()
		return false
	busy = true
	_run()
	return false


func _pin() -> void:
	if g == null:
		return
	g.mouse_at = Vector2(-50.0, -50.0)
	g.swap_live = false
	g.shake = 0.0
	if tip.is_empty():
		g.tip_a = 0.0
		g._tip_clear()
	else:
		g._tip_build(tip)
		g.tip_a = 1.0
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()


func _tick(n: int) -> void:
	for i in n:
		g._process(1.0 / 60.0)
		g._tutor_close()
		g.tutor_out = 0.0


#  hit 이 비면 화면째. 아니면 툴팁 판 ∪ 대상 사각을 6px 넉넉히 자른다.
func _shot(nm: String, hit := {}) -> void:
	tip = hit
	for i in 4:
		_pin()
		await process_frame
	var img: Image = root.get_texture().get_image()
	var path := "res://shots/%s_%s.png" % [pre, nm]
	if not hit.is_empty() and g.tip_title != "":
		var sz: Vector2 = g._tip_size()
		var box := Rect2(g._tip_pos(sz), sz)
		var mk: Rect2 = g.tip_mark
		if g.tip_slot >= 0:
			mk = g._slot_rect(g.tip_slot)
		elif g.tip_spot >= 0 and g.tip_spot < g.drop.size():
			mk = g._obj_box(g.tip_spot)
		if mk.size.x > 0.0:
			box = box.merge(mk)
		box = box.grow(6.0).intersection(Rect2(Vector2.ZERO, Vector2(640.0, 360.0)))
		var s: float = float(img.get_width()) / 640.0
		img = img.get_region(Rect2i(Vector2i(box.position * s), Vector2i(box.size * s)))
	img.save_png(path)
	var body := PackedStringArray()
	for l in g.tip_lines:
		body.append(" / ".join(l.wr))
	var tags := PackedStringArray()
	for t in g.tip_tags:
		tags.append(String(t.t))
	print("  %-16s %s :: %s :: [%s]" % [nm, g.tip_title, " || ".join(body), ", ".join(tags)])
	tip = {}


func _idx(rows: Array, id: String) -> int:
	for i in rows.size():
		if String(rows[i].get("id", "")) == id:
			return i
	return 0


#  컬렉션 한 칸 — 그 칸이 든 쪽을 펴고 짚는다(툴팁이 그 칸 밑에 선다)
func _col(nm: String, tab: int, rows: Array, id: String) -> void:
	var i := _idx(rows, id)
	g.state = g.S.COLLECT
	g.collect_tab = tab
	g.collect_page = i / g.COL_PAGE
	_tick(2)
	await _shot(nm, {"k": String(g.COL_TABS[tab].k), "i": i})


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다(글꼴로 접는다)")
		quit(0)
		return
	g.set_process(false)
	_tick(8)
	g.state = g.S.COLLECT
	_tick(10)

	# ── 컬렉션 툴팁 ───────────────────────────────────────
	var its: Array = GameData.items()
	await _col("coin_c45", 0, its, "c45")      # 패턴 조건 + 성장 — 세 줄
	await _col("coin_c29", 0, its, "c29")      # 골드만 — 조건 끝에서 접힘
	await _col("coin_c43", 0, its, "c43")      # 골드 곁줄
	await _col("coin_l05", 0, its, "l05")      # 「~당」 뒤에서 접힘
	await _col("coin_r05", 0, its, "r05")      # 조준 — 세 줄
	await _col("coin_c37", 0, its, "c37")      # 진열된 수프
	var mds: Array = GameData.mods()
	await _col("mod_jjak", 1, mds, "jjak")     # 제보 자리
	await _col("mod_holl", 1, mds, "holl")
	await _col("mod_dnut", 1, mds, "dnut")
	await _col("dart_hvy", 2, GameData.darts(), "hvy")
	await _col("candy_c_bl", 3, GameData.candies(), "c_bl")
	await _col("photo_v_pnt", 4, GameData.fixtures(), "v_pnt")
	await _col("photo_v_moth", 4, GameData.fixtures(), "v_moth")   # 「~고」 뒤에서 접힘

	# ── 판 고르기 — 뱃지 ───────────────────────────────────
	g._new_run()
	_tick(30)
	g.leg_skipped = {}
	g.leg_no = 1
	g._open_leg()
	_tick(40)
	g.leg_t = 9.0
	var tgs: Array = GameData.tags()
	var tally: Dictionary = tgs[_idx(tgs, "t_tally")]
	g.leg_tag = tally
	g.leg_tags[1] = tally
	g.pending_tags.clear()
	for id in ["t_boss", "t_wide"]:
		var t: Dictionary = tgs[_idx(tgs, id)]
		g.pending_tags.append({"kind": String(t.get("kind", "")), "v": 1,
				"n": String(t.get("name", "")), "d": g._tag_text(t),
				"w": g._tag_when(t), "rar": String(t.get("rarity", ""))})
	_tick(2)
	g.leg_t = 9.0
	await _shot("badge_skip", {"k": "tag", "i": 1})
	await _shot("badge_pend", {"k": "pend", "i": 0})

	# ── 보스 카드 ─────────────────────────────────────────
	for lv in range(1, 30):
		if GameData.is_boss(lv):
			g.leg_no = lv
			break
	g._open_leg()
	var mfs: Array = GameData.modifiers()
	var bn: int = g._round_boss()
	#  「문턱」을 꽂는다 — 목표 줄이 C_MULT 로 밀리는 것이 이 사진의 쓸모다.
	g.boss_mods[bn] = PackedStringArray([String(mfs[_idx(mfs, "tgt")].id)])
	_tick(40)
	g.leg_t = 9.0
	await _shot("constraint_tgt", {"k": "legboss", "i": bn})

	# ── 상점 — 동전 슬롯이 꽉 찬 매물의 거절 곁줄 ──────────
	g.leg_no = 4
	g.gold = 99
	g._open_shop()
	_tick(20)
	g.owned.clear()
	for k in GameData.max_items():
		var c: Dictionary = (its[k] as Dictionary).duplicate()
		c.gs = 0
		c.bought = 1
		g.owned.append(c)
	g._panel_reset()
	g.stock.clear()
	g.stock.append({"type": "item", "d": its[_idx(its, "l05")], "cost": 20, "sold": false})
	g.stock.append({"type": "mod", "d": mds[_idx(mds, "jjak")], "cost": 12, "sold": false})
	g.mods_own = ["dnut"]
	g._drop_roll()
	g._drop_settle()
	_tick(90)
	g._drop_settle()
	await _shot("shop_full", {"k": "stock", "i": 0})
	await _shot("shop_mod", {"k": "stock", "i": 1})

	# ── 새 런 — 다트통 줄글 · 리그 줄 ──────────────────────
	g.state = g.S.TITLE
	_tick(4)
	g._open_newrun()
	var pks: Array = GameData.packs()
	g._pack_view(_idx(pks, "p_gift"))
	GameData.league = "black"
	_tick(60)
	await _shot("pack_p_gift")
	var ll: Array = g._league_lines()
	for li in ll.size():
		if String(ll[li].n).begins_with("매물"):
			await _shot("league_cost", {"k": "lg", "i": li})
	GameData.league = ""
	print("  찍음")
	quit(0)
