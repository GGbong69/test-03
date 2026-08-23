extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  칩 기여 측정기 — data/_stats.csv 를 덮어쓴다
#
#  실행:  godot --path . --headless --script scripts/tools/item_stats.gd
#
#  재는 것
#    발동률   그 칩의 조건이 다트 한 발에서 걸릴 확률
#    기여     그 칩 한 장이 다트당 더해 주는 점수의 기대값
#
#  기여를 재는 이유는 가격과 나란히 놓기 위해서다. 조건이 넓고 값이 작은 칩과
#  조건이 좁고 값이 큰 칩을 같은 자로 재야 비싼 값을 하는지 알 수 있다.
#
#  수량은 게임과 같은 GameData.item_amt 로 계산한다. 측정기가 제 셈을 하면
#  게임과 갈라진 날 표 전체가 조용히 거짓말이 된다.
#
#  전제 넷 — 이 넷이 바뀌면 표의 모든 수가 통째로 무의미해진다
#    ① 개조 없는 기본 판(board=base). 개조 여덟은 링 폭과 칸 값을 바꾸므로
#       "좁은 판" 제약 하나만 걸려도 링 조건 넉 장의 발동률이 반토막 난다.
#    ② 칩은 한 장만 들었다고 본다(build=solo). 다른 칩과의 곱은 안 본다.
#       보유량 배율은 이 전제를 그대로 따른다 — 아이템 1, 빈 슬롯 나머지,
#       랙의 남 판매가 0. 골드·무거운 다트 배율은 경제를 모사하지 않으므로
#       0 으로 적는다. 0 은 "못 번다" 가 아니라 "이 모델로는 못 잰다" 다.
#    ③ 조준은 게이지가 훑는 사각형 위 균등분포다(aim_model=uniform_sq).
#       실제 사람은 가운데를 노리므로 중앙 조건(불·중물)은 여기 값보다 더 자주,
#       가장자리 조건(더블·띠쟁이)은 덜 걸린다.
#    ④ 성장(grow)은 런 하나 길이(라운드 표 전부)를 창으로 잰다. 창이 끝나면
#       성장값을 비운다 — 6만 라운드를 연속으로 자라게 두면 기여가 무한대로
#       달아나고, 실제 런은 그만큼 길지 않다. rdec 파괴는 다시 산 것으로 친다.
#
#  시드를 박아 두 번 돌리면 같은 값이 나온다. 시드가 없으면 hvy 의 배수를
#  −1 에서 0 으로 바꿨을 때 움직인 0.3 이 효과인지 잡음인지 못 가린다.
# ══════════════════════════════════════════════════════════

