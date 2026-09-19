extends SceneTree
# 게임이 툴팁에 찍는 글을 그대로 뽑는다 — 동전 · 보드 확장 · 다트 · 사탕 · 사진 · 제약 ·
# 뱃지 · 다트통 · 리그 · 팩. 표를 손으로 옮기지 않고 _tip_build 를 그대로 부른다.
# 줄은 툴팁이 접은 그대로라 「+1」 만 홀로 남은 줄 같은 접힘도 보인다.
#   godot --path . --quit-after 600 --script scripts/tools/dump_tips.gd -- <out.json>
#  창으로 돌린다 — 헤드리스는 글꼴이 없어 줄 접힘(wrapped)이 통줄로 나온다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var out := []


func _initialize() -> void:
	Save.gpath = "user://_dump_tips_g.cfg"
	Save.path = "user://_dump_tips.cfg"
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _grab(kind: String, id: String, name_hint := "") -> void:
	var lines := []
	var wraps := []
	for ln in g.tip_lines:
		lines.append(String(ln.get("s", "")))
		#  툴팁이 판 폭(글꼴로 잰)에 맞춰 접은 줄. 헤드리스는 글꼴이 없어 통줄이다 — 창으로 돌린다.
		wraps.append(Array(ln.get("wr", PackedStringArray())))
	var tags := []
	for t in g.tip_tags:
		tags.append(String(t.get("t", "")))
	out.append({"kind": kind, "id": id, "title": g.tip_title if g.tip_title != "" else name_hint,
			"lines": lines, "wrapped": wraps, "tags": tags})


func _col(kind: String, rows: Array) -> void:
	for i in rows.size():
		g._tip_build({"k": kind, "i": i})
		_grab(kind, String(rows[i].get("id", "")))


func _run() -> void:
	for i in 5:
		await process_frame
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	_col("citem", GameData.items())
	_col("cmod", GameData.mods())
	_col("cdart", GameData.darts())
	_col("ccons", GameData.candies())
	_col("cfix", GameData.fixtures())
	_col("cmodf", GameData.modifiers())
	#  뱃지 — 건너뛴 판의 보상. 툴팁과 같은 모양(본문은 효과 한 줄 · 받는 때는 태그)
	for bt in GameData.tags():
		out.append({"kind": "tag", "id": String(bt.get("id", "")), "title": String(bt.get("name", "")),
				"lines": [g._tag_text(bt)], "tags": ["뱃지", g._tag_when(bt)]})
	#  다트통 — 새 런 화면의 설명 줄
	for pk in GameData.packs():
		var pl: Array = g._pack_lines(pk) if g.has_method("_pack_lines") else []
		out.append({"kind": "pack", "id": String(pk.get("id", "")), "title": String(pk.get("name", pk.get("n", ""))),
				"lines": pl, "tags": ["다트통"]})
	#  리그
	if g.has_method("_league_lines"):
		for ll in g._league_lines():
			out.append({"kind": "league", "id": String(ll.get("id", "")), "title": String(ll.get("n", "")),
					"lines": [String(ll.get("d", ""))], "tags": ["리그"]})
	#  팩(상점의 부스터)
	if true:
		for b in GameData.boosters():
			out.append({"kind": "booster", "id": String(b.get("id", "")), "title": String(b.get("n", b.get("name", ""))),
					"lines": [String(b.get("d", b.get("desc", "")))], "tags": ["팩"]})
	var ua := OS.get_cmdline_user_args()
	var path: String = String(ua[0]) if ua.size() > 0 else "user://_dump_tips.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("  %d개 → %s" % [out.size(), path])
	quit(0)
