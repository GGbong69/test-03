extends RefCounted

const GameData = preload("res://scripts/data.gd")
# ══════════════════════════════════════════════════════════
#  게임 조건 → 음악 상태
# ──────────────────────────────────────────────────────────
#  조건을 읽는 자리를 **한 곳으로 모은다.** 상점을 닫을 때 무조건 Main 을
#  보내면 마지막 라운드에서 상점을 닫았을 때 Final 이 사라진다 — 나가는
#  자리마다 "무엇으로 돌아갈지"를 따로 적으면 반드시 그런 구멍이 생긴다.
#  그래서 나갈 때도 **지금 조건 전부를 다시 읽는다.**
#
#  우선순위는 명세가 정한 대로 Shop > Final > Aim > Main 이다.
# ══════════════════════════════════════════════════════════


static func resolve(shop_open: bool, final_round_active: bool, aiming: bool) -> StringName:
	if shop_open:
		return &"Shop"
	if final_round_active:
		return &"Final"
	if aiming:
		return &"Aim"
	return &"Main"


# 하이톤의 화면 상태를 명세의 넷으로 옮긴다.
#
#  이 게임에는 명세가 가정한 "마지막 라운드" 가 그대로는 없다. 대신 판이
#  라운드마다 셋(작은·큰·보스)이고 보스는 못 건너뛴다. 긴장이 가장 높은
#  자리가 보스 판이므로 **보스를 Final 로 읽는다** — 마지막 라운드의 보스만
#  Final 로 잡으면 여덟 보스 중 일곱이 평범한 판과 같은 소리가 된다.
#
#  조준(AIM_V·AIM_H·CONFIRM)이 Aim 이다. 날아가는 중(FLY)과 정산(RESOLVE)은
#  Aim 이 아니다 — 손을 뗀 뒤라 긴장의 성질이 다르다.
#
#  덮개 화면(런 정보·일시정지)은 **뒤 화면을 따른다.** 잠깐 여는 판 때문에
#  음악이 바뀌면 그게 더 눈에 띈다. game.gd 의 _mus_want 가 쓰는 규칙과 같다.
static func from_game(g: Object) -> StringName:
	var s: int = g.state
	if s == g.S.RUNINFO:
		s = g.run_from
	elif s == g.S.SETTINGS and g.pause_from >= 0:
		s = g.pause_from

	var shop_open: bool = (s == g.S.SHOP)
	var boss := false
	var aiming := false
	match s:
		g.S.TITLE, g.S.SETTINGS, g.S.COLLECT, g.S.NEWRUN, g.S.OVER, \
		g.S.STAGE, g.S.SHOP, g.S.LEG, g.S.CLEAR:
			pass                      # 판 밖 — 조준도 보스도 아니다
		_:
			boss = GameData.is_boss(g.leg_no)
			aiming = s in [int(g.S.AIM_V), int(g.S.AIM_H), int(g.S.CONFIRM)]
	return resolve(shop_open, boss, aiming)
