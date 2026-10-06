extends SceneTree
#  포스터 「상점 테이블」(key=shop) 의 원화 — 게임을 SubViewport 에 달아 인쇄 해상도로 찍는다.
#  상인 테이블에 물건을 깔고(동전 셋 · 팩 · 사탕 · 사진 · 다트) 자리를 손으로 잡은 뒤, 상인이
#  동전 하나를 엄지 · 검지로 테를 집어 살짝 들어 살피는 틀에서 멈춘다(shop_poster_game 의
#  poster_lift · poster_fwd · poster_grip). 같은 틀을 층마다 따로 찍는다(투명 PNG — pp).
#    shop_full          HUD 없는 한 장(확인용 — 방 화판은 안 키워 흐리다)
#    shop_body          상인 몸통
#    shop_scale · shop_register
#                       저울만 · 등록기만(화면 안쪽으로 옮겨 찍어 잘린 몸 없이)
#    shop_g_<i>         펠트 위 물건 하나씩 — 몸만(등급 빛 고리 없이 · compose 가 매끈하게 다시 짓는다)
#    shop_gs_<i>        그 물건의 그림자만
#    shop_gsh_held      든 동전의 게임 그림자(compose 는 숨긴다)
#    shop_hshadow       손 그림자
#    shop_hglow · shop_harm · shop_hcoin · shop_hfront
#                       든 동전 등급 빛(게임 — 숨김) · 팔과 손 · 든 동전 · 동전 앞에 선 검지
#    shop_room_shelves  포스터용 방 — 게임 방 카메라와 가로 시야가 같고 위아래로 길다(room_h 배).
#                       벽을 천장까지 올리고, 가운데 술병 선반은 아래 두 줄만 남긴다(제목 · 다트판이
#                       깨끗한 판자 벽에 걸린다). 네온 글자 · 그 빛은 끈다(제목이 간판이다)
#    shop_table_A · shop_table_X
#                       판형별 진열대 — 게임 진열대(Room3D.make_table)를 펠트 깊이만 늘려 새로 짓는다
#                       (A 는 deep_a · X배너는 deep_x 논리 px 만큼 가까운 난간이 내려간다). 저울 · 등록기는
#                       뺀다(따로 찍은 층을 compose 가 앞 귀퉁이에 세운다). 램프는 게임 자리 그대로.
#    shop_meta.json     배율 · 물건 자리(논리 px) · 든 동전 자리 · 진열대 깊이 — compose_shop.py 가 읽는다
#  게임 파일은 안 고친다. 3D 화판(진열대 · 손 · 몸통 · 사탕)은 찍기 전에 k3 배로 키운다(방 화판은 안 키운다).
#  창이 있어야 돈다. 인자는 이름=값(예: -- k=12 lift=-8)이고 빠지면 아래 A 의 기본값 — 포스터는 기본값 그대로다:
#    godot --path . --script scripts/tools/poster/shot_shop.gd
#  15배(9600x5400). 약 2~3분. quick=1 이면 4배로 손 · 물건만(손 모양 고르기 — raw_q/).
#  결과: outputs/poster/shop/raw/  →  compose_shop.py 가 판형마다 굽는다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Room3D = preload("res://scripts/room3d.gd")
const SUB := "res://scripts/tools/poster/shop_poster_game.gd"
const DT := 1.0 / 120.0
var OUT := "res://outputs/poster/shop/raw"
var g = null
var vp: SubViewport = null
var busy := false
var A := {
	"k": 15,          # 2D 배율 — 논리 640x360 을 이만큼 키운 기기 px 로 그린다
	"k3": 15,         # 3D 화판 배율
	"quick": 0,       # 1 이면 손 · 물건만 6배로(raw_q)
	"tables": 0,      # 1 이면 판형별 진열대만 다시 짓는다(shop_meta.json 의 tables 만 고친다)
	"room_w": 3000,   # 포스터용 방 가로 px
	"room_h": 6.0,    # 포스터용 방 세로 = 가로 x 9/16 x room_h (게임 화면 세로의 몇 배)
	"shelf_up": 2,    # 벽 · 천장을 술병 선반 세 줄 묶음 몇 벌만큼 올리나
	"deep_a": 12,     # A 판형 진열대 — 가까운 난간을 몇 논리 px 내리나(펠트를 앞으로 늘린다)
	"deep_x": 200,    # X배너 진열대
	"tbl_k": 15,      # 늘린 진열대 화판 배율(A)
	"tbl_kx": 12,     # 늘린 진열대 화판 배율(X배너)
	"lift": -10.0,    # 든 손을 더 드는 높이(면 단위) — 음수면 내린다. 동전을 「집어 살짝 든」 높이로
	"fwd": 10.0,      # 든 손을 앞으로 더 내미는 깊이(면 단위)
	"du": -50.0,      # 든 손을 가로로 더 미는 양 — 화면 가운데 쪽으로
	"hang": -8.0,     # 든 손 손각 덤(도) — 손끝이 조금 덜 가운데로(보는 사람 쪽)
	#  집는 자리 — 동전을 검지 끝의 앞 · 새끼 쪽(din +40)에 물려 집는 자리가 테의 손 쪽 뒤 어깨에 서고,
	#  엄지가 손 안쪽(화면에서 검지 왼쪽 · 몸 가운데 쪽)에서 검지 곁으로 나와 둥근 끝으로 같은 테를 밑에서
	#  받친다(tlat 8 — 검지와 한 손가락 폭 벌어져 두 손끝이 따로 읽힌다). 게임(din −50)은 동전이 엄지 쪽
	#  앞이라 엄지가 동전 밑에 통째로 숨고, 테 밑으로 앞내면(옛 포스터 값) 꽂힌 막대로 읽혔다.
	"din": 40.0,      # 검지 끝 → 동전 한가운데 방향(도)
	"tout": 0.0,      # 엄지 끝이 테 밖으로 나온 길이(게임 0.5)
	"tlat": 8.0,      # 엄지 끝을 엄지 쪽(손 안쪽)으로 미는 양(게임 3)
	"tdrop": -1.0,    # 엄지 끝을 더 내리는 양(음수면 덜 — 테 바로 밑)
	"tfwd": -1.0,     # 엄지 끝을 손끝 쪽으로 미는 양
	"knuck": 0.0,     # 너클 색 — 0 살빛 · 1 게임
	"rest_du": 6.0,   # 쉬는 손(화면 왼손)을 가운데 쪽으로
	"rest_dw": 6.0,
	"scale_in": 44.0, # 저울 · 등록기만 찍을 때 화면 안쪽으로 옮기는 양 — 화면 끝에 잘린 몸을 다 담는다
	"reg_in": 90.0,
	"look": 0.45,     # 「살핌」 안에서 멈출 자리(0..1)
}
var held := "l02"     # 상인이 든 동전

