extends SceneTree
# 상인이 두 벌로 서는가 — 상점은 잘린 상반신, 시작 화면은 통째로.
#   godot --headless --path . --script scripts/tools/qa_dealer.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_dlr_g.cfg"
	Save.path = "user://_qa_dlr.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


#  면 좌표 h 가 상점 무대에서 앉는 화면 y. 52° 투영이다.
func _shop_y(h: float) -> float:
	return float(g.TBL.fy) - h * float(g.TBL.tall)


func _run() -> void:
	g._new_run()
	var H: Dictionary = g.HEAD3
	var B: Dictionary = g.BODY3

	# ── 상점에는 한 픽셀도 안 샌다 ──────────────────────
	#  머리에서 **가장 낮은** 조각이 무대 위끝(y 0)보다 위에 있어야 한다.
	var low: float = minf(float(H.hd_lo), minf(float(H.nk_lo), float(H.col_lo)))
	var ybot: float = _shop_y(low)
	_ok("머리 조각이 상점 무대 밖이다", ybot < 0.0,
			"가장 낮은 h %.0f → 화면 y %.1f" % [low, ybot])
	_ok("어깨는 몸통 위끝에서 잇는다",
			float(H.sh_h) + float(H.sh_lo) <= float(B.hi) + 1.0,
			"어깨 밑 %.0f · 몸통 위끝 %.0f" % [float(H.sh_h) + float(H.sh_lo),
			float(B.hi)])

	# ── 위아래 차례 ─────────────────────────────────────
	var order := [["깃", float(H.col_lo)], ["나비넥타이", float(H.tie_lo)],
			["턱", float(H.hd_lo)], ["입", float(H.mo_lo)],
			["코", float(H.nose_lo)], ["눈그늘", float(H.eye_lo)],
			["모자테", float(H.brim_lo)], ["모자띠", float(H.band_lo)],
			["정수리", float(H.crn_hi2)]]
	var rising := true
	var prev: float = -1.0
	for e in order:
		if float(e[1]) <= prev:
			rising = false
		prev = float(e[1])
	_ok("얼굴 조각이 아래에서 위로 선다", rising,
			" · ".join(order.map(func(e): return "%s %.0f" % [e[0], float(e[1])])))
	#  깃이 턱 위로 올라오면 목이 없어진다 — 첫 판이 그랬다.
	_ok("깃이 턱보다 낮다", float(H.col_hi) < float(H.hd_lo),
			"깃 위끝 %.0f · 턱 %.0f" % [float(H.col_hi), float(H.hd_lo)])
	_ok("맨 목이 보인다", float(H.hd_lo) - float(H.col_hi) >= 6.0,
			"%.0f" % (float(H.hd_lo) - float(H.col_hi)))
	#  모자는 얼굴보다 넓고, 테는 통보다 넓다.
	_ok("모자 테가 통보다 넓다", float(H.brim_w) > float(H.crn_w),
			"테 %.0f · 통 %.0f" % [float(H.brim_w), float(H.crn_w)])
	_ok("모자띠가 통보다 살짝 나온다",
			float(H.band_w) > float(H.crn_w) and float(H.band_w) < float(H.brim_w),
			"띠 %.1f" % float(H.band_w))
	_ok("테가 얼굴을 덮는다", float(H.brim_w) > float(H.hd_w) + 8.0,
			"테 %.0f · 얼굴 %.0f" % [float(H.brim_w), float(H.hd_w)])
	#  눈그늘은 테 **밑**이라야 그늘이다.
	_ok("눈그늘이 테 밑이다", float(H.eye_hi) <= float(H.brim_lo),
			"그늘 위끝 %.0f · 테 %.0f" % [float(H.eye_hi), float(H.brim_lo)])

	# ── 등신 ────────────────────────────────────────────
	var head: float = float(H.crn_hi2) - float(H.hd_lo)
	var tall: float = float(H.crn_hi2)
	_ok("반신이 3~4.5 등신이다", tall / head >= 3.0 and tall / head <= 4.5,
			"키 %.0f ÷ 머리 %.0f = %.2f" % [tall, head, tall / head])
	var sh_w: float = float(H.sh_hinge) + float(H.sh_len) * cos(deg_to_rad(float(B.yaw)))
	_ok("어깨가 머리 두 개 반은 넘는다", sh_w * 2.0 / (float(H.hd_w) * 2.0) >= 2.2,
			"어깨 %.0f ÷ 얼굴 %.0f = %.2f" % [sh_w * 2.0, float(H.hd_w) * 2.0,
			sh_w / float(H.hd_w)])

	# ── 두 벌 ───────────────────────────────────────────
	g.state = g.S.SHOP
	g.pause_from = -1
	_ok("상점은 시작 화면 벌이 아니다", not g._ttl_npc())
	g.state = g.S.TITLE
	_ok("제목은 상인이 선다", g._npc_on() and g._ttl_npc())
	g.state = g.S.SETTINGS
	g.pause_from = -1
	_ok("제목 위 설정도 같은 벌이다", g._ttl_npc())
	g.pause_from = g.S.AIM_V
	_ok("판 중에 연 설정은 아니다", not g._ttl_npc() and not g._npc_on())
	g.state = g.S.AIM_V
	g.pause_from = -1
	_ok("판에서는 안 선다", not g._npc_on())

	# ── 벌을 바꾸면 값이 따라온다 ───────────────────────
	g.state = g.S.TITLE
	g._body3_mode(true)
	var r: Rect2 = g.body3_rect
	_ok("제목 벌은 제 사각을 쓴다", r != Rect2(B.rect) and r.end.y <= 360.0,
			"%s" % r)
	_ok("제목 벌은 작다", g.body3_scale < 1.0 and g.body3_scale > 0.3,
			"%.2f" % g.body3_scale)
	_ok("제목 벌은 눈높이 카메라다", g.body3_front != 0.0,
			"aim %.1f" % g.body3_front)
	#  정수리가 못박은 자리에 앉는가. 카메라가 h 를 1:1 로 편다.
	var crown_y: float = r.position.y + r.size.y * 0.5 \
			- (float(H.crn_hi2) * g.body3_scale - g.body3_front)
	_ok("정수리가 못박은 y 에 앉는다",
			absf(crown_y - float(g.NPC_TTL.top)) < 0.01,
			"%.2f (바란 것 %.0f)" % [crown_y, float(g.NPC_TTL.top)])
	#  허리는 화면 밑으로 빠져야 한다 — 안 빠지면 잘린 흉상이 허공에 뜬다.
	var waist_y: float = r.position.y + r.size.y * 0.5 + g.body3_front
	_ok("허리는 화면 밑으로 빠진다", waist_y > 360.0,
			"허리 y %.1f" % waist_y)
	#  어깨가 판 숫자 고리(x ≤ 442)를 안 스친다.
	var arm_x: float = float(g.NPC_TTL.at) \
			- (float(H.arm_u) + float(H.arm_w)) * g.body3_scale
	_ok("왼팔이 판 숫자를 안 스친다", arm_x > 448.0, "왼끝 x %.1f" % arm_x)
	_ok("오른쪽이 화면 안이다",
			float(g.NPC_TTL.at) + (float(H.arm_u) + float(H.arm_w))
			* g.body3_scale < 640.0)

	g._body3_mode(false)
	_ok("상점 벌로 되돌아온다", g.body3_rect == Rect2(B.rect)
			and is_equal_approx(g.body3_scale, 1.0) and g.body3_front == 0.0,
			"%s · %.2f" % [g.body3_rect, g.body3_scale])
