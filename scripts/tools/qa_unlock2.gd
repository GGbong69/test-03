extends SceneTree

# 해금 조건 검사. 2026-09-13 사용자 제보 —
#   "정조준이 왜 리볼버로 볼스아이 쏜것도 아니고 해금돼? 해금조건 다 기획서대로 되는거 맞아?"
#
# 기획서 s8(다트통 14) · s9(리그 8) · s27(레전더리 5) 를 하나씩 맞춘다.
# 기획서대로 못 적은 자리는 EXCUSE 에 **이유와 함께** 적는다 —
# 조용히 넘어가면 「다 기획서대로」라고 말하게 된다. 그게 이번에 난 일이다.
#
#   godot --path . --headless --script scripts/tools/qa_unlock2.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 기획서가 적었는데 게임이 그대로 못 적은 자리. 값은 「왜」다.
const EXCUSE := {
	"데칼코마니": "기획서 조건이 「[시아노타입]과 [COPPEE]가 서로 복제」인데 그 두 장이 복사 효과라 엔진에 없다(enabled 0). 기획서 안에서 닫힌 고리다",
	"저울 다트통": "기획서 조건이 「[데칼코마니 해금]」인데 그 해금이 위 고리에 걸려 있다. 고리를 끊느라 bulls 50 을 임시로 뒀다",
}

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_unl2.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-26s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n해금 조건 — 기획서 s8 · s9 · s27\n")

	# ── 레전더리 다섯 (s27) ────────────────────────────
	print("  레전더리 (s27)")
	var want := {
		"정조준":     ["revo_bull_leg", 1],
		"잭과 콩나무":  ["best_leg_bare", 24],
		"NULL":      ["best_gain", 100000],
		"녹는 시계":   ["clok_out_streak", 3],
	}
	var seen := {}
	for r in GameData.rows("items"):
		if String(r.get("rarity", "")) != "legendary":
			continue
		var nm := String(r.get("name", ""))
		seen[nm] = true
		var st := String(r.get("unlock_stat", ""))
		var uv := int(r.get("unlock_v", "0"))
		if EXCUSE.has(nm):
			print("      (못 함) %-10s %s" % [nm, EXCUSE[nm]])
			continue
		var w: Array = want.get(nm, [])
		_ok(nm, not w.is_empty() and st == String(w[0]) and uv == int(w[1]),
				"%s %d (기획서 %s)" % [st if st != "" else "없음", uv,
					"%s %d" % [w[0], w[1]] if not w.is_empty() else "?"])
	_ok("레전더리 다섯 줄", seen.size() == 5, "%d줄" % seen.size())

	# 「누적 볼스아이」로는 못 적는 조건이다 — 오래 하면 열리기 때문이다
	var bad := PackedStringArray()
	for r in GameData.rows("items"):
		if String(r.get("rarity", "")) == "legendary" \
				and String(r.get("unlock_stat", "")) == "bulls":
			bad.append(String(r.get("name", "")))
	_ok("누적 볼스아이로 여는 장이 없다", bad.is_empty(),
			"쓰는 장: %s" % ("없다" if bad.is_empty() else ", ".join(bad)))

	# ── 다트통 열넷 (s8) ───────────────────────────────
	print("\n  다트통 (s8)")
	var pw := {
		"여벌 다트통": ["prereq", "base"],
		"일당 다트통": ["prereq", "p_mag"],
		"선물 다트통": ["prereq", "p_wage"],
		"넓은 동전 슬롯": ["win_items", "4"],
		"선금 다트통": ["win_gold", "100"],
		"깃털 다트통": ["best_dart_lgt", "3"],
		"송곳 다트통": ["best_dart_prc", "3"],
		"무쇠 다트통": ["best_dart_hvy", "3"],
		"자석 다트통": ["best_dart_mag", "3"],
		"외줄 다트통": ["boss_spare", "5"],
		"[?? ???]": ["win_null", "1"],
		"0718": ["best_leg_bare", "24"],
	}
	var n := 0
	for r in GameData.rows("packs"):
		var nm := String(r.get("name", ""))
		n += 1
		if EXCUSE.has(nm):
			print("      (못 함) %-10s %s" % [nm, EXCUSE[nm]])
			continue
		if not pw.has(nm):
			continue
		var w: Array = pw[nm]
		var got := ""
		if String(w[0]) == "prereq":
			got = String(r.get("prereq", ""))
		else:
			got = "%s %s" % [r.get("unlock_stat", ""), r.get("unlock_v", "")]
		var wnt := String(w[1]) if String(w[0]) == "prereq" \
				else "%s %s" % [w[0], w[1]]
		_ok(nm, got == wnt, "%s (기획서 %s)" % [got, wnt])
	_ok("다트통 열넷 줄", n == 14, "%d줄" % n)

	# ── 리그 여덟 (s9) — 「현재 다트통으로 런 N회 클리어」 ──
	print("\n  리그 (s9)")
	var lw := [0, 1, 2, 2, 4, 5, 6, 7]
	var i := 0
	var lbad := PackedStringArray()
	for r in GameData.rows("leagues"):
		if i < lw.size():
			var got := int(r.get("unlock_wins", "0"))
			if got != lw[i]:
				lbad.append("%s %d≠%d" % [r.get("name", ""), got, lw[i]])
		i += 1
	_ok("완주 횟수 여덟 단", lbad.is_empty() and i == 8,
			"%d단 · %s" % [i, "없다" if lbad.is_empty() else ", ".join(lbad)])

	print("\n  기획서대로 못 적은 자리 %d곳" % EXCUSE.size())
	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
