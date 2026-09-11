extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  완주 장면 통계 검사 — 다트통 해금 조건이 읽는 것들
#
#  실행:  godot --path . --headless --script scripts/tools/unlock_probe.gd
#  종료 코드 = 실패 개수
#
#  2026-09-11 기획서 P.6 의 다트통 표는 해금을 「무엇을 **든 채로** 완주했나」
#  로 적는다. 그건 누적도 최댓값도 아닌 **한 장면**이다 — 판마다 재면 런
#  도중에 스쳐 간 값이 걸려서 「한 번이라도 그랬다」가 되고, 그 둘은 다른
#  조건이다. 그래서 완주하는 자리에서만 찍는다.
#
#  재는 것
#    win_gold    완주 때 골드          (선금: 100 이상)
#    win_items   완주 때 동전 수        (넓은 슬롯: 4 이하 — **최솟값**이다)
#    win_null    NULL 을 든 채 완주      ([?? ???]: 1 이상)
#    boss_spare  보스 판을 넘긴 잔탄     (외줄: 5 이상 = 한 발로)
#
#  최솟값이 이 표의 까다로운 자리다. 처음 한 번은 무조건 적어야 한다 —
#  0 에서 시작하면 「아직 안 했다」와 「0개로 했다」가 구별이 안 되고
#  뒤엣것이 늘 이겨서 조건이 처음부터 서 있다.
# ══════════════════════════════════════════════════════════

var g = null
var done := false
var fails := 0
func _initialize() -> void:
	Save.path = "user://_probe_unlock.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
func _ok(n: String, c: bool, d := "") -> void:
	print("  %s %-34s %s" % ["OK  " if c else "실패", n, d])
	if not c:
		fails += 1
func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	print("완주 장면 통계 — 기획서 다트통 조건이 읽는 것들\n")

	# ① 완주 때 골드·동전 수
	g._new_run()
	g.gold = 137
	g.owned = [GameData.items()[0].duplicate(), GameData.items()[1].duplicate()]
	g._win_peaks()
	_ok("완주 골드가 남는다", Save.stat("win_gold") == 137, "win_gold %d" % Save.stat("win_gold"))
	_ok("완주 동전 수가 남는다", Save.stat("win_items") == 2, "win_items %d" % Save.stat("win_items"))

	# ② 최솟값이라 더 적게 든 완주만 내려간다
	g.owned = [GameData.items()[0].duplicate()]
	g._win_peaks()
	_ok("동전 수는 적은 쪽이 이긴다", Save.stat("win_items") == 1, "win_items %d" % Save.stat("win_items"))
	g.owned = [GameData.items()[0].duplicate(), GameData.items()[1].duplicate(),
			GameData.items()[2].duplicate()]
	g._win_peaks()
	_ok("많이 든 완주는 안 밀어낸다", Save.stat("win_items") == 1, "win_items %d" % Save.stat("win_items"))

	# ③ NULL 을 든 채 완주
	var nul := {}
	for it in GameData.items():
		if String(it.get("side", "")) == "boardkill":
			nul = it.duplicate()
			break
	_ok("NULL 이 표에 있다", not nul.is_empty(), String(nul.get("n", "?")))
	g.owned = [nul]
	g._win_peaks()
	_ok("NULL 을 들고 완주하면 센다", Save.stat("win_null") == 1,
			"win_null %d" % Save.stat("win_null"))

	# ④ 보스 판 잔탄
	g.leg_no = 1
	g.darts_left = 5
	g.total = 1 << 30
	g.target = 1
	g._finish_leg()
	var small := Save.stat("boss_spare")
	var boss := -1
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			boss = n
			break
	g.leg_no = boss
	g.darts_left = 5
	g.total = 1 << 30
	g.target = 1
	g._finish_leg()
	_ok("작은 판 잔탄은 안 센다", small == 0, "판1 뒤 boss_spare %d" % small)
	_ok("보스 판 잔탄만 센다", Save.stat("boss_spare") == 5,
			"판%d 뒤 boss_spare %d" % [boss, Save.stat("boss_spare")])

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
