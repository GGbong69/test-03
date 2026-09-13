extends SceneTree

# 기획서 동전표 전수 대조. 2026-09-13 사용자 지시 — "수치는 안 바꿨어?"
#
# qa_deck 은 손으로 고른 열몇 줄만 봤다. 그래서 효과 칸의 수치 열일곱 건이
# 새어 나갔다(발라트로의 조커 배수 +2 를 표는 4 로 들고 있었다). 이 자는
# **백 장을 다 본다** — 이름 · 가격 · 등급 · 그리고 효과 칸에 적힌 수.
#
# 대조 상대는 docs/기획서_동전표.csv 다. 기획서(.pptx)를 고닷이 못 읽으므로
# 표를 저장소에 박아 두고 그것을 본다. 기획서가 갈리면 그 파일을 다시 뽑아야
# 한다 — 뽑는 법은 그 파일 옆 docs/대조.md 에 적었다.
#
#   godot --path . --headless --script scripts/tools/qa_spec.gd

const GameData = preload("res://scripts/data.gd")
const SPEC := "res://docs/기획서_동전표.csv"

# 기획서 이름을 **일부러 덮은** 자리. 기획서 이름 → 게임 이름.
# 사용자가 갈라고 한 것만 여기 든다 — 내 판단으로는 못 넣는다.
const RENAMED := {
	"아카로스": "이카로스",   # 2026-09-13 사용자 지시. 기획서 s22 는 아직 옛 이름이다
}

# 표가 든 수가 기획서 글에 안 적힌 자리. **이유가 없으면 여기 못 들어온다** —
# 목록이 길어지면 그만큼 대조가 안 되는 장이 는다는 뜻이라서다.
const EXEMPT := {
	"잭과 콩나무": "gstep 1 은 「커진다」의 한 걸음 단위다. 기획서는 크기가 는다고만 적고 몫을 안 적었다",
}

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


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


# 글에 박힌 수만 뽑는다. 「배수 +2」 와 「배수 +2 다」 를 같게 보려는 것이
# 아니라, 말이 달라도 **수가 같은지**만 보려는 것이다.
func _nums(s: String) -> Array:
	var out := []
	var cur := ""
	for i in s.length():
		var ch := s[i]
		if (ch >= "0" and ch <= "9") or (ch == "." and cur != ""):
			cur += ch
		else:
			if cur != "":
				out.append(cur.trim_suffix("."))
				cur = ""
	if cur != "":
		out.append(cur.trim_suffix("."))
	return out


