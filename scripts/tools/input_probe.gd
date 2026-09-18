extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  조작 검사 — 사탕 쓰기와 동전 슬롯 순서 바꾸기가 어느 화면에서 사는가
#
#  실행:  godot --headless --path . --script scripts/tools/input_probe.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    두 조작 다 화면에는 **늘 보인다**(_hud_draw 가 CLEAR·제목류만 빼고
#    매 프레임 그린다). 보이는데 안 먹는 것은 플레이어에게 "고장" 이지
#    "규칙" 이 아니다.
#
#  무엇이 규칙인가
#    사탕 — 칸에서 집어 **가운데(_use_spot)** 로 끌어 놓으면 쓴다. 딴 데
#           놓으면 칸으로 돌아간다. 누르고 떼는 옛 길도 그대로 산다.
#           확정은 둘 다 뗄 때다.
#    동전 슬롯 — 동전을 끌어 다른 칸 위에 놓으면 그 자리에 끼운다(_rack_reorder).
#    사는 화면 — 상점 · 판 중(PICK AIM_V AIM_H CONFIRM FLY) · 판 고르기 ·
#           제약 고르기. 정산(RESOLVE)만 안 산다 — 큐가 동전 슬롯 인덱스를
#           들고 있다(_hand_live · _can_rack_move). 거기서는 **안 먹어야** 통과다.
#
#  어떻게 재는가
#    오토플레이를 안 켠다 — _hand_press_at 은 오토플레이에서 통째로 물러선다.
#    화면은 게임의 여는 함수로 세운다(_new_run · _begin_leg · _open_shop ·
#    _pick_dart · _advance). 판 중 화면은 사람이 거쳐 가는 차례 그대로 앞
#    화면에서 이어 간다.
#    손짓은 **진짜 입력 이벤트**로 Input 에 밀어 넣어 _unhandled_input 을
#    지나게 한다 — 누름 → 여덟 걸음으로 나눈 끌기 → 뗌. 걸음마다 _process 를
#    한 번 돌린다. 손 상태를 매 프레임 보는 _hand_update 가 그 사이에 끼어들기
#    때문이다. 핸들러만 직접 부르면 그 관문을 통째로 건너뛴다.
#    Input.is_mouse_button_pressed 도 _hand_update 가 읽으므로(창 밖 안전망)
#    버튼 상태가 진짜여야 한다 — parse_input_event 가 그 상태까지 세운다.
#
#  자리는 뷰포트 좌표로 넣는다 (_vp)
#    _unhandled_input 첫 줄이 view_pad 를 뺀다. _cons_rect · _slot_rect ·
#    _use_spot 은 **노드 좌표**라 그만큼 더해서 넣는다. 헤드리스는 뷰포트가
#    640x640 으로 서서 view_pad 가 (0,140) 이다.
#
#  설명은 전부 배운 것으로 적고 시작한다
#    새 세이브로 런을 열면 판 고르기 설명(u_leg)이 뜨고, 설명 중의 누름은
#    _tutor_click 이 **넘기기로 삼킨다**. 손이 한 번도 안 잡혀서 옛 검사의
#    여섯 줄이 전부 "안 먹는다" 로 나왔다 — 좌표를 고친 8187a66 뒤에도 그대로
#    빨갰던 까닭이 이것이다. 게임은 맞게 삼킨 것이다.
#
#  잠깐 서는 화면은 붙든다 (_tick)
#    CONFIRM · FLY · RESOLVE 는 제 시계가 다 되면 넘어간다. 손짓 하나가 열 몇
#    프레임이라 그 사이에 화면이 바뀌면 손이 놓이고, 그것은 게임이 아니라
#    검사의 박자다. 걸음마다 그 시계를 되감는다.
#
#  게임 탓과 검사 탓을 가른다
#    이벤트가 _unhandled_input 까지 안 갔거나, 설명이 떠 있거나, 손짓 도중
#    화면이 바뀌었으면 「준비 실패」 로 따로 적는다. 손짓 도중 난 스크립트
#    오류는 게임 탓으로 센다 — 끝내 맞는 답을 내도 편집기에서는 디버거가
#    그 자리에서 멈춘다.
# ══════════════════════════════════════════════════════════

var g = null
var busy := false
var fails := 0
var trouble := ""        # 이번 손짓에서 검사 쪽이 틀린 자리. 비어 있으면 잰 것이 게임이다
var carried := false     # 마지막 손짓이 끄는 동안 CARRY 로 들렸나
var catch: Catch = null

# [화면, 묶음, 손이 사는가]. 이 차례로 잰다.
# 상점을 맨 뒤에 둔다. 테이블(drop)은 상점이 처음 열릴 때 깔리고 그 뒤로는
# 안 치워지므로, 앞에 두면 나머지 화면이 전부 지난 상점의 테이블을 들고
# 잰다. 새 게임을 켜고 첫 판에서 사탕을 끄는 사람은 빈 테이블 위에 있다.
const SCREENS := [
	["LEG", "판 고르기", true],
	["PICK", "판 중", true],
	["AIM_V", "판 중", true],
	["AIM_H", "판 중", true],
	["CONFIRM", "판 중", true],
	["FLY", "판 중", true],
	["RESOLVE", "정산", false],
	["SHOP", "상점", true],
]

