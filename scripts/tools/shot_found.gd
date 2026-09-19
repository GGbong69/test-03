extends SceneTree
# 못 본 칸의 컬렉션을 찍는다 — 물음표 원반 · 이름 ??? · 탭의 「0/N」.
#  shot_collect_all 의 짝이다. 그쪽은 **전부 발견**으로 찍고 이쪽은 **전부
#  미발견**으로 찍는다 — 잠긴 화면은 도구 없이는 개발자 판을 눌러야만
#  보이는데, 그러면 사람이 볼 때마다 프로필을 지워야 한다.
#
#   godot --path . --quit-after 900 --script scripts/tools/shot_found.gd
#   → shots/found_<탭>.png · found_tip.png (못 본 칸의 설명창)
#
#  ⚠ 제 자리(user://_shot_fd.cfg)에서 돈다 — 사람의 저장을 안 만진다.
#  2026-09-19
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_fd_g.cfg"
	Save.path = "user://_shot_fd.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _tick(n: int) -> void:
	for f in n:
		g.rar_t = 0.0          # 등급 맥동을 못박는다 — 쪽마다 번짐이 달라지면 못 견준다
		g.queue_redraw()
		await process_frame


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	#  대역이 아니라 **진짜로 비운다** — 대역(found_all)은 켜는 쪽만 있다.
	g._dev_unlock_none()
	g.state = g.S.COLLECT
	g.collect_page = 0
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.mouse_at = Vector2(-50.0, -50.0)
		await _tick(4)
		root.get_texture().get_image().save_png("res://shots/found_%d.png" % t)

	#  못 본 칸의 설명창 — 제목 ??? · 태그 한 장 · 본문 0줄.
	#  게임의 제 프레임을 끈다 — 안 끄면 _tip_update 가 다음 프레임에 페이드를
	#  0 으로 되돌려 빈 화면이 찍힌다(shot_tips 가 매 프레임 다시 박는 그 까닭).
	g.collect_tab = 0
	var c: Vector2 = (g._col_cell(9) as Rect2).get_center()
	g.set_process(false)
	g.mouse_at = c
	g._tip_build(g._tip_hit(c))
	g.tip_a = 1.0
	for f in 4:
		g.queue_redraw()
		var fr = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/found_tip.png")
	print("  찍음 — 탭 %d + 설명창" % g.COL_TABS.size())
	quit(0)
