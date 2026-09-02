extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  조작 검사 — 소비 아이템 사용과 랙 순서 변경이 어느 화면에서 사는가
#
#  실행:  godot --path . --headless --quit-after 4000 \
#             --script scripts/tools/input_probe.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    두 조작 다 화면에는 **늘 보인다**(_hud_draw 가 CLEAR·제목류만 빼고
#    매 프레임 그린다). 그런데 눌리는 화면은 그보다 훨씬 좁았다. 보이는데
#    안 먹는 것은 플레이어에게 "고장" 이지 "규칙" 이 아니다.
#
#  무엇이 규칙인가 (docs/게임내용.md)
#    소비 — "상점에서 즉시 쓸 수 있고, 보관할 수 있고, **라운드 중에도**
#           쓸 수 있다. 사용 확정은 누르고 뗄 때다."
#    랙  — "드래그는 두 곳에서 쓴다 — 상점에서 매물을 계산대로 밀 때,
#           랙에서 스티커 순서를 바꾸거나 팔 때."
#           순서는 발동 순서라 판 중에 고칠 수 있어야 뜻이 있다. 정산 중에는
#           손 시스템이 안 산다(그래서 "득점 시작 시 스냅샷" 과 안 부딪힌다).
#
#  어떻게 재는가
#    오토플레이를 안 켠다 — _hand_press 는 오토플레이에서 통째로 물러선다.
#    화면을 직접 세우고, **진짜 입력 이벤트**를 Input 에 밀어 넣는다.
#    누름과 뗌 사이에 _process 를 돌리는 것이 핵심이다 — 손 상태를 매 프레임
#    검사하는 _hand_update 가 그 사이에 끼어들기 때문이다. 핸들러만 직접
#    부르면 그 관문을 통째로 건너뛰고, 안 되는 것이 되는 것으로 보인다.
#    Input.is_mouse_button_pressed 도 _hand_update 가 읽으므로(창 밖 안전망)
#    버튼 상태가 진짜여야 한다.
# ══════════════════════════════════════════════════════════

var g = null
var busy := false
var fails := 0

# 라운드 중으로 세는 화면들. RESOLVE 는 뺀다 — 정산 중에는 손이 안 산다.
const PLAY := ["PICK", "AIM_V", "AIM_H", "CONFIRM", "FLY"]
# 고르는 화면들. 랙과 소비 칸이 여기에도 그려지고, BLIND 는 툴팁까지 띄운다.
const PICKING := ["BLIND", "STAGE"]


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-42s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_input.cfg"
	Save.wipe()
	Input.use_accumulated_input = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _btn(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	g._unhandled_input(e)


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	g._unhandled_input(e)


func _tick() -> void:
	g._process(1.0 / 60.0)


# 사람이 누르는 순서 그대로. 안 움직이고 떼면 탭이다.
func _tap(p: Vector2) -> void:
	_btn(p, true)
	_tick()
	_btn(p, false)


# 눌러서 q 까지 끌고 뗀다. HAND.slip(5) 을 넘겨야 드래그로 산다.
func _drag(p: Vector2, q: Vector2) -> void:
	_btn(p, true)
	_tick()
	_move(p + (q - p).normalized() * 12.0)
	_tick()
	_move(q)
	_tick()
	_btn(q, false)


func _give_cons() -> void:
	var cp := GameData.consumables()
	g.cons = []
	for c in cp:
		if String(c.get("cat", "")) == "area":
			g.cons = [c.duplicate()]
			break


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


func _st(name: String) -> int:
	return int(g.S[name])


# 화면을 진짜에 가깝게 세운다. 상점은 매대를 실제로 굴려야 한다 —
# _hand_update 가 drop 배열 크기를 보고 손을 취소하기 때문이다.
func _stage(state_name: String) -> void:
	g.state = _st(state_name)
	g.sweep_live = false
	g.swap_live = false
	if state_name == "SHOP":
		g._roll_stock()
		for i in 240:
			g._process(1.0 / 60.0)     # 물건이 다 앉을 때까지
	else:
		g.drop = []


func _cons_works(state_name: String) -> bool:
	_stage(state_name)
	_give_cons()
	var before: int = g.cons.size()
	_tap(g._cons_rect(0).get_center())
	return g.cons.size() < before


func _rack_moves(state_name: String) -> bool:
	_stage(state_name)
	_give_rack()
	var first: String = String(g.owned[0].id)
	_drag(g._slot_rect(0).get_center(), g._slot_rect(2).get_center())
	return String(g.owned[0].id) != first


func _run() -> void:
	g._new_run()
	print("\n── 조작 검사 ── 소비 아이템 사용 · 랙 순서 변경\n")

	print("  [소비 아이템]  규칙: 상점 + 라운드 중")
	var ok_shop := _cons_works("SHOP")
	_say(ok_shop, "상점에서 쓸 수 있다")
	var dead := []
	for s in PLAY:
		if not _cons_works(s):
			dead.append(s)
	_say(dead.is_empty(), "라운드 중에 쓸 수 있다",
			"안 먹는 화면: %s" % ("없음" if dead.is_empty() else ", ".join(dead)))
	var pdead := []
	for s in PICKING:
		if not _cons_works(s):
			pdead.append(s)
	_say(pdead.is_empty(), "고르는 화면에서 쓸 수 있다",
			"안 먹는 화면: %s" % ("없음" if pdead.is_empty() else ", ".join(pdead)))

	print("\n  [랙 순서 변경]  규칙: 판 중에 고칠 수 있어야 한다")
	var ok_rshop := _rack_moves("SHOP")
	_say(ok_rshop, "상점에서 순서를 바꾼다")
	var rdead := []
	for s in PLAY:
		if not _rack_moves(s):
			rdead.append(s)
	_say(rdead.is_empty(), "라운드 중에 순서를 바꾼다",
			"안 먹는 화면: %s" % ("없음" if rdead.is_empty() else ", ".join(rdead)))
	var rpdead := []
	for s in PICKING:
		if not _rack_moves(s):
			rpdead.append(s)
	_say(rpdead.is_empty(), "고르는 화면에서 순서를 바꾼다",
			"안 먹는 화면: %s" % ("없음" if rpdead.is_empty() else ", ".join(rpdead)))

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d" % fails))
	quit(fails)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false
