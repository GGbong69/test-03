extends SceneTree

# 3D 손. 2026-09-15 — "3D 모델같이 하고 싶은건데".
#
# 재는 것은 **자리가 맞물리는가**다. 3D 손은 2D 가 셈한 손목·각·배율을
# 받아 쓰는데, 그 셈을 두 곳에서 따로 하면 쓸기 도중에 팔과 손이 갈라진다.
# 그리고 화면(화면은 2D)과 물건(3D)이 같은 투영을 봐야 손이 면에 앉는다.
#
#   godot --path . --quit-after 1500 --script scripts/tools/qa_hand3.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_h3_g.cfg"
	Save.path = "user://_qa_h3.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 3D 는 화면이 있어야 선다")
		quit(0)
		return
	print("\n3D 손 검사 — 자리가 맞물리는가\n")

	# ① 투영이 같은 식인가. 카메라 각(−52°)이 TBL 의 정사영과 같아야 한다.
	var pit: float = deg_to_rad(float(g.HAND3.pitch))
	_ok("카메라 각이 면 투영과 같다",
			absf(sin(-pit) - float(g.TBL.flat)) < 0.002
			and absf(cos(-pit) - float(g.TBL.tall)) < 0.002,
			"sin %.3f (flat %.3f) · cos %.3f (tall %.3f)"
			% [sin(-pit), g.TBL.flat, cos(-pit), g.TBL.tall])

	# ② 상인이 서는 화면에서만 산다
	g.state = g.S.TITLE
	g._new_run()
	await _wait(40)
	_ok("판 고르기에서 손이 선다", g._hand3_live(), "state %d" % g.state)
	_ok("두 손이 섰다", g.hand3_rig.size() == 2, "%d벌" % g.hand3_rig.size())
	_ok("자세를 둘 받았다", g.hand3_pose.size() == 2,
			"%d개" % g.hand3_pose.size())

	# ③ 자세가 2D 의 셈과 같은 값인가 — 손목이 팔 끝에 있다
	var far := 0.0
	for ps in g.hand3_pose:
		var wr: Vector2 = ps.wr
		far = maxf(far, absf(wr.x - 320.0))
	_ok("손목이 상인 곁에 있다", far > 40.0 and far < 320.0,
			"가운데에서 %.0f" % far)

	# ④ 그림자가 손과 **같이** 돌되 어긋남은 월드다
	var rg: Dictionary = g.hand3_rig[0]
	var hd: Node3D = rg.hand
	var sd: Node3D = rg.shad
	_ok("그림자가 손과 같은 각", absf(sd.rotation.y - hd.rotation.y) < 0.001,
			"손 %.3f · 그림자 %.3f" % [hd.rotation.y, sd.rotation.y])
	_ok("그림자가 면에 눕는다", sd.scale.y < 0.1 and sd.position.y < 0.0,
			"두께배 %.2f · 높이 %.2f" % [sd.scale.y, sd.position.y])
	#  빛이 왼쪽 위라 그림자는 오른쪽 아래(화면 +x · +y)로 진다.
	var dx: float = sd.position.x - hd.position.x
	var dz: float = sd.position.z - hd.position.z
	_ok("그림자가 빛 반대쪽으로 진다", dx > 0.0 and dz > 0.0,
			"x +%.1f · z +%.1f" % [dx, dz])

	# ⑤ 화면을 뜨면 지워진다 — 안 보이는 뷰포트가 런 내내 돌면 안 된다
	g.state = g.S.TITLE
	await _wait(6)
	_ok("화면을 뜨면 지워진다", not g._hand3_live(), "")
	_ok("손 목록도 빈다", g.hand3_rig.is_empty(), "%d벌" % g.hand3_rig.size())

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
