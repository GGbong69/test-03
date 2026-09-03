extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  조건 전수 검사 — 활성 동전 한 장 한 장을 실제로 플레이해 본다
#
#  실행:  godot --path . --headless --quit-after 900000 \
#             -s scripts/tools/cond_probe.gd -- autoplay
#  종료 코드 = 죽은 동전 수 + ctx 에 빠진 열 수
#
#  왜 있는가
#    「지정색 증폭기 B」가 설명대로 안 먹었다. 원인은 조건식이 아니라
#    _land 의 ctx 에 col 열이 없던 것이었다 — check() 는 없는 열을 기본값으로
#    읽고 조용히 거짓을 냈다. 측정기(item_stats)도 제 ctx 를 따로 지어서
#    같은 열이 빠져 있었고, 그래서 36만 표본이 발동률 0.00 을 찍고도
#    아무도 안 울렸다. 조용히 죽는 이 길을 막는 것이 이 프로브의 일이다.
#
#  어떻게 재는가
#    게임을 오토플레이로 돌리고, 매 발마다 **게임이 만든 그 ctx**(g.last_ctx)를
#    받아 활성 동전 전부의 check() 를 다시 돌린다. 제 문맥을 짓지 않는다 —
#    그게 이 버그를 놓친 이유이기 때문이다.
#
#  두 자로 잰다
#    ① ctx 열 대조 — check() 가 읽는 열이 게임의 산 ctx 에 실제로 있는가.
#       조건 이름과 열 이름이 같은 것이 규약이라, 새 조건을 달고 열을
#       안 실으면 _keys_of 의 기본 갈래가 저절로 잡는다.
#    ② 실전 소크 — 2500발을 돌려 어느 동전가 한 번이라도 걸리는가.
#       0회인 장은 측정기 표(36만 표본)와 대 본다. 거기서도 0.00 이면
#       확률이 낮은 것이 아니라 길이 막힌 것이다.
#
#  소크가 못 보는 것 — 판정 전에 알고 있어야 한다
#    · 오토플레이는 판 안에만 꽂는다(_land). 빗나감 조건은 소크에서 영영
#      안 걸리므로 측정기 표로만 판단한다.
#    · 측정기는 동전를 **한 장씩** 재고 판은 무보드 확장 기본판이다. 다른
#      동전나 보드 확장가 있어야 서는 조건은 두 자 모두에서 0 으로 나온다.
#      그건 "죽었다" 가 아니라 "이 자로는 못 잰다" 다 — 그래서 3단이 있다.
#
#  ③ 표적 검사 — 두 자가 못 보는 길을 손으로 걸어 본다
#    few(다트 3개 이하)가 그것이다. 기본 6발에서 「곡예 다트맨」(-2)과
#    「단벌」(-1)이 **같이** 있어야 3발이 된다. 둘을 쥐여 주고 한 발을
#    던져서 실제로 서는지 본다.
# ══════════════════════════════════════════════════════════

const WARM := 2               # ctx 가 처음 서기까지 버리는 프레임
# 실전 소크 길이. 게임 한 프레임이 무거워서(초당 160프레임) 발당 80프레임을
# 먹는다 — 수십만 발은 못 던진다. 넓은 조건이 실제로 걸리는지와 ctx 열이
# 성한지를 보는 데는 이 정도면 되고, 좁은 조건은 측정기 표와 댄다.
const MIN_DARTS := 2500
# 한 엔진 프레임에 게임을 이만큼 굴린다. 엔진 프레임과 1:1 로 두면
# 2500발에 20분이 든다.
const STEPS := 600

var g: Node = null
var frames := 0
var seen := 0                 # 처리한 발 수
var last_n := 0
var fire := {}                # 동전 id → 걸린 횟수
var cond_fire := {}           # 조건 문자열 → 걸린 발 수 (발당 한 번만 센다)
var items := []
var missing := {}             # ctx 에 없던 열 → 그 열을 읽는 동전 id 들
var stat := {}                # data/_stats.csv 의 발동률. 희귀와 죽음을 가른다
var aim_n := 0                # 3단 — 표적 검사가 쓴 발 수
var aim_ok := {}              # 표적 검사 결과. 조건 → 실제로 섰는가


func _initialize() -> void:
	Save.path = "user://_probe_cond.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20260902)
	items = GameData.items()
	for it in items:
		fire[String(it.id)] = 0
		cond_fire[String(it.c)] = 0
	_load_stats()


