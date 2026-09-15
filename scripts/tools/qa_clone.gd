extends SceneTree

# 사진이 테이블을 갈아 끼웠을 때 창구. 2026-09-15 제보 —
#   "마릴린 딥틱을 사용하니까 복사된 동전을 획득한 후에 상점에 있던것 들이
#    다시 안 나타나는데?"
#
# 창구가 **두 길**로 열려 있다: 톡 누르기(_chute_click)와 끌어다 놓기
# (_hand_release). 갈래를 한 길에만 달아 두면 다른 길이 잠자코 옛 길로 샌다.
# 이 자는 **두 길을 같은 자로 잰다.**
#
#   godot --path . --headless --script scripts/tools/qa_clone.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_clone_g.cfg"
	Save.path = "user://_qa_clone.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _fix(id: String) -> Dictionary:
	for f in GameData.fixtures():
		if String(f.get("id", "")) == id:
			return f
	return {}


#  상점을 세우고 동전 둘을 쥐여 준다
func _shop(items: int) -> void:
	g.gold = 40
	g.leg_no = 2
	g.owned = []
	var pool := GameData.items()
	for k in items:
		var it: Dictionary = pool[k].duplicate()
		it.gs = 0
		it.bought = 1
		g.owned.append(it)
	g.cons = []
	g._open_shop()
	g._drop_settle()


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n복제·파괴 창구 검사 — 두 길이 같은 일을 하는가\n")

	for path in ["톡 누르기", "끌어다 놓기"]:
		print("  ── %s ──" % path)
		_shop(2)
		var shop_n: int = g.stock.size()
		_ok("%s · 상점에 매물이 있다" % path, shop_n > 0, "%d개" % shop_n)
		#  마릴린 딥틱을 연다
		var fx := _fix("v_fake")
		g._photo_open("clone", int(fx.get("v", 2)))
		g._drop_settle()
		_ok("%s · 테이블이 보유 동전으로 갈렸다" % path,
				g.photo == "clone" and g.stock.size() == 2,
				"photo '%s' · 테이블 %d개" % [g.photo, g.stock.size()])
		var own0: int = g.owned.size()
		#  창구로 보낸다 — 길만 다르다
		if path == "톡 누르기":
			g.buy_sel = 0
			g._chute_click(g.Z_BUY)
		else:
			#  끌어다 놓기: 집어서 오른쪽 창구까지 끌고 가 뗀다
			#  물건이 실제로 놓인 자리. drop 이 면 좌표(u,w)를 들고 있으므로
			#  화면으로 옮겨 잡는다 — 손은 화면 좌표로 논다.
			var d0: Dictionary = g.drop[0]
			var from: Vector2 = g._p2s(float(d0.u), float(d0.w), 0.0)
			g._hand_press(from)
			var to := Vector2(g.VIEW.x - 6.0, 200.0)
			#  _hand_update 는 **진짜 마우스 버튼이 눌려 있는지**를 본다(안전망).
			#  헤드리스에서는 늘 안 눌린 것이라 걸음을 돌리면 손을 놓아 버린다 —
			#  프로브의 한계지 게임의 버그가 아니다. 그래서 걸음은 안 돌리고,
			#  걸음이 정해 주는 값(hand_zone)만 직접 먹인다. 재려는 것은
			#  _hand_release 가 그 값을 받았을 때 어느 갈래로 가는가다.
			for k in range(1, 9):
				g._hand_motion(from.lerp(to, float(k) / 8.0))
			g.hand_zone = g.Z_BUY
			g._hand_release(to)
		g._drop_settle()
		_ok("%s · 복사본을 받았다" % path, g.owned.size() == own0 + 1,
				"동전 %d → %d" % [own0, g.owned.size()])
		_ok("%s · 복제 모드가 닫혔다" % path, String(g.photo) == "",
				"photo '%s'" % g.photo)
		_ok("%s · **상점 매물이 돌아왔다**" % path, g.stock.size() == shop_n,
				"테이블 %d개 (열기 전 %d개)" % [g.stock.size(), shop_n])
		_ok("%s · 되돌릴 자리가 비었다" % path, g.photo_back.is_empty(),
				"%d개" % g.photo_back.size())
		print("")

	print("%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
