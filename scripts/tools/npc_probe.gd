extends SceneTree

#  딜러 프로브
#
#  딜러의 팔은 여섯 번 다시 그렸다. 선 · V자 · 커프 · 타원 · 상자를 차례로
#  시도해 전부 졌는데, 지는 이유를 매번 "느낌" 으로만 말해서 다음 시도가
#  같은 함정에 다시 빠졌다. 그래서 **실루엣 조건 넷을 숫자로 못 박는다.**
#  여기 넷이 다 통과하는데도 안 좋아 보이면 그건 형태가 아니라 색 문제고,
#  하나라도 떨어지면 색을 아무리 만져도 안 산다. 순서가 그렇다.
#
#  검사 칸의 위는 **스티커 랙 밑변**이고 아래는 정착 물건이 칠하는
#  최상단(131.8, 2000롤 실측) — 딜러가 그릴 수 있는 전부다. 윗변을 손으로
#  적었더니 랙을 키운 날 그 띠가 칸에 들어와 몸통과 두 팔을 한 덩어리로
#  이었다(랙은 배경색이 아니라 전경으로 세어진다). 그래서 랙에서 뽑는다.
#
#  헤드리스로는 못 돈다. 뷰포트를 실제로 그려야 화소를 읽는다.
#
#  실행:  godot --path . -s scripts/tools/npc_probe.gd
#         godot --path . -s scripts/tools/npc_probe.gd -- shots/npc_sil.png

const X0 := 170
const X1 := 470
const Y1 := 132
const W := X1 - X0
var Y0 := 36
var H := Y1 - Y0

var g = null
var frames := 0
var fails := 0
var out_png := ""

# 배경으로 칠 색들. 딜러 전용 색을 나열하는 대신 배경을 나열한다 —
# 딜러 색은 자꾸 바뀌지만 벽·레일·펠트는 이 그림의 뼈대라 안 바뀐다.
var bg_cols: Array[Color] = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_png = a[0]
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-26s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	# 게임 시계를 우리가 돈다. 엔진에 맡기면 툴팁이 프레임마다 되살아나
	# 딜러를 가린다 — shot.gd 가 같은 이유로 같은 짓을 한다.
	if g != null:
		g.set_process(false)
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
	frames += 1
	if frames == 10:
		g.gold = 24
		g._open_shop()
		g._drop_settle()
	if frames == 50:
		_measure()
		quit(1 if fails > 0 else 0)
	return false


# 랙 밑변 아래 2px 부터 본다. 상점에서 랙은 HUD_UP 만큼 올라가 있다.
func _win() -> void:
	Y0 = int(ceil(g.PANEL.y + g.HUD_UP + g.PANEL.h)) + 2
	H = Y1 - Y0


