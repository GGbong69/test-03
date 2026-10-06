extends "res://scripts/game.gd"
#  포스터 「상점 테이블」(shot_shop.gd) 전용 — game.gd 를 한 줄도 안 고치고 그리기만 가른다.
#  poster_on 이 서면 _draw 가 상점 테이블 한 벌만 그리고(HUD · 단추 · 값 · 창구 이름 · 툴팁 ·
#  배움 띠 없음), pp 의 열쇠가 층마다 켜고 끈다 — 같은 틀을 여러 번 찍어 투명 층으로 나눈다.
#    room   3D 방(벽 · 선반 · 네온)          body   상인 몸통(3D)
#    table  3D 진열대(벨벳 · 저울 · 등록기)   goods  펠트 위 물건과 그 그림자 전부
#    gsh    그림자를 깔 물건 색인 배열        gi     몸통을 그릴 물건 색인 하나(-1 없음)
#    noglow gi 를 몸만(등급 빛 고리 없이)      shadow 손 그림자
#    hands  팔 · 손 · 든 물건 · 그 빛 전부 — 또는 낱으로:
#           hglow 든 물건의 등급 빛 · harm 팔 · 손 · hcoin 든 물건 · hfront 물건 앞에 선 검지
#  3D 화판은 shot_shop 이 크기를 키운다(k3 배). 화판 일부를 잘라 붙이는 세 곳
#  (_room3d_band · _room3d_tband · _hand3_shad_draw)은 원본 좌표가 논리 px 라
#  여기서 화판 크기 비로 다시 잰다.
#  poster_lift · poster_fwd · poster_du — 「살핌」 중인 손을 더 들고(면 높이) 앞으로 더 내민다
#  (면 깊이 · 가로). 손 그림자 · 물건 그림자는 펠트에 남으므로 손이 동전을 들어 내미는 높이가 선다.
#  poster_grip · poster_din … — 집는 자리만 포스터 값으로(엄지가 테 밑에서 비치게). 아래 머리말.
#  _hand3_mats · _hand3_build — 손등 너클 판을 살빛 · 납작하게(포스터 배율에서 쇠붙이로 읽혔다).
var poster_on := false
var pp := {"bg": true, "room": true, "body": true, "table": true, "goods": true,
		"shadow": true, "hands": true}
var poster_lift := 0.0
var poster_fwd := 0.0
var poster_du := 0.0
var poster_rest_du := 0.0     # 쉬는 손을 가로로 미는 양 — 진열대 끝 소품(저울)이 들어설 틈
var poster_rest_dw := 0.0
#  집는 자리(포스터만) — 게임의 GIVE 「테를 집는다」(검지 끝은 테 위 · 엄지 끝은 그 밑)를 그대로
#  두고 자리만 돌린다. 게임은 동전이 검지 끝에서 앞 · 엄지 쪽(din −50°)으로 뻗어 엄지가 동전 밑에
#  통째로 숨는다 — 포스터는 동전을 검지 끝의 앞 · 새끼 쪽(din +40°)에 물려, 엄지가 손 안쪽(화면에서
#  검지 왼쪽)에서 검지 곁으로 나와 둥근 끝으로 같은 테를 받치게 한다(poster_tlat 로 한 손가락 폭 벌린다).
#  poster_grip 이 거짓이면 게임 그대로다(건네기를 시작하기 전에 세운다 — _give_fit 이 깊이를 잰다).
var poster_grip := false
var poster_din := -50.0
var poster_tout := 0.5
var poster_tlat := 3.0
var poster_tdrop := 0.0       # give_tdrop 에 더한다(엄지 끝을 더 내린다)
var poster_tfwd := 0.0        # 엄지 끝을 손끝 쪽(손 좌표 +x)으로 미는 양
var poster_ang := 0.0         # 든 손의 손각 덤(라디안)
#  손등 너클 — 게임은 살빛보다 한 단 밝은 네모 판 넷(FING3.knuck)이라 포스터 배율에서는 쇠붙이
#  너클로 읽힌다. 포스터만 살빛 쪽으로 섞고 윤을 죽인다(0 살빛 · 1 게임 그대로).
var poster_knuck := 0.2
var poster_knuck_t := 0.55    # 너클 판 두께 배(1 게임 그대로) — 손등 위로 솟은 몫이 1.0 → 0.4


func _pp(k: String) -> bool:
	return not poster_on or bool(pp.get(k, false))


func _hk(k: String) -> bool:
	return not poster_on or bool(pp.get("hands", false)) or bool(pp.get(k, false))


func _draw() -> void:
	if not poster_on:
		super._draw()
		return
	ui_hot = ""
	shake_off = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	if bool(pp.get("bg", false)):
		draw_rect(_full(), C_BG)
	_table_draw()
	draw_set_transform(Vector2.ZERO)


