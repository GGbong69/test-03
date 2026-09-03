extends SceneTree

#  문서용 화면 촬영
#
#  shot.gd 는 개발 중 눈으로 확인하려고 찍는다. 이건 기획서에 넣을 것을 찍는다.
#  차이는 하나다 — **런 중반을 찍는다.** 1판 화면에는 칩 랙이 비어 있고
#  점수가 두 자리라, 만든 것을 보여 주는 그림으로는 아무 값이 없다.
#  오토플레이를 태워 목표 판까지 실제로 플레이시킨 뒤, 그때부터
#  상태가 바뀔 때마다 한 장씩 건진다.
#
#  헤드리스로는 못 돈다 — 뷰포트를 실제로 그려야 화소가 나온다.
#
#  실행:  godot --path . -s scripts/tools/doc_shots.gd -- autoplay
#         godot --path . -s scripts/tools/doc_shots.gd -- autoplay 5

const WANT := ["PICK", "AIM_V", "AIM_H", "CONFIRM", "FLY", "RESOLVE",
		"CLEAR", "SHOP", "STAGE"]

var g = null
var frames := 0
var from_round := 4
var got := {}
var prev := -1
var hold := {}       # 상태에 들어간 뒤 몇 프레임 지났나


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for s in a:
		if s.is_valid_int():
			from_round = int(s)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	frames += 1
	if g == null:
		return true
	# 툴팁은 실제 마우스 위치를 읽어서 촬영이 재현되지 않는다. 매 프레임 끈다.
	g.tip_a = 0.0
	g.tip_title = ""

	var st: int = g.state
	if st != prev:
		hold[st] = 0
		prev = st
	else:
		hold[st] = int(hold.get(st, 0)) + 1

	# 런 중반부터 건진다. 그 전에는 게임이 스스로 굴러가게 둔다.
	if g.leg_no >= from_round:
		var name: String = WANT[st] if st < WANT.size() else str(st)
		# 상태마다 몇 프레임 뒤에 찍을지가 다르다 — 정산은 카드가 다 뜬 뒤,
		# 조준은 게이지가 화면 가운데쯤 왔을 때가 그림이 된다.
		var at: int = _delay(name)
		if not got.has(name) and int(hold.get(st, 0)) == at:
			got[name] = true
			_save("doc_%s.png" % name.to_lower())

	if got.size() >= WANT.size() or frames > 20000:
		print("찍은 것 %d / %d — %s" % [got.size(), WANT.size(),
				", ".join(PackedStringArray(got.keys()))])
		var miss := PackedStringArray()
		for w in WANT:
			if not got.has(w):
				miss.append(w)
		if not miss.is_empty():
			print("못 찍음: ", ", ".join(miss))
		quit()
	return false


# 그 상태에 들어간 뒤 몇 프레임째를 찍을 것인가.
func _delay(name: String) -> int:
	match name:
		"AIM_V", "AIM_H":
			return 14      # 게이지가 끝에 붙어 있으면 무엇인지 안 보인다
		"FLY":
			return 3       # 다트가 판에 닿기 전, 날아가는 중이 보이게
		"RESOLVE":
			return 40      # 정산 카드가 다 튀어나온 뒤
		"CLEAR":
			return 24      # 클리어 화면이 다 뜬 뒤
		"SHOP":
			return 90      # 매물이 물리로 정착한 뒤
		"STAGE":
			return 70      # 카드 세 장이 다 딜링된 뒤
		_:
			return 6


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name, "  R", g.leg_no, " 누적 ", g.total,
			" 골드 ", g.gold, " 보유 ", g.owned.size())