#  펠트 위 물건 — (종류, id, 화면 x, 화면 y, 면 위 방위 psi). 화면 좌표는 논리 px 이고
#  면 깊이로 바꿔 놓는다(w = (y − 128) / 0.788). 0 번이 상인이 집어 드는 동전이다.
#  여기 자리는 찍는 자리일 뿐이다 — 물건마다 따로 찍으므로 compose_shop.py 가 판형마다
#  제 자리 · 크기(앞일수록 크게)로 옮긴다. 서로 안 겹치고 손 그림자 밖이면 된다.
#  둥근 물림 테 동전(레어 r01)은 붉은 펠트 위에서 칩으로 읽혀 뺐다 — 동전은 셋 다
#  레전더리 판(육각 · 세로 판 · 녹아내린 판)이다.
var PLAN := [
	["item", "l02", 392.0, 205.0, 0.0],
	["boost", "b_big", 230.0, 214.0, -0.30],
	["item", "l04", 280.0, 236.0, 0.12],
	["item", "l05", 330.0, 222.0, -0.06],
	["cons", "c_bl", 450.0, 236.0, 0.0],
	["fix", "v_pnt", 390.0, 246.0, 0.55],
	["dart", "", 210.0, 250.0, -0.70],
]


func _initialize() -> void:
	Save.gpath = "user://_poster_shop_g.cfg"
	Save.path = "user://_poster_shop.cfg"
	Save.wipe()
	for s in OS.get_cmdline_user_args():
		var kv := String(s).split("=", false, 1)
		if kv.size() != 2 or not A.has(kv[0]):
			push_warning("모르는 인자 " + String(s))
			continue
		if typeof(A[kv[0]]) == TYPE_INT:
			A[kv[0]] = int(kv[1])
		else:
			A[kv[0]] = float(kv[1])
	if int(A.quick) == 1:
		A.k = 6
		A.k3 = 6
		OUT = "res://outputs/poster/shop/raw_q"
	print("args ", A)
	var K: int = A.k
	vp = SubViewport.new()
	vp.size = Vector2i(640 * K, 360 * K)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load(SUB))
	g.poster_knuck = float(A.knuck)
	vp.add_child(g)
	seed(20261006)


