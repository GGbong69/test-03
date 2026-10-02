extends SceneTree

# 3D 손. 2026-09-15 — "3D 모델같이 하고 싶은건데".
#
# 재는 것은 **자리가 맞물리는가**다. 3D 손은 2D 가 셈한 손목·각·배율을
# 받아 쓰는데, 그 셈을 두 곳에서 따로 하면 쓸기 도중에 팔과 손이 갈라진다.
# 그리고 화면(화면은 2D)과 물건(3D)이 같은 투영을 봐야 손이 면에 앉는다.
#
#   godot --path . --quit-after 1500 --script scripts/tools/qa_hand3.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_h3_g.cfg"
	Save.path = "user://_qa_h3.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


#  위팔 축과 팔뚝 축이 한 점(팔꿈치)에서 만나는가 — 두 축 선분 사이 가장 가까운 거리.
#  자세 사전(hand3_pose)과 비교하지 않는다: 3D 는 지난 틀의 자세로 서므로 쓸기처럼
#  빠른 동작에서는 한 틀 차이만큼(20) 어긋나 보인다. 두 상자가 **서로** 만나는가를 잰다.
func _elbow_gap(i: int) -> float:
	if i >= g.hand3_rig.size():
		return 99.0
	var rg: Dictionary = g.hand3_rig[i]
	var ut: Transform3D = (rg.up as Node3D).transform
	var at: Transform3D = (rg.arm as Node3D).transform
	var d := 99.0
	for k in 161:
		var p: Vector3 = ut.origin + ut.basis.x * (float(k) / 160.0)
		d = minf(d, _seg_d(p, at.origin, at.origin + at.basis.x))
	return d


