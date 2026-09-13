extends SceneTree

# 설명창 검사. 2026-09-13 사용자 지시 둘을 잰다.
#   · 태그는 **아이템의 종류와 등급 둘**뿐이다
#   · 조건 · 특성 · 사용조건은 설명(본문)으로 적는다. 가격은 안 적는다
#
#   godot --path . --headless --script scripts/tools/qa_tip.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

const KINDS := ["동전", "보드 확장", "다트", "사탕", "사진", "제약", "팩",
		"뱃지", "리그"]

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_tip.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _body() -> String:
	var out := PackedStringArray()
	for l in g.tip_lines:
		out.append(String(l.s))
	return " ".join(out)


func _tags() -> PackedStringArray:
	var t := PackedStringArray()
	for x in g.tip_tags:
		t.append(String(x.t))
	return t


# 태그 한 장이 종류이거나 등급인가
func _legit(t: String) -> bool:
	if KINDS.has(t):
		return true
	for r in ["common", "uncommon", "rare", "legendary"]:
		if GameData.rarity_name(r) == t:
			return true
	return false


func _check(label: String, hit: Dictionary) -> void:
	g._tip_build(hit)
	if g.tip_title == "":
		return
	var tg := _tags()
	var bad := PackedStringArray()
	for t in tg:
		if not _legit(t):
			bad.append(t)
	_ok("%s — 태그가 종류·등급뿐" % label, bad.is_empty(),
			"[%s]%s" % ["][".join(tg), "" if bad.is_empty() else "  ← " + ", ".join(bad)])
	# 가격 — 「일반 · 4골드」 꼴이 본문에 남았나
	var b := _body()
	var priced := false
	for r in ["common", "uncommon", "rare", "legendary"]:
		if b.find(GameData.rarity_name(r) + " · ") >= 0:
			priced = true
	_ok("%s — 본문에 값이 없다" % label, not priced, b.substr(0, 46))
	# 겹말 — 같은 줄이 두 번
	var seen := {}
	var dup := ""
	for l in g.tip_lines:
		var s := String(l.s).strip_edges()
		if s == "": continue
		if seen.has(s): dup = s
		seen[s] = true
	_ok("%s — 겹말이 없다" % label, dup == "", dup)


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
	for i in 30:
		g._process(1.0 / 60.0)

	print("\n설명창 검사 — 태그는 종류와 등급 둘뿐이다\n")

	g.state = g.S.SHOP
	for i in mini(g.stock.size(), 6):
		_check("테이블 %d" % i, {"k": "stock", "i": i})
	if not g.owned.is_empty():
		_check("동전 슬롯", {"k": "rack", "i": 0})
	if not g.cons.is_empty():
		_check("손에 든 것", {"k": "held", "i": 0})

	# 컬렉션 여섯 탭
	var tabs := [["citem", "컬렉션 동전"], ["cmod", "컬렉션 보드 확장"],
			["cdart", "컬렉션 다트"], ["ccons", "컬렉션 사탕"],
			["cfix", "컬렉션 사진"], ["cmodf", "컬렉션 제약"]]
	g.state = g.S.COLLECT
	for t in tabs:
		_check(String(t[1]), {"k": String(t[0]), "i": 0})

	# 조건이 본문에 있나 — 조건 있는 동전 열 장
	print("")
	var n := 0
	for it in GameData.items():
		var c := String(it.get("c", ""))
		if c == "" or c == "always" or n >= 10:
			continue
		n += 1
		g._tip_build({"k": "citem", "i": GameData.items().find(it)})
		var ct := GameData.cond_text(c)
		_ok("조건이 본문에 · %s" % String(it.n), _body().find(ct) >= 0,
				"%s | %s" % [ct, _body().substr(0, 40)])

	# 등급 태그 — 동전에는 있고 사탕·다트·보드 확장에는 없다
	print("")
	g._tip_build({"k": "citem", "i": 0})
	_ok("동전에 등급 태그가 있다", _tags().size() == 2, "[%s]" % "][".join(_tags()))
	g._tip_build({"k": "cdart", "i": 1})
	_ok("다트에 등급 태그가 없다", _tags().size() == 1, "[%s]" % "][".join(_tags()))
	g._tip_build({"k": "cmod", "i": 0})
	_ok("보드 확장에 등급 태그가 없다", _tags().size() == 1, "[%s]" % "][".join(_tags()))

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