#  든 손을 더 들고 내민다 — 「살핌」 몸짓 위에 더한다(봉투 k 를 같이 타서 몸짓 밖에서는 0).
#  쉬는 손은 가로로 조금 민다(판형 가장자리에 걸칠 저울 · 등록기와 안 겹치게).
func _idle_hand(i: int) -> Dictionary:
	var out: Dictionary = super._idle_hand(i)
	if not poster_on or give_i < 0 or _idle_name() != "살핌":
		return out
	var k := _idle_env()
	if i == give_side:
		out.dh = float(out.dh) + poster_lift * k
		out.dw = float(out.dw) + poster_fwd * k
		out.du = float(out.du) + poster_du * k
		out.ang = float(out.ang) + poster_ang * k
	else:
		out.du = float(out.du) + poster_rest_du * k
		out.dw = float(out.dw) + poster_rest_dw * k
	return out


#  ── 집는 손 — game.gd 의 _grip3_pt 와 같은 식, GIVE.din · tout · tlat 만 포스터 값 ──────
func _grip3_pt(sg: float, k: int, sc := 1.0) -> Vector3:
	if not poster_grip:
		return super._grip3_pt(sg, k, sc)
	var t: Vector3 = GIVE.ti
	var ti := Vector3(t.x, t.y, t.z * sg)
	if k == 1 or k == 0:
		return ti
	var iv: float = 1.0 / maxf(sc, 0.1)
	var a: float = deg_to_rad(poster_din)
	var dn := Vector3(cos(a), 0.0, sin(a) * sg)
	if k == 2:
		var dd: Vector3 = Vector3(0.0, 0.0, -sg) if give_rot == 2 else dn
		return ti + dd * ((give_depth - float(GIVE.inset)) * iv) \
				+ Vector3(0.0, -give_pad * iv, 0.0)
	return ti - dn * (poster_tout * iv) \
			+ Vector3(poster_tfwd * iv, -give_tdrop * iv, -poster_tlat * sg * iv)


func _give_din_ang(ga: float) -> float:
	if not poster_grip:
		return super._give_din_ang(ga)
	var sg: float = -1.0 if give_side == 1 else 1.0
	var a: float = deg_to_rad(poster_din)
	return ga + poster_ang + atan2(sin(a) * sg, cos(a))


func _give_fit(s: Dictionary) -> void:
	super._give_fit(s)
	if poster_grip:
		give_tdrop += poster_tdrop


#  너클 판을 납작하게 — 게임은 손등 앞끝에 두께 2.6 의 네모 판 넷을 솟게 해 램프가 윗면을 밝힌다.
#  포스터 배율에서는 그 윗면이 쇠붙이 너클로 읽혀 두께를 반 밑으로 · 길이를 줄여 살 둔덕만 남긴다.
func _hand3_build(mats: Variant, mir: bool, ring := false, shadow := false) -> Dictionary:
	var d: Dictionary = super._hand3_build(mats, mir, ring, shadow)
	if shadow or not (mats is Dictionary):
		return d
	var km: Material = (mats as Dictionary).get("knuck")
	for c in (d.in as Node3D).get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == km:
			var mi := c as MeshInstance3D
			mi.scale = Vector3(0.8, poster_knuck_t, 0.92)
	return d


func _hand3_mats() -> Dictionary:
	var d: Dictionary = super._hand3_mats()
	var c: Color = Color(FING3.skin).lerp(Color(FING3.knuck), poster_knuck)
	d.knuck = _skin3_mat(c, 0.16, 0.8)
	return d


#  ── 글자 · 판 — 포스터에는 하나도 안 선다 ─────────────────
func _hud_draw() -> void:
	if not poster_on:
		super._hud_draw()


func _bills_draw(z: Array) -> void:
	if not poster_on:
		super._bills_draw(z)


func _bill_one(i: int) -> void:
	if not poster_on:
		super._bill_one(i)


func _chute_label() -> void:
	if not poster_on:
		super._chute_label()


func _tip_draw(sh: Vector2) -> void:
	if not poster_on:
		super._tip_draw(sh)


func _tutor_draw() -> void:
	if not poster_on:
		super._tutor_draw()


#  ── 층 ────────────────────────────────────────────────
func _felt_draw() -> void:
	if not poster_on or not _room3d_live():
		super._felt_draw()
		return
	if _pp("room"):
		draw_texture_rect(room_vp.get_texture(), _full(), false)
	if _pp("table"):
		draw_texture_rect(tbl3_vp.get_texture(), _room3d_rect(), false)
		_chute_draw()


