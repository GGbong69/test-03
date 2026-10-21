extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  연타 검사 — 튜토리얼 런을 마구 눌러도 안 깨지는가 (2026-10-21)
#
#  실행:  godot --headless --path . --script scripts/tools/mash_probe.gd [-- 시드 [틀 수]]
#  종료 코드 = 실패 개수
#
#  심사위원은 정산 · 상인 던지기 · 판 고르기 전환 중에도 마구 누른다. input_probe ·
#  click_probe 는 정해진 손짓만 재므로, 여기서는 첫 실행 그대로 튜토리얼 런을 열고
#  틀마다 무작위 누름 · 뗌 · 끌기 · 키(Enter · Space · ESC · 방향 · TAB)를 진짜 입력
#  이벤트로 밀어 넣는다. 반은 그 화면의 단추 자리(상점 매물 · 슬롯 · 창구 · 리롤 ·
#  다음 · 판 고르기 · 런 끝 · 메뉴 줄)를, 반은 화면 아무 데나 누른다.
#  틀마다 본다: 골드 ≥ 0 · 동전 ≤ 슬롯 · 사탕 ≤ 칸 · 저절로 넘어가야 할 화면이나
#  연출이 30초 넘게 안 멎는가 · 스크립트 오류 · push_error 가 없는가.
#  끝에 본다: 런이 적어도 한 번 끝까지 갔는가(멈춘 화면이 없다는 뜻).
#
#  게임을 끄는 줄(제목 「종료」 · 일시정지 「quit」)만은 안 누른다 — 도구 실행에서는
#  곧장 닫혀 검사가 끝난다. 저장은 전역 · 프로필 셋 다 _mash 자리라 사람의 저장도,
#  다른 도구의 _tool 자리도 안 건드린다. 같은 시드면 같은 런이다(전역 난수도 박는다).
#  shortcut: 도구 실행은 덮개 · 게임 오버 연출을 곧장 건넌다(_cine_ok) — 그 동안의 연타는
#  여기서 안 잰다. 판 갈이 · 라운드 경계는 헤드리스에서도 돌아 잰다.
#  2026-10-21 첫 돌림 — 시드 열셋 × 8만 틀 · 튜토리얼 런 끝까지: 골드 · 슬롯 · 멈춤 · 오류 다 깨끗.
# ══════════════════════════════════════════════════════════

const DT := 1.0 / 60.0
const STUCK := 30.0                 # 저절로 넘어가야 할 것이 이만큼 서 있으면 멈춘 것이다
const PER_FRAME := 200              # 한 번의 _process 에 돌리는 게임 틀

var g: Node = null
var rng := RandomNumberGenerator.new()
var steps := 20000
var step := 0
var boot := 0
var fails := 0
var catch: Catch = null
var held := false                   # 검사가 왼쪽 단추를 쥐고 있다
var held_at := Vector2.ZERO
var held_n := 0                     # 쥔 채로 남은 틀
var st_t := 0.0                     # 지금 화면에 머문 시간
var st_was := -1
var busy_t := 0.0                   # 연출(덮개 · 판 갈이 · 쓸기 · 팩)이 이어진 시간
var runs := 0                       # 런 끝(S.OVER)에 들어선 횟수
var seen := {}                      # 지나간 화면
var first_bad := {}                 # 실패 이름마다 첫 번째만 적는다
var tut0 := false
var tut_end := "못 감"
var done := false
var trail := []


class Catch extends Logger:
	var n := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		n += 1
		if last == "":
			last = "%s — %s:%d %s" % [rationale if rationale != "" else code,
					file.get_file(), line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	Save.gpath = "user://_mash_g.cfg"
	#  지난 돌림이 설정 줄을 눌러 바꾼 말 · 필터 · 창 크기가 다음 돌림 첫 틀에 실리지 않게 — 같은 시드 같은 런
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.gpath))
	Save.prof_fmt = "user://_mash_p%d.cfg"
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	Save.use_slot(1)
	Save.wipe()
	var a := OS.get_cmdline_user_args()
	var sd := 20261021
	if a.size() > 0 and String(a[0]).is_valid_int():
		sd = int(a[0])
	if a.size() > 1 and String(a[1]).is_valid_int():
		steps = maxi(100, int(a[1]))
	rng.seed = sd
	seed(sd)                        # 게임의 전역 난수(런 시드 · 섞기)도 — 같은 시드면 같은 런이다
	print("연타 검사 — 시드 %d · %d틀" % [sd, steps])
	Input.use_accumulated_input = false
	catch = Catch.new()
	OS.add_logger(catch)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _bad(name: String, detail: String) -> void:
	if first_bad.has(name):
		return
	first_bad[name] = detail
	fails += 1
	print("  실패 %-24s %s (틀 %d · %s)" % [name, detail, step, _sn(g.state)])


