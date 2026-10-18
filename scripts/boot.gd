extends Node
# ══════════════════════════════════════════════════════════
#  도트 화판 — 게임을 논리 격자에 그린다 (2026-10-18)
# ──────────────────────────────────────────────────────────
#  「퍼펙트 픽셀 … 해볼수 있어?」 · 「게임만 도트 · CRT는 그대로」(사용자). canvas_items 스트레치라
#  판의 띠 · 선 · 원 · 돌아가는 병이 창 해상도(1280 이면 기기 1px 계단)로 그려져, 3D 무대 · 그림 ·
#  글자(2026-10-11 「글자도 도트로」 — 이미 1배 격자)의 논리 도트와 한 화면에서 크기가 갈렸다.
#  그래서 게임 장면(main.tscn)을 논리 크기의 SubViewport 에 넣고 nearest 로 정수배 늘린다.
#  CRT · VHS · 도트 팔레트 층은 **기기 픽셀로 돈다**(셰이더 머리말) — 화판에 넣으면 주사선이 사라지고
#  번졌다(촬영 · shots/pixel_perfect_cmp.png). 그 셋만 이 노드(바깥 · 창 해상도) 밑에 단다
#  (game.gd screen_host).
#  ── 배율은 화판이 쥔다 ──────────────────────────────────
#  창의 스트레치는 끈다(기기 1px = 캔버스 1). 배율 k 는 창 ÷ 640×360 의 내림(1 이상)이고, 화판은
#  창 ÷ k 의 내림만큼 **넓어진다** — 남는 자리는 게임이 논리 여백(view_pad)으로 받아 방 · HUD 가
#  화면 끝까지 간다(옛 expand 와 같다). 엔진의 정수 스트레치는 화판을 640×360 에 묶고 나머지를
#  검게 남겼다 — 1600×900 이면 좌우 160 · 위아래 90 기기 px. 이제 검은 테는 많아야 k − 1 px 이다.
#  검사 · 촬영 도구는 main.tscn 을 바로 연다 — 이 화판을 안 지나 예전과 같다(scripts/tools/qa_pxbox.gd 가
#  이 화판을 잰다).
const MAIN := "res://scenes/main.tscn"
const VIEW := Vector2(640.0, 360.0)     # game.gd VIEW 와 같다 — 논리 화면의 바닥 크기

var game: Node = null
var box: SubViewportContainer = null


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	box = SubViewportContainer.new()
	box.name = "Px"
	box.stretch = true
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := SubViewport.new()
	vp.name = "PxVp"
	box.add_child(vp)
	add_child(box)
	win.size_changed.connect(_fit)
	_fit()
	game = (load(MAIN) as PackedScene).instantiate()
	game.set("screen_host", self)
	vp.add_child(game)


#  배율 · 화판 크기를 창에 맞춘다. 창을 내리면 크기가 0 으로 들어온다 — 그때는 지난 값을 둔다.
func _fit() -> void:
	var ws := Vector2(get_window().size)
	if ws.x < 1.0 or ws.y < 1.0:
		return
	var k: int = maxi(1, int(floor(minf(ws.x / VIEW.x, ws.y / VIEW.y))))
	var l: Vector2 = (ws / float(k)).floor()
	box.stretch_shrink = k
	box.position = ((ws - l * float(k)) * 0.5).floor()
	box.size = l * float(k)
