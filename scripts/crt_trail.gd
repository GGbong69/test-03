extends Node
#  CRT 잔상 — 앞 틀을 붙들어 둔다 (2026-10-04)
#  「움직일 때 남는 잔상」(사용자가 고른 방향). 셰이더(shaders/crt.gdshader ⑨)는 지금 화소와
#  앞 틀 × 남는 몫 중 밝은 쪽을 낸다. 그 앞 틀(prev)을 여기서 넣는다.
#
#  ── SubViewport 없이 ───────────────────────────────────
#  한 틀이 다 그려진 뒤(frame_post_draw) 루트 화면의 렌더 타깃을 GPU 안에서 제
#  텍스처 하나로 **복사**할 뿐이다 — 화면 크기 한 장을 한 번(4K 면 33MB 를 GPU 안에서
#  옮긴다). 다시 그리는 것이 없고, CPU 로 읽어 오지도 않는다.
#  복사본은 CRT 층까지 다 그린 화면이다. 주사선 · 마스크 · 테가 화소마다 제자리라
#  앞 틀과 지금이 같은 결을 쓰므로, 셰이더의 max 가 그대로 형광체가 식는 꼴이 된다.
#
#  ── 안 할 때 ────────────────────────────────────────────
#  렌더링 디바이스가 없는 렌더러(호환 · 헤드리스)면 아무것도 안 한다. 층이 꺼졌거나 ·
#  세기 0 · 모션 끄기면 복사를 쉬고 prev 를 비운다(검정) — 다시 켠 첫 틀이 오래된
#  화면을 잔상으로 띄우지 않는다. 비운 뒤 첫 복사가 끝난 틀부터 다시 넣는다.
#
#  ── 스레드 ──────────────────────────────────────────────
#  복사(_copy)는 렌더 스레드에서 돈다. 겉(t2)과 셰이더 prev 는 **메인 스레드만** 만진다 —
#  렌더 스레드는 창이 바뀌어 새로 판 텍스처를 hand 에 놓기만 하고, 다음 틀의 _grab 이
#  그것을 겉에 잇고 옛것을 렌더 스레드에 돌려보내 푼다(한 틀 늦게 새 크기로 넘어간다).
#  렌더를 따로 돌리는 thread_model 에서는 err 도 한 틀 늦은 값이다.
#
#  붙이는 법(game.gd 의 _crt_open — CRT 층 아래 「CrtTrail」):
#      var tr = preload("res://scripts/crt_trail.gd").new()
#      tr.name = "CrtTrail"; tr.mat = mat; tr.layer = crt_layer; crt_layer.add_child(tr)
var mat: ShaderMaterial = null
var layer: CanvasLayer = null
var rd: RenderingDevice = null
var tex := RID()                 # 겉에 이어진 복사본(메인 스레드)
var t2: Texture2DRD = null       # 셰이더에 넘기는 겉
var held := false                # prev 에 지금 복사본이 앉아 있나
var last_us := 0
var err := OK                    # 마지막 복사의 결과(도구가 읽는다)
#  렌더 스레드 몫 — r_tex 에 복사한다. 새로 팠으면 hand 에 놓는다(lk 로 건넨다).
var r_tex := RID()
var r_sz := Vector2i.ZERO
var hand := RID()
var lk := Mutex.new()


func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	t2 = Texture2DRD.new()
	RenderingServer.frame_post_draw.connect(_grab)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_grab):
		RenderingServer.frame_post_draw.disconnect(_grab)
	_let_go()
	if t2 != null:
		t2.texture_rd_rid = RID()
	if rd != null:
		#  남은 복사 뒤에 줄을 서서 푼다 — 렌더 스레드 몫은 거기서만 만진다.
		RenderingServer.call_on_render_thread(_drop.bind(tex))
	tex = RID()


#  렌더 스레드에서 — 겉에서 뗀 것과 렌더 스레드 몫을 다 푼다. 다시 붙으면 새로 판다.
func _drop(was: RID) -> void:
	lk.lock()
	var hd := hand
	hand = RID()
	lk.unlock()
	for r in [was, hd, r_tex]:
		if (r as RID).is_valid() and rd.texture_is_valid(r):
			rd.free_rid(r)
	r_tex = RID()
	r_sz = Vector2i.ZERO


func _let_go() -> void:
	if held and mat != null:
		mat.set_shader_parameter("prev", null)
	held = false


func _live() -> bool:
	if mat == null or (layer != null and not layer.visible):
		return false
	return float(mat.get_shader_parameter("motion")) > 0.5 \
			and float(mat.get_shader_parameter("strength")) > 0.0


#  한 틀이 다 그려졌다 — 그 화면을 복사본에 옮기고, 다음 틀이 그것을 prev 로 읽는다.
func _grab() -> void:
	if not _live():
		_let_go()
		return
	#  앞 틀에 렌더 스레드가 새로 판 것을 겉에 잇는다 — 옛것은 렌더 스레드가 푼다.
	lk.lock()
	var nt := hand
	hand = RID()
	lk.unlock()
	if nt.is_valid():
		var was := tex
		tex = nt
		t2.texture_rd_rid = tex
		if was.is_valid() and was != tex:
			RenderingServer.call_on_render_thread(_free.bind(was))
	var src := RenderingServer.texture_get_rd_texture(get_viewport().get_texture().get_rid())
	if not src.is_valid():
		_let_go()
		return
	RenderingServer.call_on_render_thread(_copy.bind(src))
	if not tex.is_valid() or err != OK:
		#  아직 이은 것이 없다(첫 틀 · 새 크기를 판 틀) — 다음 틀부터 넣는다.
		_let_go()
		return
	#  틀 사이 시간 — 몫을 그만큼 거듭제곱한다(셰이더 trail_dt).
	var now := Time.get_ticks_usec()
	var dt: float = 1.0 if last_us == 0 else float(now - last_us) / 16666.7
	last_us = now
	mat.set_shader_parameter("trail_dt", clampf(dt, 0.25, 4.0))
	if not held:
		mat.set_shader_parameter("prev", t2)
		held = true


func _free(r: RID) -> void:
	if rd.texture_is_valid(r):
		rd.free_rid(r)


#  렌더 스레드에서 — 크기는 렌더 타깃 그 자체에서 읽는다(창 크기 · 뷰포트 크기는
#  스트레치 · 화면 배율에 따라 렌더 타깃과 다를 수 있다).
func _copy(src: RID) -> void:
	if not rd.texture_is_valid(src):
		err = ERR_INVALID_PARAMETER
		return
	var sf: RDTextureFormat = rd.texture_get_format(src)
	var sz := Vector2i(int(sf.width), int(sf.height))
	if sz != r_sz or not r_tex.is_valid():
		var f := RDTextureFormat.new()
		f.format = sf.format
		f.width = sz.x
		f.height = sz.y
		f.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
				| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		var nt := rd.texture_create(f, RDTextureView.new())
		if not nt.is_valid():
			err = ERR_CANT_CREATE
			return
		#  겉에 아직 안 이은 것(한 틀에 창이 두 번 바뀜)은 여기서 바로 푼다 — 아무도 안 본다.
		lk.lock()
		var old := hand
		hand = nt
		lk.unlock()
		if old.is_valid():
			rd.free_rid(old)
		#  앞 r_tex 는 겉에 이어져 있을 수 있다 — 메인 스레드가 떼고 _free 로 돌려보낸다.
		r_tex = nt
		r_sz = sz
	err = rd.texture_copy(src, r_tex, Vector3.ZERO, Vector3.ZERO, Vector3(sz.x, sz.y, 1),
			0, 0, 0, 0)
