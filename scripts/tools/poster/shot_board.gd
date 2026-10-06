extends SceneTree
#  포스터 「다트판 정면」(key=board) 원화 — 던지기 화면의 다트판을 층마다 인쇄 해상도로 (2026-10-06).
#  어두운 판자 벽(WALL3 — wall3d.gd 세트) · 판 · 꽂힌 다트 · 다트 그림자 · 앞 다트를 **따로** 굽는다.
#  HUD · 안내 글 · 게임 꽂이는 안 그린다(board_layers.gd 가 게임의 _draw 를 층 하나로 갈아 끼운다).
#  다트는 포스터 자루(dart_clean.gd)로 갈아 끼우고 무대 빛을 벽 램프에 맞춘다.
#
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/poster/shot_board.gd -- [k=16] [wk=14] [eye=230] [only=wall|board|darts|shadow|fore]
#  결과(outputs/poster/board/render/):
#    wall.png        벽 — 램프 하나의 빛 웅덩이 · 고무 링 · 받침판(불투명). 한가운데가 판 한가운데(BC)
#    board.png       판(투명 바탕) — 그림자 · 두께 · 칸 · 철사 · 숫자 · 빛
#    darts.png       꽂힌 다트(투명)
#    shadow_on.png   다트 그림자 패스 — 흰 판 평면 위에 그림자만 드리운 자루(자루는 안 보인다)
#    shadow_off.png  같은 평면 · 자루 없음. compose_board.py 가 on/off 몫을 shadow.png 로 굳힌다
#    fore.png        앞 다트(투명) — 꽁지 뒤 위에서 본 한 자루, 촉이 판 쪽(위)으로. X배너 아래쪽
#    meta.json       배율 · 크기 · 판 치수(논리 px) — compose_board.py 가 읽는다(한 갈래만 찍어도 합쳐 적는다)
#  판 · 다트 층은 BC 를 한가운데에 둔 REG x REG 논리 px 를 k 배로, 벽은 WALL_L 을 wk 배로 굽는다.
const Save = preload("res://scripts/save.gd")
const Wall3D = preload("res://scripts/wall3d.gd")
const DartClean = preload("res://scripts/tools/poster/dart_clean.gd")
const LAYERS = "res://scripts/tools/poster/board_layers.gd"
const DT := 1.0 / 120.0
const OUT := "res://outputs/poster/board/render"
const REG := 320.0                     # 판 · 다트 층이 덮는 정사각(논리 px) — 가운데가 BC
const WALL_L := Vector2(360.0, 840.0)  # 벽이 덮는 논리 크기 — 가운데가 BC
const LAMP_ROT := Vector3(-32.0, -12.0, 0.0)   # 램프 빛(도) — 위 앞에서 판으로. 그림자는 촉 아래로 진다
const SH_ANG := 0.8                    # 그림자 반그늘 — 램프 갓의 겉보기 크기(도)
const FORE_PX := Vector2i(2400, 3600)  # 앞 다트 층(기기 px)


var g = null
var vp: SubViewport = null
var busy := false
var k := 16
var wk := 14
var only := ""
var eye := 230.0             # 꽂힌 다트를 보는 눈 거리(논리 px) — _bd3_fit
var meta := {}
#  앞 다트 — 인자로 바꿔 볼 수 있다(fe= fb= fu= fr= ff= fl=x,y,z)
var fore_elev := 14.0        # 앞 다트가 판 쪽으로 드는 각(도)
var fore_back := 70.0        # 눈이 꽁지 뒤로 물러난 거리(논리 px)
var fore_up := 58.0          # 눈이 자루 축 위로 뜬 거리(논리 px)
var fore_roll := 22.0        # 자루 둘레로 날개를 돌린 각(도) — 십자가 아니라 엇 X
var fore_fov := 36.0
var fore_light := Vector3(0.62, -0.62, 0.30)   # 앞 다트에 닿는 램프 빛(나아가는 쪽)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"k": k = int(kv[1])
			"wk": wk = int(kv[1])
			"only": only = kv[1]
			"eye": eye = float(kv[1])
			"fe": fore_elev = float(kv[1])
			"fb": fore_back = float(kv[1])
			"fu": fore_up = float(kv[1])
			"fr": fore_roll = float(kv[1])
			"ff": fore_fov = float(kv[1])
			"fl": fore_light = str_to_var("Vector3(" + kv[1] + ")")
	Save.gpath = "user://_poster_board_g.cfg"
	Save.path = "user://_poster_board.cfg"
	Save.wipe()
	vp = SubViewport.new()
	vp.size = Vector2i(int(REG) * k, int(REG) * k)
	vp.size_2d_override = Vector2i(int(REG), int(REG))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	root.add_child(vp)
	g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load(LAYERS))
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


