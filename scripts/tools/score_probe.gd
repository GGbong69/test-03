extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  점수 검산 — 활성 스티커를 다섯 장씩 돌려 가며 전부 쥐여 보고,
#  매 발의 정산을 게임과 따로 셈해서 대 본다
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/score_probe.gd -- autoplay
#  종료 코드 = 어긋난 발의 수
#
#  왜 있는가
#    프로브 열다섯이 상점·매대·리그·설비·판 개조를 다 재는데, 정작
#    **점수 자체**를 재는 것이 없었다. 조건이 맞는지(cond_probe)와 그래서
#    몇 점이 나는지는 다른 질문이다. 조건이 서고도 점수에 안 실리는 길이
#    실제로 있었다 — mult_rand 가 정산의 match 갈래에 없어 소리 없이
#    사라졌던 자리가 그것이고, 그 흉터가 game.gd 의 push_error 로 남아 있다.
#
#  네 가지를 잰다
#    ① 큐 ↔ 조건   정산 큐에 오른 스티커가 곧 조건이 선 스티커인가.
#                  조건이 섰는데 큐에 없으면 점수에 안 실린 것이고,
#                  큐에 있는데 조건이 안 섰으면 남의 발에 얹힌 것이다.
#    ② 큐 → 점수   큐를 따로 굴려 나온 수가 게임이 적은 last_gain 과 같은가.
#                  걸음 하나가 조용히 빠지면 여기서 갈린다.
#    ③ 효과 갈래   큐에 오른 kind 가 정산이 아는 다섯 중 하나인가.
#    ④ 치역        점수·배수가 음수로 안 떨어지는가.
#
#  스티커를 쥐여 주는 법
#    오토플레이가 사는 것만 보면 99장 중 몇 장은 런이 끝나도록 안 나온다.
#    ROTATE 발마다 랙을 다음 다섯 장으로 갈아 끼워 전부 한 번씩 던지게 한다.
#    봉인(sealed)은 끈다 — 봉인은 shop_probe 가 따로 본다.
#
#  안 재는 것
#    연발(kick)의 작은 다트. _chip_gain 이 몫을 깎는 갈래라 셈이 다르고,
#    그건 toss_probe 의 자리다. 몇 발이 그래서 빠졌는지는 끝에 적는다.
# ══════════════════════════════════════════════════════════

const WARM := 2
const ROTATE := 12            # 이만큼 던지면 랙을 다음 다섯 장으로 간다
const ARM := 5                # 랙 칸 수와 같다
const STEPS := 600

var g: Node = null
var frames := 0
var last_n := 0
var seen := 0                 # 검산한 발
var skipped := 0              # 연발이라 건너뛴 발
var bad := 0
var logs := []                # 어긋난 자리. 앞의 몇 개만 찍는다
var items := []
var cursor := 0               # 다음에 쥐여 줄 스티커
var played := {}              # 스티커 id → 실제로 던져 본 발 수
var fired := {}               # 스티커 id → 점수에 실린 발 수
var min_mult := 999
var min_chip := 999
var pend := {}                # 정산이 끝나기를 기다리는 스냅샷


func _initialize() -> void:
	Save.path = "user://_probe_score.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260902)
	for it in GameData.items():
		played[String(it.id)] = 0
		fired[String(it.id)] = 0
		items.append(it)


# 다음 다섯 장으로 랙을 간다. 성장값은 0 에서 시작한다 — 산 순간의 규약이다.
func _arm() -> void:
	var rack := []
	for k in ARM:
		var it: Dictionary = items[(cursor + k) % items.size()].duplicate()
		it.gs = 0
		it.bought = g.leg_no
		rack.append(it)
	cursor = (cursor + ARM) % items.size()
	g.owned = rack
	g.sealed = -1


# 게임의 _score_combine 과 **같은 식**을 따로 쓴다. 부르면 검산이 아니다.
func _combine(chip: int, mult: int) -> int:
	if String(g.score_mode) == "bal":
		var x := int(round((float(chip) + float(mult)) * 0.5))
		return x * x
	return chip * mult


