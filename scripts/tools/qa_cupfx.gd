extends SceneTree

# 통 이펙트가 어느 다트통에 걸리는가. 2026-09-15 사용자 지시 —
#   "이팩트나 효과같은걸로 히든들을 표현했으면" · "해금 된것도 조금은"
#
# 네 갈래가 서로 안 겹쳐야 한다. 겹치면 히든이 아닌 다트통이 히든처럼
# 보이거나(겉이 새는 것) 히든이 평범해 보인다.
#
#   잠긴 보통    민 통 · 아무것도 없다      "아직 내 것이 아니다"
#   잠긴 히든    깨진 신호                 "무엇인지도 모른다"
#   연 보통      윤                       "내 것이다"
#   연 히든      윤 + 후광                 "내 것이고, 숨어 있던 것이다"
#
#   godot --path . --headless --script scripts/tools/qa_cupfx.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_cupfx.cfg"
	Save.wipe()
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


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n통 이펙트 — 어느 다트통에 무엇이 걸리는가\n")

	var packs := GameData.packs()

	# ① 다 잠근 채로 — 히든만 깨지고 나머지는 아무것도 없다
	Save.wipe()
	var bad := PackedStringArray()
	for pi in packs.size():
		var is_hid: bool = String(packs[pi].get("kind", "base")) == "hidden"
		var open: bool = g._pack_open(pi)          # 기본(0)은 늘 열려 있다
		var want_shut: bool = is_hid and not open
		if g._cup_shut(pi) != want_shut or g._cup_glow(pi) != (is_hid and open):
			bad.append(String(packs[pi].get("id", "")))
	_ok("다 잠근 채 — 깨짐은 잠긴 히든만", bad.is_empty(),
			"어긋남: %s" % ("없다" if bad.is_empty() else ", ".join(bad)))

	# ② 다 연 채로 — 히든만 후광, 깨짐은 하나도 없다
	for r in packs:
		Save.unlock("pack:" + String(r.get("id", "")))
	var bad2 := PackedStringArray()
	var glow := 0
	for pi in packs.size():
		var is_hid: bool = String(packs[pi].get("kind", "base")) == "hidden"
		if g._cup_shut(pi):
			bad2.append("%s 깨짐" % packs[pi].get("id", ""))
		if g._cup_glow(pi) != is_hid:
			bad2.append("%s 후광" % packs[pi].get("id", ""))
		if g._cup_glow(pi):
			glow += 1
	_ok("다 연 채 — 후광은 히든만", bad2.is_empty(),
			"후광 %d개 · 어긋남: %s"
			% [glow, "없다" if bad2.is_empty() else ", ".join(bad2)])

	# ③ 둘이 같이 켜지지 않는다 — 깨진 통에 후광이 얹히면 뜻이 섞인다
	Save.wipe()
	for r in packs:
		if String(r.get("kind", "base")) != "hidden":
			Save.unlock("pack:" + String(r.get("id", "")))
	var both := 0
	for pi in packs.size():
		if g._cup_shut(pi) and g._cup_glow(pi):
			both += 1
	_ok("깨짐과 후광이 같이 안 켜진다", both == 0, "겹친 다트통 %d개" % both)

	# ④ 히든이 아닌 다트통은 **어느 상태에서도** 히든 겉을 안 받는다
	var leak := PackedStringArray()
	for pass_i in 2:
		if pass_i == 1:
			for r in packs:
				Save.unlock("pack:" + String(r.get("id", "")))
		for pi in packs.size():
			if String(packs[pi].get("kind", "base")) == "hidden":
				continue
			if g._cup_shut(pi) or g._cup_glow(pi):
				leak.append(String(packs[pi].get("id", "")))
	_ok("보통 다트통에 히든 겉이 안 샌다", leak.is_empty(),
			"샌 다트통: %s" % ("없다" if leak.is_empty() else ", ".join(leak)))

	# ⑤ 깨진 글자는 **길이를 지킨다** — 안 지키면 한바탕마다 칸이 출렁인다
	print("")
	var len_bad := PackedStringArray()
	for t in ["???", "조건 미달", "기본 다트통", "다트 +1개로 시작합니다"]:
		for st in 40:
			if String(g._gl_soup(t, st)).length() != t.length():
				len_bad.append("%s@%d" % [t, st])
	_ok("깨진 글자가 길이를 지킨다", len_bad.is_empty(),
			"40걸음 x 4줄 · 어긋남 %d" % len_bad.size())

	# ⑥ 같은 걸음이면 같은 글자, 다른 걸음이면 달라진다.
	#    앞이 깨지면 프레임마다 글자가 끓고, 뒤가 깨지면 멈춰 보인다.
	var same: bool = String(g._gl_soup("조건 미달", 7)) == String(g._gl_soup("조건 미달", 7))
	var moves := 0
	for st in 40:
		if String(g._gl_soup("조건 미달", st)) != String(g._gl_soup("조건 미달", st + 1)):
			moves += 1
	_ok("한 걸음 안에서는 안 바뀐다", same, "같은 걸음 두 번")
	_ok("걸음이 바뀌면 글자도 바뀐다", moves >= 38, "40번 중 %d번" % moves)

	# ⑦ 한바탕은 가끔 온다. 늘 오면 무늬가 되고, 안 오면 리듬이 없다.
	var bn := 0
	for st in 600:
		if g._gl_burst(st):
			bn += 1
	var rate := float(bn) / 600.0
	_ok("한바탕이 가끔 온다", rate > 0.06 and rate < 0.32,
			"600걸음 중 %d번 (%.0f%%, 표 %.0f%%)"
			% [bn, rate * 100.0, float(g.GLITCH.burst) * 100.0])

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
