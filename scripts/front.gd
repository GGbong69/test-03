extends Node2D

#  앞판. 흐림 판(Blur) **뒤에** 그리면 설정 글씨까지 같이 뿌예진다 —
#  고닷은 자식을 부모보다 나중에 그리므로, 부모(Game)가 그린 게임 위에
#  Blur 가 얹히고 그 위에 이 노드가 얹힌다. 순서가 곧 이 노드의 존재 이유다.
#
#  그리는 내용은 전부 부모가 안다. 여기는 붓만 빌려준다.

func _draw() -> void:
	var g := get_parent()
	if g != null and g.has_method("draw_front"):
		g.draw_front(self)
