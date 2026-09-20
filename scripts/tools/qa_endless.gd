extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  무한모드의 뼈대 — 곡선과 판 번호
#
#  실행:  godot --headless --path . --script scripts/tools/qa_endless.gd
#  종료 코드 = 실패 개수
#
#  ⚠ **첫 단언이 「본편이 안 바뀌었다」다.** 이 설계에서 가장 위험한 자리가
#  round_of · leg_idx 의 clamp 를 걷은 것이다 — 저장소 전체가 그 둘 위에
#  선다(target_of · leg_of · is_boss · darts_of · _round_row · 프로필 ·
#  상단바). n <= 24 에서 한 값도 안 다르다는 것이 설계의 **전제**이고,
#  그것을 기계로 재기 전에는 아무것도 믿으면 안 된다. 그래서 고치기 전
#  값을 배열로 박아 두고 댄다.
#
#  나머지는 기획서 P.17 「목표점수는 함수로 설정」이 실제로 서는가다.
# ══════════════════════════════════════════════════════════

#  ── 고치기 **전**의 값. 2026-09-20 에 _base_data.gd(HEAD 의 data.gd)로
#  찍어서 박았다. 흰 리그 · 기본 다트통 · 챌린지 없음.
const TGT0 := [42, 63, 84, 123, 185, 246, 327, 491, 654, 788, 1182, 1576,
		1722, 2583, 3444, 3413, 5120, 6827, 6135, 9202, 12270, 10000, 15000, 20000]
