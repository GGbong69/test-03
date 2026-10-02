extends SceneTree

#  상인 프로브
#
#  상인의 팔은 여섯 번 다시 그렸다. 선 · V자 · 커프 · 타원 · 상자를 차례로
#  시도해 전부 졌는데, 지는 이유를 매번 "느낌" 으로만 말해서 다음 시도가
#  같은 함정에 다시 빠졌다. 그래서 **실루엣 조건 넷을 숫자로 못 박는다.**
#  여기 넷이 다 통과하는데도 안 좋아 보이면 그건 형태가 아니라 색 문제고,
#  하나라도 떨어지면 색을 아무리 만져도 안 산다. 순서가 그렇다.
#
#  2026-10-02 — 「몸에 비해 팔이 너무 얇지 않아?」 · 「팔만 두꺼워 지는게 아니라
#  손도 같이 커져야 하지 않을까?」. 옛 팔(동전 슬롯 밑에서 떨어지는 폭 30 막대)을
#  어깨에서 나온 팔로 바꾸며 조건을 새 설계로 다시 적었다 — 팔–몸통 골은 손 ·
#  팔뚝 띠(y 100~)에서만, 그리고 위팔이 옆구리를 따라 나오는가 · 몸통 : 팔 굵기 ·
#  팔꿈치 꺾임 · 손이 동전보다 작지 않은가를 더 잰다. 옛 팔은 굵기 4.06 · 꺾임 0.2px ·
#  손 356(동전 1203)으로 셋에서 진다(같은 배경 판정으로 main 을 잰 값).
#
#  검사 칸의 위는 **동전 슬롯 밑변**이고 아래는 정착 물건이 칠하는
#  최상단(131.8, 2000롤 실측) — 상인이 그릴 수 있는 전부다. 윗변을 손으로
#  적었더니 동전 슬롯을 키운 날 그 띠가 칸에 들어와 몸통과 두 팔을 한 덩어리로
#  이었다(동전 슬롯은 배경색이 아니라 전경으로 세어진다). 그래서 동전 슬롯에서 뽑는다.
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

# 배경으로 칠 색들. 상인 전용 색을 나열하는 대신 배경을 나열한다 —
# 상인 색은 자꾸 바뀌지만 벽·레일·펠트는 이 그림의 뼈대라 안 바뀐다.
var bg_cols: Array[Color] = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_png = a[0]
	g = load("res://scenes/main.tscn").instantiate()
	#  실루엣은 벽 **단색**을 배경으로 잰다 — 3D 방(2026-10-01) 위에서는 못 잰다.
	g.room3d_on = false
	root.add_child(g)
	g.set_process(false)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-26s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	# 창을 논리 해상도에 맞춘다. 늘리기 방식이 canvas_items 라 화면은 창
	# 해상도로 그려지는데, 이 검사의 좌표(동전 슬롯 밑변·정착 최상단)는 전부
	# 640x360 자다 — 창이 크면 왼쪽 위 사분면만 재게 되고 실제로 그랬다
	# (밝은 덩어리가 둘에서 다섯이 됐다). 배율을 곱해 보정하는 대신 창을
	# 맞춘다 — 배율이 끼면 실측 임계값도 같이 흔들려서, 이 프로브가 재는
	# 것이 형태가 아니라 배율이 된다.
	#
	# 여기서 하는 이유: _process 안에서 await 를 쓰면 이 함수가 코루틴이
	# 되어 SceneTree 규약이 깨지고 검사가 한 줄도 안 돈다(한 번 당했다).
	if frames == 0 and g != null:
		DisplayServer.window_set_size(Vector2i(int(g.VIEW.x), int(g.VIEW.y)))
	# 게임 시계를 우리가 돈다. 엔진에 맡기면 툴팁이 프레임마다 되살아나
	# 상인을 가린다 — shot.gd 가 같은 이유로 같은 짓을 한다.
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
		# 화소를 읽는 검사다. 헤드리스에는 텍스처가 없어 널을 집는다 —
		# 「실패」가 아니라 「못 쟀다」라고 말해야 일괄에서 안 헷갈린다.
		if DisplayServer.get_name() == "headless":
			print("  건너뜀 — 실루엣 검사는 화면이 있어야 돈다 (--headless 를 빼고 돌려라)")
			quit(0)
			return false
		_measure()
		quit(1 if fails > 0 else 0)
	return false