func _measure() -> void:
	_win()
	var w: Color = g.C_WOOD
	bg_cols = [w.darkened(0.30), w, w.lightened(0.18), w.lightened(0.24),
			w.darkened(0.35)]
	var img := root.get_texture().get_image()

	# 두 가면을 뜬다 — 딜러인가(실루엣), 그리고 밝은가(L* 45 이상).
	var fg := PackedByteArray()
	var lit := PackedByteArray()
	fg.resize(W * H)
	lit.resize(W * H)
	for y in H:
		for x in W:
			var c := img.get_pixel(X0 + x, Y0 + y)
			fg[y * W + x] = 0 if _is_bg(c) else 1
			lit[y * W + x] = 1 if _lstar(c) >= 45.0 else 0

	var blobs := _label(fg)
	var big := _over(blobs, 30)
	var bright := _over(_label(lit), 30)

	# ── T1 실루엣이 몇 덩어리인가 ─────────────────────────
	# 몸통 + 팔 둘 = 셋. 하나로 뭉치면 그것이 옛 옷걸이다.
	_ok("실루엣 덩어리", big.size() >= 3, "%d개 (기준 3 이상)" % big.size())

	# ── T2 팔이 몸통에서 갈라지는가 ───────────────────────
	# 설계할 때는 "닫힌 구멍" 을 노렸는데 위는 랙, 아래는 카운터에 열려
	# 있어 구멍이 안 닫힌다. 대신 더 센 것을 잰다 — 행별 최소 배경 폭.
	var gap := 9999
	var gap_y := -1
	if big.size() >= 2:
		var body: int = big[0].id
		for y in H:
			var bx := PackedInt32Array()
			var ax := PackedInt32Array()
			for x in W:
				var id: int = blobs.lab[y * W + x]
				if id < 0:
					continue
				if id == body:
					bx.append(x)
				else:
					ax.append(x)
			if bx.is_empty() or ax.is_empty():
				continue
			for u in ax:
				for v in bx:
					var d: int = absi(v - u)
					if d < gap:
						gap = d
						gap_y = y + Y0
	_ok("팔–몸통 골", gap_y >= 0 and gap >= 8,
			"없음" if gap_y < 0 else "%dpx @ y%d (기준 8 이상)" % [gap, gap_y])

	# ── T4 좌우가 거울인가 ────────────────────────────────
	# 애니메이션에서 twinning 이라 부르는 것이다. 완전 미러면 0 이고,
	# 옛 팔이 0.006 이었다 — 사실상 거울. 사람은 절대 그 자세를 안 한다.
	var on := 0
	var diff := 0
	for y in H:
		for x in W:
			# X0 + X1 = 640 = 2 * cx 라 좌우 반전이 그대로 대칭축이 된다
			on += fg[y * W + x]
			if fg[y * W + x] != fg[y * W + (W - 1 - x)]:
				diff += 1
	var twin: float = 0.0 if on == 0 else float(diff) / float(on)
	_ok("좌우 비대칭", twin >= 0.25, "%.3f (기준 0.25 이상 · 완전대칭 0)" % twin)

	# ── T5 화면에서 밝은 것이 손 둘뿐인가 ─────────────────
	# 눈은 가장 밝은 데로 먼저 간다. 그게 옆구리 획이면 딜러가 안 읽힌다.
	_ok("밝은 덩어리", bright.size() == 2,
			"%d개 (기준 정확히 2 — 손 둘)" % bright.size())
	for b in bright:
		print("        L*45+ 면적 %4d  x[%d,%d] y[%d,%d]"
				% [b.area, b.x0, b.x1, b.y0, b.y1])

	print("딜러 칸 x[%d,%d] y[%d,%d] · 화소 %d — %s"
			% [X0, X1, Y0, Y1, on,
			"네 검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	if out_png != "":
		_save_sil(fg, lit, out_png)


# 배경인가. 초록이 우세하면 펠트·레일이고, 아니면 나무 색 목록과 맞춰 본다.
func _is_bg(c: Color) -> bool:
	if c.g > c.r + 0.02 and c.g > c.b + 0.015:
		return true
	for k in bg_cols:
		if absf(c.r - k.r) <= 0.02 and absf(c.g - k.g) <= 0.02 \
				and absf(c.b - k.b) <= 0.02:
			return true
	return false


# CIE L*. RGB 차이는 이 어두운 구간에서 거짓말을 한다 — 조끼(9)와 소매(24)
# 는 RGB 로 15 나 갈리는 것 같지만 L* 로는 4.0 이라 눈에 안 보인다.
func _lstar(c: Color) -> float:
	var y := 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


# 4-연결 라벨링. 대각선을 안 세는 것이 중요하다 — 이 해상도에서 모서리로만
# 닿은 두 덩어리는 눈에도 안 붙어 보인다.
func _label(mask: PackedByteArray) -> Dictionary:
	var lab := PackedInt32Array()
	lab.resize(W * H)
	lab.fill(-1)
	var blobs: Array[Dictionary] = []
	for k in W * H:
		if mask[k] == 0 or lab[k] >= 0:
			continue
		var id := blobs.size()
		var st := PackedInt32Array([k])
		lab[k] = id
		var b := {"id": id, "area": 0, "x0": W, "x1": 0, "y0": H, "y1": 0}
		while not st.is_empty():
			var q: int = st[st.size() - 1]
			st.remove_at(st.size() - 1)
			var qx: int = q % W
			var qy: int = q / W
			b.area += 1
			b.x0 = mini(b.x0, qx)
			b.x1 = maxi(b.x1, qx)
			b.y0 = mini(b.y0, qy)
			b.y1 = maxi(b.y1, qy)
			var nb := PackedInt32Array()
			if qx > 0:
				nb.append(q - 1)
			if qx < W - 1:
				nb.append(q + 1)
			if qy > 0:
				nb.append(q - W)
			if qy < H - 1:
				nb.append(q + W)
			for r in nb:
				if mask[r] != 0 and lab[r] < 0:
					lab[r] = id
					st.append(r)
		b.x0 += X0
		b.x1 += X0
		b.y0 += Y0
		b.y1 += Y0
		blobs.append(b)
	return {"lab": lab, "blobs": blobs}


func _over(r: Dictionary, min_area: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in r.blobs:
		if b.area >= min_area:
			out.append(b)
	out.sort_custom(func(a, c): return a.area > c.area)
	return out


# 실루엣을 눈으로도 보게 떨군다. 숫자가 다 통과해도 사람으로 안 읽힐 수
# 있고, 그때 볼 것은 컬러 그림이 아니라 이 흑백이다.
func _save_sil(fg: PackedByteArray, lit: PackedByteArray, path: String) -> void:
	var im := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	for y in H:
		for x in W:
			var k := y * W + x
			var c := Color(0.92, 0.92, 0.92)
			if fg[k] != 0:
				c = Color(0.98, 0.80, 0.24) if lit[k] != 0 else Color(0.08, 0.08, 0.08)
			im.set_pixel(x, y, c)
	im.save_png(path if path.begins_with("res://") else "res://" + path)
	print("실루엣: ", path, "  (검정 딜러 · 노랑 밝은 덩어리)")
