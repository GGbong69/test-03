extends SceneTree

#  기획서(84_demo.pptx)에 남은 **옛 빌드 화면**을 지금 빌드로 다시 찍는다.
#  deck_shots.gd 가 컬렉션 여섯 탭과 새 런 한 장을 맡았고, 여기는 그 바깥의
#  열둘을 맡는다 — 시작 화면 · 새 런(다트통 셋) · 판 고르기 · 정보창 트랙 탭 ·
#  보스 제약 · 왼쪽 벽 셋 · 완주.
#
#   godot --path . --quit-after 6000 --script scripts/tools/deck_shots2.gd
#   (돌린 뒤 git checkout -- project.godot)
#
#  ── 여기서 갈린 두 가지 ──────────────────────────────────
#  ① **시계를 엔진에 맡긴다.** 다른 촬영 도구는 set_process(false) 로 눌러 두고
#     _process 를 손으로 미는데, 3D 통(새 런)과 3D 상인 팔(판 고르기 · 제약)은
#     _physics_process 에서 돈다 — 손으로 밀면 자루가 허공에 굳고 팔이 안 선다.
#     대신 Engine.max_fps 를 60 으로 묶어 **한 프레임 = 한 물리 걸음**으로 맞춘다.
#     vsync 가 꺼진 창에서 30프레임이 0.05초인 그 함정을 이 한 줄이 막는다.
#  ② 커서를 눌러 두는 일은 _quiet() 이 매 프레임 한다. 설명창 틀과 튜토리얼
#     예고(노란 「!」와 조여 드는 어둠)도 같은 자리에서 죽인다.

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
#  다시 돌릴 때 한 장만 고쳐 찍는 길. 인자가 없으면 전부 찍는다.
#    ... --script scripts/tools/deck_shots2.gd -- win
var only := ""


func _want(k: String) -> bool:
	return only == "" or only == k


func _initialize() -> void:
	for s in OS.get_cmdline_user_args():
		only = String(s)
	#  진짜 저장을 안 건드린다 — 전역(해금 · 통계)까지 도구 자리로 돌린다.
	#  gpath 를 빼먹으면 _finish_leg 의 Save.bump("wins") 가 사람의 통계에 든다.
	Save.gpath = "user://_deck2_g.cfg"
	Save.path = "user://_deck2.cfg"
	Save.wipe()
	Engine.max_fps = 60
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


#  설명창을 완전히 내린다 — 알파만 0 으로 두면 틀이 한 장 남는다.
#  튜토리얼도 같이 끈다(저장을 지우고 들어오므로 첫 화면마다 걸린다).
func _quiet() -> void:
	if g == null:
		return
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_i = 0
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 0.0
	g.tip_a = 0.0
	g.tip_title = ""
	g.tip_lines = []
	g.tip_tags = []
	#  창 위의 진짜 마우스가 조금만 움직여도 mouse_at 을 덮어써서 판 칸이
	#  밝아지고 글줄에 띠가 뜬다. 매 프레임 화면 밖에 다시 박는다.
	g.mouse_at = Vector2(-999.0, -999.0)


func _process(_d: float) -> bool:
	_quiet()
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		_quiet()
		await process_frame


