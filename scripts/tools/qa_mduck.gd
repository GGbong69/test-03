extends SceneTree

# 음악이 비킨다 · 진 판의 테이프 처짐 검사(2026-10-21 · MUS_DUCK).
#   ① 목표를 넘는 틀(_cross_fire)에 곡이 −8dB 로 내려가 0.6초에 돌아온다 — 버스(음악 · 전체)는 그대로
#   ② 4단 빈 박에도 비킨다 · 3단은 안 비킨다
#   ③ 진 판이 덮쳐 오는 동안 판 곡이 반 속도로 처지고 · 실패 칠판의 로비 곡은 제 속도 · 이긴 끝은 안 처진다
#
#   godot --path . --headless --script scripts/tools/qa_mduck.gd

const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 60.0

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_mduck.cfg"
	Save.gpath = "user://_qa_mduck_g.cfg"
	Save.wipe()
	Save.teach("u_boot")
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  지금 곡을 다 올려 둔다(넘김을 기다리지 않는다).
func _full() -> void:
	for k in 120:
		g._mus_update(DT)
	g.mus_vol = 1.0
	g.mus_ph = g.MP.REST
	g.mus_duck = 0.0
	g._mus_update(DT)


func _run() -> void:
	for i in 20:
		g._process(DT)
	print("\n음악 비킴 · 테이프 처짐 검사\n")
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(DT)
	_full()
	var v0: float = g.mus_pl.volume_db
	var mi: int = AudioServer.get_bus_index("Music")
	var b0 := [AudioServer.get_bus_volume_db(0), AudioServer.get_bus_volume_db(mi)]

	# ① 목표를 넘는 틀
	g._cross_fire()
	g._mus_update(0.0)
	var v1: float = g.mus_pl.volume_db
	_ok("① 목표를 넘는 틀에 −8dB", is_equal_approx(v1, v0 - 8.0), "%.2f → %.2f dB" % [v0, v1])
	for k in 18:
		g._mus_update(DT)
	var vh: float = g.mus_pl.volume_db
	_ok("① 0.3초에 반쯤 돌아온다", absf(vh - (v0 - 4.0)) < 0.3, "%.2f dB" % vh)
	for k in 20:
		g._mus_update(DT)
	_ok("① 0.6초에 제자리", is_equal_approx(g.mus_pl.volume_db, v0), "%.2f dB" % g.mus_pl.volume_db)
	_ok("① 버스(전체 · 음악)는 안 건드린다",
			b0 == [AudioServer.get_bus_volume_db(0), AudioServer.get_bus_volume_db(mi)], "%s" % [b0])

	# ② 4단 빈 박 · 3단
	g.land_brk = false
	g.fire_lock = 3
	g._tally_land(false)
	var d3: float = g.mus_duck
	g.fire_lock = 4
	g._tally_land(false)
	var d4: float = g.mus_duck
	g.fire_lock = -1
	_ok("② 4단 빈 박에 비킨다 · 3단은 안 비킨다", d3 == 0.0 and d4 == 1.0, "3단 %.2f · 4단 %.2f" % [d3, d4])
	g.mus_duck = 0.0

	# ③ 진 판 — 판이 덮쳐 오는 동안(헤드리스는 연출이 안 서므로 시계를 손으로 세운다)
	var key0: String = g.mus_key
	g.won = false
	g.over_cine = 0.0
	g.over_went = false
	for k in 66:          # 1.1초 — 판이 다 덮기(OVERC hold + zoom_t 1.15) 전
		g.over_cine += DT
		g._mus_update(DT)
	_ok("③ 진 판 곡이 반 속도로 처진다", g.mus_key == key0 and g.mus_pitch <= 0.51
			and is_equal_approx(g.mus_pl.pitch_scale, g.mus_pitch),
			"%s x%.3f" % [g.mus_key, g.mus_pitch])
	g.over_went = true
	g.state = g.S.OVER
	for k in 120:
		g.over_cine = g.over_cine + DT if g.over_cine < 1.85 else -1.0
		g._mus_update(DT)
	_ok("③ 실패 칠판의 로비 곡은 제 속도", g.mus_key == "lobby" and g.mus_pitch >= 1.0
			and g.mus_pl.pitch_scale >= 1.0, "%s x%.3f" % [g.mus_key, g.mus_pl.pitch_scale])
	g.over_cine = -1.0

	# ③ 이긴 끝은 안 처진다 — 완주는 연출을 안 타지만 깃발로도 막는다
	g.state = g.S.PICK
	_full()
	g.won = true
	g.over_cine = 0.5
	g.over_went = false
	var p0: float = g.mus_pitch
	for k in 30:
		g._mus_update(DT)
	_ok("③ 이긴 끝은 안 처진다", g.mus_pitch >= p0, "x%.3f" % g.mus_pitch)
	g.over_cine = -1.0
	g.won = false

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