# 사탕을 딴 데 놓는 자리. 사탕 칸과도 가운데 자리와도 멀다.
const MISS := Vector2(60.0, 330.0)


# 손짓 도중 난 오류를 센다.
class Catch extends Logger:
	var n := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		n += 1
		last = "%s — %s:%d %s" % [rationale if rationale != "" else code,
				file.get_file(), line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _say(ok: bool, name: String, detail := "") -> void:
	print("    %s %-24s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_input.cfg"
	Save.wipe()
	for r in GameData.tutor():
		var id := String(r.get("id", ""))
		if id != "":
			Save.teach(id)
	Input.use_accumulated_input = false
	catch = Catch.new()
	OS.add_logger(catch)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _st(name: String) -> int:
	return int(g.S[name])


func _name(st: int) -> String:
	return String(g.S.find_key(st))


# 노드 좌표 → 뷰포트 좌표. _unhandled_input 이 도로 뺀다.
# 이벤트마다 그때의 view_pad 를 읽는다 — 누름과 뗌 사이에 창이 바뀌어도
# 둘 다 제 노드 자리를 가리킨다.
func _vp(p: Vector2) -> Vector2:
	return p + g.view_pad


func _btn(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	e.position = _vp(p)
	Input.parse_input_event(e)
	# flush 가 노드까지 배달한다. 여기서 _unhandled_input 을 또 부르면 한
	# 손짓이 두 번 들어가서, 사람이 안 하는 입력으로 게임을 재게 된다.
	Input.flush_buffered_events()
	if g.mouse_down != down and trouble == "":
		trouble = "누름·뗌이 _unhandled_input 까지 안 갔다"


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if g.mouse_down else 0
	e.position = _vp(p)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	if not g.mouse_at.is_equal_approx(p) and trouble == "":
		trouble = "끌기가 _unhandled_input 까지 안 갔다"


# 한 프레임. 잠깐 서는 화면은 시계를 되감고 돌린다 — 머리말 「붙든다」.
func _tick() -> void:
	if g.state == _st("CONFIRM"):
		g.confirm_t = 0.0
	elif g.state == _st("FLY"):
		g.fly_t = 0.0
	elif g.state == _st("RESOLVE"):
		g.qt = 9.0
	g._process(1.0 / 60.0)


# 붙들지 않고 돌린다. 화면을 다음 화면으로 넘길 때만 쓴다.
func _run_until(done: Callable, cap := 600) -> void:
	for i in cap:
		if done.call():
			return
		g._process(1.0 / 60.0)


# 사람이 누르는 순서 그대로. 안 움직이고 떼면 탭이다.
func _tap(p: Vector2) -> void:
	_btn(p, true)
	_tick()
	_btn(p, false)
	_tick()


# 눌러서 q 까지 여덟 걸음에 나눠 끌고 뗀다. 첫 걸음에 HAND.slip(5) 을 넘는다.
func _drag(p: Vector2, q: Vector2) -> void:
	_btn(p, true)
	_tick()
	for k in range(1, 9):
		_move(p.lerp(q, float(k) / 8.0))
		_tick()
	carried = g.hand_st == g.H.CARRY
	_btn(q, false)
	_tick()


func _boss_leg() -> int:
	for n in range(1, 100):
		if GameData.is_boss(n):
			return n
	return GameData.legs_per_round()


# 화면을 게임의 여는 함수로 세운다. 섰으면 빈 문자열, 못 섰으면 까닭이다.
func _stage(name: String) -> String:
	var prev := ""
	match name:
		"LEG":
			g._new_run()
		"SHOP":
			g._new_run()
			g._open_shop()
			_run_until(func(): return not g._drop_busy())     # 물건이 다 앉을 때까지
		"PICK":
			g._new_run()
			g._begin_leg()           # 첫 판은 보스가 아니라 곧장 _start_leg 로 간다
			g._swap_skip()
			#  탄창이 한 종류면 _to_pick 이 고르기를 건너뛰고 곧장 조준으로 간다.
			#  고르는 화면 자체를 재려고 한 칸 되돌린다 — 상태를 직접 미는 곳은
			#  여기 하나다.
			g.state = _st("PICK")
			g.grip_pick = -1
		"AIM_V":
			prev = _stage("PICK")
			g._pick_dart(0)
		"AIM_H":
			prev = _stage("AIM_V")
			g._advance()
		"CONFIRM":
			prev = _stage("AIM_H")
			g._advance()
		"FLY":
			prev = _stage("CONFIRM")
			g.confirm_t = g.ch()
			_run_until(func(): return g.state != _st("CONFIRM"))
		"RESOLVE":
			prev = _stage("FLY")
			g.fly_t = GameData.tune("fly_time")
			_run_until(func(): return g.state != _st("FLY"))
	if prev != "":
		return prev
	if g.state != _st(name):
		return "%s 이 안 섰다 — 지금 %s" % [name, _name(g.state)]
	if g.swap_live:
		return "판 갈이가 도는 중이다"
	return ""


func _candy() -> Dictionary:
	var pool := GameData.candies()
	for c in pool:
		if String(c.get("use_at", "any")) == "any":
			return c.duplicate()
	return pool[0].duplicate()


func _lv(c: Dictionary) -> int:
	return int(g.track_lv.get(c.track, 0))


# 테이블 물건 자리. 사탕을 끄는 손은 이것을 한 치도 안 건드려야 한다.
func _table() -> Array:
	var out := []
	for it in g.drop:
		out.append(Vector2(it.u, it.w))
	return out


func _give_rack() -> void:
	var out := []
	for it in GameData.items():
		if out.size() < 3:
			var cp: Dictionary = it.duplicate()
			cp.gs = 0
			out.append(cp)
	g.owned = out
	g.sealed = -1
	g._panel_reset()


func _ids(arr: Array) -> String:
	var out := []
	for it in arr:
		out.append(String(it.id))
	return " ".join(out)


# 사탕 — 칸에서 집어 딴 데 한 번, 가운데 한 번 놓는다.
func _cons_drag(live: bool) -> Array:
	var c := _candy()
	var from: Vector2 = g._cons_rect(0).get_center()
	g.cons = [c]
	var lv := _lv(c)
	var table := _table()
	_drag(from, MISS)
	var still: bool = _table() == table
	var miss_held := carried
	var miss_kept: bool = g.cons.size() == 1 and _lv(c) == lv
	g.cons = [c.duplicate()]
	lv = _lv(c)
	table = _table()
	_drag(from, g._use_spot())
	still = still and _table() == table
	var spot_held := carried
	var spot_used: bool = g.cons.is_empty() and _lv(c) == lv + 1
	var spot_kept: bool = g.cons.size() == 1 and _lv(c) == lv
	g.cons = []
	var ok: bool = miss_kept and still
	if live:
		ok = ok and miss_held and spot_held and spot_used
	else:
		ok = ok and not miss_held and not spot_held and spot_kept
	var d := "%s · 딴 데 %s · 가운데 %s" % ["들린다" if spot_held else "안 들린다",
			"남음" if miss_kept else "씀", "씀" if spot_used else "남음"]
	if not still:
		d += " · 테이블 물건이 따라 움직였다"
	return [ok, d]


# 사탕 — 칸을 누르고 그대로 뗀다.
func _cons_tap(live: bool) -> Array:
	var c := _candy()
	g.cons = [c]
	var lv := _lv(c)
	_tap(g._cons_rect(0).get_center())
	var used: bool = g.cons.is_empty() and _lv(c) == lv + 1
	var kept: bool = g.cons.size() == 1 and _lv(c) == lv
	g.cons = []
	return [used if live else kept, "씀" if used else ("남음" if kept else "어중간")]


# 동전 슬롯 — 첫 칸을 끌어 셋째 칸에 놓는다. 끼워 넣기라 B C A 가 된다.
func _rack_drag(live: bool) -> Array:
	_give_rack()
	var o: Array = g.owned
	var before := _ids(o)
	var want := _ids([o[1], o[2], o[0]])
	_drag(g._slot_rect(0).get_center(), g._slot_rect(2).get_center())
	var after := _ids(g.owned)
	var ok: bool = (carried and after == want) if live \
			else (not carried and after == before)
	return [ok, "%s → %s" % [before, after]]


# 검사 하나. 검사 탓(trouble)과 게임 오류를 게임의 답과 갈라서 적는다.
func _check(name: String, live: bool, f: Callable) -> void:
	trouble = ""
	if g.tutor_id != "":
		trouble = "설명이 떠 있다(%s)" % g.tutor_id
	var st: int = g.state
	var e0: int = catch.n
	var r: Array = f.call(live)
	if g.state != st and trouble == "":
		trouble = "손짓 도중 화면이 바뀌었다 — %s" % _name(g.state)
	var ne: int = catch.n - e0
	var d: String = r[1]
	if ne > 0:
		d += " · 오류 %d건: %s" % [ne, catch.last]
	if trouble != "":
		d = "준비 실패 — %s" % trouble
	_say(bool(r[0]) and ne == 0 and trouble == "", name, d)


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n── 조작 검사 ── 사탕 쓰기 · 동전 슬롯 순서 바꾸기 — 누름 · 끌기 · 뗌\n")
	for s in SCREENS:
		var name: String = s[0]
		var live: bool = s[2]
		print("  [%s] %-8s %s" % [s[1], name,
				"손이 산다" if live else "손이 안 산다 — 안 먹어야 통과"])
		var why := _stage(name)
		if why != "":
			_say(false, "화면 세우기", why)
			continue
		for i in 4:
			_tick()
		_check("사탕 — 끌어서 가운데 놓기", live, _cons_drag)
		_check("사탕 — 누르고 떼기", live, _cons_tap)
		_check("동전 슬롯 — 끌어서 순서 바꾸기", live, _rack_drag)

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d" % fails))
	OS.remove_logger(catch)
	quit(fails)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false