func _process(_d: float) -> bool:
	if g != null:
		g.hover_live = false
		g.tip_pin = {}
		g.tip_a = 0.0
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


#  게임 시계를 손으로 민다. 몸짓은 막는다(상인이 제멋대로 손을 털지 않게) — 단 건네는
#  중에는 _give_tick 이 「살핌」 몸짓을 스스로 세우므로 그대로 둔다.
func _step(sec: float) -> void:
	for k in int(ceil(sec / DT)):
		if not g._give_live():
			g.idle_act = -1
		g.idle_wait = 99.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(DT)


#  그리기(자세 셈) → 3D 맞춤을 몇 번 돌려 2D 물건과 3D 손이 같은 틀에 서게 한다.
func _settle() -> void:
	for k in 4:
		g.queue_redraw()
		await _wait(3)
		g._process(0.00001)
	g.queue_redraw()
	await _wait(3)


func _grab() -> Image:
	g.queue_redraw()
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _row(tbl: Array, id: String) -> Dictionary:
	for r in tbl:
		if String(r.get("id", "")) == id:
			return r
	return tbl[0]


#  3D 화판을 키운다 — 아직 안 키운 것만(그리는 중에 새로 서는 사탕 화판도 잡는다).
#  방 화판은 안 키운다(포스터는 따로 찍는 shop_room_* 을 쓴다 — 키우면 그래픽 메모리만 먹는다).
func _grow_vps() -> int:
	var n := 0
	var K3: int = A.k3
	for c in g.get_children():
		if c is SubViewport and not c.has_meta("poster_k3") and c != g.room_vp:
			var sv := c as SubViewport
			sv.set_meta("poster_k3", K3)
			sv.set_meta("poster_base", sv.size)
			sv.size = sv.size * K3
			if sv.positional_shadow_atlas_size > 0:
				sv.positional_shadow_atlas_size = 8192
			if sv.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
				sv.render_target_update_mode = SubViewport.UPDATE_ONCE
			print("  grow ", sv.name, " -> ", sv.size)
			n += 1
	return n


#  다 찍은 화판은 본디 크기로 — 늘린 진열대를 찍기 전에 그래픽 메모리를 비운다.
func _shrink_vps() -> void:
	for c in g.get_children():
		if c is SubViewport and c.has_meta("poster_base"):
			(c as SubViewport).size = c.get_meta("poster_base")


func _save(img: Image, nm: String) -> void:
	var p := "%s/%s.png" % [OUT, nm]
	img.save_png(p)
	print("saved ", p, " ", img.get_size())


func _pass(nm: String, d: Dictionary) -> void:
	g.pp = d
	var img: Image = await _grab()
	_save(img, nm)


#  진열대 3D 화판에서 무엇을 보이나 — "" 전부 · "bare" 저울 · 등록기 빼고 · "Scale" · "Register" 그것만.
func _table_show(keep: String) -> void:
	var tr: Node3D = g.tbl3_vp.get_node_or_null("Table")
	for c in tr.get_children():
		if c is Light3D or c is Camera3D or c is WorldEnvironment or not (c is Node3D):
			continue
		var nm := String(c.name)
		var vis := true
		match keep:
			"bare":
				vis = nm != "Scale" and nm != "Register"
			"Scale", "Register":
				vis = nm == keep
		(c as Node3D).visible = vis