# 36만 표본짜리 측정기 표. 실전 소크에서 0회인 동전가 여기서도 0.00 이면
# 확률이 낮은 것이 아니라 길이 막힌 것이다 — 그 둘을 가르는 자다.
func _load_stats() -> void:
	var f := FileAccess.open("res://data/_stats.csv", FileAccess.READ)
	if f == null:
		return
	var head := f.get_csv_line()
	var ci := head.find("fire_pct")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > ci and String(row[0]) != "":
			stat[String(row[0])] = float(row[ci])


# item_amt 의 per 배율이 읽는 열. 조건과 달리 이름이 열과 다르므로 적어 둔다.
# 「기본에서 줄어든 다트」가 기본을 6 으로 박아 두고 있던 것을 이 축이 잡았다.
const PER_KEYS := {
	"darts_left": ["darts_left"], "items": ["items_n"],
	"gold": ["gold"], "gold5": ["gold"], "mag_hvy": ["mag_hvy"],
	"missing": ["leg_base", "leg_darts"], "low": ["low"],
	"zonehist": ["zonehist"], "rackval": ["rackval_all"],
	"empty": ["empty_n"],
}

# kind 가 읽는 열. mult_streak 은 streak 을, mult_rand 는 rand01 을 판다.
const KIND_KEYS := {"mult_streak": ["streak"], "mult_rand": ["rand01"]}


# check() 가 읽는 열. 조건 이름 = 열 이름이 규약이라 기본 갈래가 그것을
# 그대로 쓴다 — 새 조건을 달고 ctx 에 열을 안 실으면 여기서 잡힌다.
# 아래 다섯 줄은 이름과 열이 다른 예외들이다.
func _keys_of(c: String) -> PackedStringArray:
	if c == "":
		return PackedStringArray([])          # 조준·골드 전용 장. 조건이 없다
	if c.begins_with("sec:"):
		return PackedStringArray(["sector"])
	if c.begins_with("col:"):
		return PackedStringArray(["col"])
	match c:
		"always": return PackedStringArray([])
		"triple", "double", "band": return PackedStringArray(["mult"])
		"bull", "odd", "even", "big", "mid", "small": return PackedStringArray(["sector"])
		"left", "right": return PackedStringArray(["left"])
		"diff": return PackedStringArray(["same"])     # not same 이다
		"risk": return PackedStringArray(["mult", "sector"])
		_: return PackedStringArray([c])


func _tally() -> void:
	var ctx: Dictionary = g.last_ctx
	if ctx.is_empty():
		return
	seen += 1
	var hit_c := {}          # 이 발에 선 조건들. 여러 장이 같은 조건을 쥔다
	for it in items:
		var c := String(it.c)
		var need := Array(_keys_of(c))
		need += PER_KEYS.get(String(it.get("per", "")), [])
		need += KIND_KEYS.get(String(it.get("k", "")), [])
		for k in need:
			if not ctx.has(k):
				if not missing.has(k):
					missing[k] = {}
				missing[k][String(it.id)] = true
		if c != "" and GameData.check(c, ctx):
			fire[String(it.id)] = int(fire[String(it.id)]) + 1
			hit_c[c] = true
	for c in hit_c:
		cond_fire[c] = int(cond_fire[c]) + 1


# ── 3단. 두 자가 못 보는 길을 손으로 깐다 ──────────────────
#  few 는 판 시작 다트가 3개 이하여야 선다. 기본 6발이므로 「곡예
#  다트맨」(dadd -2)과 「단벌」(darts_add -1)을 같이 쥐여 줘야 3발이 된다.
#  _start_leg 가 그 셈을 하는 유일한 자리라 그것을 다시 부른다.
func _aim_arm() -> void:
	var acro := {}
	for it in GameData.items():
		if String(it.id) == "j138":
			acro = it.duplicate()
	var short := {}
	for m in GameData.modifiers():
		if String(m.id) == "short":
			short = m
	if acro.is_empty() or short.is_empty():
		return
	acro.gs = 0
	g.owned = [acro]
	g.active_mods = [short]
	g._start_leg()


func _aim_check() -> void:
	var ctx: Dictionary = g.last_ctx
	if ctx.is_empty():
		return
	aim_n += 1
	if bool(ctx.get("few", false)):
		aim_ok["few"] = true