# 동전 슬롯 밑변 아래 2px 부터 본다. 상점에서 동전 슬롯은 HUD_UP 만큼 올라가 있다.
func _win() -> void:
	Y0 = int(ceil(g.PANEL.y + g.HUD_UP + g.PANEL.h)) + 2
	H = Y1 - Y0


func _measure() -> void:
	_win()
	var w: Color = g.C_WOOD
	bg_cols = [w.darkened(0.30), w, w.lightened(0.18), w.lightened(0.24),
			w.darkened(0.35)]
	var img := root.get_texture().get_image()
	if img.get_width() != int(g.VIEW.x):
		print("  창이 %dx%d 다 — 이 검사는 논리 해상도(%dx%d)에서만 돈다"
				% [img.get_width(), img.get_height(), g.VIEW.x, g.VIEW.y])
		fails += 1
		return

	# 두 가면을 뜬다 — 상인인가(실루엣), 그리고 밝은 **살**인가(L* 45 이상 · 살빛 채도).
	#  2026-10-02 시안 B 에서 「밝은 것」 을 살빛으로 좁혔다. 이 검사의 뜻은 눈이 손부터
	#  가는가인데, L* 하나로만 세면 걷은 크림 소매가 손 다음 밝기라 소매 조각이 「손 말고
	#  밝은 것」 으로 잡혔다 — 그래서 소매를 0.9 배로 눌러 맞췄더니 크림이 낙타색 · 황토로
	#  읽혀 시안 B 의 정체가 무너졌다(검토 B: 「프로브가 그림을 틀린 쪽으로 몰았다」).
	#  천을 다시 어둡게 하지 않고 검사를 고친다 — 밝고(L* 45) **살빛 채도**(a* 12 · b* 18
	#  이상)인 화소만 센다. 손이 먼저 읽히는 것은 채도와 램프 웅덩이가 맡는다. 무채색에
	#  가까운 크림 천(a* ≤ 8 · b* ≤ 14)은 밝아도 손과 다투지 않는다.
	var fg := PackedByteArray()
	var lit := PackedByteArray()
	fg.resize(W * H)
	lit.resize(W * H)
	for y in H:
		for x in W:
			var c := img.get_pixel(X0 + x, Y0 + y)
			fg[y * W + x] = 0 if _is_bg(c, Y0 + y) else 1
			var lab := _lab(c)
			lit[y * W + x] = 1 if lab.x >= 45.0 and lab.y >= 12.0 and lab.z >= 18.0 else 0

	var blobs := _label(fg)
	var big := _over(blobs, 30)
	var bright := _over(_label(lit), 30)

	# ── T1 실루엣이 몇 덩어리인가 ─────────────────────────
	# 몸통 + 팔 둘 = 셋. 하나로 뭉치면 그것이 옛 옷걸이다.
	_ok("실루엣 덩어리", big.size() >= 3, "%d개 (기준 3 이상)" % big.size())

	# ── 팔 둘을 고른다 ────────────────────────────────────
	# 몸통이 가장 큰 덩어리고, 팔은 그다음 큰 둘이다(왼쪽 · 오른쪽).
	# 셔츠 V 는 밝아서 배경으로 세어지고, 그 안의 단추가 혼자 떨어진 작은
	# 덩어리가 된다 — 「몸통 아닌 것」을 다 팔로 세면 단추와 V 테두리의 3px 가
	# 팔–몸통 골로 잡힌다(2026-10-02 이전 판이 그래서 늘 3px 로 떨어졌다).
	# 그래서 팔은 **면적 300 이상** 덩어리 중 몸통 바깥에 선 둘로 고른다.
	var body: int = big[0].id if big.size() > 0 else -1
	var arms: Array[Dictionary] = []
	for b in big:
		if b.id != body and b.area >= 300:
			arms.append(b)
	arms.sort_custom(func(a, c): return a.x0 < c.x0)
	_ok("팔 둘", arms.size() >= 2, "%d개 (면적 300 이상 · 몸통 밖)" % arms.size())

	# ── T2 손 · 팔뚝이 몸통에서 떨어져 있는가 ─────────────
	# 2026-09-15 제보: "오른쪽 손이 너무 몸이랑 붙어 있는거 아니야?"
	# **카운터 선 언저리(y 100~)에서만 잰다.** 2026-10-02 부터 위팔은 일부러
	# 몸에 붙는다(「몸에 비해 팔이 너무 얇지 않아?」 — 어깨에서 나온 팔). 손과
	# 팔뚝이 서는 띠에서 행별 최소 배경 폭이 8 이상이어야 한다.
	var gap := 9999
	var gap_y := -1
	if body >= 0 and arms.size() >= 2:
		for y in range(maxi(100 - Y0, 0), H):
			var bx := _run(blobs.lab, y, body)
			if bx.x < 0:
				continue
			for a in arms.slice(0, 2):
				var ax := _run(blobs.lab, y, a.id)
				if ax.x < 0:
					continue
				var d: int = (bx.x - ax.y) if ax.x < bx.x else (ax.x - bx.y)
				if d < gap:
					gap = d
					gap_y = y + Y0
	_ok("손·팔뚝–몸통 골", gap_y >= 0 and gap >= 8,
			"없음" if gap_y < 0 else "%dpx @ y%d (기준 8 이상)" % [gap, gap_y])

	# ── T6 위팔이 어깨에서 나오는가 ───────────────────────
	# 2026-10-02 「몸에 비해 팔이 너무 얇지 않아?」 — 옛 팔은 동전 슬롯 밑변에서
	# 곧장 떨어지는 막대였다(어깨도 위팔도 팔꿈치 꺾임도 없이). 이제 위팔이
	# 슬롯 밑으로 나와 옆구리를 따라 내려온다: 검사 칸 첫 줄에서 팔이 서고, 그
	# 안쪽 모서리가 몸통 모서리에서 18px 안이다.
	var top_gap := 9999
	if body >= 0 and arms.size() >= 2:
		var bx0 := _run(blobs.lab, 0, body)
		top_gap = -1
		for a in arms.slice(0, 2):
			var ax0 := _run(blobs.lab, 0, a.id)
			if bx0.x < 0 or ax0.x < 0:
				top_gap = 9999
				break
			var d0: int = (bx0.x - ax0.y) if ax0.x < bx0.x else (ax0.x - bx0.y)
			top_gap = maxi(top_gap, d0)
	_ok("위팔이 옆구리를 따라 나온다", top_gap <= 18,
			"첫 줄 y%d 골 %s (기준 18 이하)" % [Y0, "없음" if top_gap >= 9999 else "%dpx" % top_gap])

	# ── T7 팔 굵기 : 몸통 폭 ─────────────────────────────
	# 같은 제보다. 옛 막대는 몸통 145 : 팔 30 = 4.8 이었다. 사람 가슴 : 위팔이
	# 3.2 : 1.1 = 2.9 다(HAND3 머리말). 위팔이 서는 줄(첫 줄 + 10)에서 3.6 아래.
	var thick := 0.0
	if body >= 0 and arms.size() >= 2:
		var bxt := _run(blobs.lab, 10, body)
		for a in arms.slice(0, 2):
			var axt := _run(blobs.lab, 10, a.id)
			if bxt.x < 0 or axt.x < 0:
				thick = 99.0
				break
			thick = maxf(thick, float(bxt.y - bxt.x + 1) / float(axt.y - axt.x + 1))
	_ok("몸통 : 팔 굵기", thick > 0.0 and thick <= 3.6,
			"%.2f (기준 3.6 이하 · 옛 막대 4.8)" % thick)

	# ── T8 팔꿈치가 꺾이는가 ─────────────────────────────
	# 막대는 위에서 아래로 곧다. 팔은 어깨 → 팔꿈치(바깥) → 손목(안쪽)으로
	# 꺾인다 — 팔 가운데선이 위 · 아래 두 끝을 이은 줄보다 바깥으로 4px 이상
	# 나간 줄이 있어야 한다.
	var bend := 99.0
	if arms.size() >= 2:
		for a in arms.slice(0, 2):
			#  위끝은 검사 칸 첫 줄, 아래끝은 손목 바로 위(y 92) — 손은 넓어서
			#  가운데선을 끌어당기므로 넣지 않는다.
			var yb: int = 92 - Y0
			var c0 := _run(blobs.lab, 0, a.id)
			var c1 := _run(blobs.lab, yb, a.id)
			var out := 0.0
			var sgn: float = -1.0 if a.x0 < X0 + W / 2 else 1.0
			for y in range(1, yb):
				var cy := _run(blobs.lab, y, a.id)
				if c0.x < 0 or c1.x < 0 or cy.x < 0:
					continue
				var t: float = float(y) / float(yb)
				var mid: float = lerpf(float(c0.x + c0.y), float(c1.x + c1.y), t) * 0.5
				out = maxf(out, sgn * (float(cy.x + cy.y) * 0.5 - mid))
			bend = minf(bend, out)
			var cl := PackedStringArray()
			for y in range(0, yb + 1, 6):
				var cy2 := _run(blobs.lab, y, a.id)
				cl.append("%d:%.0f" % [y + Y0, float(cy2.x + cy2.y) * 0.5 + X0])
			print("        팔 가운데선 ", " ".join(cl), "  꺾임 %.1f" % out)
	_ok("팔꿈치 꺾임", bend >= 4.0 and bend < 99.0, "%.1fpx (기준 4 이상)" % bend)

	# ── T4 좌우가 거울인가 ────────────────────────────────
	# 애니메이션에서 twinning 이라 부르는 것이다. 완전 미러면 0 이고,
	# 옛 팔이 0.006 이었다 — 사실상 거울. 사람은 절대 그 자세를 안 한다.
	#
	# 2026-10-02 에 **팔만** 재도록 바꿨다. 옛 기준(실루엣 전체 0.25)은 가는 막대
	# 팔 시절 값인데, 그 뒤 3D 몸통이 서면서 main 도 0.15 로 못 넘고 있었다(배경
	# 판정을 고친 이 판으로 재 보면). 「몸에 비해 팔이 너무 얇지 않아?」 로 팔이
	# 세 배 굵어지자 같은 어긋남(팔꿈치 6 · 손목 8 · 손각 20°)이 차지하는 몫이 더
	# 줄었다 — 분모의 대부분이 좌우가 원래 같은 조끼라서다. 그래서 몸통을 빼고
	# 팔 화소 가운데 거울 자리가 팔이 아닌 몫을 잰다. 기준 0.12 는 쌍둥이(0.006)의
	# 스무 배 — 「거울이 아니다」 를 재는 값이지 「많이 어긋나라」 가 아니다.
	var on := 0
	var diff := 0
	for y in H:
		for x in W:
			# X0 + X1 = 640 = 2 * cx 라 좌우 반전이 그대로 대칭축이 된다
			on += fg[y * W + x]
			if fg[y * W + x] != fg[y * W + (W - 1 - x)]:
				diff += 1
	var twin: float = 0.0 if on == 0 else float(diff) / float(on)
	#  팔만 따로 — 몸통(조끼)은 옷이라 원래 좌우가 같고, 그 화소가 분모에 들면
	#  팔이 얼마나 어긋나든 값이 묽어진다. 팔 화소 가운데 거울 자리가 팔이 아닌 몫.
	var arm_on := 0
	var arm_diff := 0
	if arms.size() >= 2:
		var ids := [arms[0].id, arms[1].id]
		for y in H:
			for x in W:
				if not ids.has(blobs.lab[y * W + x]):
					continue
				arm_on += 1
				if not ids.has(blobs.lab[y * W + (W - 1 - x)]):
					arm_diff += 1
	var atwin: float = 0.0 if arm_on == 0 else float(arm_diff) / float(arm_on)
	_ok("좌우 비대칭 (팔)", atwin >= 0.12,
			"%.3f (기준 0.12 이상 · 완전대칭 0) · 실루엣 전체 %.3f" % [atwin, twin])

	# ── T5 화면에서 밝은 것이 손 둘뿐인가 ─────────────────
	# 눈은 가장 밝은 데로 먼저 간다. 그게 옆구리 획이면 상인이 안 읽힌다.
	_ok("밝은 덩어리", bright.size() == 2,
			"%d개 (기준 정확히 2 — 손 둘 · L* 45+ 살빛)" % bright.size())
	for b in bright:
		print("        L*45+ 살빛 면적 %4d  x[%d,%d] y[%d,%d]"
				% [b.area, b.x0, b.x1, b.y0, b.y1])

	# ── T9 손이 동전보다 작지 않은가 ──────────────────────
	# 2026-10-02 「팔만 두꺼워 지는게 아니라 손도 같이 커져야 하지 않을까?」 —
	# 옛 손(밝은 덩어리 356 · 481)은 판 위 동전(윗면 π·22·17.3 ≈ 1200)의 3분의 1 이었다.
	# 검사 칸이 카운터 선 밑(132)에서 끊기므로 손의 윗부분만 잡히는데도
	# 동전 윗면의 0.8 배는 넘어야 한다.
	var coin: float = PI * float(g.TBL.chip_r) * float(g.TBL.chip_r) * float(g.TBL.flat)
	var small := 99999
	for b in bright:
		small = mini(small, int(b.area))
	_ok("손 ≥ 동전", bright.size() >= 2 and float(small) >= coin * 0.8,
			"작은 손 %d · 동전 윗면 %.0f (기준 0.8 배)" % [small if small < 99999 else 0, coin])

	print("상인 칸 x[%d,%d] y[%d,%d] · 화소 %d — %s"
			% [X0, X1, Y0, Y1, on,
			"검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	if out_png != "":
		_save_sil(fg, lit, out_png)


# 한 줄(y)에서 덩어리 id 가 차지한 x 범위 (첫 칸, 끝 칸). 없으면 (−1, −1).
func _run(lab: PackedInt32Array, y: int, id: int) -> Vector2i:
	if y < 0 or y >= H:
		return Vector2i(-1, -1)
	var lo := -1
	var hi := -1
	for x in W:
		if lab[y * W + x] == id:
			if lo < 0:
				lo = x
			hi = x
	return Vector2i(lo, hi)


# 배경인가. 초록이 우세하면 펠트·레일이고, 아니면 나무 색 목록과 맞춰 본다.
# **레일 색은 레일 줄에서만** 배경이다(sy 는 화면 y). 벽 앞에서 배경은 벽 하나뿐이다 —
# 위팔이 서면서(2026-10-02) 굴린 소매의 밝은 면이 마침 C_WOOD 와 0.02 안으로
# 맞아 떨어져 위팔 한 짝이 통째로 「배경」이 됐다(팔이 팔꿈치에서 끊긴 것으로 잡혔다).
func _is_bg(c: Color, sy: int) -> bool:
	if c.g > c.r + 0.02 and c.g > c.b + 0.015:
		return true
	var rail: bool = sy >= int(g.TBL.fy) - 4
	for k in (bg_cols if rail else bg_cols.slice(0, 1)):
		if absf(c.r - k.r) <= 0.02 and absf(c.g - k.g) <= 0.02 \
				and absf(c.b - k.b) <= 0.02:
			return true
	return false


# CIE L*a*b* (D65). RGB 차이는 이 어두운 구간에서 거짓말을 한다 — 조끼(9)와 소매(24)
# 는 RGB 로 15 나 갈리는 것 같지만 L* 로는 4.0 이라 눈에 안 보인다. 살빛인가는
# a*(붉은 쪽) · b*(노란 쪽)로 가른다(T5 머리말).
func _lab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var gg := _lin(c.g)
	var b := _lin(c.b)
	var xx := (0.4124 * r + 0.3576 * gg + 0.1805 * b) / 0.95047
	var yy := 0.2126 * r + 0.7152 * gg + 0.0722 * b
	var zz := (0.0193 * r + 0.1192 * gg + 0.9505 * b) / 1.08883
	var fx := _labf(xx)
	var fy := _labf(yy)
	var fz := _labf(zz)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _labf(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0




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
	print("실루엣: ", path, "  (검정 상인 · 노랑 밝은 덩어리)")