#  소품을 화면 안쪽으로 du 만큼 옮긴다 — 화면 끝에 잘린 몸(저울 왼 접시 · 등록기 오른 몸)을 다
#  담으려고. 소품을 비추는 스포트 · 웅덩이 빛도 같이 옮겨 빛이 그대로다. 직교 카메라라 가로로
#  옮긴 그림은 자리만 다르고 모양은 같다.
#  등록기는 매 틀 xf0 로 자세를 다시 세우므로(_reg_set) 그 값도 옮긴다.
func _prop_move(nm: String, du: float) -> void:
	var tr: Node3D = g.tbl3_vp.get_node_or_null("Table")
	var pn: Node3D = tr.get_node_or_null(nm)
	if pn == null:
		return
	pn.position.x += du
	if pn.has_meta("xf0"):
		var x0: Transform3D = pn.get_meta("xf0")
		x0.origin.x += du
		pn.set_meta("xf0", x0)
	var ln := "SellLamp" if nm == "Scale" else "BuyLamp"
	for l in [ln, ln + "Pool"]:
		var ll: Node3D = tr.get_node_or_null(l)
		if ll != null:
			ll.position.x += du


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await _wait(10)
	DisplayServer.window_set_size(Vector2i(640, 360))
	DirAccess.make_dir_recursive_absolute(OUT)
	if int(A.tables) == 1:
		await _tables_only()
		print("done(tables) ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
		quit(0)
		return
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(0.5)
	g.total = g.target
	g.darts_left = 0
	g.remaining.clear()
	g._finish_leg()
	for k in 600:
		if g.state == g.S.CLEAR:
			break
		_step(DT)
		g._swap_skip()
	g.clear_t = 99.0
	_step(0.2)
	g._clear_go()
	_step(2.5)
	g._tutor_close()
	g.tutor_q.clear()
	g.gold = 99
	#  필터는 끈다 — 층을 투명으로 나눠 찍으므로 화면 통째에 거는 브라운관 · VHS · 도트는
	#  층마다 따로 걸 수 없다. 결 · 어둠은 compose_shop.py 가 층으로 얹는다.
	g.crt = 0.0
	g.warp = 0.0
	g.vhs = 0.0
	g.dot = 0.0
	g._crt_apply()
	print("shop state ", g.state == g.S.SHOP)

	var items: Array = GameData.items()
	g.stock.clear()
	for e in PLAN:
		var d: Dictionary
		match String(e[0]):
			"item":
				d = _row(items, String(e[1]))
			"boost":
				d = _row(GameData.boosters(), String(e[1]))
			"cons":
				d = _row(GameData.candies(), String(e[1]))
			"fix":
				d = _row(GameData.fixtures(), String(e[1]))
			"dart":
				d = GameData.darts()[2]
		g.stock.append({"type": String(e[0]), "d": d, "cost": 4, "sold": false})
	g._drop_roll()
	_step(4.0)
	#  자리를 손으로 잡는다 — 물리가 흩어 놓은 자리 대신 PLAN 의 자리 · 방위로 눕힌다.
	for i in g.drop.size():
		var it: Dictionary = g.drop[i]
		var e: Array = PLAN[i]
		it.u = float(e[2])
		it.w = (float(e[3]) - float(g.TBL.fy)) / float(g.TBL.flat)
		it.h = 0.0
		it.psi = float(e[4])
		it.vu = 0.0
		it.vw = 0.0
		it.vh = 0.0
		it.om = 0.0
		it.wob = 0.0
		it.wv = 0.0
		it.air = false
		it.sleep = true
		it.lg = 0.0
	_step(0.5)
	for i in g.drop.size():
		var it: Dictionary = g.drop[i]
		print("drop ", i, " ", g.stock[i].type, " u ", snappedf(float(it.u), 0.1),
				" w ", snappedf(float(it.w), 0.1), " psi ", snappedf(float(it.psi), 0.01),
				" look ", g._pack_look(g.stock[i].d) if String(g.stock[i].type) == "boost" else "")

	#  건네기 — 0 번 동전을 상인이 집어 들고 살피는 한가운데에서 멈춘다.
	#  집는 자리(poster_grip)는 건네기 전에 세운다 — _give_fit 이 그 방향으로 깊이를 잰다.
	g.poster_grip = true
	g.poster_din = float(A.din)
	g.poster_tout = float(A.tout)
	g.poster_tlat = float(A.tlat)
	g.poster_tdrop = float(A.tdrop)
	g.poster_tfwd = float(A.tfwd)
	g.poster_ang = deg_to_rad(float(A.hang))
	var gi := 0
	var it0: Dictionary = g.drop[gi]
	g._give_begin(gi, Vector2(float(it0.u), float(g.TBL.fy)))
	var gv: Dictionary = g.GIVE
	var stop_t: float = float(gv.take) + float(gv.look) * float(A.look)
	for k in 2000:
		if not g._give_live() or g.give_t >= stop_t:
			break
		_step(DT)
	print("give_t ", g.give_t, " side ", g.give_side)

	g.poster_on = true
	g.poster_lift = float(A.lift)
	g.poster_fwd = float(A.fwd)
	g.poster_du = float(A.du)
	g.poster_rest_du = float(A.rest_du)
	g.poster_rest_dw = float(A.rest_dw)
	g.pp = {"bg": true, "room": true, "body": true, "table": true, "goods": true,
			"shadow": true, "hands": true}
	await _settle()
	var n := _grow_vps()
	print("grew ", n, " viewports x", A.k3)
	await _settle()
	n = _grow_vps()
	if n > 0:
		print("grew late ", n)
		await _settle()

	var all_on := {"room": true, "body": true, "table": true, "goods": true, "shadow": true,
			"hands": true, "bg": true}
	await _pass("shop_full", all_on)
	var quick: bool = int(A.quick) == 1
	if not quick:
		await _pass("shop_body", {"body": true})
		_table_show("Scale")
		_prop_move("Scale", float(A.scale_in))
		await _pass("shop_scale", {"table": true})
		_prop_move("Scale", -float(A.scale_in))
		_prop_move("Register", -float(A.reg_in))
		_table_show("Register")
		await _pass("shop_register", {"table": true})
		_prop_move("Register", float(A.reg_in))
		_table_show("")
	var others := []
	for i in g.drop.size():
		if i != g.give_i:
			others.append(i)
	await _pass("shop_gsh_held", {"gsh": [g.give_i]})
	var meta_goods := []
	for i in others:
		var e: Array = PLAN[i]
		var nm := "shop_g_%d" % i
		await _pass(nm, {"gi": i, "noglow": true})
		await _pass("shop_gs_%d" % i, {"gsh": [i]})
		var it: Dictionary = g.drop[i]
		var rar := ""
		if String(e[0]) == "item":
			rar = String(g.stock[i].d.get("rar", g.stock[i].d.get("rarity", "")))
		meta_goods.append({"i": i, "type": String(e[0]), "id": String(e[1]), "file": nm,
				"shadow": "shop_gs_%d" % i, "rar": rar,
				"x": float(it.u), "y": g._p2s(float(it.u), float(it.w), 0.0).y})
	await _pass("shop_hshadow", {"shadow": true})
	await _pass("shop_hglow", {"hglow": true})
	await _pass("shop_harm", {"harm": true})
	await _pass("shop_hcoin", {"hcoin": true})
	await _pass("shop_hfront", {"hfront": true})
	var ih: Dictionary = g.drop[g.give_i]
	var hc: Vector2 = g._p2s(float(ih.u), float(ih.w), float(ih.h) + float(ih.lift))
	var hs: Vector2 = g._p2s(float(ih.u), float(ih.w), 0.0)
	print("held at ", hc, " floor ", hs, " h ", ih.h)
	#  어깨 자리(논리 px) — compose 가 든 팔을 원근으로 키울 때 이 점을 붙박는다.
	var shs := []
	for i in 2:
		var sp: Vector3 = g._npc_shoulder(i, g._idle_body())
		var ss: Vector2 = g._p2s(sp.x, sp.y, sp.z)
		shs.append([ss.x, ss.y])
	var meta := {"k": A.k, "k3": A.k3, "args": A, "goods": meta_goods,
			"scale_in": A.scale_in, "reg_in": A.reg_in, "shoulders": shs,
			"held": {"id": held, "x": hc.x, "y": hc.y, "floor_y": hs.y, "h": float(ih.h),
					"wob": float(ih.get("wob", 0.0))},
			"give_side": g.give_side, "fy": float(g.TBL.fy), "ny": float(g.TBL.ny),
			"flat": float(g.TBL.flat), "tall": float(g.TBL.tall)}
	if quick:
		_write_meta(meta)
		print("done(quick) ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
		quit(0)
		return

	#  포스터용 방 — 게임 방과 같은 세계 · 같은 카메라 자리, 가로 시야(79.3°)를 지키고
	#  세로만 길게. 네온 글자는 끈다(제목이 간판을 맡는다).
	_shrink_vps()
	await _wait(4)
	await _room_tall()
	#  판형별 진열대 — 펠트를 앞으로 늘린 새 진열대.
	meta["tables"] = {}
	for spec in [["A", int(A.deep_a), int(A.tbl_k)], ["X", int(A.deep_x), int(A.tbl_kx)]]:
		meta.tables[spec[0]] = await _table_deep("shop_table_" + String(spec[0]), spec[1], spec[2])
	_write_meta(meta)
	print("done ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit(0)


#  진열대만 — 앞서 찍은 shop_meta.json 을 읽어 tables 만 갈아 적는다.
func _tables_only() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/shop_meta.json"))
	meta["args"]["deep_a"] = A.deep_a
	meta["args"]["deep_x"] = A.deep_x
	meta["tables"] = {}
	for spec in [["A", int(A.deep_a), int(A.tbl_k)], ["X", int(A.deep_x), int(A.tbl_kx)]]:
		meta.tables[spec[0]] = await _table_deep("shop_table_" + String(spec[0]), spec[1], spec[2])
	_write_meta(meta)


func _write_meta(meta: Dictionary) -> void:
	var f := FileAccess.open(OUT + "/shop_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()


func _room_tall() -> void:
	var rv: SubViewport = g.room_vp
	var rr: Node3D = rv.get_node_or_null("Room")
	var gc: Camera3D = rr.get_node_or_null("Cam")
	var neon: Node3D = rr.get_node_or_null("Neon")
	var nl: OmniLight3D = rr.get_node_or_null("NeonLight")
	var room_w: int = A.room_w
	var h := int(round(float(room_w) * 9.0 / 16.0 * float(A.room_h)))
	var tv := SubViewport.new()
	tv.size = Vector2i(room_w, h)
	tv.own_world_3d = false
	tv.world_3d = rv.find_world_3d()
	tv.transparent_bg = false
	tv.msaa_3d = Viewport.MSAA_4X
	tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tv)
	var cam := Camera3D.new()
	#  게임 카메라는 세로 시야 50° · 16:9 — 가로 시야로 옮겨 KEEP_WIDTH 로 잡는다.
	var hf := rad_to_deg(2.0 * atan(tan(deg_to_rad(gc.fov * 0.5)) * 16.0 / 9.0))
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = hf
	cam.near = gc.near
	cam.far = gc.far
	cam.position = Vector3(0.0, 1.5, 3.6)
	cam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	tv.add_child(cam)
	cam.make_current()
	#  네온 글자와 그 빛은 끈다 — 포스터에서는 제목이 간판이다(같은 말이 둘 서지 않게).
	if neon != null:
		neon.visible = false
	if nl != null:
		nl.visible = false
	_stack_shelves(rr, int(A.shelf_up))
	await _wait(8)
	await RenderingServer.frame_post_draw
	_save(tv.get_texture().get_image(), "shop_room_shelves")
	tv.queue_free()


#  벽을 선반 세 줄 묶음(1.44) n 벌만큼 위로 올린다(천장 · 들보 · 벽 · 판자 이음). 술병 선반은 —
#    가운데 묶음(x −2.3~2.3): 맨 윗줄(2.11)을 걷고 아래 두 줄(1.15 · 1.63)만 남긴다. 상인 머리
#    자리(제목 밑 · 몸통 위)가 술병으로 붐비지 않고, 다트판 · 제목이 깨끗한 판자 벽에 걸린다.
#    양옆: 한 벌씩 더 깐다(X배너 · A 의 끝에 조금 걸친다 — 벽이 가운데만 술병이면 무대 세트로 읽힌다).
#  옆 선반이 벽의 다트판 자리를 덮는다 — 게임 벽 다트판과 그 뒤판은 숨긴다(포스터는 큰 판을 따로 건다).
func _stack_shelves(rr: Node3D, n: int) -> void:
	var step := 0.48 * 3.0
	var src := []
	var top_row := []
	for c in rr.get_children():
		if c is Node3D:
			var p: Vector3 = (c as Node3D).position
			if p.z >= -2.4 and p.z <= -2.0 and p.y >= 1.0 and p.y <= 2.6 and absf(p.x) <= 2.4:
				src.append(c)
				if p.y >= 1.95:
					top_row.append(c)
	print("shelf parts ", src.size(), " top row ", top_row.size())
	for side in [-1, 1]:
		for c in src:
			var cp: Node3D = (c as Node3D).duplicate()
			if absi(side) % 2 == 1:
				cp.position.x = -cp.position.x
			cp.position.x += 4.8 * float(side)
			rr.add_child(cp)
	for c in top_row:
		(c as Node3D).visible = false
	for c in rr.get_children():
		if c is MeshInstance3D and absf((c as Node3D).position.x - 3.05) < 0.01:
			(c as Node3D).visible = false
	var up := step * float(n)
	for c in rr.get_children():
		if not (c is MeshInstance3D and c.mesh is BoxMesh):
			continue
		var mi := c as MeshInstance3D
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		if is_equal_approx(sz.y, 0.2) and is_equal_approx(sz.z, 8.0) and mi.position.y > 3.0:
			mi.position.y += up                       # 천장
		elif is_equal_approx(sz.y, 0.16) and is_equal_approx(sz.z, 6.0):
			mi.position.y += up                       # 들보
		elif is_equal_approx(sz.y, 5.0):
			#  벽 · 판자 이음 — 밑(−0.5)은 그대로, 위를 천장까지
			var top := 4.5 + up
			mi.scale.y = (top + 0.5) / 5.0
			mi.position.y = (top - 0.5) * 0.5


#  펠트를 앞으로 늘린 진열대 — 게임과 같은 Room3D.make_table 로 새로 짓되 가까운 모서리(ny)만
#  dy 논리 px 내린다. 먼 턱 · 벨벳 먼 끝은 게임과 한 점도 안 다르다(같은 카메라 식 · fy 그대로)
#  — 손 · 몸통 · 물건 층이 그대로 얹힌다. 화판은 화면 y 44 부터 앞판 밑 ext 까지.
#  저울 · 등록기는 숨긴다. 머리 위 램프는 게임 자리(게임 벨벳 깊이의 한가운데)로 되돌린다 — 늘린
#  깊이의 한가운데로 가면 손 · 동전 자리 빛이 손 층(게임 램프)과 갈린다. 늘린 앞쪽에는 약한
#  채움 램프 하나(앞 물건이 놓일 자리가 죽은 어둠이 안 되게).
func _table_deep(nm: String, dy: int, kk: int) -> Dictionary:
	var fy: float = float(g.TBL.fy)
	var ny: float = float(g.TBL.ny) + float(dy)
	var ext := 90.0                                   # 가까운 난간 밑으로 보일 앞판 논리 px
	var r := Rect2(0.0, fy - 84.0, 640.0, ny - fy + 84.0 + ext)
	var host := Node.new()
	root.add_child(host)
	var tv: SubViewport = Room3D.make_table(host, r, fy, ny, float(g.CHUTE.back),
			float(g.TBL.flat), float(g.TBL.tall), float(g.HAND3.pitch))
	var tr: Node3D = tv.get_node_or_null("Table")
	var W0: float = (float(g.TBL.ny) - fy) / float(g.TBL.flat)
	var W1: float = (ny - fy) / float(g.TBL.flat)
	for c in tr.get_children():
		var nn := String(c.name)
		if nn == "Scale" or nn == "Register":
			(c as Node3D).visible = false
		if c is SpotLight3D and is_equal_approx((c as SpotLight3D).spot_angle, 38.0):
			(c as SpotLight3D).position.z = W0 * 0.5
	if dy > 0:
		var fl := SpotLight3D.new()
		fl.light_color = Color("ffd9a8")
		fl.light_energy = 3.2
		fl.spot_range = 1200.0
		fl.spot_attenuation = 0.2
		fl.spot_angle = 34.0
		fl.spot_angle_attenuation = 2.4
		fl.shadow_enabled = false
		fl.position = Vector3(320.0, 360.0, lerpf(W0, W1, 0.55))
		fl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		tr.add_child(fl)
	tv.positional_shadow_atlas_size = 8192
	tv.msaa_3d = Viewport.MSAA_4X
	tv.size = Vector2i(int(r.size.x) * kk, int(r.size.y) * kk)
	await _wait(10)
	await RenderingServer.frame_post_draw
	_save(tv.get_texture().get_image(), nm)
	tv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tv.size = Vector2i(2, 2)
	host.queue_free()
	await _wait(2)
	return {"file": nm, "k": kk, "top": r.position.y, "h": r.size.y, "ny": ny, "dy": dy,
			"rail": ny - 6.0}
