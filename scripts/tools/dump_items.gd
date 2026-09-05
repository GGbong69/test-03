extends SceneTree

# 동전을 게임이 찍는 문구 그대로 뽑는다. 이름·희귀도를 다시 정할 때
# 조건과 효과를 눈으로 보고 정해야 하므로 표를 손으로 옮기지 않는다.
#
#     godot --headless --script scripts/tools/dump_items.gd
#
# 화면이 쓰는 것은 eff_line 이다 — item_desc 는 조건+효과만 잇는
# 축약판이라 "1개당" 앞머리와 곁다리 효과가 빠진다.
# items() 는 켜진 99장만 준다. 꺼진 86장도 이름을 다시 지을 대상이므로
# 원본 CSV 를 직접 읽어 같은 cond_text/eff_text 로 문구를 만든다.

var gd


func _initialize() -> void:
	gd = load("res://scripts/data.gd")
	var rows := _csv("res://data/items.csv")
	var out := PackedStringArray()
	out.append(",".join(PackedStringArray([
			"사용", "id", "이름", "희귀도", "값", "가중치", "등장판",
			"조건", "효과", "골드", "태그", "새이름", "새희귀도", "메모"])))
	var on := 0
	for r in rows:
		var use: bool = String(r.get("enabled", "1")).strip_edges() != "0"
		if use:
			on += 1
		# items() 가 굳히는 sec/col 조건을 여기서도 같은 꼴로 만든다
		var cnd: String = r.get("cond", "")
		if cnd == "sec" or cnd == "col":
			cnd = cnd + ":" + String(r.get("secs", "")).replace(";", ",")
		# item_desc 는 per·k2·grow·dadd·side·boom 까지 읽는다. 넷만 넘기면
		# "보유 아이템 1개당" 같은 앞머리와 곁다리 효과가 통째로 빠진다.
		var it := {
			"c": cnd, "k": String(r.get("kind", "")),
			"v": int(r.get("value", "0")), "aim": String(r.get("aim", "")),
			"per": String(r.get("per", "")),
			"k2": String(r.get("k2", "")), "v2": int(r.get("v2", "0")),
			"grow": String(r.get("grow", "")), "gstep": int(r.get("gstep", "0")),
			"dadd": int(r.get("dadd", "0")), "side": String(r.get("side", "")),
			"boom": String(r.get("boom", "")),
		}
		var g := ""
		if String(r.get("gold", "")) != "":
			g = gd.gold_text(String(r.get("gold")), int(r.get("gv", "0")))
		var w: String = String(r.get("weight", "")).strip_edges()
		if w == "":
			w = "(등급값)"
		var ml: String = String(r.get("min_leg", "")).strip_edges()
		if ml == "":
			ml = "(등급값)"
		out.append(",".join(PackedStringArray([
			"O" if use else "X", _q(r.get("id", "")), _q(r.get("name", "")),
			_q(r.get("rarity", "")), _q(r.get("cost", "")), _q(w), _q(ml),
			_q(gd.cond_text(cnd)), _q(gd.eff_line(it)), _q(g),
			_q(String(r.get("_tags", "")).replace(";", " · ")), "", "",
			_q(r.get("_note", "")),
		])))
	# 엑셀이 UTF-8 로 읽게 BOM 을 앞에 둔다
	var f := FileAccess.open("res://shots/items_all.csv", FileAccess.WRITE)
	f.store_8(0xEF); f.store_8(0xBB); f.store_8(0xBF)
	f.store_string("\n".join(out))
	f.close()
	print("전체 %d · 켜짐 %d · 꺼짐 %d" % [rows.size(), on, rows.size() - on])
	quit()


func _q(v) -> String:
	var s := String(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		return "\"%s\"" % s.replace("\"", "\"\"")
	return s


func _csv(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var head := f.get_csv_line()
	# BOM 이 첫 열 이름에 붙어 온다 — 떼지 않으면 id 를 못 찾는다
	head[0] = head[0].lstrip("\ufeff")
	var out := []
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 2:
			continue
		var d := {}
		for i in head.size():
			d[head[i]] = line[i] if i < line.size() else ""
		out.append(d)
	f.close()
	return out
