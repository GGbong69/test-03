extends SceneTree

# 설명 글자색 검사. 2026-09-13 사용자 지시.
#   일반 회색 · 점수 푸름(C_CHIP) · 배수 붉음(C_MULT) · 확률 초록(C_ODDS)
#
#   godot --path . --headless --script scripts/tools/qa_tint.gd

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
	print("  %s %-30s %s" % ["통과" if c else "실패", n, d])


#  색 이름. **게임이 든 상수를 읽는다** — 전에는 hex 앞자리(3f8f·e259·6fbf)를
#  박아 두었고, 2026-09-13 에 값 셋의 색이 갈리자(점수와 배수의 상호 대비가
#  1.07:1 이라 실눈에 같은 회색이었다) 이 자가 통째로 눈이 멀었다.
#  칠이 안 된 것이 아니라 **칠을 못 알아본** 것이었다.
func _tag_of(c: Color) -> String:
	if c.is_equal_approx(g.C_CHIP): return "푸"
	if c.is_equal_approx(g.C_MULT): return "붉"
	if c.is_equal_approx(g.C_ODDS): return "초"
	return "·"


func _paint(t: String) -> String:
	var out := ""
	for s in g._tint(t, Color("8f86a8")):
		out += _tag_of(s.c).repeat(maxi(String(s.s).strip_edges().length(), 1))
	return out


# 토막을 이어 붙이면 원문과 같아야 한다
func _same(t: String) -> bool:
	var j := ""
	for s in g._tint(t, Color("8f86a8")):
		j += String(s.s)
	return j == t


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n글자색 검사 — 점수 푸름 · 배수 붉음 · 확률 초록\n")

	# ① 손으로 지은 표본
	var cases := [
		["배수 ×4 · 판마다 1/10 확률로 파괴", ["배수", "×4", "1/10", "확률로"]],
		["점수 +40 · 배수 +4", ["점수", "+40", "배수", "+4"]],
		["명중마다 배수 +1 · 빗나가면 −1", ["배수", "+1"]],
		["더블·트리플·불 명중 시 절반 확률로 골드 +2", ["절반", "확률로"]],
	]
	for c in cases:
		var t := String(c[0])
		var seg: Array = g._tint(t, Color("8f86a8"))
		var bad := PackedStringArray()
		for want in c[1]:
			var got := ""
			for s in seg:
				if String(s.s).strip_edges() == String(want):
					got = _tag_of(s.c)
			if got == "·" or got == "":
				bad.append(String(want))
		_ok("칠해짐 · %s" % t.substr(0, 22), bad.is_empty(),
				"%s  안 칠해진 것: %s" % [_paint(t), ", ".join(bad)])

	# ② 전수 — 모든 표의 설명이 토막을 이어 붙여도 원문 그대로인가
	print("")
	var n := 0
	var broke := PackedStringArray()
	var flat := PackedStringArray()
	for it in GameData.items():
		var lines := [GameData.eff_line(it), GameData.item_desc(it)]
		for t in lines:
			if String(t) == "": continue
			n += 1
			if not _same(String(t)): broke.append(String(t))
	for pool in [GameData.consumables(), GameData.darts(), GameData.mods(),
			GameData.modifiers()]:
		for r in pool:
			var t := String(r.get("d", ""))
			if t == "": continue
			n += 1
			if not _same(t): broke.append(t)
			# 점수나 배수를 말하는데 하나도 안 칠해졌나.
			# 「목표 점수」는 물건의 점수가 아니라 그 판을 넘길 수라
			# 안 칠하는 것이 맞다 — 그 말을 걷고 센다.
			var bare := t.replace("목표 점수", "").replace("목표 배수", "")
			var says: bool = bare.find("점수") >= 0 or bare.find("배수") >= 0
			if says and _paint(t).find("푸") < 0 and _paint(t).find("붉") < 0:
				flat.append(t)
	_ok("토막을 이어 붙이면 원문 그대로", broke.is_empty(),
			"%d줄 검사 · 어긋남 %d" % [n, broke.size()])
	for b in broke:
		print("      어긋남: %s" % b)
	_ok("점수·배수를 말하면 칠해진다", flat.is_empty(),
			"안 칠해진 줄 %d" % flat.size())
	for f in flat:
		print("      안 칠해짐: %s" % f)

	# ③ 지나치게 칠한 자리 — 「목표 점수」처럼 물건의 점수가 아닌 곳
	print("")
	var over := PackedStringArray()
	for t in ["목표 점수 1.25배", "목표 점수 0.7배", "판 시작 다트 +1"]:
		if _paint(t).find("푸") >= 0 or _paint(t).find("붉") >= 0:
			over.append("%s → %s" % [t, _paint(t)])
	_ok("물건의 점수가 아닌 곳은 안 칠한다", over.is_empty(), ", ".join(over))

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