func _seg_d(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


#  월드 → 화면. 상인 무대의 직교 −52° 카메라와 같은 식(_p2s)이다.
func _scr(p: Vector3) -> Vector2:
	return Vector2(p.x, float(g.TBL.fy) + p.z * float(g.TBL.flat) - p.y * float(g.TBL.tall))


#  든 물건의 그려진 윤곽(윗면 타원 + 그 밑 옆면 띠) 안에서 점이 얼마나 바깥인가.
#  1 이하면 물건이 덮는다. 옆면 띠는 윗면을 sd 만큼 끌어내린 것이라 중심보다
#  아래 점은 sd 만큼 당겨 잰다.
func _cover_r(p: Vector2, c: Vector2, it: Dictionary) -> float:
	var wob: float = float(it.get("wob", 0.0))
	var rx: float = float(g.TBL.chip_r) * (1.0 + wob * 0.05)
	var ry: float = float(g.TBL.chip_r) * float(g.TBL.flat) * (1.0 - wob * 0.12)
	var sd: float = float(g.TBL.chip_t) * float(g.TBL.tall)
	var dy: float = p.y - c.y
	if dy > 0.0:
		dy = maxf(dy - sd, 0.0)
	return sqrt(pow((p.x - c.x) / rx, 2.0) + pow(dy / ry, 2.0))


#  점이 윤곽 밖으로 나간 화면 px(안이면 음수). 타원은 한가운데에서 그 점까지의 거리를
#  _cover_r 로 나누면 그 방향의 반지름이라, 그 차가 곧 테에서의 거리다(윗쪽 반에서 정확).
func _rim_px(p: Vector2, c: Vector2, it: Dictionary) -> float:
	var cr: float = maxf(_cover_r(p, c, it), 0.001)
	return p.distance_to(c) * (1.0 - 1.0 / cr)


#  판 위 매물 하나를 kind 로 갈아 끼운다(shot_npc3 과 같은 길) — 그리는 것만 바뀐다.
func _stock_as(kind: String) -> int:
	var gi := -1
	for i in g.drop.size():
		if not bool(g.drop[i].get("gone", false)) and float(g.drop[i].get("sold", 0.0)) <= 0.0:
			gi = i
			break
	if gi < 0:
		return -1
	match kind:
		"rare":
			for r in GameData.items():
				if String(r.get("rarity", "")) == "rare":
					g.stock[gi] = {"type": "item", "cost": 9, "sold": false, "d": r}
					break
		"dart":
			var ds: Array = GameData.darts()
			g.stock[gi] = {"type": "dart", "cost": 6, "sold": false, "d": ds[mini(1, ds.size() - 1)]}
		"pack":
			g.stock[gi] = {"type": "boost", "cost": 6, "sold": false, "d": GameData.boosters()[0]}
	return gi


func _front(n: Node) -> bool:
	return n is VisualInstance3D and ((n as VisualInstance3D).layers & g.HAND3_FRONT) != 0


#  손등 윗면(손바닥 덩어리 윗면 네 모서리)의 화면 윗선 — 화면 x 에서 그 면이 가장 위로
#  올라간 y. x 가 면 밖이면 면 전체의 가장 위.
func _back_top(hd: Node3D, x: float) -> float:
	var pt: float = float(g.HAND3.palm_t) * 0.5
	var pw: float = float(g.HAND3.palm_w) * 0.5
	var q := [_scr(hd.global_transform * Vector3(0.0, pt, -pw + 2.0)),
			_scr(hd.global_transform * Vector3(float(g.FING3.palm), pt - 1.0, -pw)),
			_scr(hd.global_transform * Vector3(float(g.FING3.palm), pt - 1.0, pw)),
			_scr(hd.global_transform * Vector3(0.0, pt, pw - 2.0))]
	var top := 1e9
	var lo := 1e9
	for k in 4:
		var a: Vector2 = q[k]
		var b: Vector2 = q[(k + 1) % 4]
		lo = minf(lo, a.y)
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 0.001:
			top = minf(top, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return top if top < 1e8 else lo


#  ── 엄지의 살 (2026-10-02) ─────────────────────────────────
#  「나이 엄지에 무지내전근이랑 무지대립근이 없잖아」 — 엄지가 상자 손바닥 모서리에 꽂힌 가는
#  토막 둘이라 손의 일부가 아니라 막대로 읽혔다. 사람 엄지는 손목 노뼈 쪽 CMC 에서 나온
#  손허리뼈가 엄지 두덩(무지대립근 · 짧은 벌림근 · 짧은 굽힘근) 속에 묻혀 있고, 첫 물갈퀴
#  (무지내전근 · 첫째 등쪽 뼈사이근)가 엄지 첫마디 한가운데쯤까지 검지 손허리뼈 머리와 잇는다
#  (game.gd THUMB3 머리말). 그래서 손등에서 본 엄지 쪽 윤곽은 손목에서 엄지 끝까지 볼록한
#  곡선 하나다 — 손목 쪽으로 파인 V 도, 손바닥 모서리에서 꺾여 나간 막대도 없다. 그것을
#  쉼 · 집기 · 쓸기에서 잰다:
#    · 엄지 쪽 윤곽(손 화판의 알파)이 손목 옆구리 → 엄지 MCP 사이에서 그 두 점을 잇는 줄보다
#      2px 넘게 안으로 파이지 않는다 — 막대가 모서리에 꽂히면 그 사이가 V 로 파인다
#    · 엄지 첫마디 한가운데 자리와 검지 손허리뼈 머리를 잇는 줄이 통째로 손 안이다 — 손목
#      쪽으로 깊은 틈이 없다(물갈퀴가 메운다)
#    · 물갈퀴 살이 엄지 첫마디에 닿는 가장 먼 자리가 첫마디의 한가운데(0.5) 이상
#    · 엄지 두덩(손허리뼈 + 둔덕) 폭이 뿌리 쪽 4 분의 1 자리에서 손바닥 폭의 0.28 이상
func _mask(im: Image, p: Vector2) -> bool:
	var r3: Rect2 = g.HAND3.rect
	var x := int(floor(p.x - r3.position.x))
	var y := int(floor(p.y - r3.position.y))
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
		return false
	return im.get_pixel(x, y).a > 0.5


#  손 안의 점 p 에서 d 쪽으로 윤곽 끝까지 반 px 씩 간다.
func _edge(im: Image, p: Vector2, d: Vector2) -> Vector2:
	var q := p
	for _k in 80:
		var nq := q + d * 0.5
		if not _mask(im, nq):
			return q
		q = nq
	return q


#  손목 옆구리 → 엄지 MCP 의 윤곽 파임(px). 두 점을 엄지 쪽(손 −z·sg 의 화면 방향)으로
#  윤곽 끝까지 밀고, 그 두 끝을 잇는 줄 위의 점마다 손 밖이면 안으로 얼마나 들어가야 손에
#  닿는지 잰다. 손목 점은 손목 관절 바로 앞(x 2.5 — 손바닥 뿌리 깎은 모서리 3.4 안)이다:
#  x 0~1 은 팔뚝과 손이 만나는 모서리라 손목을 꺾은 만큼 오목해지고, 그것은 엄지가 아니다
#  (쉬는 오른손은 x 1 에서 재면 2.0px · 2.5 에서 1.5px). 대각선 윤곽의 화소 계단만으로
#  0.5~1px 이 나온다.
func _notch(im: Image, hj: Dictionary) -> float:
	var hd: Node3D = hj.root
	var sg: float = hj.sg
	var o := _scr(hd.global_transform.origin)
	var out := (_scr(hd.global_transform * Vector3(0.0, 0.0, -10.0 * sg)) - o).normalized()
	var wb := _edge(im, _scr(hd.global_transform * Vector3(2.5, 0.0, -11.0 * sg)), out)
	var mb := _edge(im, _scr((hj.t1 as Node3D).global_transform.origin), out)
	var deep := 0.0
	for k in range(1, 40):
		var q: Vector2 = wb.lerp(mb, float(k) / 40.0)
		var dd := 0.0
		while dd < 20.0 and not _mask(im, q):
			q -= out * 0.5
			dd += 0.5
		deep = maxf(deep, dd)
	return deep


#  물갈퀴 자리에 틈이 없는가 — 엄지 첫마디 한가운데와 검지 손허리뼈 머리를 잇는 줄에서
#  손 밖인 표본의 수.
func _web_gap(im: Image, hj: Dictionary) -> int:
	var hd: Node3D = hj.root
	var sg: float = hj.sg
	var a := _scr((hj.t1 as Node3D).global_transform * Vector3(float(g.THUMB3.lp) * 0.5, 0.0, 0.0))
	var b := _scr(hd.global_transform * Vector3(27.0, 0.6, -12.8 * sg))
	var miss := 0
	for k in 21:
		if not _mask(im, a.lerp(b, float(k) / 20.0)):
			miss += 1
	return miss


#  물갈퀴 살이 엄지 첫마디에 닿는 가장 먼 자리(첫마디 길이의 비). 물갈퀴 타원체 겉면을
#  고루 찍어 첫마디 좌표로 옮기고, 첫마디 굵기 안(축에서 반폭 + 1)에 든 점의 x 가운데 가장 큰 것.
func _web_reach(hj: Dictionary) -> float:
	var inv: Transform3D = (hj.t1 as Node3D).global_transform.affine_inverse()
	var wt: Transform3D = (hj.web as Node3D).global_transform
	var r: float = float(g.THUMB3.pw0) * 0.5 + 1.0
	var best := -99.0
	for a in 24:
		for b in 13:
			var th: float = PI * float(b) / 12.0
			var ph: float = TAU * float(a) / 24.0
			var q := Vector3(cos(th), sin(th) * cos(ph), sin(th) * sin(ph))
			var lq: Vector3 = inv * (wt * q)
			if Vector2(lq.y, lq.z).length() <= r:
				best = maxf(best, lq.x)
	return best / float(g.THUMB3.lp)


#  엄지 두덩 폭 — 손허리뼈 뿌리 쪽 4 분의 1 자리에서 손허리뼈 단면과 둔덕 타원체 단면을
#  합친 폭(손허리뼈 좌표의 z). 둔덕은 손허리뼈의 자식이라 그 자리 · 배율을 그대로 읽는다.
func _thenar_w(hj: Dictionary) -> float:
	var T: Dictionary = g.THUMB3
	var tn: Node3D = hj.thenar
	var xb: float = float(T.lm) * 0.25
	var u: float = (xb - tn.position.x) / tn.scale.x
	var hw: float = tn.scale.z * sqrt(maxf(0.0, 1.0 - u * u))
	var mb: float = T.m_back
	var mw: float = lerpf(float(T.mw0), float(T.mw1), (xb + mb) / (float(T.lm) + mb)) * 0.5
	return maxf(tn.position.z + hw, mw) - minf(tn.position.z - hw, -mw)


func _thumb_anat(tag: String, i: int) -> void:
	var hj: Dictionary = (g.hand3_rig[i] as Dictionary).hj
	var nm: String = "%s · %s손" % [tag, "왼" if i == 0 else "오른"]
	var im: Image = (g.hand3_vp as SubViewport).get_texture().get_image()
	var nt := _notch(im, hj)
	_ok("엄지 쪽 윤곽이 손목 → MCP 에서 안 파인다 (%s)" % nm, nt <= 2.0,
			"가장 깊은 파임 %.1fpx (2 이하 — 막대가 꽂히면 V)" % nt)
	var gp := _web_gap(im, hj)
	_ok("물갈퀴 자리에 틈이 없다 (%s)" % nm, gp == 0,
			"엄지 첫마디 한가운데 → 검지 머리 21점 중 손 밖 %d" % gp)
	var wr := _web_reach(hj)
	_ok("물갈퀴가 엄지 첫마디 한가운데까지 (%s)" % nm, wr >= 0.5, "첫마디의 %.2f (0.5 이상)" % wr)
	var tw := _thenar_w(hj) / float(g.HAND3.palm_w)
	_ok("엄지 두덩이 굵다 (%s)" % nm, tw >= 0.28, "뿌리 쪽 폭 = 손바닥 폭의 %.2f (0.28 이상)" % tw)


#  2026-10-02 「지금 동전 짚는 손 모양 너무 이상한데 좀 레퍼런스 찾으면서 어떻게 해봐」 →
#  「뭔하려느지는 알겠는데 엄지가 너무 올라가지 않았어? 레퍼런스 찾아보고 좀 손모양 제대로
#  만들어봐」. 둘째 판은 엄지 끝 · 검지 끝으로 뒤 테 양 어깨를 집었는데, 엄지가 손목 위에서
#  나와 검지와 70° 벌어진 갈퀴였다. 사진(Unsplash 「테이블 위에 동전을 쌓는 사람」)과 동전
#  다루기 안내(테만 잡는다)대로 이제 **닫힌 집기**다 — 검지 끝은 동전 윗면 테 안, 엄지는 그
#  바로 밑에서 받친다(GIVE 「테를 집는다」). 그것을 두 손 다 잰다:
#    · 물건이 손 좌표에서 안 미끄러진다(흔들림 ≤ 1.5 — 그대로)
#    · 검지 끝(볼이 닿는 자리)이 동전 윗면 테 안 1.5~4.5px — 사진의 2~4px
#    · 엄지 끝이 검지 끝에서 화면 6.5px 안 — 닫힌 집기(두 손끝이 만난다)
#    · 엄지 벌림(손바닥 면에서 검지와 엄지 사이 각)이 30° 안 — 사진의 20~30°. 갈퀴는 70°
#    · 엄지 어느 마디(뿌리 · 마디 · 끝)도 화면에서 손등 윗선 위로 안 솟는다
#    · 손 나머지(너클 넷 · 말린 마디 · 손끝 셋 · 손바닥 모서리)는 물건 윤곽 밖 — 검지는 위로
#      아치, 엄지는 밑이라 뺀다
#    · 반지 낀 손(오른손)이 쥐어도 반지가 물건에 안 가린다
#    · 앞 층에는 물건 위로 아치를 그리는 검지(두 마디)만 선다 — 엄지 · 손바닥은 아니다.
#      다트는 손 밑을 지나므로 손 전부가 선다(give_all)
func _grip_case(kind: String, mx: float) -> void:
	var gi := _stock_as(kind)
	var nm: String = "%s · %s손" % [kind, "왼" if mx < 320.0 else "오른"]
	_ok("건넬 매물이 있다 (%s)" % nm, gi >= 0, "")
	if gi < 0:
		return
	g._give_begin(gi, Vector2(mx, 130.0))
	var side: int = g.give_side
	var t1: float = float(g.GIVE.take)
	var t2: float = t1 + float(g.GIVE.look)
	var guard := 0
	while g.give_t < t1 + 0.05 and guard < 400:
		guard += 1
		await _wait(1)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var tip_in := Vector2(99.0, -99.0)     # 검지 볼이 테 안으로 들어온 px (최소, 최대)
	var pinch := 0.0                       # 엄지 끝 ↔ 검지 끝 화면 거리 최대
	var abd := 0.0                         # 엄지 벌림 최대(도)
	var rise := -99.0                      # 엄지가 손등 윗선 위로 솟은 px 최대
	var tpad := Vector2(99.0, -99.0)       # 엄지 끝(축)이 테 밖으로 나간 px (최소, 최대)
	var rise_at := ""
	var hand_in := 99.0
	var hand_at := ""
	var ring_r := 99.0
	var front_ok := true
	var n := 0
	var rg: Dictionary = g.hand3_rig[side]
	var hj: Dictionary = rg.hj
	var oj: Dictionary = (g.hand3_rig[1 - side] as Dictionary).hj
	while g.give_t < t2 - 0.05 and guard < 800:
		guard += 1
		await _wait(1)
		if g.give_i != gi:
			break
		var hd: Node3D = rg.hand
		var it: Dictionary = g.drop[gi]
		var c3 := Vector3(float(it.u), float(it.h), float(it.w))
		var lc: Vector3 = hd.global_transform.affine_inverse() * c3
		lo = Vector2(minf(lo.x, lc.x), minf(lo.y, lc.z))
		hi = Vector2(maxf(hi.x, lc.x), maxf(hi.y, lc.z))
		if kind == "rare":
			var cs: Vector2 = g._p2s(float(it.u), float(it.w), float(it.h))
			var ti3: Vector3 = (rg.tips[0] as Node3D).global_transform.origin
			var tt3: Vector3 = (rg.ttip as Node3D).global_transform.origin
			#  검지 볼이 닿는 자리 = 손끝 축에서 볼 반 두께(give_pad) 아래.
			var pin := -_rim_px(_scr(ti3 - Vector3(0.0, float(g.give_pad), 0.0)), cs, it)
			tip_in = Vector2(minf(tip_in.x, pin), maxf(tip_in.y, pin))
			pinch = maxf(pinch, _scr(ti3).distance_to(_scr(tt3)))
			var tr := _rim_px(_scr(tt3), cs, it)
			tpad = Vector2(minf(tpad.x, tr), maxf(tpad.y, tr))
			#  벌림 — 손 좌표 xz 에서 너클 → 검지 끝, 엄지 뿌리 → 엄지 끝.
			var inv: Transform3D = hd.global_transform.affine_inverse()
			var kn: Vector3 = inv * (hj.j1[0] as Node3D).global_transform.origin
			var vi: Vector3 = inv * ti3 - kn
			var vt: Vector3 = inv * tt3 - inv * (hj.thumb as Node3D).global_transform.origin
			abd = maxf(abd, rad_to_deg(absf(Vector2(vi.x, vi.z).angle_to(Vector2(vt.x, vt.z)))))
			for pr in [["엄지 뿌리", (hj.thumb as Node3D).global_transform.origin],
					["엄지 MCP", (hj.t1 as Node3D).global_transform.origin],
					["엄지 마디", (hj.t2 as Node3D).global_transform.origin], ["엄지 끝", tt3]]:
				var sp := _scr(pr[1])
				var up: float = _back_top(hd, sp.x) - sp.y
				if up > rise:
					rise = up
					rise_at = String(pr[0])
			var pts := []
			for f in 4:
				pts.append(["너클%d" % f, (hj.j1[f] as Node3D).global_transform.origin])
			for f in range(1, 4):
				pts.append(["말린 손끝%d" % f, (rg.tips[f] as Node3D).global_transform.origin])
				pts.append(["말린 마디%d" % f, (hj.j2[f] as Node3D).global_transform.origin])
			for x in [0.0, 16.0, 30.0]:
				for z in [-15.0, 15.0]:
					for y in [-5.0, 5.0]:
						pts.append(["손바닥 %.0f" % x, hd.global_transform * Vector3(x, y, z)])
			for pr in pts:
				var cr := _cover_r(_scr(pr[1]), cs, it)
				if cr < hand_in:
					hand_in = cr
					hand_at = String(pr[0])
			if side == 1:
				var rn: Node3D = (hj.j1[2] as Node3D)
				ring_r = minf(ring_r, _cover_r(_scr(rn.global_transform * Vector3(6.0, 0.0, 0.0)), cs, it))
			if n == 20:
				_thumb_anat("집기", side)
		var all: bool = bool(g.give_all)
		var palm_on := _front((hj["in"] as Node3D).get_child(0))
		var idx_on := _front((hj.j1[0] as Node3D).get_child(0)) \
				and _front((hj.j2[0] as Node3D).get_child(0))
		var thumb_on := _front((hj.thumb as Node3D).get_child(0)) \
				or _front((hj.t2 as Node3D).get_child(0))
		var other_off := not _front((oj.j1[0] as Node3D).get_child(0)) \
				and not _front((oj.t2 as Node3D).get_child(0))
		front_ok = front_ok and g.hand3_front_on and idx_on and other_off \
				and palm_on == all and thumb_on == all \
				and g.hand3_fvp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		n += 1
	_ok("살핀 틀이 있다 (%s)" % nm, n > 10, "%d틀" % n)
	var drift: float = (hi - lo).length()
	_ok("물건이 쥔 자리에서 안 미끄러진다 (%s)" % nm, drift <= 1.5,
			"손 좌표 흔들림 %.2f (손각 · 숙임 · 들기를 다 탄다)" % drift)
	if kind == "rare":
		_ok("검지 끝이 동전 윗면 테 안 (%s)" % nm, tip_in.x >= 1.5 and tip_in.y <= 4.5,
				"테 안 %.1f ~ %.1fpx (1.5~4.5 — 사진의 2~4)" % [tip_in.x, tip_in.y])
		_ok("엄지 끝이 검지 끝과 만난다 (%s)" % nm, pinch <= 6.5,
				"화면 거리 최대 %.1fpx (6.5 이하)" % pinch)
		print("        엄지 끝 축이 테 밖으로 %.1f ~ %.1fpx" % [tpad.x, tpad.y])
		_ok("엄지 벌림이 30° 안 (%s)" % nm, abd <= 30.0,
				"%.0f° (사진 20~30° · 옛 갈퀴 70°)" % abd)
		_ok("엄지가 손등 위로 안 솟는다 (%s)" % nm, rise <= 0.0,
				"%s 가 손등 윗선보다 %.1fpx %s" % [rise_at, absf(rise), "위" if rise > 0.0 else "아래"])
		_ok("손 나머지는 물건 윤곽 밖 (%s)" % nm, hand_in >= 1.0,
				"가장 안쪽 %s %.2f (1 이상이면 윤곽 밖)" % [hand_at, hand_in])
		if side == 1:
			_ok("반지가 물건에 안 가린다", ring_r >= 1.0, "윤곽 비 %.2f" % ring_r)
	_ok("검지만 앞 층에 선다 (%s)" % nm, front_ok,
			"손 전부" if bool(g.give_all) else "검지 두 마디 — 엄지 · 손바닥은 밑")
	#  뿌린 뒤 집기는 GIVE.rel 초에 걸쳐 풀린다(give_rel) — 다 풀릴 때까지 기다린다.
	guard = 0
	while (g.give_i >= 0 or float(g.give_rel) > 0.0) and guard < 900:
		guard += 1
		await _wait(1)
	await _wait(3)
	var off := true
	for i in 2:
		var hj2: Dictionary = (g.hand3_rig[i] as Dictionary).hj
		off = off and not _front((hj2.j1[0] as Node3D).get_child(0)) \
				and not _front((hj2.j2[0] as Node3D).get_child(0)) \
				and not _front((hj2["in"] as Node3D).get_child(0))
	_ok("놓으면 앞 층을 걷는다 (%s)" % nm, off and not g.hand3_front_on
			and g.hand3_fvp.render_target_update_mode == SubViewport.UPDATE_DISABLED, "")


func _grip_checks() -> void:
	await _grip_case("rare", 400.0)
	await _grip_case("rare", 240.0)
	await _grip_case("dart", 240.0)
	await _grip_case("pack", 400.0)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 3D 는 화면이 있어야 선다")
		quit(0)
		return
	print("\n3D 손 검사 — 자리가 맞물리는가\n")

	# ① 투영이 같은 식인가. 카메라 각(−52°)이 TBL 의 정사영과 같아야 한다.
	var pit: float = deg_to_rad(float(g.HAND3.pitch))
	_ok("카메라 각이 면 투영과 같다",
			absf(sin(-pit) - float(g.TBL.flat)) < 0.002
			and absf(cos(-pit) - float(g.TBL.tall)) < 0.002,
			"sin %.3f (flat %.3f) · cos %.3f (tall %.3f)"
			% [sin(-pit), g.TBL.flat, cos(-pit), g.TBL.tall])

	# ② 상인이 서는 화면에서만 산다
	g.state = g.S.TITLE
	g._new_run()
	await _wait(40)
	_ok("판 고르기에서 손이 선다", g._hand3_live(), "state %d" % g.state)
	_ok("두 손이 섰다", g.hand3_rig.size() == 2, "%d벌" % g.hand3_rig.size())
	_ok("자세를 둘 받았다", g.hand3_pose.size() == 2,
			"%d개" % g.hand3_pose.size())

	# ③ 자세가 2D 의 셈과 같은 값인가 — 손목이 팔 끝에 있다
	var far := 0.0
	for ps in g.hand3_pose:
		var wr: Vector2 = ps.wr
		far = maxf(far, absf(wr.x - 320.0))
	_ok("손목이 상인 곁에 있다", far > 40.0 and far < 320.0,
			"가운데에서 %.0f" % far)

	# ④ 그림자가 손과 **같이** 돌되 어긋남은 월드다
	var rg: Dictionary = g.hand3_rig[0]
	var hd: Node3D = rg.hand
	var sd: Node3D = rg.shad
	_ok("그림자가 손과 같은 각", absf(sd.rotation.y - hd.rotation.y) < 0.001,
			"손 %.3f · 그림자 %.3f" % [hd.rotation.y, sd.rotation.y])
	_ok("그림자가 면에 눕는다", sd.scale.y < 0.1 and sd.position.y < 0.0,
			"두께배 %.2f · 높이 %.2f" % [sd.scale.y, sd.position.y])
	#  빛이 왼쪽 위라 그림자는 오른쪽 아래(화면 +x · +y)로 진다.
	var dx: float = sd.position.x - hd.position.x
	var dz: float = sd.position.z - hd.position.z
	_ok("그림자가 빛 반대쪽으로 진다", dx > 0.0 and dz > 0.0,
			"x +%.1f · z +%.1f" % [dx, dz])

	# ⑤ 팔 그림자는 펠트를 밟는 토막에만 — 쉬는 팔은 통째로 카운터 위다
	_ok("쉴 때 팔 그림자는 없다", not (rg.armsh as Node3D).visible, "")

	# ⑥ 몸통도 같은 각으로 선다. 무대가 둘이면 값이 갈리기 쉬운 자리다
	_ok("몸통 무대가 섰다", g._body3_live(), "")
	if g._body3_live():
		var bcam: Camera3D = null
		for c in g.body3_vp.get_children():
			if c is Camera3D:
				bcam = c
		var hcam: Camera3D = null
		for c in g.hand3_vp.get_children():
			if c is Camera3D:
				hcam = c
		_ok("몸통 카메라 각이 손과 같다",
				bcam != null and hcam != null
				and absf(bcam.rotation.x - hcam.rotation.x) < 0.0001,
				"%.4f" % (bcam.rotation.x if bcam != null else 0.0))
		_ok("몸통이 카운터에서 잘린다",
				g.BODY3.rect.position.y + g.BODY3.rect.size.y == g.TBL.fy,
				"밑변 %.0f (fy %.0f)" % [g.BODY3.rect.position.y
				+ g.BODY3.rect.size.y, g.TBL.fy])
		#  셔츠가 앞자락에 덮이는가 — BODY3 머리말의 그 한 줄을 여기서 잰다.
		var need: float = float(g.BODY3.sh_w) + tan(deg_to_rad(
				float(g.BODY3.vee_a))) * (float(g.BODY3.vee)
				- float(g.BODY3.sh_lo))
		_ok("앞자락이 셔츠를 덮는다", float(g.BODY3.pan_w) >= need,
				"앞자락 %.0f ≥ %.1f" % [float(g.BODY3.pan_w), need])

	# ⑦ 위팔은 **늘** 선다 — 2026-10-02 「몸에 비해 팔이 너무 얇지 않아?」.
	#  옛 팔은 위팔을 쓸 때만 그려서, 쉬는 팔이 동전 슬롯 밑변에서 곧장 떨어지는
	#  막대였다(어깨도 팔꿈치 꺾임도 없이). 이제 어깨에서 나온다.
	for i in 2:
		var rgu: Dictionary = g.hand3_rig[i]
		_ok("쉴 때 위팔이 선다 (%s)" % ("왼" if i == 0 else "오른"),
				(rgu.up as Node3D).visible, "")
		_ok("위팔과 팔뚝이 팔꿈치에서 만난다 (%s)" % ("왼" if i == 0 else "오른"),
				_elbow_gap(i) < 1.0, "틈 %.2f" % _elbow_gap(i))
	# ⑦′ 비례 — 손과 팔이 **같이** 컸는가. 사람 비를 과녁으로 둔다(HAND3 머리말):
	#    가슴 : 위팔 : 팔뚝(팔꿈치) : 손 폭 ≈ 3.2 : 1.1 : 1.0 : 0.9
	#    손 폭 ≈ 손목 × 1.2 · 손 길이 ≈ 손 폭 × 2
	#  「팔만 두꺼워 지는게 아니라 손도 같이 커져야 하지 않을까?」 — 표에서 바로 잰다.
	var H3: Dictionary = g.HAND3
	var B3: Dictionary = g.BODY3
	var chest: float = 2.0 * (float(B3.hinge) + float(B3.side) * cos(deg_to_rad(float(B3.yaw)))
			+ (104.0 - float(B3.lean_y)) * tan(deg_to_rad(float(B3.lean))))
	var k_up: float = float(H3.up_w0) / float(H3.arm_w0)
	var k_hd: float = float(H3.palm_w) / float(H3.arm_w0)
	var k_wr: float = float(H3.palm_w) / float(H3.arm_w1)
	var k_ln: float = float(H3.palm_l) / float(H3.palm_w)
	var k_ch: float = chest / float(H3.arm_w0)
	_ok("가슴 : 팔뚝 2.8~3.6", k_ch >= 2.8 and k_ch <= 3.6, "%.2f (가슴 %.0f)" % [k_ch, chest])
	_ok("위팔 : 팔뚝 1.0~1.25", k_up >= 1.0 and k_up <= 1.25, "%.2f" % k_up)
	_ok("손 폭 : 팔뚝 0.8~1.0", k_hd >= 0.8 and k_hd <= 1.0, "%.2f" % k_hd)
	_ok("손 폭 : 손목 1.1~1.3", k_wr >= 1.1 and k_wr <= 1.3, "%.2f" % k_wr)
	_ok("손 길이 : 손 폭 1.75~2.2", k_ln >= 1.75 and k_ln <= 2.2, "%.2f" % k_ln)
	_ok("손이 동전보다 크다", float(H3.palm_w) * float(H3.palm_l)
			>= PI * float(g.TBL.chip_r) * float(g.TBL.chip_r),
			"손 %.0f · 동전 %.0f" % [float(H3.palm_w) * float(H3.palm_l),
			PI * float(g.TBL.chip_r) * float(g.TBL.chip_r)])
	#  쓸기는 상점의 일이다 — 시계(_sweep_update)가 거기서만 돈다.
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	#  상점을 열면 배움이 한 걸음 뜨고, 그동안 게임 시간이 0.3 배로
	#  느려진다(_tutor_slow). 팔을 재는 검사라 그것부터 걷는다 —
	#  안 걷으면 열네 프레임 뒤에도 쓸기가 거의 시작조차 안 한다.
	g._tutor_close()
	g.tutor_q.clear()
	await _wait(30)
	g.idle_act = -1
	g.idle_wait = 9.0
	await _wait(20)
	for i in 2:
		_thumb_anat("쉼", i)
	g._sweep_begin()
	await _wait(14)
	_ok("쓸면 위팔이 선다",
			((g.hand3_rig[1] as Dictionary).up as Node3D).visible, "")
	#  위팔과 팔뚝이 같은 팔꿈치를 지나야 한다. 벌어지면 팔이 끊긴다.
	_ok("쓸 때도 팔꿈치에서 만난다", _elbow_gap(1) < 1.0, "틈 %.2f" % _elbow_gap(1))
	_ok("쓸면 팔 그림자가 진다",
			((g.hand3_rig[1] as Dictionary).armsh as Node3D).visible, "")
	#  편 손 — 쓸기가 손을 다 편 박자(_sweep_amt 0.9 이상)에서 엄지를 잰다. 왼손은 쓸지 않는다.
	var sw_guard := 0
	while g.sweep_live and g._sweep_amt() < 0.9 and sw_guard < 120:
		sw_guard += 1
		await _wait(1)
	_ok("쓸기가 손을 편다", g._sweep_amt() >= 0.9, "%.2f" % g._sweep_amt())
	_thumb_anat("쓸기", 1)
	while g.sweep_live:
		await _wait(8)
	await _wait(6)

	# 팔뿌리(어깨)가 동전 슬롯(밑변 48) 밑으로 나오면 안 된다 — 거기서 위팔이
	#  끝나는 상자라 잘린 단면이 그대로 보인다. 옛 판은 팔뚝 뿌리를 46 늘려
	#  숨겼다(HAND3.back) — 이제 위팔이 어깨까지 잇고 어깨가 슬롯 뒤다.
	#  제일 멀리 뻗는 「살핌」으로 잰다.
	g._npc_react("살핌", 1)
	g.idle_t = g._idle_len() * 0.5
	await _wait(3)
	for i in 2:
		var up3: Node3D = (g.hand3_rig[i] as Dictionary).up
		var uo: Vector3 = up3.transform.origin
		var usy: float = g.TBL.fy + uo.z * g.TBL.flat - uo.y * g.TBL.tall
		_ok("살필 때 어깨가 동전 슬롯 뒤에 있다 (%s)" % ("왼" if i == 0 else "오른"),
				usy <= 44.0, "화면 y %.1f (슬롯 48)" % usy)
		_ok("살필 때도 팔꿈치에서 만난다 (%s)" % ("왼" if i == 0 else "오른"),
				_elbow_gap(i) < 1.0, "틈 %.2f" % _elbow_gap(i))
	g.idle_act = -1
	g.idle_t = 0.0
	await _wait(3)

	# ⑦″ 집는다 — 2026-10-02 「동전에 손가락이 뚫리는데 이건 뭐 어떻게 안될까?」 ·
	#  「지금 동전 짚는 손 모양 너무 이상한데」. 상인이 물건을 받아 살피는 박자 내내 잰다 —
	#  레어 동전을 두 손에 한 번씩, 다트(손 전부가 앞 층) · 팩을 한 번씩.
	await _grip_checks()


	# ⑧ 화면을 뜨면 지워진다 — 안 보이는 뷰포트가 런 내내 돌면 안 된다
	g.state = g.S.TITLE
	await _wait(6)
	_ok("화면을 뜨면 지워진다", not g._hand3_live(), "")
	_ok("손 목록도 빈다", g.hand3_rig.is_empty(), "%d벌" % g.hand3_rig.size())
	_ok("몸통 무대도 지워진다", not g._body3_live(), "")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