func _snap(nm: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("저장: %s" % nm)


# ══════════════════════════════════════════════════════════
#  ① 시작 화면
# ══════════════════════════════════════════════════════════
func _shoot_title() -> void:
	g.state = g.S.TITLE
	g.ttl_fly.clear()
	g.ttl_stuck.clear()
	g._egg_reset()
	#  제목 판의 자루는 _title_tick 이 민다 — 프레임을 세지 말고 시간을 민다.
	for i in 40:
		g._title_tick(1.0 / 60.0)
	await _snap("deck_title")
	#  인트로가 꽂아 두고 넘기는 세 발. 사람이 켰을 때의 첫 화면은 이쪽이다 —
	#  도구는 인트로를 안 타므로(--script 면 _intro_wanted 가 거짓) 손으로 꽂는다.
	for i in 3:
		g._ttl_throw(g._intro_aim(i))
	for i in 60:
		g._title_tick(1.0 / 60.0)
	await _snap("deck_title_darts")


# ══════════════════════════════════════════════════════════
#  ② 새 런 — 다트통 셋 · 초록 리그
# ══════════════════════════════════════════════════════════
func _shoot_newrun() -> void:
	#  잠긴 다트통은 효과 줄 대신 조건 줄이 뜬다.
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	#  리그 해금은 **다트통마다 따로** 뚫린다(league_key 가 다트통 id 를 낀다).
	#  한 통에만 뚫으면 통을 넘기는 순간 _pack_view 가 흰 리그로 내린다.
	for p in GameData.packs():
		for l in GameData.leagues():
			Save.unlock(GameData.league_key(String(l.get("id", "")),
					String(p.get("id", ""))))
	Save.flush()
	g._open_newrun()
	await _wait(240)                 # 자루가 통 안에서 가라앉기를 기다린다
	_green()
	await _snap("deck_cup_base")     # 첫 칸 = 기본 다트통
	g._pack_step(1)                  # 둘째 칸 = 여벌 다트통
	await _wait(200)
	_green()
	await _snap("deck_newrun_green")
	await _snap("deck_cup_mag")      # 같은 화면 — 왼쪽 미리보기만 잘라 쓴다
	g._pack_step(1)                  # 셋째 칸 = 일당 다트통
	await _wait(200)
	_green()
	await _snap("deck_cup_wage")


func _green() -> void:
	GameData.league = "green"
	Save.set_pick("league", "green")


# ══════════════════════════════════════════════════════════
#  ③ 판 고르기 — 작은 판 · 큰 판 · 보스 판 셋
# ══════════════════════════════════════════════════════════
func _shoot_leg() -> void:
	GameData.pack = "base"
	Save.set_pick("pack", "base")
	_green()
	g._new_run()                     # 끝에서 _open_leg() → state = S.LEG, 1판
	await _wait(120)                 # 카드가 눕고 상인 팔이 설 때까지
	await _snap("deck_leg3")


# ══════════════════════════════════════════════════════════
#  ④ 정보창 「트랙」 탭
# ══════════════════════════════════════════════════════════
func _shoot_info() -> void:
	g._open_stage()                  # 1판은 보스가 아니라 곧장 _start_leg 로 간다
	g._swap_skip()
	await _wait(20)
	for k in 4:
		Dev._give_item(g, GameData.items()[k * 5])
	for c in GameData.fixtures().slice(0, 2):
		g.cons.append(c.duplicate())
	#  키는 **트랙 번호**(areas.csv 의 track 열)다. 영역 인덱스를 넣으면
	#  조용히 Lv.1 로 남는다.
	g.track_lv = {610001: 2, 610003: 1, 610004: 1}
	g.track_hits = {610001: 9, 610002: 3, 610003: 2, 610004: 1}
	g.gold = 46
	g.leg_no = 7
	g.target = GameData.target_of(g.leg_no)
	g.total = int(float(g.target) * 0.45)
	g.grip_t = 9.0
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	g.runinfo_tab = 1
	await _wait(60)
	var p: Rect2 = g._ri_panel()
	print("  정보창 판(논리) %s → 1280x720 에서 (%d,%d)-(%d,%d)" % [p,
			int(p.position.x * 2.0), int(p.position.y * 2.0),
			int(p.end.x * 2.0), int(p.end.y * 2.0)])
	await _snap("deck_info_track")


# ══════════════════════════════════════════════════════════
#  ⑤ 보스 판의 제약 셋
# ══════════════════════════════════════════════════════════
func _boss_leg() -> int:
	for n in range(1, 100):
		if GameData.is_boss(n):
			return n
	return GameData.legs_per_round()


func _shoot_mods() -> void:
	g.state = g.S.PICK
	g.leg_no = _boss_leg()
	g._open_stage()                  # → state = S.STAGE, 카드 셋
	g._swap_skip()
	#  깔리는 셋은 _draw_weighted 로 뽑혀 매번 다르다. 옛 덱과 같은 셋
	#  (그늘 · 홀대 · 역풍)으로 못 박아 다시 돌려도 같은 그림이 나오게 한다.
	var base: int = GameData.target_of(g.leg_no)
	g.stage_pick.clear()
	g.stage_stand.clear()
	for id in ["shade", "odd", "gust"]:
		for m in GameData.modifiers():
			if String(m.get("id", "")) != id:
				continue
			var tgt := base
			if String(m.get("k", "")) == "target_mul":
				tgt = int(ceil(float(base) * float(m.get("v", 1.0))))
			g.stage_pick.append({"d": m, "target": tgt})
			g.stage_stand.append(0.0)
			break
	g.stage_t = 0.0
	#  카드가 다 설 때까지 — 프레임을 세지 말고 깔리는 시간을 본다.
	await _wait(40)
	for i in 300:
		if g.stage_t >= g._deal_time() + 0.6:
			break
		await _wait(1)
	await _wait(30)
	await _snap("deck_mods")


# ══════════════════════════════════════════════════════════
#  ⑥ 왼쪽 벽 — 가벼운 · 자석 · 표준 여섯 발
# ══════════════════════════════════════════════════════════
func _wall(id: String) -> void:
	g.mods_own = []
	g.active_mods = []
	g.leg_no = 5
	g._board_bake()
	g._start_leg()                   # remaining 을 magazine 으로 다시 깐다
	g._swap_skip()
	#  그래서 **그 뒤에** 갈아 끼운다. 벽이 읽는 것은 remaining 하나다.
	var row: Dictionary = GameData.dart_of(id)
	g.remaining = []
	g.grip_slot = []
	for k in 6:
		g.remaining.append(row)
		g.grip_slot.append(k)
	g.grip_n = g.remaining.size()
	g.darts_left = g.remaining.size()
	g.grip_pick = -1
	g.grip_t = 9.0                   # 여섯 자루가 다 날아와 꽂힌 뒤
	g.darts = []
	g._bd3_close()
	g.state = g.S.PICK
	g.aim_dim = 0.0
	await _wait(30)
	g.grip_t = 9.0
	g.grip_pick = -1


func _shoot_racks() -> void:
	for id in ["lgt", "mag", "std"]:
		await _wall(id)
		await _snap("deck_rack_%s" % id)


# ══════════════════════════════════════════════════════════
#  ⑦ 완주 화면
# ══════════════════════════════════════════════════════════
func _shoot_win() -> void:
	GameData.pack = "base"
	Save.set_pick("pack", "base")
	g._new_run()
	g._swap_skip()
	#  오른쪽 칸(마지막까지 든 것)이 「없음」으로 안 뜨게 먼저 채운다.
	for k in 4:
		Dev._give_item(g, GameData.items()[k * 7])
	#  「던진 다트」는 Save.stat("darts") 를 그대로 읽는다. 손으로 세운 런이라
	#  한 발도 안 던졌고, 그러면 완주 화면에 0 이 박힌다 — 스물넷 판을 여섯
	#  발로 넘긴 셈(24 x 5.75)을 미리 채워 넣는다.
	Save.bump("darts", 138)
	g.gold = 120
	g.leg_no = GameData.legs_n()     # 24 = 마지막 보스 판
	g.target = GameData.target_of(g.leg_no)
	g.total = g.target
	g.darts_left = 2
	g._finish_leg()                  # → state = S.OVER · won = true
	print("  완주 갈래 state=%d won=%s" % [g.state, g.won])
	await _wait(220)                 # over_t 가 판 · 쪽지를 다 띄운다
	await _snap("deck_win")


func _run() -> void:
	await _wait(20)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	if _want("title"):
		await _shoot_title()
	if _want("newrun"):
		await _shoot_newrun()
	#  아래 넷은 런 하나를 이어서 쓴다 — 따로 찍으려면 새 런부터 다시 연다.
	if _want("leg") or _want("info") or _want("mods") or _want("rack"):
		await _shoot_leg()
	if _want("info"):
		await _shoot_info()
	if _want("mods"):
		await _shoot_mods()
	if _want("rack"):
		await _shoot_racks()
	if _want("win"):
		await _shoot_win()
	print("  다 찍었다")
	quit(0)
