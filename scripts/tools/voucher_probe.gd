extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  설비 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 4000 --script scripts/tools/voucher_probe.gd
#  종료 코드 = 실패 개수
#
#  설비의 약속은 둘이다.
#    ① 산 것이 **실제로 그 값을 민다** — 표만 맞고 아무 데도 안 걸리는
#       사고가 이 저장소의 단골이다(안개가 그랬고, 넓은 매대 딱지도
#       여섯을 굴리기만 하고 뭉쳤다).
#    ② 런 스코프다 — 새 런에서 사라지고, 새로고침에 안 씻긴다.
#
#  static 에 사는 값이라 프로브가 서로를 오염시킨다. 검사마다
#  voucher_clear() 로 시작한다.
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-32s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_vou.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	GameData.voucher_clear()
	g._new_run()
	g._swap_skip()

	# ① 표와 코드가 같은 축을 안다
	var unknown := ""
	for f in GameData.vouchers():
		if not GameData.VOUCHER_KEYS.has(String(f.key)):
			unknown = String(f.key)
		if not GameData.VOUCHER_OPS.has(String(f.op)):
			unknown = String(f.op)
	_say(unknown == "", "표와 코드가 같은 축을 안다", unknown)

	# ② 축마다 **값이 실제로 바뀐다**
	GameData.voucher_clear()
	var w0: int = int(GameData.shop_of(1).items)
	GameData.voucher_set(["v_shelf"])
	var w1: int = int(GameData.shop_of(1).items)
	GameData.voucher_set(["v_shelf", "v_shelf2"])
	var w2: int = int(GameData.shop_of(1).items)
	_say(w1 == w0 + 1 and w2 == w0 + 2, "진열대가 매대를 넓힌다",
			"%d → %d → %d칸" % [w0, w1, w2])

	GameData.voucher_clear()
	g.rerolls_used = 1
	var p0: int = g._reroll_price()
	GameData.voucher_set(["v_roll"])
	var p1: int = g._reroll_price()
	_say(p0 > 0 and p1 == 0, "덤 새로고침이 값을 0 으로", "%d → %d골드" % [p0, p1])

	GameData.voucher_clear()
	var c0: int = g._interest_cap()
	GameData.voucher_set(["v_bank"])
	var c1: int = g._interest_cap()
	_say(c1 == c0 + 5, "저금통이 이자 상한을 올린다", "%d → %d" % [c0, c1])

	GameData.voucher_clear()
	g.active_mods = []
	g.cur_dart = GameData.darts()[0]
	var gs0: float = g.gs()
	GameData.voucher_set(["v_aim"])
	var gs1: float = g.gs()
	GameData.voucher_set(["v_aim", "v_aim2"])
	var gs2: float = g.gs()
	_say(is_equal_approx(gs1, gs0 * 0.85) and is_equal_approx(gs2, gs0 * 0.85 * 0.85),
			"침착이 게이지를 늦춘다", "%.3f → %.3f → %.3f" % [gs0, gs1, gs2])

	GameData.voucher_clear()
	g.round_no = 1
	g._start_round()
	g._swap_skip()
	var d0: int = g.remaining.size()
	GameData.voucher_set(["v_mag"])
	g.round_no = 1
	g._start_round()
	g._swap_skip()
	var d1: int = g.remaining.size()
	_say(d1 == d0 + 1, "긴 탄창이 다트를 늘린다", "%d → %d발" % [d0, d1])

	# ③ 벽이 자루를 다 담는다. 아홉 자루째가 화면 밖으로 나가던 자리다.
	var worst := 0.0
	var over := 0
	for n2 in range(4, 11):
		g.grip_n = n2
		g.grip_slot.clear()
		for k in n2:
			g.grip_slot.append(k)
		g.grip_hov = []
		for k in n2:
			g.grip_hov.append(0.0)
		var bot: float = g._mag_rect(n2 - 1).end.y
		worst = maxf(worst, bot)
		if bot > g.VIEW.y:
			over = n2
	_say(over == 0, "자루가 벽 안에 다 꽂힌다",
			"넷~열 자루 · 가장 아래 %.1f (화면 %.0f)" % [worst, g.VIEW.y])

	# ④ 런 스코프 — 새 런에서 사라진다
	GameData.voucher_set(["v_shelf", "v_mag"])
	g._new_run()
	g._swap_skip()
	_say(GameData.vouchers_own.is_empty()
			and int(GameData.shop_of(1).items) == w0,
			"새 런에서 설비가 사라진다", "%d개" % GameData.vouchers_own.size())

	# ⑤ 새로고침에 안 씻긴다
	GameData.voucher_clear()
	g.round_no = 1
	g.gold = 99
	g._open_shop()
	g._swap_skip()
	var had: Dictionary = g.shelf
	g._reroll()
	g._sweep_reset()
	_say(not had.is_empty() and g.shelf == had,
			"새로고침해도 선반은 그대로", String(had.get("n", "(없음)")))

	# ⑥ 사면 골드를 내고 목록에 남고 선반이 빈다
	g.gold = 99
	var before: int = g.gold
	var want: String = String(g.shelf.get("id", ""))
	var cost: int = int(g.shelf.get("cost", 0))
	g._click(g._shelf_rect().get_center())
	_say(g.gold == before - cost and GameData.vouchers_own.has(want)
			and g.shelf.is_empty(),
			"사면 값을 내고 목록에 남는다",
			"골드 %d → %d · 산 것 %d개" % [before, g.gold, GameData.vouchers_own.size()])

	# ⑦ 못 살 때는 거절한다
	GameData.voucher_clear()
	g.round_no = 1
	g.shelf_ante = 0            # 다시 굴리게 한다 — 안 비우면 빈 선반끼리 비교한다
	g._open_shop()
	g._swap_skip()
	g.gold = 0
	var kept: Dictionary = g.shelf
	g._click(g._shelf_rect().get_center())
	_say(not kept.is_empty() and g.gold == 0 and g.shelf == kept
			and GameData.vouchers_own.is_empty(),
			"골드가 모자라면 안 팔린다", String(kept.get("n", "(빈 선반)")))

	# ⑧ 앤티가 안 바뀌면 같은 것이 걸려 있다
	GameData.voucher_clear()
	g.round_no = 1
	g.shelf_ante = 0
	g._open_shop()
	g._swap_skip()
	var s1: Dictionary = g.shelf
	g.round_no = 2                      # 같은 앤티(라운드 1~3)
	g._open_shop()
	g._swap_skip()
	var same: bool = g.shelf == s1
	g.round_no = 4                      # 앤티 2 — 여기서는 갈린다
	g._open_shop()
	g._swap_skip()
	_say(not s1.is_empty() and same and g.shelf_ante == 2,
			"앤티가 바뀔 때만 갈린다",
			"%s → 앤티 %d" % [s1.get("n", "(빈 선반)"), g.shelf_ante])

	GameData.voucher_clear()
	print("
%s" % ("실패 %d건" % fails if fails > 0 else "열둘 검사 전부 통과"))
	quit(mini(fails, 125))
