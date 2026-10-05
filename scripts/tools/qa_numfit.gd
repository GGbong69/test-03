extends SceneTree
#  판 숫자가 고리 안에 든다(2026-10-05 · game.gd 의 NUMFIT · _num_layout).
#  「글씨 삐져 나가는건 아직도 마찬가지네」 — 수마다 잉크 상자를 재서 고리 한가운데에 놓고,
#  스무 수가 다 NUMFIT.gap 이상 남기는 크기 하나를 쓴다.
#  못 박는 것:
#    ① 기본 판 — 스무 수 모두 안 · 밖 여유가 gap 이상, 크기는 min 이상.
#    ② 수마다 안 여유와 밖 여유가 0.3px 안으로 같다(한쪽으로 안 쏠린다).
#    ③ 판이 커져도(보드 확장 R × 1.25) ①이 선다.
#    ④ 판 고르기 미니 판(_legb_front)은 판 얼굴에 글을 안 쓴다 — 돌린 판의 숫자 스물이 7px 링을
#       넘어 더블 띠 · 가죽 띠에 닿았다(검토, 2026-10-05). 숫자 크기 열쇠(LEGB.nsz)도 없다.
#    ⑤ 판 밑 글(_legb_label_lay) — 라운드 1 · 8 × 보스 제약 하나하나 · 겹치기 · 무효 · 지난 판
#       (클리어 · 건너뜀)에서 1줄이 칸(_row_rect) 폭 안에 들고, 2줄 폭이 칸 안이며 2줄 잉크
#       아랫끝이 칸 아랫끝 안이다.
#  헤드리스로 돈다(글리프 상자는 TextServer 가 준다):
#    godot --headless --path . --script scripts/tools/qa_numfit.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var n := 0
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_numfit_g.cfg"
	Save.path = "user://_qa_numfit.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


func _check(tag: String) -> void:
	g.num_fit = {}
	g.num_fit_f = -1
	var lay: Dictionary = g._num_layout()
	var sz: int = lay.sz
	var rin: float = g._board_rim(0.0)
	var rout: float = g._board_rim(g._theme_ring_w(g._board_theme())) - 1.5
	var worst := INF
	var skew := 0.0
	for i in g._sec_n():
		var a: float = float(i) * g._sec_w()
		var u := Vector2(sin(a), -cos(a))
		var hs: Vector2 = g._num_ink(g._num_text(i), sz).size * 0.5
		var p: Vector2 = u * float((lay.c as PackedFloat32Array)[i])
		var gi: float = g._num_near(p, hs) - rin
		var go: float = rout - g._num_far(p, hs)
		worst = minf(worst, minf(gi, go))
		skew = maxf(skew, absf(gi - go))
	_ok("%s — 크기 %d ≥ %d" % [tag, sz, int(g.NUMFIT.min)], sz >= int(g.NUMFIT.min))
	_ok("%s — 가장 좁은 여유 ≥ %.1f" % [tag, float(g.NUMFIT.gap)], worst >= float(g.NUMFIT.gap),
			"%.2f px" % worst)
	_ok("%s — 안 · 밖 여유가 같다" % tag, skew < 0.3, "가장 큰 차 %.2f px" % skew)


func _process(_d: float) -> bool:
	n += 1
	if n < 3:
		return false
	print("① · ② 기본 판")
	_check("기본")
	print("③ 큰 판")
	var r0: float = g.R
	g.R = r0 * 1.25
	_check("R × 1.25")
	g.R = r0
	print("④ 판 고르기 미니 판")
	_legb_face()
	print("⑤ 판 밑 글")
	_legb_labels()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
	return false


func _legb_face() -> void:
	var src: String = (g.get_script() as GDScript).source_code
	var i0 := src.find("func _legb_front(")
	var i1 := src.find("\nfunc ", i0 + 10)
	var body := src.substr(i0, i1 - i0) if i0 >= 0 else ""
	_ok("미니 판 얼굴에 글이 없다", i0 >= 0 and body.find("draw_string") < 0,
			"_legb_front %d 자" % body.length())
	_ok("숫자 크기 열쇠가 없다(LEGB.nsz)", not (g.LEGB as Dictionary).has("nsz")
			and not (g.LEGB as Dictionary).has("nsz_s"))


#  칸 하나 — 1줄 · 2줄이 칸 안인가. 가장 나쁜 여유를 돌려준다.
func _fit(i: int, rn: int) -> float:
	var L: Dictionary = g._legb_label_lay(i, rn)
	var cell: Rect2 = L.cell
	var x0: float = float(L.x)
	var x1: float = x0 + float(L.iw) + float(L.nw) + float(L.gap) + float(L.rw)
	var m: float = minf(x0 - cell.position.x, cell.end.x - x1)
	if not bool(L.done):
		m = minf(m, cell.size.x - float(L.gw))
		var asc: float = g.font.get_ascent(int(g.LEGB.goal_sz))
		var ink_bot: float = float(L.y2) + asc * float(g.INK.bot)
		m = minf(m, cell.end.y - ink_bot)
	return m


func _legb_labels() -> void:
	g._new_run()
	var per: int = GameData.legs_per_round()
	var ids := []
	for row in GameData.modifiers():
		ids.append([String(row.id)])
	ids.append(["dead", "odd"])
	for rd in [1, 8]:
		var first: int = (rd - 1) * per + 1
		var bn: int = g._round_boss(first)
		var worst := INF
		var at := ""
		for ms in ids:
			for vd in [false, true]:
				g.boss_mods[bn] = PackedStringArray(ms)
				if vd:
					g.boss_void[bn] = true
				else:
					g.boss_void.erase(bn)
				g.leg_skipped = {}
				g.leg_no = first
				for i in per:
					var m: float = _fit(i, first + i)
					if m < worst:
						worst = m
						at = "%s%s 판 %d" % [",".join(PackedStringArray(ms)), " 무효" if vd else "", i]
		g.boss_void.erase(bn)
		_ok("라운드 %d — 판 밑 글이 칸 안(제약 %d 벌 × 무효)" % [rd, ids.size()], worst >= 0.0,
				"가장 좁은 여유 %.2f px · %s" % [worst, at])
		#  지난 판 — 클리어 · 건너뜀 한 줄
		g.leg_skipped = {first + 1: true}
		g.leg_no = first + per - 1
		var wp := INF
		for i in per - 1:
			wp = minf(wp, _fit(i, first + i))
		_ok("라운드 %d — 지난 판 한 줄이 칸 안" % rd, wp >= 0.0, "가장 좁은 여유 %.2f px" % wp)
	g.leg_skipped = {}
