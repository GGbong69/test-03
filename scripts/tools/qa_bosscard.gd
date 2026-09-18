extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  보스 카드가 거짓말을 안 하는가 (2026-09-18)
#
#  실행:  godot --path . --headless --script scripts/tools/qa_bosscard.gd
#  종료 코드 = 실패 개수
#
#  「카드를 보고 상점에서 빌드를 짠다」가 이번 변경의 전부다. 그러니 카드가
#  적은 수와 판정이 쓰는 수가 갈리는 순간 변경 자체가 무너진다. 목표를 읽는
#  자가 넷(카드 · 「던진다」 부제 · 상점 명판 · _begin_leg)이라 **넷을 한꺼번에**
#  잰다 — 옛 구조에서 target_mul 이 목표에 닿는 길은 한 줄뿐이었다.
#
#  재는 것
#    ① 넷이 같은 수다 (문턱이 걸린 보스와 안 걸린 보스 양쪽에서)
#    ② 「문턱」이면 맨 목표 × v 의 올림이다
#    ③ 무효면 넷이 전부 맨 목표로 돌아오고 _leg_mods 가 빈다
#    ④ 이름 줄이 칸 84px 을 안 넘고, 명판과 안 겹친다 (열 종 전수)
#    ⑤ 명판과 글리프가 카드 안쪽 면을 안 넘는다 (열 종 전수)
#    ⑥ {v} 자리표가 카드 · 명판 · 툴팁 어디에도 날것으로 안 뜬다
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0

#  카드 제 좌표. rim 5.5 → 안쪽 면 x[5.5,147.83] · y[5.5,80.5].
const RIM := 5.5
#  이름 줄은 목표 줄과 같은 축(w*0.5)에 서고 폭만 84 로 묶인다 —
#  절반 42 라 왼끝 34.7 이 명판 오른끝 31.5 와 3.2px 떨어진다.
const NAME_W := 84.0


func _ok(nm: String, cond: bool, note := "") -> void:
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])
	if not cond:
		fails += 1


func _first_boss() -> int:
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			return n
	return 0


func _initialize() -> void:
	Save.gpath = "user://_qa_bc_g.cfg"
	Save.path = "user://_qa_bc.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.drop_fast = true
	#  _initialize 는 _ready 앞이라 글꼴이 아직 안 올라와 있다. _elide 가
	#  font 를 읽으므로 여기서 먼저 세운다 — 안 세우면 「안 넘친다」가
	#  0px 끼리 맞아떨어지며 **헛통과**한다.
	if g.font == null:
		g.font = load("res://fonts/Paperlogy-7Bold.ttf")
	if g.font_sm == null:
		g.font_sm = load("res://fonts/Paperlogy-6SemiBold.ttf")
	_run()
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "전부 통과"))
	quit(mini(fails, 125))


#  상점 명판이 적는 목표. 명판은 그리기만 하므로 같은 식을 여기서 되짚는다 —
#  둘이 갈리면 이 검사가 아니라 눈이 먼저 속는다.
func _plaque_target(bn: int) -> int:
	return g._target_at(bn)


