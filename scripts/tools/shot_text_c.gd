extends SceneTree
# 글자 키우기 C 묶음 — 판 밖 메뉴 · 덮개 화면을 **가장 긴 글줄**로 한 장씩.
#   제목 · 프로필(큰 수 · 빈 자리 · 지우기) · 새 런(검정 리그 일곱 줄 · 긴 다트통 설명 ·
#   잠긴 히든) · 설정(제목에서 · 판 중에 · 경고 줄 · 게이지) · 컬렉션(긴 이름 · 툴팁) ·
#   런 정보 네 탭(꽉 찬 동전 · 긴 사진 효과 · 큰 수) · 런 끝(완주 · 실패 · 해금 줄) ·
#   개발자 판(다섯 쪽 · 목록 고르개 두 쪽)
#
#   godot --path . --quit-after 20000 --script scripts/tools/shot_text_c.gd -- txtc_before
#
# 첫 사용자 인자가 파일 이름 앞말이다(없으면 txtc_now). shots/<앞말>_<장면>.png.
#
# 툴팁 판정은 mouse_at 이 아니라 진짜 OS 커서를 읽으므로, 게임이 한 프레임을 다
# 돈 **뒤에** 도는 노드(Pin)가 커서 · 툴팁을 다시 박는다(shot_hover_c 와 같다).
#
# 프로필 파일(user://profile_N.cfg)은 진짜 자리다 — 찍기 전에 떠 두었다가 끝에
# 되돌린다. 검사 프로브들이 그 자리를 지우고 쓰는 것과 같은 자리라 겹쳐 돌리지 않는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var tip := {"k": "-", "i": 0}
var pre := "txtc_now"


class Pin extends Node:
	var t = null

	func _process(_d: float) -> void:
		t._pin()


