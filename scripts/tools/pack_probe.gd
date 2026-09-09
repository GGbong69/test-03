extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  다트통 회귀 검사 — 기본 · 히든, 그리고 갈라지는 두 자리
#
#  실행:  godot --path . --headless --quit-after 4000 --script scripts/tools/pack_probe.gd
#  종료 코드 = 실패 개수
#
#  이 검사가 지키는 것은 **자리**지 내용이 아니다. 조준·계산 변형은
#  아직 안 정했고, 여기는 "그 자리가 실제로 갈라지는가" 만 잰다.
#
#    ① 표의 갈래·방식 이름이 전부 코드에 등록돼 있다
#    ② 히든에는 여는 조건이 있다 (없으면 영영 안 열린다)
#    ③ 조준·계산이 다트통에서 실제로 읽힌다 (판 시작에 한 번)
#    ④ 등록 안 된 이름은 std 로 떨어지되 **조용히는 아니다**
#    ⑤ 히든은 조건을 채우면 열리고, 못 채우면 안 열린다
#    ⑥ 잠긴 히든은 이름도 조건도 안 보인다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-32s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_probe_pack.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	GameData.fixture_clear()

	# ① 표와 코드가 같은 이름을 안다
	var bad := ""
	for r in GameData.packs():
		if not GameData.PACK_KINDS.has(GameData.pack_kind(r)):
			bad = "갈래 " + GameData.pack_kind(r)
		var am := String(r.get("aim", "std"))
		var sm := String(r.get("score", "std"))
		if am != "" and not GameData.AIM_MODES.has(am):
			bad = "조준 " + am
		if sm != "" and not GameData.SCORE_MODES.has(sm):
			bad = "계산 " + sm
	_say(bad == "", "표와 코드가 같은 이름을 안다", bad)

	# ② 두 갈래가 다 있다. 히든에는 조건이 있다.
	var base_n: int = GameData.packs_of("base").size()
	var hid := GameData.packs_of("hidden")
	var no_cond := ""
	for r in hid:
		if String(r.get("unlock_stat", "")) == "" and String(r.get("prereq", "")) == "":
			no_cond = String(r.get("id", ""))
	_say(base_n > 0 and hid.size() > 0 and no_cond == "",
			"기본과 히든이 갈려 있다",
			"기본 %d · 히든 %d · 조건 없는 것 '%s'" % [base_n, hid.size(), no_cond])

	# ③ 조준도 계산도 **든 동전**이 먼저 쥔다. 안 쥐면 다트통 표로 떨어진다.
	GameData.pack = "base"
	g._new_run()
	g._swap_skip()
	_say(g.score_mode == GameData.score_mode() and g.aim_mode == "std",
			"동전이 안 쥐면 다트통 표로 떨어진다",
			"조준 '%s' · 계산 '%s'" % [g.aim_mode, g.score_mode])

	# 조준 방식을 쥔 동전을 손에 넣으면 그 방식으로 던진다.
	# 봉인되면 그 판은 다시 기본으로 돌아간다 — 동전의 규칙 그대로다.
	var fake: Dictionary = GameData.items()[0].duplicate()
	fake.aim = "std"
	g.owned = [fake]
	g.sealed = -1
	_say(g._aim_from_items() == "std", "동전이 조준을 쥔다",
			"'%s'" % g._aim_from_items())
	g.sealed = 0
	_say(g._aim_from_items() == "std", "봉인된 동전은 조준을 안 쥔다")

	# 계산 방식도 같은 규약이다(2026-09-09). 사본에 심는다 — 원본
	# 카탈로그를 만지면 뒤의 검사가 그 오염을 물려받는다.
	var deca: Dictionary = GameData.items()[0].duplicate()
	deca["score"] = "bal"
	g.owned = [deca]
	g.sealed = -1
	_say(g._score_item() == 0, "동전이 계산 방식을 쥔다",
			"자리 %d" % g._score_item())
	g.sealed = 0
	_say(g._score_item() == -1, "봉인된 동전은 계산 방식을 안 쥔다")
	g.owned = []
	g.sealed = -1

	# 저울 다트통이 그 동전을 쥐여 주는가 — 표와 코드가 갈리는 자리다.
	# 계산 방식은 **판이 설 때** 정해지므로 _start_leg 까지 가야 한다.
	GameData.pack = "p_x1"
	g._new_run()
	g._swap_skip()
	g._start_leg()
	var granted := ""
	for it in g.owned:
		if String(it.get("score", "")) != "":
			granted = String(it.id)
	_say(granted != "" and g.score_mode == "bal",
			"저울 다트통이 계산 방식을 쥔 동전을 쥐여 준다",
			"'%s' · 계산 '%s'" % [granted, g.score_mode])
	GameData.pack = "base"
	g._new_run()
	g._swap_skip()

	# ③' 두 갈래가 실제로 그 값을 쓴다
	var chip := 7
	var mult := 3
	g.score_mode = "std"
	_say(g._score_combine(chip, mult) == chip * mult,
			"std 계산은 기본 점수 × 배수", "%d × %d = %d" % [chip, mult, g._score_combine(chip, mult)])
	g.score_mode = "bal"
	_say(g._score_combine(chip, mult) == 25, "저울은 평균을 맞춘 뒤 곱한다",
			"(7+3)/2 = 5 · 5×5 = %d" % g._score_combine(chip, mult))
	# 저울은 기본 점수가 배수보다 클수록 크게 튄다. 목표 배수가 왜 필요한지가 이
	# 한 줄에 있다 — 보통 판(기본 점수 40 · 배수 3)에서 std 의 세 배를 넘는다.
	_say(g._score_combine(40, 3) > 3 * (40 * 3), "저울은 보통 판에서 크게 튄다",
			"std %d → 저울 %d" % [40 * 3, g._score_combine(40, 3)])
	g.score_mode = "std"

	# 표적을 화면 밖에 두고 시작한다. 같은 틱 수를 두 번 돌리면 게이지가
	# 같은 자리에 착지해서 "안 움직였다" 와 구분이 안 된다 — 실제로 한 번
	# 그렇게 헛통과했다.
	g.state = g.S.AIM_V
	g.gt = 0.0
	g.aim_mode = "std"
	g.aim.y = -999.0
	for i in 20:
		g._aim_tick(1.0 / 60.0)
	_say(g.aim.y > 0.0 and g.gt > 0.0,
			"std 조준은 게이지가 움직인다", "y -999 → %.1f · gt %.3f" % [g.aim.y, g.gt])

	# ④ 판 시작 가드가 모르는 이름을 잡아 std 로 되돌린다.
	#    소리는 그 자리에서 한 번 나고, 조준은 안 멎는다 — 멎으면 조준이
	#    영영 안 잠겨 런이 통째로 막힌다.
	g.aim_mode = "없는것"
	g.score_mode = "없는것"
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()
	_say(g.aim_mode == "std" and g.score_mode == "std",
			"모르는 방식은 std 로 되돌린다", "'%s' · '%s'" % [g.aim_mode, g.score_mode])

	g.aim_mode = "없는것"
	g.state = g.S.AIM_V
	g.gt = 0.0
	g.aim.y = -999.0
	for i in 20:
		g._aim_tick(1.0 / 60.0)
	_say(g.aim.y > 0.0, "그래도 조준은 안 멎는다", "y -999 → %.1f" % g.aim.y)
	g.aim_mode = "std"
	g.score_mode = "std"

	# ⑤ 히든 해금 — 조건 미달이면 안 열린다
	if hid.is_empty():
		_say(false, "히든 다트통이 표에 없다")
	else:
		var h: Dictionary = hid[0]
		var hid_id := String(h.get("id", ""))
		var st := String(h.get("unlock_stat", ""))
		var need := int(String(h.get("unlock_v", "0")))
		Save.wipe()
		g._pack_unlock_check()
		_say(not Save.unlocked("pack:" + hid_id),
				"조건 미달이면 안 열린다", "%s %d/%d" % [st, Save.stat(st), need])
		Save.bump(st, need)
		g._pack_unlock_check()
		_say(Save.unlocked("pack:" + hid_id),
				"조건을 채우면 열린다", "%s %d/%d" % [st, Save.stat(st), need])

		# ⑥ 잠긴 히든은 이름도 조건도 안 보인다
		Save.wipe()
		_say(g._pack_cond(h) == "조건 미달",
				"잠긴 히든은 조건을 안 알려 준다", g._pack_cond(h))

	# ⑦ 기본 다트통은 완주로 열린다 — 표에 다음 기본이 있을 때만 뜻이 있다
	var bases := GameData.packs_of("base")
	Save.wipe()
	GameData.pack = String(bases[0].get("id", ""))
	g._pack_unlock_next()
	if bases.size() < 2:
		_say(true, "기본 다트통 사다리", "다음 기본 다트통이 아직 없다 (표 %d행)" % bases.size())
	else:
		_say(Save.unlocked("pack:" + String(bases[1].get("id", ""))),
				"완주가 다음 기본 다트통을 연다", String(bases[1].get("name", "")))

	# ⑥' 다트통이 미는 값과 굴리는 값 — 계산 쪽 손잡이 둘
	# 외줄: chip_mul 이 칸 값을 통째로 민다. _chip_gain 한 곳을 지나므로
	# 칸 값이든 동전이 얹은 점수든 다 받는다.
	GameData.pack = "p_solo"
	g._new_run()
	g._swap_skip()
	g._start_leg()
	_say(abs(g.score_mul - 1.6) < 0.001 and g.magazine.size() == 3
				and g._chip_gain(20) == 20,
			"외줄은 다트가 셋이고 **최종** 점수가 1.6배다",
			"%d발 · 배율 %.2f · 칸 값은 그대로 %d"
			% [g.magazine.size(), g.score_mul, g._chip_gain(20)])

	# 물음표: 굴리는 것은 **걸음**이 하고 _score_combine 은 순수해야 한다.
	# 안에서 굴리면 같은 발을 두 번 셀 때마다 값이 달라져 화면과 총점이
	# 갈리고, 검산기가 따로 셈한 값과 영영 안 맞는다.
	GameData.pack = "p_rnd"
	g._new_run()
	g._swap_skip()
	g._start_leg()
	_say(g.score_mode == "rand" and g._score_combine(7, 3) == 21
				and g._score_combine(7, 3) == 21,
			"물음표는 rand 로 세고 곱셈은 순수하다",
			"'%s' · 7×3 = %d" % [g.score_mode, g._score_combine(7, 3)])
	g.queue.clear()
	g.aim = g.BC
	g._land()
	var has_rnd := false
	for st0 in g.queue:
		if String(st0.k) == "rnd":
			has_rnd = true
	_say(has_rnd, "물음표는 합산 앞에 굴리는 걸음을 세운다")
	GameData.pack = "base"
	g._new_run()
	g._swap_skip()
	g._start_leg()
	_say(abs(g.score_mul - 1.0) < 0.001,
			"다른 다트통은 최종 점수를 안 민다", "배율 %.2f" % g.score_mul)

	# ⑦ 기본 다트통도 통계로 연다(2026-09-09 · 혼합 해금). 앞의 다섯은
	# 체인, 뒤는 조건 — 기획서 P.21 이 다트통마다 고유 조건을 적어 둔 그
	# 꼴이다. 히든만 보던 시절의 _pack_unlock_check 로 되돌아가면 걸린다.
	var cond_base := ""
	for cr0 in GameData.packs_of("base"):
		if String(cr0.get("unlock_stat", "")) != "":
			cond_base = String(cr0.get("id", ""))
			break
	if cond_base == "":
		_say(true, "조건으로 여는 기본 다트통이 아직 없다", "검사 건너뜀")
	else:
		var cr := GameData.pack_row(cond_base)
		var cs := String(cr.get("unlock_stat", ""))
		var cv := int(String(cr.get("unlock_v", "0")))
		Save.wipe()
		g._pack_unlock_check()
		_say(not Save.unlocked("pack:" + cond_base),
				"조건 미달인 기본 다트통은 안 열린다",
				"%s %d/%d" % [cs, Save.stat(cs), cv])
		Save.peak(cs, cv)
		g._pack_unlock_check()
		_say(Save.unlocked("pack:" + cond_base),
				"기본 다트통도 통계로 열린다",
				"%s · %s %d/%d" % [cr.get("name", ""), cs, Save.stat(cs), cv])

	# 완주한 순간의 다트 구성이 통계에 남는가 — 위 조건이 읽는 값이다.
	var lgt := {}
	for d0 in GameData.darts():
		if String(d0.id) == "lgt":
			lgt = d0
	if lgt.is_empty():
		_say(true, "가벼운 다트가 표에 없다", "검사 건너뜀")
	else:
		Save.wipe()
		g.magazine = [lgt, lgt]
		g._dart_peaks()
		_say(Save.stat("best_dart_lgt") == 2, "다트 구성이 통계에 남는다",
				"best_dart_lgt %d" % Save.stat("best_dart_lgt"))
		g.magazine = []
		g._dart_peaks()
		_say(Save.stat("best_dart_lgt") == 2, "최댓값이라 안 내려간다")

	Save.wipe()
	print("
%s" % ("실패 %d건" % fails if fails > 0 else "검사 전부 통과"))
	quit(mini(fails, 125))
