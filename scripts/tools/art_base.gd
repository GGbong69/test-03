extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

#  물성 사다리 기준선 — **고치기 전에 한 번, 고친 뒤에 한 번.**
#  골드 불변식(폭몫 + 틈몫 = 1.15)이 깨지면 값표 폭 · 자금판 강등 문턱 ·
#  정산 오른끝 · 툴팁 예약이 한꺼번에 밀린다. 그 넷은 아무 검사도 안
#  터지고 조용히 밀리므로, **수를 찍어 두는 것**이 유일한 그물이다.
#
#   godot --path . --quit-after 600 --script scripts/tools/art_base.gd

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_art_base.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()

	print("── 골드 계약 ──────────────────────────────")
	for n in ["7", "1234", "99999"]:
		var row := ""
		for sz in [12, 20, 24, 36]:
			row += "%s:%.4f  " % [str(sz), g.gold_w(n, int(sz))]
		print("  gold_w(%-6s) %s" % [n, row])
	#  _gold_icon_top 은 **플라크 윗변 y** 다(면 폭이 아니다). 한 번
	#  「면 폭」이라 찍어 두고 size 12 에서 −9.0000 을 읽었다 — 자가
	#  거짓말을 하면 「고치기 전 · 고친 뒤」가 통째로 못 쓰게 된다.
	#  면 폭과 덩어리는 qa_art ② 가 재는 그 식 그대로 낸다.
	for sz in [12, 20, 24, 36]:
		var fw: float = float(sz) * float(g.PLQ.w)
		var ih: float = fw * float(g.PLQ.h) * (1.0 + float(g.PLQ.side))
		print("  gold_gap(%d) = %.4f · 면 폭 %.4f · 덩어리 %.4f · 윗변 %.4f"
				% [sz, g.gold_gap(int(sz)), fw, ih,
				g._gold_icon_top(0.0, int(sz))])
	print("── 자금판 ────────────────────────────────")
	for n in ["7", "99", "123", "99999"]:
		print("  _bank_gold_w(%-6s) 24:%.4f  20:%.4f  12:%.4f"
				% [n, g._bank_gold_w(n, 24), g._bank_gold_w(n, 20),
				g._bank_gold_w(n, 12)])

	print("── 팩 ───────────────────────────────────")
	#  **FIX 를 빌려 쓰지 않는다.** 여기서 옛 식(FIX × 1.06)을 손으로 베껴
	#  두고 _obj_box 가 PACK 을 읽도록 고친 뒤에도 23.903 을 찍고 있었다 —
	#  자가 저 혼자 옛 그림을 재면 기준선이 거짓이 된다.
	var gk: float = g.GOODS_K
	var pw: float = float(g.PACK.w) * gk
	var ph: float = float(g.PACK.h) * gk
	print("  사진 면 %.2f x %.2f · 화면 %.2f x %.2f · 비 %.3f"
			% [g.FIX_W * gk * 2.0, g.FIX_H * gk * 2.0,
			g.FIX_W * gk * 2.0, g.FIX_H * gk * 2.0 * g.TBL.flat,
			float(g.FIX_W) / float(g.FIX_H)])
	print("  팩   면 %.2f x %.2f · 화면 %.2f x %.2f · 비 %.3f"
			% [pw * 2.0, ph * 2.0, pw * 2.0, ph * 2.0 * g.TBL.flat,
			float(g.PACK.w) / float(g.PACK.h)])
	print("  팩 면적 %.0fpx² (사진 %.0fpx²) · 외접 반지름 %.2f"
			% [pw * 2.0 * ph * 2.0 * g.TBL.flat,
			g.FIX_W * gk * 2.0 * g.FIX_H * gk * 2.0 * g.TBL.flat,
			sqrt(pw * pw + ph * ph)])
	print("  이음매 반두께 %.3f · 띠 반높이 %.3f · 뜯는 실 화면 %.3fpx"
			% [float(g.PACK.seam) * gk,
			float(g.PACK.seam) * float(g.PACK.band) * gk,
			g._pack_thread(gk) * g.TBL.flat])
	print("  _obj_box(boost) 반폭 %.3f · 히트 %.2f x %.2f"
			% [maxf(float(g.PACK.w), float(g.PACK.h)) * gk + 3.0,
			pw * float(g.PACK.hit) * 2.0, ph * float(g.PACK.hit) * 2.0])

	print("── 대비 (C_GOLD 위) ──────────────────────")
	for pair in [["윗줄 빛 .45", g.C_GOLD.lightened(0.45)],
			["대각 광택 .50", g.C_GOLD.lightened(0.50)],
			["대각 광택 .75", g.C_GOLD.lightened(0.75)],
			["속 네모 .40", g.C_GOLD.darkened(0.40)],
			["밑 옆면 .55", g.C_GOLD.darkened(0.55)]]:
		print("  %-14s %.3f:1" % [pair[0], _contrast(pair[1], g.C_GOLD)])
	print("  %-14s %.3f:1" % ["C_ACC 대 GOLD", _contrast(g.C_ACC, g.C_GOLD)])
	print("  %-14s %.3f:1" % ["loss 대 grey",
			_contrast(g.C_MULT.lightened(0.25), g.C_WIRE.lightened(0.18))])
	quit()


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
