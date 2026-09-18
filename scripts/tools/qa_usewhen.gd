extends SceneTree

# 사진 사용조건 검사. 기획서 s33 이 표로 낸 「사용조건」 열(use_at)이
# _cons_use 의 게이팅을 쥐는가. 못 쓰는 자리에서 손에 남는가.
#
#   godot --path . --headless --script scripts/tools/qa_usewhen.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 기획서 s33 표 그대로
const WANT := {
	"v_cash": "any", "v_pick": "any", "v_moth": "any", "v_par": "rest",
	"v_redo": "play", "v_fake": "any", "v_pnt": "play", "v_peek": "rest",
	"c_again": "play",
}

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_when.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-36s %s" % ["통과" if c else "실패", n, d])


func _find(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.id) == id:
			return c
	return {}


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	print("\n사용조건 검사 — 표가 쥐는가\n")

	# ① 표가 기획서와 같은가
	var bad := PackedStringArray()
	for id in WANT:
		var c := _find(id)
		if c.is_empty():
			bad.append("%s 없다" % id)
			continue
		if String(c.get("use_at", "")) != String(WANT[id]):
			bad.append("%s %s≠%s" % [String(c.n), String(c.get("use_at", "")), String(WANT[id])])
	_ok("표가 기획서 s33 과 같다", bad.is_empty(), ", ".join(bad))

	# 사탕 다섯은 any
	var cbad := PackedStringArray()
	for c in GameData.candies():
		if String(c.get("use_at", "any")) != "any":
			cbad.append(String(c.n))
	_ok("사탕 다섯은 아무 때나", cbad.is_empty(), ", ".join(cbad))

	# ② 자리 셋 × 아홉 장 전수
	print("")
	#  제약 고르기 화면이 없어져 자리가 셋이다 — use_at "rest" 는 원래
	#  상점·판 고르기만 열었으므로 두 사탕 모두 애초에 그 화면에서 못 썼다.
	var spots := [["상점", g.S.SHOP], ["판 고르기", g.S.LEG],
			["판 플레이", g.S.PICK]]
	print("      %-22s %s" % ["", "상점  판고르기  판플레이"])
	for id in WANT:
		var c := _find(id)
		if c.is_empty(): continue
		var w := String(c.get("use_at", "any"))
		var row := PackedStringArray()
		var wrong := PackedStringArray()
		for sp in spots:
			# 매번 새로 쥐여 준다
			g.cons = [c.duplicate()]
			g.owned = [GameData.items()[0].duplicate()]
			g.state = sp[1]
			g.pay_msg = ""
			#  런 값도 같이 되돌린다. GOOD AFTERNOON 이 이 표에서 프리크라임
			#  **앞줄**이라, 그것이 남긴 무효를 안 지우면 프리크라임이
			#  「이미 무효인 보스다」로 막혀 자리 검사가 거짓으로 실패한다
			#  — 여기서 재는 것은 자리(use_at)지 런 상태가 아니다(2026-09-18).
			g.boss_void.clear()
			# 구성 VIII 은 사용조건 위에 「첫 다트 착탄 이후」가 더 붙는다.
			# 여기서 재는 것은 사용조건이므로 궤적을 미리 심어 둔다 —
			# 그 추가 조건은 qa_again 이 따로 잰다.
			if String(c.id) == "c_again":
				g.again_aim = g.BC
				g.again_dart = GameData.darts()[0].duplicate()
			g._cons_use(0)
			# 썼으면 손에서 없어지거나(즉시) 고르는 중이 된다(burn·clone)
			var used: bool = g.cons.is_empty() or g.photo_rack != "" \
					or g.photo != ""
			row.append("○" if used else "×")
			var should: bool = w == "any" \
					or (w == "rest" and (sp[1] == g.S.SHOP or sp[1] == g.S.LEG)) \
					or (w == "play" and sp[1] == g.S.PICK)
			if used != should:
				wrong.append(String(sp[0]))
			# 못 썼으면 손에 남아야 한다
			if not used and g.cons.size() != 1:
				wrong.append("%s(잃음)" % String(sp[0]))
			g.photo = ""
			g.photo_rack = ""
		_ok("%s (%s)" % [String(c.n), w], wrong.is_empty(),
				"%s   %s" % ["  ".join(row), ", ".join(wrong)])

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