func _run() -> void:
	var boss: int = _first_boss()
	var bare: int = GameData.target_of(boss)
	g._new_run()

	# ① · ② 문턱을 꽂고 넷을 같이 본다
	g.boss_mods[boss] = PackedStringArray(["tgt"])
	var row: Dictionary = g._mod_row("tgt")
	var want: int = int(ceil(float(bare) * float(row.get("v", 1.0))))
	_ok("문턱 — 맨 목표 × v 의 올림", g._target_at(boss) == want,
			"%d × %s = %d (실제 %d)"
			% [bare, str(row.get("v", "?")), want, g._target_at(boss)])
	g.leg_no = boss
	g._begin_leg()
	_ok("문턱 — 카드 · 부제 · 명판 · 판정이 같은 수",
			g.target == want and g._target_at(boss) == want
			and _plaque_target(boss) == want,
			"판정 %d · 자 %d" % [g.target, g._target_at(boss)])

	# ③ 무효 — 넷이 맨 목표로 돌아오고 제약이 빈다
	g.boss_void[boss] = true
	_ok("무효 — 목표가 맨 목표로 돌아온다", g._target_at(boss) == bare,
			"%d (맨 목표 %d)" % [g._target_at(boss), bare])
	_ok("무효 — 걸릴 제약이 빈다", g._leg_mods(boss).is_empty(),
			"%d개" % g._leg_mods(boss).size())
	g._begin_leg()
	_ok("무효 — 판정 목표도 맨 목표", g.target == bare,
			"%d (맨 목표 %d)" % [g.target, bare])
	_ok("무효 — 걸린 제약이 없다", g.active_mods.is_empty(),
			"%d개" % g.active_mods.size())
	g.boss_void.clear()

	# 제약이 없는 보스는 맨 목표다 — 「문턱만 목표를 민다」의 반대쪽이다
	g.boss_mods[boss] = PackedStringArray(["narrow"])
	_ok("문턱이 아니면 목표가 그대로", g._target_at(boss) == bare,
			"%d (맨 목표 %d)" % [g._target_at(boss), bare])

	# ④ 이름 줄 — 열 종 전수. 표가 늘어 긴 이름이 오면 _elide 가 물어야 한다.
	#    ⚠ 헤드리스에서는 글꼴이 안 올라와 재는 것 자체가 안 된다
	#    (_tip_wrap 이 같은 자리에 같은 방어를 적어 뒀다). 창을 띄워 돌릴 때만
	#    실제로 잰다 — godot --path . --quit-after 900 --script ... 로.
	var f20: Font = g.font_sm
	if f20 == null:
		print("      이름 줄 폭 — 건너뜀(글꼴이 안 올라왔다)")
	else:
		var over := PackedStringArray()
		var cut := PackedStringArray()
		for m in GameData.modifiers():
			var nm := String(m.get("n", ""))
			var el: String = g._elide(nm, NAME_W, 20)
			var w: float = f20.get_string_size(
					el, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			if w > NAME_W:
				over.append("%s %.0f" % [nm, w])
			if el != nm:
				cut.append(nm)
		_ok("이름 줄이 칸 84px 을 안 넘는다", over.is_empty(),
				"넘친 것: %s" % ", ".join(over))
		#  명판과 실제로 안 겹치는가 — 폭만 재면 짧은 이름이 가운데로
		#  모여 통과하고 긴 이름 하나가 명판 위에 올라앉는다.
		var hit := PackedStringArray()
		for m2 in GameData.modifiers():
			var nm2 := String(m2.get("n", ""))
			var w2: float = f20.get_string_size(
					g._elide(nm2, NAME_W, 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			if 153.33 * 0.5 - w2 * 0.5 < 19.5 + 12.0 + 1.0:
				hit.append("%s %.0f" % [nm2, w2])
		_ok("이름 줄이 명판과 안 겹친다", hit.is_empty(),
				"겹친 것: %s" % ", ".join(hit))
		print("      (잘린 이름: %s)"
				% ("없음" if cut.is_empty() else ", ".join(cut)))

	# ⑤ 명판 · 글리프가 카드 안쪽 면 안이다.
	#    _icon_modifier 열 종의 실측 바깥 지름은 전부 ±0.92r 안이다 —
	#    가장 멀리 가는 것이 dead 의 부채꼴(위 -0.84r · 옆 ±0.785r)이고
	#    flat 의 대각선이 ±0.86r + 획이다. 여기서는 그 상수로 잰다.
	var face := Rect2(RIM, RIM, 153.33 - RIM * 2.0, 86.0 - RIM * 2.0)
	var bad := PackedStringArray()
	for one in [true, false]:
		var pr: float = 12.0 if one else 13.0
		var gr: float = 8.5 if one else 9.0
		var cs := [Vector2(19.5, 27.0)] if one else [
				Vector2(153.33 * 0.5 - 16.0, 27.0),
				Vector2(153.33 * 0.5 + 16.0, 27.0)]
		for c in cs:
			var pl := Rect2(c.x - pr, c.y - pr, pr * 2.0, pr * 2.0)
			if not face.encloses(pl):
				bad.append("명판 %s" % str(c))
			var gl: float = gr * 0.92
			if not face.encloses(Rect2(c.x - gl, c.y - gl, gl * 2.0, gl * 2.0)):
				bad.append("글리프 %s" % str(c))
			#  글리프가 명판 안쪽 반지름(pr - 2)에도 들어야 한다
			if gl > pr - 2.0:
				bad.append("글리프가 명판을 넘는다 %.2f > %.2f" % [gl, pr - 2.0])
	_ok("명판 · 글리프가 카드 면 안이다", bad.is_empty(),
			"%s" % ", ".join(bad))

	# ⑥ {v} 자리표 — GameData.modifiers() 의 d 는 fill() 을 지난 값이고
	#    표의 desc 는 날것이다. 날것을 물리면 화면에 「{v}배」가 그대로 뜬다.
	var raw := PackedStringArray()
	for m in GameData.modifiers():
		var d := String(m.get("d", ""))
		if d.find("{") >= 0:
			raw.append(String(m.get("id", "")))
	_ok("효과 글에 자리표가 안 남는다", raw.is_empty(),
			"남은 것: %s" % ", ".join(raw))

	#  툴팁도 같은 열을 지나는가 — 갈래 하나가 표의 날 desc 를 물면 여기서 뜬다
	g.boss_mods[boss] = PackedStringArray(["tgt"])
	g._tip_build({"k": "legboss", "i": boss})
	var tip_raw := false
	for r in g.tip_lines:
		if String(r.get("s", "")).find("{") >= 0:
			tip_raw = true
	_ok("툴팁에도 자리표가 안 남는다", not tip_raw,
			"제목 '%s'" % g.tip_title)
	_ok("툴팁이 목표를 _target_at 으로 적는다",
			str(g.tip_lines[g.tip_lines.size() - 1].get("s", "")).find(
					str(g._target_at(boss))) >= 0,
			"%s" % str(g.tip_lines[g.tip_lines.size() - 1].get("s", "")))
