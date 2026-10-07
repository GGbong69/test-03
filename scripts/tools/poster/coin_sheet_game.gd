extends "res://scripts/game.gd"
#  동전 낱장(shot_assets.gd mode=coin) 전용 — game.gd 를 한 줄도 안 고치고 _draw 만 바꿔 끼운다.
#  sheet 가 차 있으면 동전 스티커만 칸마다 그린다(투명 바탕). draw_item_sticker 는 동전 슬롯 ·
#  상점 · 툴팁이 같이 쓰는 그 그림이다 — 정면, 판 모양 · 테 · 얼굴 · 등급 밴드까지 게임 그대로.
var sheet := []          # [{"c": Vector2, "r": float, "it": Dictionary}]


func _draw() -> void:
	if sheet.is_empty():
		super._draw()
		return
	draw_set_transform(Vector2.ZERO)
	for e in sheet:
		draw_item_sticker(e.c, float(e.r), e.it, 0.0, 0.0, 0.0, 12)
