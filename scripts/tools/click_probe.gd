extends SceneTree

#  2클릭 매매 프로브
#
#  shop_probe 는 드래그 경로만 잰다. 2클릭 경로는 판정 순서에 걸려 있어서
#  따로 물어야 한다 — 실제로 _chute_at 이 _sell_hit 뒤에 있던 동안
#  상점의 2클릭 판매가 통째로 죽어 있었고 어떤 도구도 그걸 못 봤다.
#  (_sell_hit 이 sell_sel 을 지운 뒤 창구가 "먼저 고른다" 로 거절했다.)
#
#  실행:  godot --path . --script scripts/tools/click_probe.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var step := 0
var fails := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-28s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


# 창구는 화면 좌우 끝, 테이블 세로 한가운데다.
func _chute_pt(right: bool) -> Vector2:
	return Vector2(634.0 if right else 6.0, (g.TBL.fy + g.TBL.ny) * 0.5)


func _process(_d: float) -> bool:
	step += 1
	if step < 12:            # 낙하·레이아웃이 자리를 잡을 때까지
		return false

	g.gold = 99
	g._open_shop()
	g._drop_settle()

	# ── 판매: 동전 슬롯 기본 점수 클릭 → 왼쪽 창구 클릭
	g.owned = [GameData.items()[0]]
	g._panel_reset()
	g._click(g._slot_rect(0).get_center())
	_ok("동전 슬롯 기본 점수 클릭 → 고름", g.sell_sel == 0, "sell_sel %d" % g.sell_sel)

	var g0: int = g.gold
	g._click(_chute_pt(false))
	_ok("왼쪽 창구 클릭 → 판매", g.gold > g0 and g.owned.is_empty(),
			"골드 %d → %d · 남은 기본 점수 %d" % [g0, g.gold, g.owned.size()])

	# ── 구매: 매물 클릭 → 오른쪽 창구 클릭
	var hit := -1
	for i in g.stock.size():
		if g._buy_block(i) == "":
			hit = i
			break
	if hit < 0:
		_ok("살 수 있는 매물", false, "하나도 없다")
	else:
		g._click(g._obj_box(hit).get_center())
		_ok("매물 클릭 → 고름", g.buy_sel == hit, "buy_sel %d" % g.buy_sel)
		var g1: int = g.gold
		g._click(_chute_pt(true))
		_ok("오른쪽 창구 클릭 → 구매", g.gold < g1, "골드 %d → %d" % [g1, g.gold])

	print("네 검사 전부 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)
	return true
