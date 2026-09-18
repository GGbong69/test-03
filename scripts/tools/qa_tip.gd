extends SceneTree

# 설명창 검사. 2026-09-13 사용자 지시 둘을 잰다.
#   · 태그는 **아이템의 종류와 등급 둘**뿐이다
#   · 조건 · 특성은 설명(본문)으로 적는다. 가격은 안 적는다
#   · 쓰는 때(사진 · 사탕) · 받는 때(뱃지)는 시점이라 태그다(2026-09-17)
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
#  사진·사탕의 쓰는 때(use_at_name)와 뱃지를 받는 때(_tag_when)도 태그다(2026-09-17 — 본문
#  둘째 줄에서 태그 줄로 옮겼다). 둘 다 시점이지 효과가 아니다.
func _legit(t: String) -> bool:
	if KINDS.has(t):
		return true
	for w in ["rest", "play"]:
		if GameData.use_at_name(w) == t:
			return true
	for w in ["now", "leg", "shop", "stage", "boss"]:
		if g._tag_when({"when": w}) == t:
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

	#  ── 등급 판 위에서 글이 읽히는가 (2026-09-18) ──────
	#  판 면을 등급색 쪽으로 섞으면 그 위의 잉크 대비가 깎인다. 섞는 몫 0.08 은
	#  **무너지는 자리 바로 한 칸 아래**다 — 0.10 이면 배수 붉음(C_MULT)이
	#  4.41 로 4.5:1 밑으로 떨어지고 0.12 면 4.22 다. 이 자리는 한 번 깨진
	#  적이 있다(_tip_draw 의 lightened(0.06) 주석: 배수 붉음이 3.7:1 까지
	#  떨어져 있었다). face_mix 를 올리면 **일부러 실패해야** 한다.
	print("")
	var mix: float = g.TIP_RANK.face_mix
	for rr in GameData.RARITIES:
		var face: Color = g.C_PANEL
		if String(rr) != "common":
			face = g.C_PANEL.lerp(GameData.rarity_color(String(rr)), mix)
		for ink in [["C_TXT", g.C_TXT], ["C_DIM", g.C_DIM],
				["C_MULT", g.C_MULT], ["C_ACC", g.C_ACC]]:
			var cr := _contrast(ink[1], face)
			_ok("%s 판 위 %s >= 4.5:1" % [rr, ink[0]], cr >= 4.5,
					"면 #%s · %.2f" % [face.to_html(false), cr])

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))


func _lum(c: Color) -> float:
	var v := [c.r, c.g, c.b]
	var w := [0.2126, 0.7152, 0.0722]
	var o := 0.0
	for i in 3:
		var x: float = v[i]
		x = x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
		o += x * float(w[i])
	return o


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