func _snap() -> void:
	var ctx: Dictionary = g.last_ctx
	if ctx.is_empty():
		return
	if bool(g.kick_pellet):
		skipped += 1
		return

	# ── ① 큐에 오른 스티커 ↔ 조건이 선 스티커
	var in_q := {}
	var kinds_ok := true
	var chip := 0
	var mult := 0
	for st in g.queue:
		match String(st.k):
			"chip", "pierce":
				chip += int(st.v)
			"mult":
				mult = int(st.v)
			"item":
				if st.has("i"):
					in_q[int(st.i)] = true
				match String(st.kind):
					"chip": chip += int(st.v)
					"mult", "mult_streak", "mult_rand": mult += int(st.v)
					"xmult": mult *= int(st.v)
					_: kinds_ok = false

	# 봉인은 발동을 막는다 — 게임의 fired 루프가 이 인덱스를 건너뛴다.
	# 「둔화」가 걸린 판은 랙을 갈아 끼운 뒤에도 다시 선다.
	var seal := int(g.sealed)
	var want := {}
	for i in g.owned.size():
		var it: Dictionary = g.owned[i]
		played[String(it.id)] = int(played[String(it.id)]) + 1
		if i == seal or String(it.k) == "save":
			continue      # 목숨은 정산이 아니라 판 실패가 읽는다
		if GameData.check(String(it.c), ctx):
			want[i] = true
			fired[String(it.id)] = int(fired[String(it.id)]) + 1

	# 큐에 없는데 조건이 선 장 — 수량이 0 이면 게임이 일부러 안 싣는다.
	# 그 경우만 빼고 나머지는 "점수에 안 실린" 것이다.
	for i in want:
		if in_q.has(i):
			continue
		var it: Dictionary = g.owned[i]
		# 성장(grow)을 쥔 장은 스냅샷 시점에 gs 가 이미 한 걸음 갔다 —
		# 큐를 지을 때의 수량을 여기서 되짚을 수 없으므로 뺀다.
		if String(it.get("grow", "")) != "":
			continue
		ctx.rackval_others = int(ctx.get("rackval_all", 0)) - GameData.sell_value(it)
		if GameData.item_amt(it, ctx) == 0 and String(it.get("k2", "")) == "":
			continue
		_fail("조건이 섰는데 큐에 없다", "%s(%s) 조건 %s · 칸 %d/%d · 봉인 %d · 큐 %d · 배수 %s · 빗나감 %s · 수량 %d"
				% [it.n, it.id, it.c, i, g.owned.size(), seal, g.queue.size(),
				str(ctx.get("mult", "?")), str(ctx.get("miss", "?")),
				GameData.item_amt(it, ctx)])
	for i in in_q:
		if not want.has(i):
			var it2: Dictionary = g.owned[i]
			_fail("큐에 있는데 조건이 안 섰다", "%s(%s) 조건 %s"
					% [it2.n, it2.id, it2.c])
	if not kinds_ok:
		_fail("정산이 모르는 효과 갈래가 큐에 있다", "")

	# ── ④ 치역
	min_chip = mini(min_chip, chip)
	min_mult = mini(min_mult, mult)
	if chip < 0 or mult < 0:
		_fail("점수·배수가 음수다", "chip %d · mult %d" % [chip, mult])

	# ── ② 정산이 끝나면 이 수와 대 본다
	pend = {"gain": _combine(chip, mult), "chip": chip, "mult": mult}
	seen += 1


func _settled() -> void:
	if pend.is_empty():
		return
	var got := int(g.last_gain)
	if got != int(pend.gain):
		_fail("정산 결과가 다르다", "따로 셈 %d (점수 %d × 배수 %d) · 게임 %d"
				% [pend.gain, pend.chip, pend.mult, got])
	pend = {}


