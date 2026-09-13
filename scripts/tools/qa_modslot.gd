extends SceneTree

# 보드 확장 검사. 2026-09-13 사용자 지시.
#   한 장만 낀다 · 새로 사면 옛것을 덮는다 · 덮인 장은 사라지고 연출이 선다
#   판값 상한은 상점 문지기에서만 뗐고 표에는 남는다
#
#   godot --path . --headless --script scripts/tools/qa_modslot.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-32s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n보드 확장 검사 — 한 장만 낀다\n")

	# ① 빈손이면 열두 장 다 살 수 있다 (전에는 피자·도넛이 상한에 걸렸다)
	g.mods_own = []
	var no := PackedStringArray()
	for m in GameData.mods():
		if not g._mod_room(String(m.id)):
			no.append(String(m.n))
	_ok("빈손이면 열두 장 다 뜬다", no.is_empty(),
			"못 사는 것: %s" % ("없다" if no.is_empty() else ", ".join(no)))

	# ② 판값을 재서 표로
	print("")
	g.mods_own = []
	var b0: Array = g._board_of([])
	var basev := GameData.board_val(b0[0], b0[1])
	print("      기본 판값 %.2f · 상한 %.2f (표는 그대로 산다)"
			% [basev, GameData.board_val_max()])

	# ③ 한 장만 남는다 · 덮는다
	print("")
	g.mods_own = []
	g._apply_mod("pizz")
	_ok("한 장 끼면 크기 1", g.mods_own.size() == 1, str(g.mods_own))
	var gold0: int = g.gold
	g._apply_mod("clok")
	_ok("새로 사도 크기 1", g.mods_own.size() == 1, str(g.mods_own))
	_ok("내용이 새것이다", String(g.mods_own[0]) == "clok", str(g.mods_own))
	_ok("덮으면 골드가 안 는다", g.gold == gold0, "%d → %d" % [gold0, g.gold])

	# ④ 연출
	_ok("덮인 장이 스러진다", String(g.mod_shed) == "pizz" and g.mod_shed_t > 0.0,
			"mod_shed '%s' t=%.2f" % [g.mod_shed, g.mod_shed_t])
	# _mod_shed_draw 는 _draw() 안에서만 부를 수 있다(Godot 규약). 여기서는
	# 시간이 제대로 줄어드는지만 잰다 — 그리기는 화면 검사가 본다.
	var t0: float = g.mod_shed_t
	for i in 60:
		g._process(1.0 / 60.0)
	_ok("연출이 끝난다", g.mod_shed_t <= 0.0, "%.2f → %.2f" % [t0, g.mod_shed_t])

	# ⑤ 같은 장은 또 못 산다
	_ok("낀 장은 또 못 산다", not g._mod_room("clok"), "clok")

	# ⑥ 배타 열이 이제 아무것도 안 막는다
	g.mods_own = ["soks"]
	_ok("핵심을 낀 채 테두리를 산다", g._mod_room("guts"), "excl 이 죽었다")

	# ⑦ 판이 실제로 갈린다 — 열두 장 하나씩
	print("")
	for m in GameData.mods():
		var nx: Array = g._board_of([String(m.id)])
		var b := GameData.board_val(nx[0], nx[1])
		print("      %-10s 판값 %6.2f  (기본 대비 %+.1f%%)"
				% [String(m.n), b, (b / basev - 1.0) * 100.0])

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