const IDX0 := [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2]
const BOSS0 := [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_endless.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-44s %s" % ["OK  " if cond else "실패", nm, detail])
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
	GameData.endless = false

	print("무한 검사 — 본편이 안 바뀌었는가 · 무한이 실제로 도는가\n")

	# ── ① 본편이 한 값도 안 바뀌었다 ─────────────────────
	print("① 본편 스물넷")
	var tg := []
	var ix := []
	var bs := []
	var dz := true
	for n in range(1, 25):
		tg.append(GameData.target_of(n))
		ix.append(GameData.leg_idx(n))
		bs.append(1 if GameData.is_boss(n) else 0)
		if GameData.darts_of(n) != 6:
			dz = false
	_ok("목표 스물넷이 그대로다", tg == TGT0, str(tg) if tg != TGT0 else "")
	_ok("판 종류 스물넷이 그대로다", ix == IDX0, str(ix) if ix != IDX0 else "")
	_ok("보스 자리 스물넷이 그대로다", bs == BOSS0, str(bs) if bs != BOSS0 else "")
	_ok("다트 수가 그대로다", dz)
	_ok("round_of(1..24) 가 그대로다",
			GameData.round_of(1) == 1 and GameData.round_of(3) == 1
			and GameData.round_of(4) == 2 and GameData.round_of(24) == 8)
	#  clamp 를 걷었으므로 **범위 밖**에서도 식이 옳아야 한다.
	_ok("round_of(0)·round_of(−5) 가 1 이다",
			GameData.round_of(0) == 1 and GameData.round_of(-5) == 1)

	# ── ② 전환 라운드에 벽이 없다 ────────────────────────
	print("\n② 곡선")
	var b8 := GameData.round_base_endless(8)
	var b9 := GameData.round_base_endless(9)
	var step := b9 / b8
	#  ⚠ 지수가 m(m−1)/2 인가를 재는 자리다. m(m+1)/2 면 1.724 가 나와 운다.
	_ok("R8→R9 걸음이 step 그대로다(1.630)", absf(step - 1.63) < 0.001,
			"걸음 %.4f" % step)
	var b16 := GameData.round_base_endless(16)
	_ok("R16/R8 = 238 (무한 한 바퀴 = 본편 한 바퀴)",
			absf(b16 / b8 - 238.0) < 1.0, "%.2f" % (b16 / b8))
	_ok("round_base_endless(a<=8) 가 round_base(a) 그대로다",
			GameData.round_base_endless(5) == GameData.round_base(5))
	#  ⚠ **라운드 기본**이 단조증가하는가를 본다. 판 목표는 본편에서도
	#  라운드 경계에서 꺾인다(판 21 보스 12270 → 판 22 작은 10000) —
	#  판 배수가 2.00 에서 1.00 으로 떨어지는 그 자리라 사고가 아니다.
	GameData.endless = true
	var mono := true
	var lo := 0
	for a in range(2, GameData.endless_rounds() + 1):
		if GameData.round_base_endless(a) <= GameData.round_base_endless(a - 1):
			mono = false
			lo = a
	_ok("라운드 1..34 기본이 단조증가한다", mono,
			"" if mono else "라운드 %d 에서 꺾였다" % lo)
	#  같은 판 종류끼리도 판 번호를 따라 오르는가(작은 판만 훑는다)
	var mono2 := true
	var prev := 0
	for n in range(1, GameData.endless_legs_n() + 1, 3):
		var t: int = GameData.target_of(n)
		if t <= prev:
			mono2 = false
		prev = t
	_ok("작은 판 목표가 판 1..100 에서 단조증가한다", mono2)
	#  천장 — 한 판의 최악 = 기본 x 보스 2.00 x 검정 리그 4.00 x 제약 1.25
	var worst := GameData.round_base_endless(GameData.endless_rounds()) * 10.0
	_ok("R34 최악이 int64 의 절반 아래다", worst < 4.6e18,
			"최악 %.4f경 · int64 922경" % (worst / 1.0e16))
	_ok("라운드 35 로 못 넘어간다",
			GameData.round_base_endless(35) == GameData.round_base_endless(34))

	# ── ③ 무한에도 박자가 산다 ───────────────────────────
	print("\n③ 판 번호")
	_ok("판 25 가 라운드 9 다", GameData.round_of(25) == 9,
			"라운드 %d" % GameData.round_of(25))
	_ok("판 25 가 작은 판이다", GameData.leg_idx(25) == 0,
			GameData.leg_name(25))
	_ok("판 26 이 큰 판이다", GameData.leg_idx(26) == 1, GameData.leg_name(26))
	_ok("판 27 이 보스 판이다", GameData.is_boss(27), GameData.leg_name(27))
	_ok("판 25 를 건너뛸 수 있다", GameData.skippable(25))
	_ok("판 27 을 못 건너뛴다", not GameData.skippable(27))
	_ok("legs_top() 이 102 다", GameData.legs_top() == 102,
			str(GameData.legs_top()))
	_ok("rounds_top() 이 34 다", GameData.rounds_top() == 34)
	#  ⚠ clamp 를 **남긴** 자리가 의도대로인가
	_ok("판 25 가 rounds.csv 8행을 읽는다(남긴 clamp)",
			GameData.darts_of(25) == GameData.darts_of(24),
			"다트 %d" % GameData.darts_of(25))

	# ── ④ 무한 구간에 보스 제약이 걸린다 ─────────────────
	print("\n④ 보스 제약")
	g.leg_no = 25
	g.boss_mods.clear()
	g.boss_void.clear()
	g.boss_seen.clear()
	_ok("_round_boss(25) 가 27 이다", g._round_boss(25) == 27,
			str(g._round_boss(25)))
	g._roll_boss_mods(g._round_boss(25))
	var ids: PackedStringArray = g.boss_mods.get(27, PackedStringArray())
	_ok("판 27 에 제약이 걸렸다", ids.size() >= 1, "%d개" % ids.size())
	#  (R−8) % 4 == 0 인 라운드는 둘이다 — 라운드 12 = 판 34~36, 보스 36
	g.boss_mods.clear()
	g.boss_seen.clear()
	g.leg_no = 34
	g._roll_boss_mods(g._round_boss(34))
	var ids2: PackedStringArray = g.boss_mods.get(36, PackedStringArray())
	_ok("무한 4라운드마다 보스 제약이 둘이다", ids2.size() == 2,
			"라운드 %d · %d개" % [GameData.round_of(36), ids2.size()])
	#  주기 밖(라운드 10)은 하나다
	g.boss_mods.clear()
	g.boss_seen.clear()
	g.leg_no = 28
	g._roll_boss_mods(g._round_boss(28))
	var ids3: PackedStringArray = g.boss_mods.get(30, PackedStringArray())
	_ok("주기 밖 라운드는 하나다", ids3.size() == 1, "%d개" % ids3.size())

	# ── ⑤ 본편에서는 아무것도 안 달라졌다(끄고 다시) ─────
	print("\n⑤ 껐을 때")
	GameData.endless = false
	_ok("legs_top() 이 24 로 돌아온다", GameData.legs_top() == 24)
	_ok("rounds_top() 이 8 로 돌아온다", GameData.rounds_top() == 8)
	var tg2 := []
	for n in range(1, 25):
		tg2.append(GameData.target_of(n))
	_ok("목표 스물넷이 여전히 그대로다", tg2 == TGT0)

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