func _spec() -> Array:
	var f := FileAccess.open(SPEC, FileAccess.READ)
	if f == null:
		return []
	var out := []
	var head := true
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 5:
			continue
		if head:
			head = false
			continue
		out.append({"slide": r[0], "name": r[1], "eff": r[2],
				"cost": r[3], "rar": r[4]})
	f.close()
	return out


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n기획서 동전표 전수 대조 — 백 장\n")

	var spec := _spec()
	_ok("기획서 표를 읽는다", spec.size() == 100, "%d행" % spec.size())
	if spec.is_empty():
		print("\n실패 — 표가 없다\n")
		quit(1)
		return

	var raw := {}
	for r in GameData.rows("items"):
		raw[String(r.get("name", ""))] = r
	# 갈아 끼운 이름은 기획서 이름으로도 찾을 수 있게 한 줄 더 건다.
	# 대조를 통과시키려는 것이 아니라, **어느 장이 갈렸는지 말하려는** 것이다.
	for k in RENAMED:
		if raw.has(String(RENAMED[k])):
			raw[k] = raw[String(RENAMED[k])]
	var live := {}
	for x in GameData.items():
		live[String(x.get("n", ""))] = x
	# live 에도 같이 걸어야 한다. 안 걸면 갈아 끼운 장이 **수 대조에서
	# 통째로 빠진다** — 이름만 맞추고 값은 안 보는 구멍이 된다.
	for k in RENAMED:
		if live.has(String(RENAMED[k])):
			live[k] = live[String(RENAMED[k])]

	var RAR := {"일반": "common", "희귀": "uncommon", "레어": "rare",
			"레전더리": "legendary"}

	# ① 이름 — 백 장이 1:1 이다
	var miss := PackedStringArray()
	for s in spec:
		if not raw.has(s.name):
			miss.append(String(s.name))
	_ok("이름 백 장이 표에 다 있다", miss.is_empty(),
			"없는 것: %s" % ("없다" if miss.is_empty() else ", ".join(miss)))
	for k in RENAMED:
		print("      (갈아 끼움) 기획서 「%s」 → 게임 「%s」" % [k, RENAMED[k]])
	_ok("표에 기획서 밖 동전이 없다", GameData.rows("items").size() == 100,
			"%d행" % GameData.rows("items").size())

	# ② 가격 · 등급
	var bad_c := PackedStringArray()
	var bad_r := PackedStringArray()
	for s in spec:
		if not raw.has(s.name):
			continue
		var r: Dictionary = raw[s.name]
		if String(s.cost) != "" and String(s.cost) != String(r.get("cost", "")):
			bad_c.append("%s %s≠%s" % [s.name, s.cost, r.get("cost", "")])
		var want: String = RAR.get(String(s.rar).split("/")[0].strip_edges(), "")
		if want != "" and want != String(r.get("rarity", "")):
			bad_r.append("%s %s≠%s" % [s.name, want, r.get("rarity", "")])
	_ok("가격 백 장", bad_c.is_empty(),
			"어긋남: %s" % ("없다" if bad_c.is_empty() else ", ".join(bad_c)))
	_ok("등급 백 장", bad_r.is_empty(),
			"어긋남: %s" % ("없다" if bad_r.is_empty() else ", ".join(bad_r)))

	# ③ 효과 칸의 수 — 켜진 동전만. 꺼진 장은 값 칸이 아예 비어 있다
	print("")
	var bad_n := []
	var seen := 0
	for s in spec:
		if not raw.has(s.name) or not live.has(s.name):
			continue
		var r: Dictionary = raw[s.name]
		# 값을 안 든 장(조준·계산 방식만 바꾸는 장 등)은 잴 수가 없다.
		# secs 는 값이 아니다 — cond 가 sec 이면 **칸 번호**(무전기 4;10 ·
		# 피보나치 1;2;3;5;8;13)라 기획서 글에 그대로 있고, cond 가 col 이면
		# **색 번호**(0 크림 · 1 먹)라 글에 있을 수가 없다. 뒤엣것을 값으로
		# 세면 「양」이 배수 3 을 제대로 들고도 0 때문에 어긋난 것으로 읽힌다.
		var cells := PackedStringArray()
		for col in ["value", "v2", "gv", "gstep", "boom", "dadd"]:
			var v := String(r.get(col, ""))
			if v == "":
				continue
			# 「…1개당」 꼴은 값 1 이 단위일 뿐이라 글에 수로 안 적힌다
			if col == "value" and v == "1" and String(r.get("per", "")) != "":
				continue
			cells.append(v)
		if String(r.get("cond", "")) == "sec":
			for sv in String(r.get("secs", "")).split(";", false):
				cells.append(sv)
		if cells.is_empty():
			continue
		seen += 1
		var want_n := _nums(String(s.eff))
		# 표가 든 수가 기획서 글의 수 안에 다 있어야 한다. 기획서 쪽에만
		# 있는 수(조건에 박힌 숫자 등)는 안 따진다 — 조건은 cond 열이 쥔다.
		var lost := PackedStringArray()
		for c in cells:
			var cc := c.trim_prefix("-").trim_prefix("r").trim_prefix("+")
			if cc.ends_with(".0"):
				cc = cc.substr(0, cc.length() - 2)
			if not want_n.has(cc):
				lost.append(c)
		if not lost.is_empty() and not EXEMPT.has(String(s.name)):
			bad_n.append("%-22s 표 [%s] · 기획서 「%s」"
					% [s.name, ", ".join(lost), s.eff])
	_ok("효과 칸의 수 (%d장)" % seen, bad_n.is_empty(),
			"어긋남 %d건 · 면제 %d장" % [bad_n.size(), EXEMPT.size()])
	for b in bad_n:
		print("        %s" % b)
	for k in EXEMPT:
		print("        (면제) %-14s %s" % [k, EXEMPT[k]])

	# ④ 등급 확률 — 기획서 P.18
	print("")
	var w := {}
	var sum := 0.0
	for r in GameData.rows("rarity"):
		var ww := float(r.get("weight", "0"))
		w[String(r.get("id", ""))] = ww
		sum += ww
	var want_p := {"common": 60.0, "uncommon": 35.0, "rare": 5.0, "legendary": 0.0}
	for k in want_p:
		var got: float = 100.0 * float(w.get(k, 0.0)) / maxf(sum, 0.001)
		_ok("등급 확률 %s" % k, absf(got - float(want_p[k])) < 0.05,
				"%.1f%% (기획서 %.0f%%)" % [got, want_p[k]])

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
