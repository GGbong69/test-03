extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  무한 구간을 **실제로 걷는다** — 판 25 부터 102 까지
#
#  실행:  godot --headless --path . --script scripts/tools/qa_endwalk.gd
#  종료 코드 = 실패 개수
#
#  ⚠ **가장 빠지기 쉬운 함정이 「무한을 만들었더니 도는 것처럼 보이는데
#  실은 8라운드가 무한 반복」이다.** clamp 는 오류를 안 뱉는다 — 목표가
#  20000 에 굳고 전부 보스라 못 건너뛰고 보스 제약이 하나도 안 걸리는
#  것이 **조용히** 선다. 그래서 판 하나씩 진짜 길(_open_leg → _begin_leg →
#  _start_leg)로 걸어가며 판마다 묻는다.
#
#  qa_endless 는 **자**(data.gd)를 재고 여기는 **런**(game.gd)을 건다.
#  둘이 같은 것을 다른 몸으로 재는 것이 이 짝의 요점이다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.gpath = "user://_qa_endwalk_g.cfg"
	Save.path = "user://_qa_endwalk.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-46s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false
	GameData.challenge = ""
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	GameData.endless = true
	g.gold = 999

	print("무한 구간을 걷는다 — 판 25 부터 102 까지\n")

	var prev_tgt := 0
	var names := {}
	var boss_n := 0
	var skip_n := 0
	var stack_n := 0
	var no_ahead := 0
	var flat := 0
	var last_leg_said := 0
	for n in range(GameData.legs_n() + 1, GameData.endless_legs_n() + 1):
		g.leg_no = n
		g._open_leg()
		g._begin_leg()
		g._swap_skip()
		var t: int = g.target
		names[GameData.leg_name(n)] = true
		if GameData.is_boss(n):
			boss_n += 1
			var ids: PackedStringArray = g.boss_mods.get(n, PackedStringArray())
			if ids.size() >= 2:
				stack_n += 1
			if g.active_mods.is_empty():
				flat += 1
		elif GameData.skippable(n):
			skip_n += 1
		#  보스 예고 — _boss_ahead 를 안 뚫으면 사탕 둘 · 상점 명판 ·
		#  런 정보의 예고가 통째로 빈다.
		if n < GameData.endless_legs_n() - 2 and g._boss_ahead() <= 0:
			no_ahead += 1
		#  자금판의 「마지막 판」이 무한 내내 뜨면 화면이 판을 속인다.
		if n < GameData.endless_legs_n() - 1 and n + 1 >= GameData.legs_top():
			last_leg_said += 1
		#  같은 라운드 안에서는 판 배수만큼만 오르고, 라운드가 넘어가면
		#  기본이 오른다. 여기서는 **라운드 첫 판끼리** 댄다.
		if GameData.leg_idx(n) == 0:
			if t <= prev_tgt:
				_ok("판 %d 목표가 앞 라운드보다 높다" % n, false,
						"%d → %d" % [prev_tgt, t])
			prev_tgt = t

	print("  걸은 판 %d · 보스 %d · 건너뛸 수 있는 판 %d"
			% [GameData.endless_legs_n() - GameData.legs_n(), boss_n, skip_n])
	_ok("판 종류 셋이 다 선다(8라운드 반복이 아니다)", names.size() == 3,
			str(names.keys()))
	_ok("보스가 라운드마다 하나다",
			boss_n == GameData.endless_rounds() - GameData.rounds_n(),
			"%d개" % boss_n)
	_ok("건너뛸 수 있는 판이 보스의 두 배다", skip_n == boss_n * 2,
			"%d개" % skip_n)
	_ok("보스 판마다 제약이 걸린다", flat == 0, "빈 보스 %d개" % flat)
	_ok("무한 4라운드마다 제약이 둘이다",
			stack_n == int(boss_n / maxi(GameData.tune_i("endless_stack_per"), 1)),
			"%d개 / 바라는 값 %d" % [stack_n,
					int(boss_n / maxi(GameData.tune_i("endless_stack_per"), 1))])
	_ok("보스 예고가 안 빈다", no_ahead == 0, "빈 판 %d개" % no_ahead)
	_ok("「마지막 판」이 무한 내내 안 뜬다", last_leg_said == 0,
			"%d판" % last_leg_said)

	# ── 화면 규약 ─────────────────────────────────────────
	print("\n화면")
	g.leg_no = 61
	g._open_leg()
	g._begin_leg()
	g._swap_skip()
	_ok("런 정보 판이 안 커진다", g._ri_h(0) <= g._ri_h(3),
			"진행 %.0f · 보유 %.0f" % [g._ri_h(0), g._ri_h(3)])
	_ok("목표가 깎여 나온다", GameData.big(g.target).length() <= 7,
			"%s (%d자)" % [GameData.big(g.target), GameData.big(g.target).length()])
	_ok("판 이름이 표의 셋 중 하나다",
			GameData.leg_name(61) == "작은 판", GameData.leg_name(61))

	# ── 무한을 끄면 본편으로 돌아온다 ─────────────────────
	GameData.endless = false
	g.leg_no = 3
	g._open_leg()
	g._begin_leg()
	g._swap_skip()
	_ok("본편 판 3 의 목표가 84 다", g.target == 84, str(g.target))
	_ok("본편 판 3 이 보스다", GameData.is_boss(3))
	_ok("legs_top() 이 24 로 돌아온다", GameData.legs_top() == 24)

	GameData.endless = false
	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