func _calm() -> void:
	g.idle_act = -1
	g.idle_wait = 99.0
	g.npc_eye = 0.0
	g.mouse_at = Vector2(-50.0, -50.0)
	g._tutor_close()
	g.tutor_q.clear()


func _step(sec: float) -> void:
	for _k in int(ceil(sec / DT)):
		_calm()
		g._process(DT)


func _save(img: Image, nm: String) -> void:
	var p := "%s/%s.png" % [OUT, nm]
	img.save_png(p)
	print("  %s %s" % [nm, str(img.get_size())])


#  판 · 다트 층 — 그리기 층을 고르고 열두 틀을 넘긴 뒤 찍는다.
func _cap(layer: String, nm: String) -> void:
	g.poster_layer = layer
	for _k in 12:
		_calm()
		g._process(0.0)
		g.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	_save(vp.get_texture().get_image(), nm)
	meta[nm] = {"k": k, "reg": REG}


#  3D 다트 무대를 판 둘레 reg x reg 로 좁히고 kk 배로 키운다 — 카메라 축은 BC 그대로,
#  판 평면(z 0)에서 월드 1 = 논리 1px 도 그대로다(시야각만 맞춘다).
#  dist > 0 이면 눈을 판에 그만큼 다가 세운다 — 게임의 눈(_bd3_eye 322)은 실물 던지는 줄이라
#  자루가 판 위에서 짧게 뭉친다. 포스터는 한 걸음 다가가 자루 옆구리가 읽히게 한다.
func _bd3_fit(reg: float, kk: int, dist := 0.0) -> void:
	if not g._bd3_live():
		return
	var bvp: SubViewport = g.bd_vp
	bvp.size = Vector2i(int(reg) * kk, int(reg) * kk)
	bvp.msaa_3d = Viewport.MSAA_4X
	var d: float = dist if dist > 0.0 else g._bd3_eye()
	for c in bvp.get_children():
		if c is Camera3D:
			var cam := c as Camera3D
			cam.position = Vector3(0.0, 0.0, d)
			cam.fov = rad_to_deg(2.0 * atan(reg * 0.5 / d))
	bvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bc: Vector2 = g.BC
	g.poster_bd3_rect = Rect2(bc - Vector2(reg, reg) * 0.5, Vector2(reg, reg))


#  꽂힌 다트를 포스터 자루(dart_clean.gd)로 갈고, 무대 빛을 벽 램프 쪽으로 — 위 앞에서 내리는
#  따뜻한 빛 하나 · 낮은 환경광. 게임 무대는 왼쪽 위 흰빛 + 밝은 회보라 환경광(평평하다)이다.
func _bd3_poster_look() -> void:
	if not g._bd3_live():
		return
	var dl: float = float(g.BD3.len) * 0.5
	for n in g.bd_nodes:
		if not is_instance_valid(n):
			continue
		for c in n.get_children():
			n.remove_child(c)
			c.free()
		n.add_child(DartClean.build(dl, g._dart3_col("std")))
	for c in g.bd_vp.get_children():
		if c is DirectionalLight3D:
			_lamp_light(c as DirectionalLight3D)
		elif c is WorldEnvironment:
			_lamp_env((c as WorldEnvironment).environment)


func _lamp_light(lt: DirectionalLight3D) -> void:
	lt.light_color = Color("ffd9a0")
	lt.light_energy = 1.35
	lt.rotation_degrees = LAMP_ROT


func _lamp_env(env: Environment) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffd9a0")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC


#  벽 — wall3d.gd 의 세트를 그대로 짓고 크게 굽는다(램프 켬 · 판 자리 있음).
func _wall() -> void:
	var host := Node.new()
	host.name = "PosterWallHost"
	root.add_child(host)
	var wv: SubViewport = Wall3D.make_wall(host)
	#  판자 한 장은 판 위 1.0m · 아래 0.9m 까지다 — 위아래로 한 장씩 이어 붙인다(같은 판자라
	#  세로 이음이 그대로 이어지고 가로 이음 하나가 더 생길 뿐이다). X배너의 아래(앞 다트 자리)까지 덮는다.
	var pil: MeshInstance3D = wv.get_node_or_null("Wall/Pillar") as MeshInstance3D
	if pil != null:
		var ph: float = (pil.mesh as QuadMesh).size.y
		for sy in [-1.0, 1.0]:
			var q := pil.duplicate() as MeshInstance3D
			q.name = "PillarX%d" % int(sy)
			q.position = pil.position + Vector3(0.0, ph * sy, 0.0)
			pil.get_parent().add_child(q)
	var bc: Vector2 = g.BC
	var pad := WALL_L * 0.5 - bc - Vector2(Wall3D.MARGIN, Wall3D.MARGIN)
	var ro: float = g._wall3_ro()
	var px: Vector2i = Wall3D.wall_fit(wv, pad, ro, bc, float(wk))
	wv.msaa_3d = Viewport.MSAA_4X
	Wall3D.lamp_on(wv, true)
	wv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _k in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = wv.get_texture().get_image()
	_save(img, "wall")
	meta["wall"] = {"k": wk, "px": [px.x, px.y], "logical": [float(px.x) / wk, float(px.y) / wk]}
	wv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	wv.size = Vector2i(2, 2)
	host.queue_free()


