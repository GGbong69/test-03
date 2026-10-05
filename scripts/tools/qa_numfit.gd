extends SceneTree
#  판 숫자가 고리 안에 든다(2026-10-05 · game.gd 의 NUMFIT · _num_layout).
#  「글씨 삐져 나가는건 아직도 마찬가지네」 — 수마다 잉크 상자를 재서 고리 한가운데에 놓고,
#  스무 수가 다 NUMFIT.gap 이상 남기는 크기 하나를 쓴다.
#  못 박는 것:
#    ① 기본 판 — 스무 수 모두 안 · 밖 여유가 gap 이상, 크기는 min 이상.
#    ② 수마다 안 여유와 밖 여유가 0.3px 안으로 같다(한쪽으로 안 쏠린다).
#    ③ 판이 커져도(보드 확장 R × 1.25) ①이 선다.
#  헤드리스로 돈다(글리프 상자는 TextServer 가 준다):
#    godot --headless --path . --script scripts/tools/qa_numfit.gd
const Save = preload("res://scripts/save.gd")
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
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
	return false
