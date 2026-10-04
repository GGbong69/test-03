extends Node2D

#  장면 전환 덮개(game.gd 의 WIPE 머리말). 층(CanvasLayer 95)이 게임 · 앞판 · 개발자 판
#  위, CRT(100) 밑이라 덮개도 브라운관 결을 탄다. 그리는 내용은 전부 Game 이 안다 —
#  front.gd 와 같은 어법이다. 여기는 붓만 빌려준다.

var g: Node = null


func _draw() -> void:
	if g != null and g.has_method("wipe_draw"):
		g.wipe_draw(self)