#  bd_vp 를 그대로 한 장 — 판 층 캔버스를 거치지 않는다(그림자 패스는 불투명 평면이다).
func _grab_bd(nm: String) -> void:
	var bvp: SubViewport = g.bd_vp
	bvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	_save(bvp.get_texture().get_image(), nm)


func _dart_meshes(cb: Callable) -> void:
	for n in g.bd_nodes:
		if not is_instance_valid(n):
			continue
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false):
			cb.call(mi)


#  다트 그림자 — 판 자리(z 0)에 흰 무광 평면을 깔고 램프에 그림자를 켠다.
#  ① 자루를 그림자만 드리우게(SHADOWS_ONLY) 한 장 ② 자루를 숨기고 한 장. ①/② 가 곧 그림자 몫이다
#  (환경광을 꺼서 몫이 0 그림자 · 1 빛으로 떨어진다). 반그늘은 램프 갓 크기(SH_ANG)가 낸다 —
#  촉에 붙은 곳은 칼같고 꽁지 쪽으로 갈수록 번진다.
func _shadow() -> void:
	if not g._bd3_live():
		return
	var bvp: SubViewport = g.bd_vp
	RenderingServer.directional_shadow_atlas_set_size(16384, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(REG * 1.6, REG * 1.6)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color.WHITE
	pmat.roughness = 1.0
	pmat.metallic_specular = 0.0
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := MeshInstance3D.new()
	plane.mesh = pm
	plane.material_override = pmat
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bvp.add_child(plane)
	var lt: DirectionalLight3D = null
	var env: Environment = null
	for c in bvp.get_children():
		if c is DirectionalLight3D:
			lt = c
		elif c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
	var keep := [lt.light_color, lt.light_energy, env.ambient_light_energy, env.tonemap_mode]
	lt.light_color = Color.WHITE
	lt.light_energy = 0.55
	lt.shadow_enabled = true
	lt.light_angular_distance = SH_ANG
	lt.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	lt.directional_shadow_max_distance = eye * 2.0
	lt.shadow_bias = 0.02
	lt.shadow_normal_bias = 0.2
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_dart_meshes(func(mi): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	await _grab_bd("shadow_on")
	for n in g.bd_nodes:
		if is_instance_valid(n):
			n.visible = false
	await _grab_bd("shadow_off")
	for n in g.bd_nodes:
		if is_instance_valid(n):
			n.visible = true
	_dart_meshes(func(mi): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	plane.queue_free()
	lt.shadow_enabled = false
	lt.light_color = keep[0]
	lt.light_energy = keep[1]
	env.ambient_light_energy = keep[2]
	env.tonemap_mode = keep[3]
	meta["shadow"] = {"k": k, "reg": REG, "lamp": [LAMP_ROT.x, LAMP_ROT.y], "ang": SH_ANG}


#  앞 다트 — X배너 아래, 보는 사람 손 앞에 든 한 자루. 꽁지 뒤 조금 위에서 자루 축을 따라 보아
#  날개는 크게 · 촉은 작게 판 쪽(위)으로 모인다. 빛은 판 위 램프 — 앞 다트에게는 **뒤에서** 오는
#  빛이라 날개 등은 그늘이고 윗가장자리만 빛을 받는다. compose_board.py 가 더 누르고 흐린다(심도).
func _fore() -> void:
	var fv := SubViewport.new()
	fv.size = FORE_PX
	fv.own_world_3d = true
	fv.transparent_bg = true
	fv.msaa_3d = Viewport.MSAA_4X
	fv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(fv)
	var dl: float = float(g.BD3.len) * 0.5
	var e := deg_to_rad(fore_elev)
	var u := Vector3(0.0, -sin(e), cos(e))        # 촉 → 꽁지(눈 쪽 · 아래)
	var w := Vector3(0.0, cos(e), sin(e))         # u 에 수직 · 위
	var bx := Vector3.RIGHT
	var bs := Basis(bx, u, bx.cross(u)) * Basis(Vector3.UP, deg_to_rad(fore_roll))
	var n := Node3D.new()
	n.add_child(DartClean.build(dl, g._dart3_col("std")))
	n.transform = Transform3D(bs, Vector3.ZERO)
	fv.add_child(n)
	var tail := u * dl
	var tip := -u * dl
	var cam := Camera3D.new()
	cam.fov = fore_fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 1000.0
	fv.add_child(cam)
	cam.look_at_from_position(tail + u * fore_back + w * fore_up, tip.lerp(tail, 0.45), Vector3.UP)
	var lt := DirectionalLight3D.new()
	_lamp_light(lt)
	fv.add_child(lt)
	#  판 위 램프에서 눈 쪽으로 · 아래로 — 앞 다트에게는 맞은편 위에서 오는 빛
	lt.basis = Basis.looking_at(fore_light.normalized(), Vector3.UP)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	_lamp_env(env)
	env.ambient_light_energy = 0.22
	we.environment = env
	fv.add_child(we)
	for _k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	_save(fv.get_texture().get_image(), "fore")
	var pt := cam.unproject_position(tip)
	var pl := cam.unproject_position(tail)
	meta["fore"] = {"px": [FORE_PX.x, FORE_PX.y], "tip": [pt.x, pt.y], "tail": [pl.x, pl.y],
			"elev": fore_elev, "back": fore_back, "up": fore_up, "roll": fore_roll}
	fv.queue_free()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(640, 360))
	DirAccess.make_dir_recursive_absolute(OUT)
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_aim",
			"u_pick", "u_throw", "u_more", "u_info", "u_last"]:
		Save.teach(id)
	g.set_process(false)
	g.motion_off = true
	g.wall3_on = false          # 벽은 _wall 이 따로 굽는다
	g.crt = 0.0
	g.warp = 0.0
	g.vhs = 0.0
	g.dot = 0.0
	g._crt_apply()
	g.legb_force = true
	g._new_run(true)
	_step(1.5)
	await _wait(4)
	#  판 고르기 → 판(PICK) — 판 갈이는 건너뛴다
	g._swap_skip()
	g.leg_skipped = {}
	g.leg_no = 1
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	_step(1.6)
	g.legb_force = false
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(1.2)
	g.grip_t = 9.0
	g.state = g.S.PICK
	g.grip_pick = -1
	g.board_punch = 0.0
	g.hit_flash = 0.0

	#  판 한가운데를 층 한가운데로 — 층 0 만 따라온다(CanvasLayer 는 안 그린다)
	var bc: Vector2 = g.BC
	vp.canvas_transform = Transform2D(0.0, Vector2(REG * 0.5, REG * 0.5) - bc)
	var r: float = g.R
	if FileAccess.file_exists(OUT + "/meta.json"):
		var old = JSON.parse_string(FileAccess.get_file_as_string(OUT + "/meta.json"))
		if old is Dictionary:
			meta = old
	meta["bc"] = [bc.x, bc.y]
	meta["R"] = r
	meta["ro"] = g._wall3_ro()
	meta["ring"] = Wall3D.RING

	if only == "" or only == "wall":
		await _wall()

	if only == "" or only == "board":
		g.darts = []
		await _cap("board", "board")

	#  꽂힌 다트 — 이너 불 하나 · 트리플 20 · 싱글 18. 촉 자리(논리 px, BC 기준)
	var ds := [
		{"p": bc + Vector2(0.6, -0.8), "id": "std", "rot": 0.28},
		{"p": bc + Vector2(-2.8, -r * 0.61), "id": "std", "rot": -0.10},
		{"p": bc + Vector2(sin(deg_to_rad(31.0)), -cos(deg_to_rad(31.0))) * r * 0.80, "id": "std", "rot": 0.16},
	]
	meta["dart_tips"] = []
	for e in ds:
		meta["dart_tips"].append([e.p.x - bc.x, e.p.y - bc.y])
	if only in ["", "darts", "shadow"]:
		g.darts = ds
		g.poster_layer = "darts"
		g.queue_redraw()
		await _wait(3)
		_bd3_fit(REG, k, eye)
		_bd3_poster_look()
		meta["eye"] = eye
		await _cap("darts", "darts")
		if only != "darts":
			g.poster_layer = "none"
			g.queue_redraw()
			await _shadow()

	#  앞 다트 — X배너 아래
	if only == "" or only == "fore":
		await _fore()

	var f := FileAccess.open(OUT + "/meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	g.poster_layer = "none"
	await _wait(2)
	print("찍었다 — ", OUT)
	quit(0)