func _fail(what: String, detail: String) -> void:
	bad += 1
	if logs.size() < 12:
		logs.append("%s — %s" % [what, detail])


# ── 카드가 적은 대로 내는가 — per 배율의 뜻을 직접 댄다 ──────
#  소크는 기본 팩(6발)만 돌아서 「기본에서 줄어든 다트」의 기본이 6 으로
#  박혀 있어도 안 걸린다. 팩이 그 수를 바꾸는 두 경우를 손으로 세운다.
func _per_check() -> void:
	var j079 := {}
	for it in GameData.items():
		if String(it.id) == "j079":
			j079 = it
	if j079.is_empty():
		return
	var v: int = int(j079.v)
	var cases := [
		# 이름                        기본  실제  기대 배수
		["기본 팩 · 안 줄었다",          6, 6, 0],
		["기본 팩 · 단벌",              6, 5, v],
		["기본 팩 · 단벌 + 곡예",        6, 3, v * 3],
		["넓은 랙(5발) · 안 줄었다",     5, 5, 0],
		["여벌 팩(7발) · 단벌",          7, 6, v],
	]
	for c in cases:
		var ctx := {"leg_base": c[1], "leg_darts": c[2],
				"sector": 5, "mult": 1, "miss": false}
		var got: int = GameData.item_amt(j079, ctx)
		if got != int(c[3]):
			_fail("압축 투척이 적은 대로 안 낸다",
					"%s — 기대 배수 +%d · 실제 +%d" % [c[0], c[3], got])


func _report() -> void:
	_per_check()
	print("\n── 점수 검산 ── 검산 %d발 · 연발이라 건너뜀 %d발\n" % [seen, skipped])
	if bad == 0:
		print("  어긋난 발 없음 — 큐·조건·갈래·치역 넷 다 맞는다")
	else:
		print("  ★ 어긋난 발 %d" % bad)
		for l in logs:
			print("    %s" % l)
	print("  점수 최소 %d · 배수 최소 %d (둘 다 0 이상이어야 한다)"
			% [min_chip, min_mult])

	var never := []
	var nofire := []
	for it in items:
		if int(played[String(it.id)]) == 0:
			never.append(it)
		elif int(fired[String(it.id)]) == 0 and String(it.c) != "" 				and String(it.k) != "save":
			nofire.append(it)
	print("\n  던져 본 스티커 %d / %d" % [items.size() - never.size(), items.size()])
	if not never.is_empty():
		var ids := []
		for it in never:
			ids.append(String(it.id))
		print("    한 번도 안 쥐어 본 장: %s" % " ".join(ids))
	if not nofire.is_empty():
		print("\n  쥐여 줬으나 한 번도 안 실린 장 %d" % nofire.size())
		for it in nofire:
			print("    %-6s %-18s %-10s %d발 쥠" % [it.id, it.n, it.c,
					played[String(it.id)]])

	print("\n%s" % ("전부 통과" if bad == 0 else "실패 %d" % bad))
	quit(bad)


func _process(_d: float) -> bool:
	frames += 1
	if frames == WARM:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
		_arm()
	g.set_process(false)
	for _i in STEPS:
		var q_before: int = g.queue.size()
		g._process(1.0 / 60.0)
		# 정산이 방금 끝났다 — last_gain 이 선 자리다
		if q_before > 0 and g.queue.is_empty():
			_settled()
		if g.land_n == last_n:
			continue
		last_n = g.land_n
		# 예열 구간에도 last_n 은 따라간다. 안 맞춰 두면 예열이 끝난
		# 첫 순간에 곧바로 어긋난 것으로 보이고, 그때 게임은 이미
		# 정산을 끝낸 뒤라 큐가 비어 있다 — 있지도 않은 버그가 뜬다.
		if frames <= WARM:
			continue
		_snap()
		if (seen + skipped) % ROTATE == 0:
			_arm()
		if seen >= items.size() * 18:
			_report()
			return false
	return false
