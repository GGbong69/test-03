extends SceneTree

# UI 체계 검사. docs/UI개편_설계.md 의 규칙을 코드가 지키는지 **소스를 읽어**
# 잰다. 그림을 보고 판단하는 자가 아니라, 규칙을 어긴 자리를 집는 자다.
#
# 개편이 스물두 커밋이라 손으로는 못 지킨다 — 크기 하나를 새로 만들거나
# 글자색을 그 자리에서 어둡게 하면 여기서 소리가 나야 한다.
#
#   godot --path . --headless --script scripts/tools/qa_ui.gd

const SRC := "res://scripts/game.gd"

var okn := 0
var fail := 0
var busy := false


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-32s %s" % ["통과" if c else "실패", n, d])


func _initialize() -> void:
	_run()


func _process(_d: float) -> bool:
	return true


#  WCAG 상대휘도. Color.get_luminance() 는 sRGB 값을 **선형화 없이** 섞으므로
#  대비를 재는 데 못 쓴다 — 그걸로 재면 f4efe2 가 판 위 5.67:1 로 나오는데
#  실제는 14.2:1 이다. 감마를 펴고 섞어야 눈이 보는 값이 된다.
func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _src() -> PackedStringArray:
	var f := FileAccess.open(SRC, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var out := f.get_as_text().split("\n")
	f.close()
	return out


# 그리는 줄인가 — 주석과 상수 정의는 안 센다.
func _live(ln: String) -> bool:
	var t := ln.strip_edges()
	return t != "" and not t.begins_with("#")


func _run() -> void:
	var L := _src()
	print("\nUI 체계 검사 — game.gd %d줄\n" % L.size())
	_ok("소스를 읽는다", L.size() > 100, "%d줄" % L.size())

	# ① 글자 크기는 다섯 단뿐이다(10 · 12 · 20 · 24 · 36).
	#    정규식을 안 쓴다 — GDScript 문자열의 이스케이프와 싸우느라 자가
	#    죽는 것보다, 쉼표로 끊어 읽는 편이 짧고 안 깨진다.
	#    갈무리 시절에는 격자에 떨어지는 크기였다(갈무리9 10 배수 · 갈무리11 12 배수,
	#    shot_fontgrid). 페이퍼로지(매끈한 글꼴)로 바꾼 뒤로는 격자가 아니라 **글자
	#    위계**가 이 다섯이다 — 단이 늘면 화면마다 크기가 제각각이 된다(2026-09-17).
	var allow := [10, 12, 20, 24, 36]
	var sizes := {}
	var bad_sz := []
	for i in L.size():
		if not _live(L[i]):
			continue
		if L[i].find("draw_string(") < 0:
			continue
		#  draw_string 은 여러 줄에 걸친다. 이 줄과 다음 둘을 붙여 본다.
		var blob := L[i]
		for k in range(1, 3):
			if i + k < L.size():
				blob += " " + L[i + k].strip_edges()
		#  크기는 **색 바로 앞의 정수**다. 서식이 그렇게 고정돼 있다:
		#    draw_string(font, at, t, 맞춤, 폭, 크기, 색)
		var parts := blob.split(",")
		for k in parts.size() - 1:
			var t := String(parts[k]).strip_edges()
			if not t.is_valid_int():
				continue
			var nxt := String(parts[k + 1]).strip_edges()
			if not (nxt.begins_with("Color") or nxt.begins_with("C_")
					or nxt.begins_with("_tint")):
				continue
			var sz := int(t)
			sizes[sz] = int(sizes.get(sz, 0)) + 1
			if not allow.has(sz):
				bad_sz.append("%d행 %dpx" % [i + 1, sz])
			break
	var ks := sizes.keys()
	ks.sort()
	var tally := PackedStringArray()
	for k in ks:
		tally.append("%d×%d" % [k, sizes[k]])
	print("      쓰이는 크기: %s" % ", ".join(tally))
	_ok("글자 크기가 다섯 단뿐", bad_sz.is_empty(),
			"밖의 것 %d곳%s" % [bad_sz.size(),
				"" if bad_sz.is_empty() else " — " + ", ".join(
					PackedStringArray(bad_sz.slice(0, 40)))])

	# ② 글자색을 그 자리에서 어둡게/밝게 안 한다.
	#    **글자만 본다.** 도형은 그늘과 깊이를 위해 같은 색의 여러 단이
	#    있어야 한다 — draw_rect(q, C_ACC.darkened(0.62)) 는 테이블 위의
	#    그늘이지 글자가 아니다. 처음 이 자를 넓게 잡았더니 그런 자리까지
	#    잡아서, 규칙이 실제로 무엇을 금하는지가 흐려졌다.
	var names := ["C_TXT", "C_DIM", "C_OFF", "C_GOLD", "C_ACC",
			"C_CHIP", "C_MULT", "C_ODDS"]
	var bad_col := []
	for i in L.size():
		if not _live(L[i]):
			continue
		if L[i].find("draw_string(") < 0 and L[i].find("_tip_add(") < 0:
			continue
		var blob := L[i]
		for k in range(1, 3):
			if i + k < L.size():
				blob += " " + L[i + k].strip_edges()
		for n in names:
			if blob.find(n + ".darkened") >= 0 or blob.find(n + ".lightened") >= 0:
				bad_col.append(str(i + 1))
				break
	_ok("글자색을 그 자리에서 안 만든다", bad_col.is_empty(),
			"만드는 곳 %d" % bad_col.size())
	if not bad_col.is_empty():
		print("      %s" % ", ".join(PackedStringArray(bad_col.slice(0, 24))))

	# ③ 값 셋이 명도로 갈린다 — 이 게임에서 가장 중요한 두 숫자다
	var ratio := _contrast(Color("8fc9f2"), Color("e8705c"))
	_ok("점수와 배수가 명도로 갈린다", ratio >= 1.4,
			"상호 %.2f:1 (전에는 1.07 — 실눈에 같은 회색)" % ratio)

	# ④ 판 위 글자가 읽힌다
	var pan := Color("221d33")
	for pair in [["글 1층", "f4efe2", 7.0], ["글 2층", "9b92b4", 5.0],
			["배수", "e8705c", 5.0], ["점수", "8fc9f2", 7.0],
			["꺼진 것", "6b647e", 2.5]]:
		var r := _contrast(Color(String(pair[1])), pan)
		_ok("%s 가 판 위에서 읽힌다" % pair[0], r >= float(pair[2]),
				"%.2f:1 (바라는 값 %.1f)" % [r, pair[2]])

	# ⑤ 뿌리 부품이 다 섰나
	# ⑥ 제약마다 그림이 있나 — 표에 있는 열이 다 그려져야 한다
	var src2 := FileAccess.open(SRC, FileAccess.READ)
	var whole2 := src2.get_as_text()
	src2.close()
	var head := whole2.find("func _icon_modifier")
	var tail := whole2.find("func _chute_edge")
	var body := whole2.substr(head, tail - head) if head >= 0 and tail > head else ""
	var GD = load("res://scripts/data.gd")
	var noico := PackedStringArray()
	for mo in GD.modifiers():
		if body.find("\"%s\":" % String(mo.get("id", ""))) < 0:
			noico.append(String(mo.get("n", "")))
	_ok("제약마다 그림이 있다", noico.is_empty(),
			"그림 없는 것: %s" % ("없다" if noico.is_empty() else ", ".join(noico)))
	_ok("모르는 id 에도 그림이 선다", body.find("		_:") >= 0,
			"기본 가지 — 표에 id 가 늘어도 빈 칸이 안 나온다")

	# ⑦ 모션 끄기가 실제로 시간을 0 으로 만드나
	var gg = load("res://scenes/main.tscn").instantiate()
	root.add_child(gg)
	gg.set_process(false)
	var on_t: float = gg._mo("panel")
	gg.motion_off = true
	var off_t: float = gg._mo("panel")
	_ok("모션 끄기가 시간을 0 으로", on_t > 0.0 and off_t == 0.0,
			"켬 %.3f초 → 끔 %.3f초" % [on_t, off_t])
	gg.queue_free()

	var need := ["const TYPE :=", "const PAD :=", "const MO :=",
			"func _ease_enter", "func _ease_exit", "func _ease_move",
			"func _px(", "func _pr(", "func _panel(",
			"const C_OFF :=", "const FONT_SMALL :=", "const SAFE :=",
			"var motion_off"]
	var miss := PackedStringArray()
	var whole := "\n".join(L)
	for n in need:
		if whole.find(n) < 0:
			miss.append(n)
	_ok("뿌리 부품이 다 섰다", miss.is_empty(),
			"없는 것: %s" % ("없다" if miss.is_empty() else ", ".join(miss)))

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
