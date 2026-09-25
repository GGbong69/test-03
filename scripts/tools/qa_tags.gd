extends SceneTree

# 건너뛰기 보상. 2026-09-15 기획자 표(열다섯 가지)를 그대로 잰다.
#   godot --path . --headless --script scripts/tools/qa_tags.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_tags.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-36s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _tag(id: String) -> Dictionary:
	for r in GameData.tags():
		if String(r.get("id", "")) == id:
			return r
	return {}


#  런 하나를 깨끗하게 세운다
func _fresh() -> void:
	g.gold = 0
	g.cons = []
	g.owned = []
	g.pending_tags.clear()
	g.tag_copy = 0
	g.leg_skipped = {}
	g.track_hits = {}
	g.track_lv = {}
	g.leg_no = 1


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n건너뛰기 보상 검사 — 표 열다섯\n")

	# ① 표 자체
	var tg := GameData.tags()
	_ok("표가 열다섯 줄", tg.size() == 15, "%d줄" % tg.size())
	var kinds := {}
	for r in tg:
		kinds[String(r.get("kind", ""))] = true
	_ok("갈래가 다 TAG_KINDS 안에 있다",
			func_all(kinds.keys(), GameData.TAG_KINDS),
			"쓰는 갈래 %d가지" % kinds.size())

	# ② 골드
	print("")
	_fresh()
	g._take_tag(_tag("t_gold"))
	_ok("삯 — 골드 +6", g.gold == 6, "골드 %d" % g.gold)
	_fresh()
	g._take_tag(_tag("t_purse"))
	_ok("두둑한 삯 — 골드 +12", g.gold == 12, "골드 %d" % g.gold)

	# ③ 사탕과 사진이 제 풀에서 온다
	print("")
	_fresh()
	g._take_tag(_tag("t_candy"))
	var got_candy: bool = g.cons.size() == 1 \
			and not GameData.is_fixture(String(g.cons[0].get("id", "")))
	_ok("군것질 — 사탕이 온다", got_candy,
			"%s" % (g.cons[0].get("n", "없다") if g.cons.size() > 0 else "빈손"))
	_fresh()
	g._take_tag(_tag("t_photo"))
	var got_photo: bool = g.cons.size() == 1 \
			and GameData.is_fixture(String(g.cons[0].get("id", "")))
	_ok("한 컷 — 사진이 온다", got_photo,
			"%s" % (g.cons[0].get("n", "없다") if g.cons.size() > 0 else "빈손"))

	# ④ 칸이 꽉 차 있으면 안 들어온다 (그리고 그 사실을 말한다 — 눈으로)
	_fresh()
	for i in GameData.cons_slots():
		g.cons.append(GameData.candies()[0].duplicate())
	var before: int = g.cons.size()
	g._take_tag(_tag("t_photo"))
	_ok("칸이 꽉 차면 안 들어온다", g.cons.size() == before,
			"%d장 그대로" % g.cons.size())

	# ⑤ 동전 등급 — 셋이 저마다 제 등급만 준다
	print("")
	for pair in [["t_item", "common"], ["t_rare", "uncommon"], ["t_epic", "rare"]]:
		var id := String(pair[0])
		var want := String(pair[1])
		var miss := 0
		var none := 0
		for k in 40:
			_fresh()
			g.leg_no = 8            # min_leg 문을 다 연다
			g._take_tag(_tag(id))
			if g.owned.is_empty():
				none += 1
			elif String(g.owned[0].get("rarity", "")) != want:
				miss += 1
		_ok("%s — %s 등급만" % [String(_tag(id).get("name", "")), want],
				miss == 0 and none == 0,
				"40번 · 딴 등급 %d · 빈손 %d" % [miss, none])

	# ⑥ 발품 — 건너뛴 판을 센다. 준 그 판까지 포함한다
	print("")
	_fresh()
	g.leg_skipped = {1: true}
	g._take_tag(_tag("t_tally"))
	_ok("발품 — 한 판이면 5", g.gold == 5, "골드 %d" % g.gold)
	_fresh()
	g.leg_skipped = {1: true, 2: true, 4: true, 5: true}
	g._take_tag(_tag("t_tally"))
	_ok("발품 — 네 판이면 20", g.gold == 20, "골드 %d" % g.gold)

	# ⑦ 주력 트랙 — 가장 많이 맞힌 트랙
	print("")
	var tracks := {}
	for a in GameData.areas_all():
		tracks[int(a.get("track", 0))] = true
	var tl: Array = tracks.keys()
	_fresh()
	g.track_hits = {int(tl[0]): 3, int(tl[1]): 9, int(tl[2]): 1}
	g._take_tag(_tag("t_hot"))
	_ok("주력 트랙 — 제일 많이 맞힌 트랙", int(g.track_lv.get(int(tl[1]), 0)) == 2,
			"%s Lv%d (나머지 %d/%d)" % [g._track_name(int(tl[1])),
					int(g.track_lv.get(int(tl[1]), 0)),
					int(g.track_lv.get(int(tl[0]), 0)),
					int(g.track_lv.get(int(tl[2]), 0))])
	#  한 발도 안 맞힌 런에서도 빈손이 아니어야 한다
	_fresh()
	g._take_tag(_tag("t_hot"))
	var any := 0
	for k2 in g.track_lv:
		any += int(g.track_lv[k2])
	_ok("한 발도 안 맞혔어도 빈손이 아니다", any == 2, "올린 단 합 %d" % any)

	# ⑧ 쌍둥이 — 다음 하나만 두 번, 그리고 쌓인다
	print("")
	_fresh()
	g._take_tag(_tag("t_twin"))
	_ok("쌍둥이는 그 자리에서 아무것도 안 준다",
			g.gold == 0 and int(g.tag_copy) == 1, "쌓인 수 %d" % g.tag_copy)
	g._take_tag(_tag("t_gold"))
	_ok("다음 뱃지가 두 번 걸린다", g.gold == 12, "골드 %d (삯 6 x2)" % g.gold)
	g._take_tag(_tag("t_gold"))
	_ok("그 다음 뱃지는 한 번만", g.gold == 18, "골드 %d" % g.gold)
	_fresh()
	g._take_tag(_tag("t_twin"))
	g._take_tag(_tag("t_twin"))
	g._take_tag(_tag("t_gold"))
	_ok("쌍둥이 둘이면 세 번 걸린다", g.gold == 18, "골드 %d (삯 6 x3)" % g.gold)

	# (9) 현상금 — 보스를 넘겨야 들어온다.
	#
	#    **차이로 잰다.** 판을 넘기면 정산이 판 보상·이자·잔탄 골드를 같이
	#    얹으므로 절대값으로 재면 그 몫까지 현상금으로 센다 — 처음에 그렇게
	#    재서 25 를 35 로 읽었다. 재는 자리가 아니라 세는 자리의 문제였다.
	print("")
	var boss_leg := 0
	for k3 in range(1, 12):
		if GameData.is_boss(k3):
			boss_leg = k3
			break

	_fresh()
	g.leg_no = boss_leg
	g.target = 1
	g.total = 99
	g._finish_leg()
	var plain_boss: int = g.gold

	_fresh()
	g._take_tag(_tag("t_boss"))
	_ok("현상금은 그 자리에서 안 준다", g.gold == 0 and g.pending_tags.size() == 1,
			"골드 %d · 쌓인 뱃지 %d" % [g.gold, g.pending_tags.size()])
	g.leg_no = boss_leg
	g.target = 1
	g.total = 99
	g._finish_leg()
	_ok("보스를 넘기면 25 가 더 붙는다", g.gold - plain_boss == 25,
			"뱃지 %d - 맨몸 %d = %d" % [g.gold, plain_boss, g.gold - plain_boss])
	_ok("받고 나면 쌓인 뱃지가 빈다", g.pending_tags.is_empty(),
			"남은 뱃지 %d" % g.pending_tags.size())

	_fresh()
	g.leg_no = 1
	g.target = 1
	g.total = 99
	g._finish_leg()
	var plain_small: int = g.gold
	_fresh()
	g._take_tag(_tag("t_boss"))
	g.leg_no = 1
	g.target = 1
	g.total = 99
	g._finish_leg()
	_ok("보스가 아닌 판에서는 안 나온다", g.gold == plain_small,
			"뱃지 %d · 맨몸 %d" % [g.gold, plain_small])
	_ok("안 받았으면 뱃지가 남아 있다", g.pending_tags.size() == 1,
			"남은 뱃지 %d" % g.pending_tags.size())

	#  마지막 판(라운드 8 보스)은 **정산 화면을 안 거친다** — 완주 갈래가
	#  먼저 돌아간다. 거기서도 치러지는지 본다. 이 골드가 「100골드 소지
	#  완주」(선금 다트통 해금)를 가른다.
	var last: int = GameData.legs_n()
	_fresh()
	g.leg_no = last
	g.target = 1
	g.total = 99
	g._finish_leg()
	var plain_last: int = g.gold
	_fresh()
	g._take_tag(_tag("t_boss"))
	g.leg_no = last
	g.target = 1
	g.total = 99
	g._finish_leg()
	_ok("마지막 판에서도 현상금이 들어온다", g.gold - plain_last == 25,
			"뱃지 %d - 맨몸 %d = %d (판 %d · 보스 %s)"
			% [g.gold, plain_last, g.gold - plain_last, last, GameData.is_boss(last)])

	# ⑩ 굴림 — 라운드마다 후보가 는다
	print("")
	var seen := {}
	for rd in [1, 3, 5]:
		var pool := {}
		for k4 in 4000:
			var r2 := GameData.tag_roll(rd)
			if not r2.is_empty():
				pool[String(r2.get("id", ""))] = true
		seen[rd] = pool.size()
	_ok("라운드가 오르면 후보가 는다",
			int(seen[1]) < int(seen[3]) and int(seen[3]) < int(seen[5]),
			"R1 %d → R3 %d → R5 %d가지" % [seen[1], seen[3], seen[5]])
	#  라운드 1 에 레어 견본이 안 뜬다
	var early := true
	for k5 in 4000:
		if String(GameData.tag_roll(1).get("id", "")) == "t_epic":
			early = false
	_ok("레어 견본은 라운드 1 에 안 뜬다", early, "4000번 굴림")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)


func func_all(got: Array, allowed: Array) -> bool:
	for k in got:
		if not allowed.has(k):
			return false
	return true