func _bak(i: int) -> String:
	return "user://_shot_txtc_bak_%d.cfg" % i


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		pre = String(ua[0])
	#  제 슬롯 자리를 박는다 — 진짜 프로필은 이제 아예 안 건드린다(아래 떠 두기는 옛 규약의 흔적).
	Save.prof_fmt = "user://_shot_txtc_%d.cfg"
	for i in range(1, Save.SLOTS + 1):
		var fp := Save.slot_path(i)
		if FileAccess.file_exists(fp):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(fp),
					ProjectSettings.globalize_path(_bak(i)))
	Save.gpath = "user://_shot_txtc_g.cfg"
	Save.path = ""
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	#  1번 — 큰 수. 2번 — 작은 수. 3번 — 빈 자리.
	Save.use_slot(2)
	Save.bump("runs", 2)
	Save.peak("best_leg", 4)
	Save.peak("best_score", 96)
	Save.flush()
	Save.use_slot(1)
	Save.bump("runs", 999)
	Save.bump("wins", 999)
	Save.bump("darts", 99999)
	Save.peak("best_leg", 24)
	Save.peak("best_score", 99999)
	#  리그 해금은 다트통마다 따로다(GameData.league_key) — 다트통마다 다 연다.
	for p in GameData.packs():
		var pid := String(p.get("id", ""))
		Save.unlock("pack:" + pid)
		for l in GameData.leagues():
			Save.unlock(GameData.league_key(String(l.get("id", "")), pid))
			Save.unlock(GameData.win_key(String(l.get("id", "")), pid))
	Save.flush()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var p := Pin.new()
	p.t = self
	p.process_priority = 1000
	root.add_child(p)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _pin() -> void:
	if g == null:
		return
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	g.mouse_at = pin
	g._tip_build(tip)
	g.tip_a = 1.0 if g.tip_title != "" else 0.0
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nm: String, at := Vector2(-50.0, -50.0), t := {"k": "-", "i": 0},
		frames := 30) -> void:
	pin = at
	tip = t
	await _wait(frames)
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [pre, nm])
	print("  %s_%s" % [pre, nm])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var none := {"k": "-", "i": 0}
	#  ── 제목 ──
	g.state = g.S.TITLE
	await _shot("title")
	await _shot("title_hov", g._menu_rect(0).get_center())
	await _shot("title_prof", g._prof_badge_rect().get_center())
	#  ── 프로필 ──
	g._open_profile()
	await _shot("prof_1")
	await _shot("prof_hov2", g._prof_rect(1).get_center())
	g.prof_sel = 3
	await _shot("prof_3")
	g.prof_sel = 1
	await _shot("prof_delhov", g._prof_del_rect().get_center())
	g.prof_arm = 1
	await _shot("prof_armed", g._prof_del_rect().get_center())
	g.prof_arm = -1
	#  ── 새 런 ──
	g.state = g.S.TITLE
	await _wait(4)
	g._open_newrun()
	#  설명이 가장 긴 다트통 — 줄 수가 먼저, 같으면 **그린 폭**이 긴 쪽. 줄글이 다 한 줄로
	#  접히면 줄 수로는 첫 다트통(「기준」 한 줄)을 집어 긴 줄을 못 봤다.
	var best := 0
	var bl := -1.0
	for i in GameData.packs().size():
		var ls: Array = g._pack_lines(GameData.packs()[i])
		var lw0 := 0.0
		for l in ls:
			lw0 = maxf(lw0, g.font.get_string_size(String(l),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var sc: float = float(ls.size()) * 1000.0 + lw0
		if sc > bl:
			bl = sc
			best = i
	g._pack_view(best)
	GameData.league = String(GameData.leagues()[0].get("id", ""))
	await _shot("newrun_white", Vector2(-50.0, -50.0), none, 60)
	var last: int = GameData.leagues().size() - 1
	GameData.league = String(GameData.leagues()[last].get("id", ""))
	await _shot("newrun_black", g._league_rect(last).get_center(), none, 40)
	var nl: int = (g._league_lines() as Array).size()
	await _shot("newrun_line", g._league_line_rect(nl - 1).get_center(),
			{"k": "lg", "i": nl - 1}, 40)
	#  잠긴 히든 — 해금을 걷고 본다
	var hid := -1
	for i in GameData.packs().size():
		if GameData.pack_kind(GameData.packs()[i]) == "hidden":
			hid = i
	if hid >= 0:
		g.newrun_pip = hid
		GameData.pack = String(GameData.packs()[hid].get("id", ""))
		Save.boot()
		Save._cfg.set_value(Save.S_UNL, "pack:" + GameData.pack, false)
		g._cup_reset()
		await _shot("newrun_hidden", g._pack_arrow(true).get_center(), none, 60)
		Save._cfg.set_value(Save.S_UNL, "pack:" + GameData.pack, true)
	GameData.league = String(GameData.leagues()[0].get("id", ""))
	GameData.pack = String(GameData.packs()[0].get("id", ""))
	#  ── 설정(제목에서) ──
	g.state = g.S.TITLE
	await _wait(4)
	g.pause_from = -1
	g.state = g.S.SETTINGS
	await _shot("set_title", Vector2(-50.0, -50.0), none, 40)
	await _shot("set_vol", g._set_rect(2).get_center())
	await _shot("set_track", g._vol_track().get_center())
	#  ── 컬렉션 ──
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	await _shot("col_items")
	#  가장 긴 이름이 든 쪽으로 넘긴다 — 글자 수가 아니라 **그린 폭**으로 잰다.
	#  「quite my tempo」 와 「더 굿 더 베드 더 트리플」 은 둘 다 열네 자인데 앞의 것만
	#  한 줄에 들고 뒤의 것은 두 줄로 접힌다.
	var li := 0
	var lw := 0.0
	for i in GameData.items().size():
		var w: float = g.font.get_string_size(String(GameData.items()[i].n),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		if w > lw:
			lw = w
			li = i
	g.collect_page = li / g.COL_PAGE
	var ci: int = li - g.collect_page * g.COL_PAGE
	await _shot("col_long", g._col_cell(ci).get_center(),
			{"k": "citem", "i": li})
	g.collect_page = 0
	g.collect_tab = 1
	await _shot("col_mods", g._col_tab_rect(1).get_center())
	g.collect_tab = 4
	await _shot("col_fix")
	g.collect_tab = 5
	await _shot("col_modf", g._col_cell(8).get_center(), {"k": "cmodf", "i": 8})
	g.collect_tab = 0
	#  ── 런 정보 ──
	g._new_run()
	await _wait(20)
	g.gold = 999
	g.total = 99999
	g.target = 99999
	g.reroll_cost = 99
	g.owned.clear()
	var its: Array = GameData.items()
	for i in GameData.max_items():
		g.owned.append((its[(li + i) % its.size()] as Dictionary).duplicate())
	g.cons.clear()
	var fx: Array = GameData.fixtures()
	var fl := fx.duplicate()
	fl.sort_custom(func(a, b): return String(a.d).length() > String(b.d).length())
	#  실제로 설 수 있는 가장 긴 판 — 사진은 칸 수만큼(효과가 긴 것부터),
	#  보드 확장은 하나(_apply_mod 가 하나만 쥔다), 다트 세 종류, 뱃지 둘, 제약 하나.
	for i in mini(GameData.cons_slots(), fl.size()):
		g.cons.append((fl[i] as Dictionary).duplicate())
	g.mods_own.clear()
	var ml := GameData.mods().duplicate()
	ml.sort_custom(func(a, b): return String(a.n).length() > String(b.n).length())
	g.mods_own.append(String(ml[0].id))
	var dts: Array = GameData.darts()
	if g.magazine.size() > 2 and dts.size() > 2:
		g.magazine[0] = (dts[1] as Dictionary).duplicate()
		g.magazine[1] = (dts[2] as Dictionary).duplicate()
	g.pending_tags.clear()
	var tg := GameData.tags().duplicate()
	tg.sort_custom(func(a, b): return String(a.get("name", "")).length() \
			> String(b.get("name", "")).length())
	for i in 2:
		g.pending_tags.append({"kind": String(tg[i].get("kind", "")), "v": 1,
				"n": String(tg[i].get("name", "")), "d": "", "w": "", "rar": ""})
	g.active_mods.clear()
	var mfl := GameData.modifiers().duplicate()
	mfl.sort_custom(func(a, b): return String(a.n).length() > String(b.n).length())
	g.active_mods.append(mfl[0])
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	for t in g.RI_TABS.size():
		g.runinfo_tab = t
		await _shot("ri_tab%d" % t, Vector2(-50.0, -50.0), none, 12)
	await _shot("ri_tabhov", g._ri_tab_rect(1).get_center(), none, 12)
	await _shot("ri_backhov", g._runinfo_back_rect().get_center(), none, 12)
	#  빈 보유 — 동전 · 사진 · 뱃지 없음
	var keep_owned: Array = g.owned.duplicate()
	var keep_cons: Array = g.cons.duplicate()
	var keep_tags: Array = g.pending_tags.duplicate()
	g.owned.clear()
	g.cons.clear()
	g.pending_tags.clear()
	g.runinfo_tab = 3
	await _shot("ri_tab3_empty", Vector2(-50.0, -50.0), none, 12)
	g.runinfo_tab = 2
	await _shot("ri_tab2_empty", Vector2(-50.0, -50.0), none, 12)
	g.owned = keep_owned
	g.cons = keep_cons
	g.pending_tags = keep_tags
	#  ── 설정(판 중에) ──
	g.state = g.S.PICK
	await _wait(4)
	g.pause_from = g.S.PICK
	g.state = g.S.SETTINGS
	await _shot("set_pause", g._set_rect(4).get_center(), none, 40)
	g.pause_from = -1
	#  ── 런 끝 ──
	g.leg_no = 24
	#  ⚠ 쓰는 값을 손으로 적지 말 것 — 게임이 쓰는 그 자(_unl_tag)를
	#  그대로 통과시킨다. 손으로 적어 둔 동안 이 그림이 「리그 검정 리그」
	#  같은 겹말을 그대로 보여 주면서도, 게임을 고친 뒤에도 같은 그림을
	#  내서 「고친 것이 화면에 안 났다」는 거짓말을 했다. 2026-09-24
	g.run_unlocked = [
		g._unl_tag("다트통", "넓은 동전 슬롯"),
		g._unl_tag("리그", "검정 리그"),
		g._unl_tag("다트통", "선금 다트통"),
	]
	g.won = true
	g.over_t = 0.0
	g.state = g.S.OVER
	await _shot("over_won", Vector2(-50.0, -50.0), none, 120)
	g.won = false
	g.leg_no = 23
	g.run_unlocked = []
	g.over_t = 0.0
	await _shot("over_lost", Vector2(-50.0, -50.0), none, 120)
	#  실패 + 해금 줄 — 수 넷째 줄(마지막 판)과 해금 줄이 한 판에 같이 선다
	g.run_unlocked = [
		g._unl_tag("다트통", "넓은 동전 슬롯"),
		g._unl_tag("리그", "검정 리그"),
	]
	g.over_t = 0.0
	await _shot("over_lost_unl", Vector2(-50.0, -50.0), none, 120)
	g.run_unlocked = []
	#  ── 개발자 판 ──
	g.state = g.S.PICK
	Dev.on = true
	for pg in Dev.PAGES.size():
		Dev.page = pg
		await _shot("dev_%d" % pg, Vector2(-50.0, -50.0), none, 8)
	Dev.page = 1
	Dev.open_k = "item"
	Dev.open_n1 = "동전 주기"
	for op in 2:
		Dev.open_page = op
		await _shot("devpick_%d" % op, Vector2(-50.0, -50.0), none, 8)
	Dev.open_k = ""
	Dev.on = false
	#  되돌린다 — 진짜 프로필
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
		var b := _bak(i)
		if FileAccess.file_exists(b):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(b),
					ProjectSettings.globalize_path(Save.slot_path(i)))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(b))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.gpath))
	print("  찍음")
	quit(0)
