extends "res://scripts/game.gd"
#  포스터 「다트판 정면」(board) 의 그리기 층 고르기 (2026-10-06).
#  게임을 그대로 돌리되 _draw 만 갈아 끼워 한 층씩 투명 바탕에 그린다 —
#  HUD · 안내 글 · 툴팁 · 꽂이 · 벽은 안 그린다(벽은 shot_board.gd 가 따로 굽는다).
#  게임 파일은 안 건드린다: 이 스크립트를 main.tscn 의 Game 노드에 set_script 로 앉힌다.
#    "board"       판(그림자 · 두께 · 칸 · 철사 · 숫자 · 빛)
#    "darts"       꽂힌 다트(3D 무대 한 장)
#    "none"        아무것도
#    "game"        게임 그대로(견줄 때만)
var poster_layer := "none"
#  3D 다트 무대가 덮는 논리 사각 — shot_board.gd 가 무대를 판 둘레로 좁히며 적는다.
#  비어 있으면 게임 그대로(640 x 392, 왼쪽 위 0).
var poster_bd3_rect := Rect2()


func _draw() -> void:
	if poster_layer == "game":
		super._draw()
		return
	shake_off = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	match poster_layer:
		"board":
			_draw_board()
		"darts":
			_poster_bd3()


#  _draw_darts 의 3D 갈래만 — 그림자는 shot_board.gd 의 그림자 패스(_shadow)가 따로 굽는다.
func _poster_bd3() -> void:
	if not _bd3_live() and (not darts.is_empty() or state == S.FLY):
		_bd3_open()
	if not _bd3_live():
		return
	_bd3_sync()
	_bd3_fly()
	var tex: Texture2D = bd_vp.get_texture()
	if tex != null:
		var rc := poster_bd3_rect if poster_bd3_rect.size.x > 0.0 else Rect2(Vector2.ZERO, _bd3_size())
		draw_texture_rect(tex, rc, false)


func draw_front(_c: CanvasItem) -> void:
	pass