const ROUNDS := 60000
const SEED := 20260821
const BOARD := "base"
const AIM := "uniform_sq"
const OUT := "res://data/_stats.csv"


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var items: Array = GameData.items()
	var n := items.size()
	var fire := []          # 발동 횟수
	var gain := []          # 점수 기여 합
	var clean_hit := []     # "무실책" 골드가 걸린 라운드 수
	fire.resize(n); fire.fill(0)
	gain.resize(n); gain.fill(0.0)
	clean_hit.resize(n); clean_hit.fill(0)
	for it in items:
		it.gs = 0

	var per_round: int = GameData.darts_of(1)
	var window: int = GameData.rounds_n()       # 성장 창 = 런 길이
	var darts := 0
	var base_sum := 0.0
	var miss := 0
	var clean_rounds := 0
	var risk_hits := 0      # risk50 골드용 — 라운드당 위험 명중 평균이 필요하다

	for r in ROUNDS:
		if r % window == 0:
			for it in items:
				it.gs = 0
		var last_sec := -1
		var last_miss := false
		var streak := 0
		var warm := false
		var round_miss := false
		# 라운드 패턴 추적 — 게임의 _land 후처리와 같은 규칙
		var sec_cnt := {}
		var zone_cnt := {}
		var pat := {}
		var seen_risk := false
		var low_hit := 0
		for d in per_round:
			var p := Vector2(
					g.BC.x + rng.randf_range(-g.SWING, g.SWING),
					g.BC.y + rng.randf_range(-g.SWING, g.SWING))
			var info: Dictionary = g.hit_info(p)
			darts += 1
			var is_miss: bool = info.mult == 0
			if is_miss:
				miss += 1
				round_miss = true
			var same: bool = info.sector > 0 and info.sector == last_sec
			streak = streak + 1 if same else 0
			var zone := ""
			if not is_miss:
				if info.idx == -1:
					zone = "bull"
				elif info.mult == 3:
					zone = "triple"
				elif info.mult == 2:
					zone = "double"
				else:
					zone = "single"
			var is_risk: bool = info.mult >= 2 or info.sector >= 25
			if is_risk and not is_miss:
				risk_hits += 1
			var ctx := {
				"sector": info.sector,
				"mult": info.mult,
				"miss": is_miss,
				"left": p.x < g.BC.x,
				"same": same,
				"first": d == 0,
				"last": d == per_round - 1,
				"streak": streak,
				"warm": warm,
				"missp": last_miss,
				"risk1": is_risk and not is_miss and not seen_risk,
				"few": per_round <= 3,
				"sixth": d == per_round - 1,   # 6발 라운드에선 매 여섯째 = 막발
				"pair": pat.get("pair", false),
				"trip": pat.get("trip", false),
				"quad": pat.get("quad", false),
				"pair2": pat.get("pair2", false),
				"spread": pat.get("spread", false),
				"zone3": pat.get("zone3", false),
				"zones2": pat.get("zones2", false),
				"zones4": pat.get("zones4", false),
				"rezone": zone != "" and zone_cnt.get(zone, 0) > 0,
				# 배율 재료 — 전제 ② 의 solo 값들
				"darts_left": per_round - 1 - d,
				"items_n": 1,
				"gold": 0,
				"mag_hvy": 0,
				"round_darts": per_round,
				"low": low_hit,
				"zonehist": zone_cnt.get(zone, 0) + 1 if zone != "" else 0,
				"empty_n": GameData.max_items() - 1,
				"rackval_others": 0,
				"rand01": rng.randf(),
			}
			var b: float = float(info.base)
			var m: float = float(info.mult)
			base_sum += b * m

			for i in n:
				var it: Dictionary = items[i]
				if GameData.check(it.c, ctx):
					fire[i] += 1
					if String(it.get("grow", "")) == "fire":
						it.gs = int(it.gs) + int(it.gstep)
					var amt := GameData.item_amt(it, ctx)
					gain[i] += _score_delta(String(it.k), amt, b, m)
					if String(it.get("k2", "")) != "":
						gain[i] += _score_delta(String(it.k2), int(it.v2), b, m)
				# 성장 걸음은 발동과 무관하게 매 발이다 — 게임과 같은 규칙
				match String(it.get("grow", "")):
					"hitmiss":
						it.gs = maxi(0, int(it.gs)
								+ (int(it.gstep) if not is_miss else -int(it.gstep)))
					"tdec":
						it.gs = int(it.gs) + 1
			if info.mult == 3:
				warm = true
			# 이력 갱신 — ctx 를 만든 뒤. 패턴은 다음 발부터 산다
			if zone != "":
				if info.sector >= 1 and info.sector <= 20:
					sec_cnt[info.sector] = int(sec_cnt.get(info.sector, 0)) + 1
				zone_cnt[zone] = int(zone_cnt.get(zone, 0)) + 1
				if is_risk:
					seen_risk = true
				if info.sector >= 1 and info.sector <= 20:
					low_hit = info.sector if low_hit == 0 else mini(low_hit, info.sector)
				var pairs := 0
				var maxrep := 0
				for kx in sec_cnt:
					maxrep = maxi(maxrep, int(sec_cnt[kx]))
					if int(sec_cnt[kx]) >= 2:
						pairs += 1
				if maxrep >= 2: pat.pair = true
				if maxrep >= 3: pat.trip = true
				if maxrep >= 4: pat.quad = true
				if pairs >= 2: pat.pair2 = true
				if sec_cnt.size() >= 3: pat.spread = true
				for kz in zone_cnt:
					if int(zone_cnt[kz]) >= 3:
						pat.zone3 = true
				if zone_cnt.size() >= 2: pat.zones2 = true
				if zone_cnt.size() >= 4: pat.zones4 = true
			last_sec = info.sector
			last_miss = is_miss
		# 라운드 끝 — rdec 감쇠. 0 에 닿으면 다시 산 것으로 친다(전제 ④)
		for it in items:
			if String(it.get("grow", "")) == "rdec":
				it.gs = int(it.gs) + 1
				if int(it.v) - int(it.gstep) * int(it.gs) <= 0:
					it.gs = 0
		if not round_miss:
			clean_rounds += 1
			for i in n:
				if items[i].get("g", "") == "clean":
					clean_hit[i] += 1

	var risk_per_round := float(risk_hits) / float(ROUNDS)
	var hash_src := _balance_hash()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line("id,name,rarity,cond,kind,value,cost,fire_pct,gain_per_dart,"
			+ "gain_per_round,gain_per_gold,gold_per_round,board,aim_model,samples,seed,_src_hash")
	for i in n:
		var it: Dictionary = items[i]
		var fp: float = 100.0 * float(fire[i]) / float(darts)
		var gp: float = float(gain[i]) / float(darts)
		var gr: float = gp * float(per_round)
		var gold: float = _gold_per_round(it,
				float(clean_hit[i]) / float(ROUNDS), risk_per_round)
		f.store_line("%s,%s,%s,%s,%s,%d,%d,%.2f,%.2f,%.2f,%.3f,%.2f,%s,%s,%d,%d,%s"
				% [it.id, it.n, it.rarity, String(it.c).replace(",", ";"), it.k, it.v, it.cost,
					fp, gp, gr, gp / float(it.cost), gold,
					BOARD, AIM, darts, SEED, hash_src])
	f.close()

	print("다트 %d발 · 빗나감 %.2f%% · 무실책 라운드 %.2f%% · 무개조 판 다트당 기본 %.2f점"
			% [darts, 100.0 * float(miss) / float(darts),
				100.0 * float(clean_rounds) / float(ROUNDS),
				base_sum / float(darts)])
	print("표 해시 %s — items.csv 의 밸런스 열이 바뀌면 이 값이 달라진다" % hash_src)
	quit()


