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
#  전제 셋 — 이 셋이 바뀌면 표의 모든 수가 통째로 무의미해진다
#    ① 개조 없는 기본 판(board=base). 개조 여덟은 링 폭과 칸 값을 바꾸므로
#       "좁은 판" 제약 하나만 걸려도 링 조건 넉 장의 발동률이 반토막 난다.
#    ② 칩은 한 장만 들었다고 본다(build=solo). 다른 칩과의 곱은 안 본다.
#    ③ 조준은 게이지가 훑는 사각형 위 균등분포다(aim_model=uniform_sq).
#       실제 사람은 가운데를 노리므로 중앙 조건(불·중물)은 여기 값보다 더 자주,
#       가장자리 조건(더블·띠쟁이)은 덜 걸린다.
#    그래서 이 표는 상한도 하한도 아닌 기준선이다.
#
#  골드 반쪽 — 모델은 여섯 발을 항상 다 던진다. 라운드를 일찍 끝내는 것을
#  모사하지 않으므로 남은 다트가 늘 0 이고, 그래서 spare·blitz 는 0 으로
#  적는다. 0 은 "그 칩이 골드를 못 번다" 가 아니라 "이 모델로는 못 잰다" 다.
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

	var per_round: int = GameData.darts_of(1)
	var darts := 0
	var base_sum := 0.0
	var miss := 0
	var clean_rounds := 0

	for r in ROUNDS:
		var last_sec := -1
		var streak := 0
		var warm := false
		var round_miss := false
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
			}
			var b: float = float(info.base)
			var m: float = float(info.mult)
			base_sum += b * m

			for i in n:
				var it: Dictionary = items[i]
				if not GameData.check(it.c, ctx):
					continue
				fire[i] += 1
				# 이 칩 한 장만 들었을 때 늘어나는 점수
				match String(it.k):
					"chip":
						gain[i] += float(it.v) * maxf(m, 1.0)
					"mult":
						gain[i] += b * float(it.v)
					"xmult":
						gain[i] += b * m * (float(it.v) - 1.0)
					"mult_streak":
						gain[i] += b * float(it.v) * float(streak)
			if info.mult == 3:
				warm = true
			last_sec = info.sector
		if not round_miss:
			clean_rounds += 1
			for i in n:
				if items[i].get("g", "") == "clean":
					clean_hit[i] += 1

	var hash_src := _balance_hash()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line("id,name,rarity,cond,kind,value,cost,fire_pct,gain_per_dart,"
			+ "gain_per_round,gain_per_gold,gold_per_round,board,aim_model,samples,seed,_src_hash")
	for i in n:
		var it: Dictionary = items[i]
		var fp: float = 100.0 * float(fire[i]) / float(darts)
		var gp: float = float(gain[i]) / float(darts)
		var gr: float = gp * float(per_round)
		var gold: float = _gold_per_round(it, float(clean_hit[i]) / float(ROUNDS))
		f.store_line("%s,%s,%s,%s,%s,%d,%d,%.2f,%.2f,%.2f,%.3f,%.2f,%s,%s,%d,%d,%s"
				% [it.id, it.n, it.rarity, it.c, it.k, it.v, it.cost,
					fp, gp, gr, gp / float(it.cost), gold,
					BOARD, AIM, darts, SEED, hash_src])
	f.close()

	print("다트 %d발 · 빗나감 %.2f%% · 무실책 라운드 %.2f%% · 무개조 판 다트당 기본 %.2f점"
			% [darts, 100.0 * float(miss) / float(darts),
				100.0 * float(clean_rounds) / float(ROUNDS),
				base_sum / float(darts)])
	print("표 해시 %s — items.csv 의 밸런스 열이 바뀌면 이 값이 달라진다" % hash_src)
	quit()


# 라운드당 골드. 모델이 여섯 발을 다 던지므로 남은 다트에 걸린 것은 못 잰다.
func _gold_per_round(it: Dictionary, clean_p: float) -> float:
	if not it.has("g"):
		return 0.0
	var gv := float(it.gv)
	match String(it.g):
		"clear": return gv          # 넘긴 라운드마다. 모델은 늘 넘긴다고 본다
		"clean": return gv * clean_p
		"broke": return gv          # 보유 골드 조건은 이 모델 밖이다
		"spare", "blitz": return 0.0   # 남은 다트를 모사하지 않는다
	return 0.0


# items.csv 에서 밸런스에 영향을 주는 열만 이어 붙여 해시한다. 파일 수정
# 시각을 쓰면 git 체크아웃마다 "낡았다" 가 뜨고, 늑대 소년 경고는 없는
# 경고보다 나쁘다. 이름이나 _note 만 고친 커밋은 통계를 안 낡게 만든다.
func _balance_hash() -> String:
	var parts := PackedStringArray()
	for r in GameData.rows("items"):
		parts.append("%s|%s|%s|%s|%s|%s|%s|%s" % [
			r.get("id", ""), r.get("cond", ""), r.get("kind", ""),
			r.get("value", ""), r.get("cost", ""), r.get("gold", ""),
			r.get("gv", ""), r.get("enabled", "")])
	return "|".join(parts).md5_text().substr(0, 12)