func _report() -> void:
	print("\n── 조건 전수 검사 ── 다트 %d발 · 활성 동전 %d장\n" % [seen, items.size()])

	if not missing.is_empty():
		print("  ★ ctx 에 없는 열 — 그 조건은 조용히 거짓이 된다")
		for k in missing:
			var who: Array = missing[k].keys()
			who.sort()
			print("    %-10s ← %s" % [k, " ".join(who)])
		print("")

	var noc := []            # 조건 자체가 없는 장 — 조준·골드가 본업이다
	var never := []          # 소크 0회 · 측정기도 0.00 · 표적 검사도 못 세움
	var rareo := []          # 소크 0회 · 표에는 있다. 그냥 희귀하다
	var byot := []           # 표적 검사가 세운 것 — 다른 장이 있어야 선다
	for it in items:
		if String(it.c) == "":
			noc.append(it)
		elif int(fire[String(it.id)]) == 0:
			if bool(aim_ok.get(String(it.c), false)):
				byot.append(it)
			elif float(stat.get(String(it.id), 0.0)) <= 0.0:
				never.append(it)
			else:
				rareo.append(it)

	if never.is_empty():
		print("  두 자 모두에서 0인 동전 없음")
	else:
		print("  ★ 두 자 모두 0 — 소크 %d발 0회 · 측정기 36만 표본 0.00%%" % seen)
		for it in never:
			print("    %-6s %-18s %-10s %s" % [it.id, it.n, it.c,
					GameData.cond_text(String(it.c))])
	if not rareo.is_empty():
		print("\n  소크에선 못 봤다 — 표에는 있으므로 희귀할 뿐이다")
		for it in rareo:
			print("    %-6s %-18s %-10s 측정기 %.3f%%" % [it.id, it.n, it.c,
					float(stat.get(String(it.id), 0.0))])
	if not byot.is_empty():
		print("\n  표적 검사에서 섰다 — 혼자서는 못 서고 다른 장이 있어야 한다")
		for it in byot:
			print("    %-6s %-18s %-10s %s" % [it.id, it.n, it.c,
					GameData.cond_text(String(it.c))])
	if not noc.is_empty():
		var ids := []
		for it in noc:
			ids.append(String(it.id))
		print("\n  조건 없는 장 %d개 — 조준·골드가 본업이라 셈에서 뺀다" % noc.size())
		print("    %s" % " ".join(ids))

	print("\n  조건별 발동률 (소크 %d발 · 발당 한 번만 센다)" % seen)
	var keys := cond_fire.keys()
	keys.sort()
	for c in keys:
		if String(c) == "":
			continue
		print("    %-14s %6.2f%%   %s" % [c,
				100.0 * float(cond_fire[c]) / float(maxi(seen, 1)),
				GameData.cond_text(String(c))])

	var bad := never.size() + missing.size()
	print("\n%s" % ("전부 통과" if bad == 0 else "실패 %d" % bad))
	quit(bad)


func _process(_d: float) -> bool:
	frames += 1
	# 오토플레이가 이미 빠른 값을 깔지만(beat 0.10) 정산 연출이 여전히
	# 발당 140프레임을 먹는다. 프로브는 연출을 안 보므로 더 조인다 —
	# 판정에 쓰는 값은 하나도 안 건드린다. _ready 가 첫 프레임에야 돌므로
	# _initialize 에서 만지면 덮인다 — 둘째 프레임이 유일한 자리다.
	if frames == WARM:
		g.beat = 0.015
		g.gauge_speed = 8.0
		g.confirm_hold = 0.0
	g.set_process(false)
	for _i in STEPS:
		g._process(1.0 / 60.0)
		if g.land_n == last_n:
			continue
		last_n = g.land_n
		# 예열 구간에도 last_n 은 따라간다. 안 맞춰 두면 예열이 끝난
		# 첫 순간에 곧바로 어긋난 것으로 보이고, 그때 게임은 이미
		# 정산을 끝낸 뒤라 큐가 비어 있다 — 있지도 않은 버그가 뜬다.
		if frames <= WARM:
			continue
		if seen < MIN_DARTS:
			_tally()
			# 소크가 끝나는 그 발에서 3단을 깐다 — 동전 슬롯과 제약을 갈아 끼우고
			# 판을 다시 연다. 여기부터의 발은 소크 셈에 안 들어간다.
			if seen >= MIN_DARTS:
				_aim_arm()
		else:
			_aim_check()
			# 3발 판라 한 판면 충분하다. 넉넉히 보고 닫는다.
			if aim_n >= 3:
				_report()
				return false
	return false