func _room3d_band(top: float, bot: float) -> void:
	if not _pp("room"):
		return
	var f := _full()
	var t0: float = clampf((top - f.position.y) / f.size.y, 0.0, 1.0)
	var t1: float = clampf((bot - f.position.y) / f.size.y, 0.0, 1.0)
	var ts := Vector2(room_vp.size)
	draw_texture_rect_region(room_vp.get_texture(),
			Rect2(f.position.x, top, f.size.x, bot - top),
			Rect2(0.0, ts.y * t0, ts.x, ts.y * (t1 - t0)))


func _room3d_tband(top: float, bot: float) -> void:
	if not _pp("table"):
		return
	var r := _room3d_rect()
	var k := Vector2(tbl3_vp.size) / r.size
	draw_texture_rect_region(tbl3_vp.get_texture(),
			Rect2(r.position.x, top, r.size.x, bot - top),
			Rect2(0.0, (top - r.position.y) * k.y, r.size.x * k.x, (bot - top) * k.y))


func _body3_draw() -> void:
	if _pp("body"):
		super._body3_draw()


func _prop_coin_draw() -> void:
	if _pp("table"):
		super._prop_coin_draw()


#  물건 — goods 가 서면 게임 그대로 전부. 아니면 gsh(그림자를 깔 색인들) · gi(몸통 하나).
func _goods_draw() -> void:
	if not poster_on:
		super._goods_draw()
		return
	if bool(pp.get("goods", false)):
		super._goods_draw()
		return
	var gsh: Array = pp.get("gsh", [])
	var gi: int = int(pp.get("gi", -1))
	if gsh.is_empty() and gi < 0:
		return
	var z := _z_order()
	for i in z:
		if gsh.has(i):
			_obj_shadow(i)
			_land_floor(i)
	if gi >= 0 and gi != give_i and gi < drop.size() and gi < stock.size():
		#  noglow — 몸만(등급 빛 고리는 compose 가 실루엣에서 매끈하게 다시 짓는다)
		if bool(pp.get("noglow", false)):
			glow_pass = 2
		_obj_draw(gi, 0.0)
		glow_pass = 0


func _waste_draw() -> void:
	if _pp("goods"):
		super._waste_draw()


func _smash_draw() -> void:
	if _pp("goods"):
		super._smash_draw()


func _burst_draw() -> void:
	if _pp("goods"):
		super._burst_draw()


func _pound_candy_draw(lay: int) -> void:
	if _pp("goods"):
		super._pound_candy_draw(lay)


func _give_glow_draw() -> void:
	if _hk("hglow"):
		super._give_glow_draw()


func _give_draw() -> void:
	if _hk("hcoin"):
		super._give_draw()


func _hand3_front_draw() -> void:
	if _hk("hfront"):
		super._hand3_front_draw()


func _hand3_draw() -> void:
	if not poster_on:
		super._hand3_draw()
		return
	if not _hand3_live():
		return
	if _pp("shadow"):
		_hand3_shad_draw()
	if _hk("harm"):
		var tex: Texture2D = hand3_vp.get_texture()
		if tex != null:
			draw_texture_rect(tex, HAND3.rect, false)


#  game.gd 의 _hand3_shad_draw 와 같은 식 — 원본 사각만 화판 크기 비(k)로 잰다.
func _hand3_shad_draw() -> void:
	if not poster_on:
		super._hand3_shad_draw()
		return
	if hand3_svp == null or not is_instance_valid(hand3_svp):
		return
	var a0: float = hand3_sa[0]
	var a1: float = hand3_sa[1]
	if a0 <= 0.0 and a1 <= 0.0:
		return
	var r: Rect2 = HAND3.rect
	var k := Vector2(hand3_svp.size) / r.size
	var y0: float = maxf(_p2s(0.0, float(HAND3.lip_b), float(HAND3.lip_h)).y, r.position.y)
	var y1: float = r.end.y
	var xs: float = r.position.x
	if a0 > 0.0 and a1 > 0.0:
		xs = clampf(((npc_palm[0] as Vector3).x + (npc_palm[1] as Vector3).x) * 0.5,
				r.position.x, r.end.x)
	elif a0 > 0.0:
		xs = r.end.x
	var tex: Texture2D = hand3_svp.get_texture()
	if xs > r.position.x:
		draw_texture_rect_region(tex, Rect2(r.position.x, y0, xs - r.position.x, y1 - y0),
				Rect2(0.0, (y0 - r.position.y) * k.y, (xs - r.position.x) * k.x, (y1 - y0) * k.y),
				Color(1.0, 1.0, 1.0, a0))
	if xs < r.end.x:
		draw_texture_rect_region(tex, Rect2(xs, y0, r.end.x - xs, y1 - y0),
				Rect2((xs - r.position.x) * k.x, (y0 - r.position.y) * k.y,
						(r.end.x - xs) * k.x, (y1 - y0) * k.y),
				Color(1.0, 1.0, 1.0, a1))