# 한 발에서 이 효과가 늘리는 점수. solo 전제라 다른 칩의 배수는 없다.
func _score_delta(kind: String, amt: int, b: float, m: float) -> float:
	match kind:
		"chip":
			return float(amt) * maxf(m, 1.0)
		"mult", "mult_streak", "mult_rand":
			return b * float(amt)
		"xmult":
			return b * m * (float(amt) - 1.0)
	return 0.0     # save · 빈 kind — 점수 밖에서 일한다


# 라운드당 골드. 모델이 여섯 발을 다 던지므로 남은 다트에 걸린 것은 못 잰다.
func _gold_per_round(it: Dictionary, clean_p: float, risk_pr: float) -> float:
	if String(it.get("g", "")) == "":
		return 0.0
	var gv := float(it.gv)
	match String(it.g):
		"clear": return gv          # 넘긴 라운드마다. 모델은 늘 넘긴다고 본다
		"clean": return gv * clean_p
		"broke": return gv          # 보유 골드 조건은 이 모델 밖이다
		"round": return gv
		"risk50": return gv * 0.5 * risk_pr
		"spare", "blitz": return 0.0   # 남은 다트를 모사하지 않는다
	return 0.0


# items.csv 에서 밸런스에 영향을 주는 열만 이어 붙여 해시한다. 파일 수정
# 시각을 쓰면 git 체크아웃마다 "낡았다" 가 뜨고, 늑대 소년 경고는 없는
# 경고보다 나쁘다. 이름이나 _note 만 고친 커밋은 통계를 안 낡게 만든다.
func _balance_hash() -> String:
	var parts := PackedStringArray()
	for r in GameData.rows("items"):
		parts.append("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
			r.get("id", ""), r.get("cond", ""), r.get("kind", ""),
			r.get("value", ""), r.get("cost", ""), r.get("gold", ""),
			r.get("gv", ""), r.get("enabled", ""),
			r.get("per", ""), r.get("k2", ""), r.get("v2", ""),
			r.get("grow", ""), r.get("gstep", ""), r.get("boom", ""),
			r.get("dadd", ""), r.get("side", ""), r.get("secs", "")])
	return "|".join(parts).md5_text().substr(0, 12)