func _sn(s: int) -> String:
	return String(g.S.find_key(s))


func _vp(p: Vector2) -> Vector2:
	return p + g.view_pad


#  마지막 손짓들 — 게임이 저 혼자 닫히면 _finalize 가 적는다(닫힘은 그 틀 묶음이 끝나야 난다).
func _log(s: String) -> void:
	trail.append("틀 %d %s %s" % [step, _sn(g.state), s])
	if trail.size() > PER_FRAME:
		trail.pop_front()


func _btn(p: Vector2, down: bool) -> void:
	_log("%s %s" % ["누름" if down else "뗌", p.round()])
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	e.position = _vp(p)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _move(p: Vector2) -> void:
	_log("끌기 %s" % [p.round()])
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	e.position = _vp(p)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(code: int) -> void:
	_log(OS.get_keycode_string(code))
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()


#  게임을 끄는 줄 위인가 — 도구 실행에서는 곧장 닫힌다(_pwr_quit · _cine_ok 거짓).
#  게임이 재는 자리는 굴곡을 되짚은 뒤다(_unhandled_input) — 같은 길로 옮겨 잰다.
func _quits(p0: Vector2) -> bool:
	var p: Vector2 = g._warp_v(_vp(p0)) - g.view_pad
	if g.state == g.S.TITLE:
		var tr: Array = g._title_rows()
		for i in tr.size():
			if String(tr[i].n) == "종료" and g._menu_rect(i).grow(2.0).has_point(p):
				return true
	elif g.state == g.S.SETTINGS:
		var sr: Array = g._set_rows()
		var qi := sr.find("quit")
		if qi >= 0 and g._set_rect(qi).grow(2.0).has_point(p):
			return true
	return false


#  지금 화면의 단추 자리들. 그 화면에서만 뜻이 있는 것만 부른다.
func _hot() -> Array:
	var out := []
	var s: int = g.state
	match s:
		g.S.LEG:
			out.append(g._leg_go())
			out.append(g._leg_skip())
		g.S.SHOP:
			out.append(g._reroll_rect())
			out.append(g._next_rect())
			for i in g.stock.size():
				out.append(g._obj_box(i))
			for i in GameData.max_items():
				out.append(g._slot_rect(i))
			for i in GameData.cons_slots():
				out.append(g._cons_rect(i))
			var cy: float = (g.TBL.fy + g.TBL.ny) * 0.5
			out.append(Rect2(Vector2(2.0, cy - 4.0), Vector2(8.0, 8.0)))
			out.append(Rect2(Vector2(630.0, cy - 4.0), Vector2(8.0, 8.0)))
		g.S.OVER:
			out.append(g._over_newrun_rect())
			out.append(g._over_row_l())
			out.append(g._over_row_r())
		g.S.NEWRUN:
			out.append(g._newrun_go())
			out.append(g._newrun_back())
		g.S.TITLE:
			for i in (g._title_rows() as Array).size():
				out.append(g._menu_rect(i))
		g.S.SETTINGS:
			for i in (g._set_rows() as Array).size():
				out.append(g._set_rect(i))
	if g._is_play():
		out.append(Rect2(Vector2(300.0, 160.0), Vector2(40.0, 40.0)))   # 판 한가운데
	return out


func _spot() -> Vector2:
	#  정보 · 일시정지 단추는 가끔만 — 자주 누르면 검사가 메뉴에서만 논다.
	if g._hud_btns_on() and rng.randf() < 0.04:
		return (g._hud_btn_rect(rng.randi() % 2) as Rect2).get_center()
	var hot := _hot()
	if not hot.is_empty() and rng.randf() < 0.5:
		var r: Rect2 = hot[rng.randi() % hot.size()]
		return r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
	var px: float = g._ui_pad().x
	return Vector2(rng.randf_range(-px, 640.0 + px), rng.randf_range(0.0, 360.0))


