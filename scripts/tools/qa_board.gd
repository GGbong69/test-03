extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  보드 확장 무게 측정 — 여덟 장이 판을 얼마나 바꾸나
#
#  실행:  godot --path . --headless --script scripts/tools/qa_board.gd
#
#  자는 판값(board_val)이다 — 균등 조준 다트당 기대 점수를 면적 적분
#  하나로 낸다. 보드 확장은 판의 모양을 바꾸는 물건이라 이 한 수가
#  "얼마나 세나" 를 그대로 말한다.
#
#  같이 보는 것
#    구간 넓이   트리플·더블·불이 던진 것 중 몇 %를 먹나
#    빗나감      판 밖으로 나가는 비율
#    상한        판값 상한(기본의 1.50배)까지 얼마나 남았나
#    짝          둘을 같이 샀을 때 상한에 걸리는 조합
# ══════════════════════════════════════════════════════════

var g = null
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_board.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


# 던진 것 중 그 구간에 걸리는 비율. 조준 사각형이 판보다 넓어서
# 빗나감이 생기는 그 모형 그대로다 — 넓이비가 아니라 사각형 대비다.
func _share(b: Dictionary) -> Dictionary:
	var R: float = GameData.tune("board_r")
	var S: float = GameData.tune("aim_swing")
	var box: float = (2.0 * S) * (2.0 * S)
	var u: float = PI * R * R / box            # 판 전체가 사각형에서 차지하는 몫
	var f := func(r0: float, r1: float) -> float:
		return u * (r1 * r1 - r0 * r0) / (b.dout * b.dout)
	var trp: float = f.call(b.ti, b.to)
	if b.t2o > 0.0:
		trp += f.call(b.t2i, b.t2o)
	return {
		"bull": f.call(0.0, b.bo),
		"trp": trp,
		"dbl": f.call(b.din, b.dout),
		"miss": 1.0 - u * (b.dout * b.dout) / 1.0,
	}


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)

	var base_r: Array = g._board_of([])
	var bv0: float = GameData.board_val(base_r[0], base_r[1])
	var cap: float = GameData.board_val_max()
	var s0 := _share(base_r[0])
	print("기본 판 — 판값 %.2f · 상한 %.2f (기본의 %.2f배)"
			% [bv0, cap, cap / bv0])
	print("          불 %.2f%% · 트리플 %.2f%% · 더블 %.2f%% · 빗나감 %.2f%%\n"
			% [s0.bull * 100.0, s0.trp * 100.0, s0.dbl * 100.0, s0.miss * 100.0])

	print("%-8s %-6s %7s %8s %8s %8s %8s %8s"
			% ["이름", "축", "값", "판값", "기본대비", "트리플", "더블", "빗나감"])
	var rows := []
	for m in GameData.mods():
		var r: Array = g._board_of([m.id])
		var bv: float = GameData.board_val(r[0], r[1])
		var sh := _share(r[0])
		rows.append({"id": String(m.id), "n": String(m.n), "bv": bv})
		print("%-8s %-6s %7s %8.2f %+7.1f%% %7.2f%% %7.2f%% %7.2f%%"
				% [m.n, m.get("axis", m.get("k", "")), str(m.get("v0", "")),
				bv, (bv / bv0 - 1.0) * 100.0,
				sh.trp * 100.0, sh.dbl * 100.0, sh.miss * 100.0])

	# 혼자서도 상한을 넘으면 테이블에 아예 안 뜬다 — 살 수 없는 카드다.
	print("\n혼자서 상한을 넘는 장")
	var lone := 0
	for m in GameData.mods():
		var rr: Array = g._board_of([m.id])
		if not g._board_ok(rr[0], rr[1]):
			print("  %-8s 판값 %.2f > 상한 %.2f — 상점에 안 뜬다"
					% [m.n, GameData.board_val(rr[0], rr[1]), cap])
			lone += 1
	if lone == 0:
		print("  없다")

	rows.sort_custom(func(a, b): return a.bv > b.bv)
	print("\n판값 순서")
	for r in rows:
		print("  %-8s %6.2f  %+6.1f%%" % [r.n, r.bv, (r.bv / bv0 - 1.0) * 100.0])

	# 둘을 같이 사면 상한에 걸리는 짝
	print("\n둘을 같이 못 사는 짝 (판값 상한 %.2f 초과 · 또는 판이 안 성립)" % cap)
	var bad := 0
	var mods: Array = GameData.mods()
	for i in mods.size():
		for j in range(i + 1, mods.size()):
			var a: Dictionary = mods[i]
			var b: Dictionary = mods[j]
			var rr: Array = g._board_of([a.id, b.id])
			var ok: bool = g._board_ok(rr[0], rr[1])
			if not ok:
				var v: float = GameData.board_val(rr[0], rr[1])
				var why := "판값 %.2f" % v if v > cap else "판이 안 선다"
				print("  %-8s + %-8s  %s" % [a.n, b.n, why])
				bad += 1
	print("  모두 %d짝" % bad)
	quit()
	return true