#  한 틀의 손. 쥐고 있으면 놓을 때까지 가끔 끈다 — 안 움직이고 떼면 탭이다.
func _hand() -> void:
	if held:
		held_n -= 1
		if rng.randf() < 0.15:
			held_at += Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-20.0, 20.0))
			_move(held_at)
		if held_n <= 0:
			held = false
			_btn(held_at, false)
		return
	var r := rng.randf()
	if r < 0.25:
		var p := _spot()
		if _quits(p):
			return
		held = true
		held_at = p
		held_n = 1 if rng.randf() < 0.7 else rng.randi_range(2, 24)
		_move(p)
		_btn(p, true)
	elif r < 0.33:
		#  ESC · TAB 은 한 몫씩만 — 자주 누르면 검사가 메뉴에서만 논다.
		var keys := [KEY_ENTER, KEY_ENTER, KEY_SPACE, KEY_SPACE, KEY_LEFT, KEY_RIGHT,
				KEY_UP, KEY_DOWN, KEY_ESCAPE, KEY_TAB]
		var k: int = keys[rng.randi() % keys.size()]
		#  제목 · 설정에서는 고른 줄을 여는 키가 「종료」를 고른 채일 수 있다.
		if (k == KEY_ENTER or k == KEY_SPACE) \
				and (g.state == g.S.TITLE or g.state == g.S.SETTINGS):
			return
		_key(k)
	elif r < 0.38:
		_move(_spot())


#  틀마다 지켜야 하는 것.
func _check() -> void:
	if int(g.gold) < 0:
		_bad("골드가 0 밑", "%d골드" % g.gold)
	if g.owned.size() > GameData.max_items():
		_bad("동전이 슬롯보다 많다", "%d / %d" % [g.owned.size(), GameData.max_items()])
	if g.cons.size() > GameData.cons_slots():
		_bad("사탕이 칸보다 많다", "%d / %d" % [g.cons.size(), GameData.cons_slots()])
	if catch.n > 0:
		_bad("스크립트 오류", catch.last)
	if g.state != st_was:
		st_was = g.state
		st_t = 0.0
		if g.state == g.S.OVER:
			runs += 1
			if g.tut_run:
				tut_end = "완주" if g.won else "실패"
	seen[_sn(g.state)] = int(seen.get(_sn(g.state), 0)) + 1
	st_t += DT
	#  사람이 고를 차례가 아닌 화면 — 제 시계로 넘어가야 한다.
	var auto: bool = g.state in [g.S.CONFIRM, g.S.FLY, g.S.RESOLVE, g.S.CLEAR, g.S.BOOST,
			g.S.INTRO, g.S.BDUEL]
	if auto and st_t > STUCK:
		_bad("화면이 안 넘어간다", "%s %.0f초" % [_sn(g.state), st_t])
	var cine: bool = g.wipe_t >= 0.0 or g.over_cine >= 0.0 or g.swap_live or g.turn_live \
			or g.sweep_live or g.boost_t >= 0.0
	busy_t = busy_t + DT if cine else 0.0
	if busy_t > STUCK:
		_bad("연출이 안 멎는다", "덮개 %.2f · 게임 오버 %.2f · 판 갈이 %s · 라운드 %s · 쓸기 %s · 팩 %.2f"
				% [g.wipe_t, g.over_cine, g.swap_live, g.turn_live, g.sweep_live, g.boost_t])


func _process(_d: float) -> bool:
	boot += 1
	if boot < 3:
		return false
	if boot == 3:
		g.set_process(false)
		g._new_run(true)            # 첫 실행 그대로 — 저장이 비어 튜토리얼 런이 선다
		tut0 = g.tut_run
		if not tut0:
			_bad("튜토리얼 런이 안 선다", "tut_run 거짓")
		return false
	for _i in PER_FRAME:
		step += 1
		_hand()
		g._process(DT)
		_check()
		if step >= steps:
			_finish()
			return true
	if step % 4000 < PER_FRAME:
		print("  … 틀 %d · %s · 판 %d · 골드 %d · 런 끝 %d" % [step, _sn(g.state), g.leg_no,
				g.gold, runs])
	return false


#  게임이 검사보다 먼저 닫혔다 — 끄는 줄을 못 가린 것이다. 통과 줄 없이 끝난다.
func _finalize() -> void:
	if not done:
		print("  실패 게임이 저 혼자 닫혔다 (틀 %d)\n    %s" % [step, "\n    ".join(PackedStringArray(trail))])


func _finish() -> void:
	if done:
		return
	done = true
	if runs < 1:
		_bad("런이 끝까지 안 간다", "마지막 화면 %s · 판 %d" % [_sn(g.state), g.leg_no])
	print("  튜토리얼 런 끝 %s · 런 끝 %d번 · 화면마다 틀 %s" % [tut_end, runs, seen])
	var ok_n := 8 - first_bad.size()     # 검사 갈래 여덟
	print("통과 %d · 실패 %d" % [maxi(ok_n, 0), fails])
	quit(fails)
