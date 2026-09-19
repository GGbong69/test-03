extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  이어하기 검사 — 적고 → 껐다 켜고 → 되살린 뒤 **한 칸씩** 댄다
#
#  실행:  godot --headless --path . --script scripts/tools/resume_probe.gd
#         … --script scripts/tools/resume_probe.gd -- pass2   (…3 4 5 6 7 8)
#  종료 코드 = 실패 개수. **차수를 이 순서로 돌려야 한다.**
#
#  **두 번 돌려야 진짜 검사다.** save_probe 머리말의 그 한 문장이 이 검사의
#  뼈대다 — 한 프로세스 안에서 쓰고 읽는 것은 ConfigFile 이 메모리에 들고
#  있는 값을 다시 보는 것뿐이라 디스크에 안 닿아도 통과한다. 그래서 짝수
#  차수가 **새 프로세스**에서 읽는다.
#
#    0차 (모든 차수의 첫 줄) — **사람 저장 방어.** 붉으면 곧장 죽는다
#    1차 — 매듭 셋에서 적고 죽는다 (상점 매듭을 남긴다)
#    2차 — 새 프로세스에서 되살려 **한 칸씩** 댄다 · 파생 · 공짜 리롤 방어
#    3차 — 못 읽는 저장 · 옛 판 · 표가 바뀐 척
#    4차 — 판 첫머리 매듭을 적고 죽는다 (봉인 · 목표물 · 칸 섞기)
#    5차 — 되감기가 **무르기**인가(리롤이 아닌가) · 뱃지를 두 번 안 먹는가
#    6차 — 지우는 자리 넷과 「로비로 나가기」 · 슬롯
#    7차 — 제목 자리와 겨눔 · 「글자가 안 늘었다」
#    8차 — 값은 나갔는데 매듭이 안 적히던 자리들 (2026-09-20 검토)
#
#  ⚠ 비교는 **한 칸씩** 한다. 통째로 대면 어느 칸이 어긋났는지가 로그에
#  안 남아, 붉어진 다음에 다시 사람이 읽어야 한다.
# ══════════════════════════════════════════════════════════

const PROBE := "user://_resume_probe.cfg"
const GPROBE := "user://_resume_probe_g.cfg"
#  0차가 「파일이 안 늘었다」를 재고 버리는 자리. 검사 파일과 가른다 —
#  같이 쓰면 0차의 뒷정리가 1차가 남긴 절을 지운다.
const GUARD := "user://_resume_guard.cfg"
#  1차·4차가 **살아 있는 변수**를 여기 따로 덤프한다. 2차·5차가 댈 자다.
#  이어하기 절과 갈라 두는 이유: 절을 그대로 대면 「적힌 것이 적힌 대로
#  돌아왔다」만 재게 된다. 재려는 것은 **런이 같은 런인가**다.
const WANT := "user://_resume_want.cfg"
const WS := "want"

var fails := 0
var g = null


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-46s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


#  같은가를 **한 칸씩** 묻는다. 어긋나면 양쪽을 다 찍는다.
func _eq(name: String, got: Variant, want: Variant) -> void:
	var ok: bool = str(got) == str(want)
	_say(ok, name, "" if ok else "%s  ←  바란 것 %s" % [str(got), str(want)])


# ── 0차 — 사람의 저장을 안 건드린다는 것을 **첫 줄에서** 증명한다 ──
#  이것이 붉으면 아래 검사는 전부 무의미하다. 곧장 죽는다.
func _guard() -> void:
	print("0차 — 사람의 저장을 안 건드린다")
	#  아직 아무것도 안 박은 상태에서 묻는다 — 도구가 **저절로** 제 자리로
	#  돌아가는가(save.gd 의 _tool_run → TOOL_PROF).
	_say(Save.slot_path(1) == Save.TOOL_PROF % 1, "도구 자리로 저절로 돌아갔다",
			Save.slot_path(1))
	_say(not Save.slot_path(1).begins_with("user://profile_"),
			"사람 프로필을 안 연다")
	_say(not Save.allow_real, "진짜 저장을 안 쓴다")
	if fails > 0:
		print("\n0차가 붉다 — 아래를 안 돈다")
		quit(125)
		return
	#  **절이지 새 파일이 아니다.** 새 파일을 팠다면 user:// 의 .cfg 수가 는다.
	#  ⚠ 이 재기는 **버리는 파일**에서 한다. 검사 파일(PROBE)에서 했더니
	#  끝의 run_drop() 이 1차가 남긴 절을 지워, 2차가 빈손으로 시작했다.
	Save.gpath = GPROBE
	Save.path = GUARD
	Save.flush()                # 파일부터 세운다 — 그 다음에 센다
	var before := _cfg_files()
	Save.run_set("ver", Save.RUN_VER)
	Save.flush()
	_say(_cfg_files() == before, "파일이 안 늘었다 — 절이지 새 파일이 아니다",
			"%d개" % before.size())
	#  이제 검사 파일로 옮긴다. boot() 이 _at != want 면 다시 읽으므로
	#  경로만 바꿔 두면 된다.
	Save.path = PROBE


func _cfg_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("user://")
	if d == null:
		return out
	for f in d.get_files():
		if String(f).ends_with(".cfg"):
			out.append(String(f))
	out.sort()
	return out


func _initialize() -> void:
	var which := "pass1"
	for a in OS.get_cmdline_user_args():
		which = String(a)
	_guard()
	if fails > 0:
		quit(mini(fails, 125))
		return
	print("")
	match which:
		"pass2": _pass2()
		"pass3": _pass3()
		"pass4": _pass4()
		"pass5": _pass5()
		"pass6": _pass6()
		"pass7": _pass7()
		"pass8": _pass8()
		_: _pass1()
	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "전부 통과"))
	quit(mini(fails, 125))


func _game() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.drop_fast = true          # 도구는 팔을 안 기다린다


# ── 살아 있는 상태의 한 장 ──────────────────────────────
#  **적는 목록과 따로 세운다.** 같은 표를 쓰면 「적는 것을 적은 대로
#  돌려줬다」만 재게 된다. 여기는 파생까지 같이 담는다.
func _snap() -> Dictionary:
	var ow := []
	for o in g.owned:
		ow.append([String(o.get("id", "")), int(o.get("gs", 0)),
				int(o.get("bought", 0))])
	var st := []
	for s in g.stock:
		st.append([String(s.type), String((s.d as Dictionary).get("id", "")),
				int(s.cost), bool(s.sold), bool(s.get("free", false)),
				bool(s.get("pack", false))])
	var lt := {}
	for k in g.leg_tags:
		lt[int(k)] = String((g.leg_tags[k] as Dictionary).get("id", ""))
	return {
		# ── 뼈대 ──
		"at": String(Save.run_get("at", "")),
		"slot": Save.slot(),
		"seed": g.run_seed,
		"rng": g.knot_rng,
		#  ⚠ **실제로 선 행**을 댄다. GameData.pack 은 빈 값일 수 있고
		#  (「빈 값이면 표의 첫 행」), 되살리면 그 첫 행의 id 로 풀려 적힌다 —
		#  글자는 달라도 **같은 다트통**이다. 여기서 raw 를 대면 뜻이 같은
		#  것을 틀렸다고 찍는다.
		"pack": String(GameData.pack_row().get("id", "")),
		"league": String(GameData.league_row().get("id", "")),
		"challenge": GameData.challenge,
		# ── 런 단위 진도 ──
		"leg_no": g.leg_no, "gold": g.gold, "throw6": g.throw6,
		"shop_seen": g.shop_seen, "bought_item": g.bought_item,
		"carry_darts": g.carry_darts,
		"track_lv": g.track_lv.duplicate(true),
		"track_hits": g.track_hits.duplicate(true),
		"zone_hist": g.zone_hist.duplicate(true),
		"run_unlocked": g.run_unlocked.duplicate(true),
		# ── 손에 든 것 ──
		"owned": ow,
		"cons": _ids(g.cons),
		"magazine": _ids(g.magazine),
		"mods_own": PackedStringArray(g.mods_own),
		# ── 뱃지 ──
		"leg_tags": lt, "leg_tags_round": g.leg_tags_round,
		"leg_skipped": g.leg_skipped.duplicate(true),
		"pending_tags": g.pending_tags.duplicate(true),
		"tag_copy": g.tag_copy,
		# ── 보스 ──
		"boss_mods": g.boss_mods.duplicate(true),
		"boss_void": g.boss_void.duplicate(true),
		"boss_seen": PackedStringArray(g.boss_seen),
		# ── 상점 ──
		"stock": st, "reroll_cost": g.reroll_cost,
		"rerolls_used": g.rerolls_used,
		# ── 파생 — 적는 것이 아니라 **다시 낸 것** ──
		#  적는 것만 맞고 다시 낸 것이 틀리면 저장은 초록인데 런이 다르다.
		"sectors": PackedInt32Array(g.sectors),
		"bull_i": g.bull_i, "bull_o": g.bull_o,
		"trp_in": g.trp_in, "trp_out": g.trp_out,
		"trp2_in": g.trp2_in, "trp2_out": g.trp2_out,
		"dbl_in": g.dbl_in, "dbl_out": g.dbl_out,
		"m_sgl": g.m_sgl, "m_dbl": g.m_dbl, "m_trp": g.m_trp,
		"m_bull": g.m_bull,
		"score_mode": g.score_mode, "aim_mode": g.aim_mode,
		"leg_tag": String(g.leg_tag.get("id", "")),
		# ── 이어하기가 **안 밀어야** 하는 것 ──
		"runs": Save.stat("runs"),
		"taught_n": Save.unlock_keys().size(),
	}


func _ids(rows: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in rows:
		out.append(String(r.get("id", "")))
	return out


func _dump(snap: Dictionary) -> void:
	var c := ConfigFile.new()
	for k in snap:
		c.set_value(WS, String(k), snap[k])
	c.save(WANT)


func _load_want() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(WANT)
	return c


# ══════════════════════════════════════════════════════════
#  1차 — 매듭 셋에서 적는다. 상점 매듭을 남기고 죽는다
# ══════════════════════════════════════════════════════════
func _pass1() -> void:
	print("1차 — 매듭 셋에서 적는다")
	Save.wipe()
	Save.run_drop()
	_game()
	g._new_run()                # 끝에서 _open_leg → 매듭 ①

	_eq("① 판 선택에서 적혔다", String(Save.run_get("at", "")), "leg")
	_say(Save.run_live(), "ver 가 섰다")
	_eq("슬롯이 적혔다", int(Save.run_get("slot", -1)), Save.slot())
	_eq("판 번호가 적혔다", int(Save.run_get("leg_no", 0)), g.leg_no)
	#  **뱃지 · 보스를 이미 굴려 둔 뒤**라야 되살릴 때 다시 안 굴린다.
	_say(int(Save.run_get("leg_tags_round", 0)) == g.leg_tags_round
			and g.leg_tags_round > 0,
			"라운드 뱃지 문지기가 같이 적혔다", "%d" % g.leg_tags_round)

	#  런을 조금 굴린다 — 빈 런으로 대면 「사전이 비어 같다」가 통과한다.
	g.gold = 137
	g.throw6 = 4
	g.track_lv[1] = 2
	g.track_hits[1] = 9
	g.zone_hist["trp"] = 3
	g.tag_copy = 1
	g.leg_skipped[1] = true
	g.run_unlocked.append({"k": "리그", "n": "초록"})
	#  다음 판에 한 발을 더 주는 뱃지. 5차가 **한 번만** 먹히는지를 잰다.
	g.pending_tags.append({"kind": "dart", "v": 1, "n": "덤",
			"d": "다트 +1", "w": "다음 판", "rar": "common"})
	g.carry_darts = 2
	#  보드 확장 한 장 — 판 기하 여덟이 mods_own 의 함수라는 것을 5차가 잰다.
	g._apply_mod(String(GameData.mods()[0].id))
	#  동전 둘. 하나는 성장 걸음을 올려 gs 가 살아 오는지 본다.
	for it in GameData.items():
		if g.owned.size() >= 2:
			break
		var cp: Dictionary = it.duplicate()
		cp.erase("w")
		cp.gs = g.owned.size() + 3
		cp.bought = 1
		g.owned.append(cp)
	if not GameData.candies().is_empty():
		g.cons.append(GameData.candies()[0].duplicate())

	g._begin_leg()              # 매듭 ②
	_eq("② 판 첫머리에서 적혔다", String(Save.run_get("at", "")), "pick")
	#  ⚠ 매듭이 _start_leg **앞**이라는 증거 — 적힌 잔탄이 **안 먹힌** 값이다.
	_eq("잔탄을 먹기 **전** 값이 적혔다", int(Save.run_get("carry_darts", -1)), 2)
	_say(g.carry_darts == 0, "판이 서면서 잔탄을 먹었다", "%d" % g.carry_darts)
	var pt: Array = Save.run_get("pending_tags", [])
	_say(pt.size() == 1, "뱃지를 쓰기 **전** 줄이 적혔다", "%d장" % pt.size())
	_say(g.pending_tags.is_empty(), "판이 서면서 뱃지를 먹었다")

	g.gold = 999                # 사고 굴릴 밑천
	g._open_shop()              # 매듭 ③
	_eq("③ 상점에서 적혔다", String(Save.run_get("at", "")), "shop")
	var st0: Array = Save.run_get("stock", [])
	_say(st0.size() == g.stock.size() and st0.size() > 0,
			"매물이 통째로 적혔다", "%d칸" % st0.size())

	#  하나 사고 한 번 굴린다 — 값이 바뀔 때마다 다시 적히는가.
	var bought := -1
	for i in g.stock.size():
		if g._buy_block(i) == "" and String(g.stock[i].type) != "boost":
			bought = i
			break
	if bought >= 0:
		g._buy(bought)
		var st1: Array = Save.run_get("stock", [])
		_say(bool((st1[bought] as Dictionary).get("sold", false)),
				"산 뒤에 다시 적혔다 — 판 것이 팔린 채다")
	g._reroll()
	var st2: Array = Save.run_get("stock", [])
	var live := []
	for s in g.stock:
		live.append(String((s.d as Dictionary).get("id", "")))
	var wrote := []
	for s in st2:
		wrote.append(String((s as Dictionary).get("id", "")))
	#  ⚠ **리롤이 끝나는 순간 적는 것**이 세이브 스커밍 방어의 핵심이다.
	_eq("굴린 그 결과가 곧장 적혔다", wrote, live)
	_eq("굴린 횟수도 적혔다", int(Save.run_get("rerolls_used", -1)), g.rerolls_used)

	#  ⚠ **굴린 뒤에 한 번 더 산다.** 리롤은 stock 을 통째로 새로 깔아
	#  sold 를 전부 지우므로, 여기서 안 사면 매듭에 팔린 칸이 하나도 없어
	#  2차의 「낙하에서도 팔린 채다」가 **빈 검사**가 된다. 실제로 그랬다 —
	#  그 빈 검사 때문에 되살린 상점이 지난 구매를 다시 연출하는 버그가
	#  초록으로 통과하고 있었다. 2026-09-20
	var again := -1
	for i in g.stock.size():
		if g._buy_block(i) == "" and String(g.stock[i].type) != "boost":
			again = i
			break
	_say(again >= 0, "굴린 판에서도 살 것이 있다")
	if again >= 0:
		g._buy(again)
		var sold_n := 0
		for s in Save.run_get("stock", []):
			if bool((s as Dictionary).get("sold", false)):
				sold_n += 1
		_say(sold_n >= 1, "매듭에 팔린 칸이 남는다", "%d칸" % sold_n)

	#  ── 문지기 ──
	#  ⚠ 팩은 **뜯는 중(boost_t >= 0)만** 막는다. 쏟은 것을 집는 중
	#  (boost_pick > 0)까지 막았더니 그것이 곧 팩 내용 스커밍이었다 —
	#  8차가 그 자리를 잰다. 2026-09-20
	g.boost_t = 0.2
	var before := int(Save.run_get("gold", 0))
	g.gold = 12345
	g._knot("shop")
	_eq("팩을 뜯는 중에는 한 글자도 안 적는다",
			int(Save.run_get("gold", 0)), before)
	g.boost_t = -1.0
	g.photo = "burn"
	g._knot("shop")
	_eq("사진이 테이블을 갈아 낀 중에도 안 적는다",
			int(Save.run_get("gold", 0)), before)
	g.photo = ""
	g.gold = 321
	g._knot("shop")
	_eq("문지기가 풀리면 다시 적는다", int(Save.run_get("gold", 0)), 321)

	#  동전 사전을 통째로 안 적었는가 — 「밸런스는 나중에」를 기계로 막는 단언
	var ow: Array = Save.run_get("owned", [])
	var shape := true
	for o in ow:
		var d: Dictionary = o
		if d.size() != 3 or not (d.has("id") and d.has("gs") and d.has("bought")):
			shape = false
	_say(shape and ow.size() > 0, "동전은 **열쇠 셋만** 적는다",
			"%d장 · %s" % [ow.size(), str(ow[0]) if ow.size() > 0 else ""])

	_dump(_snap())
	print("  … 상점 매듭을 남기고 죽는다. 2차를 돌려라")


# ══════════════════════════════════════════════════════════
#  2차 — 새 프로세스에서 되살려 한 칸씩 댄다
# ══════════════════════════════════════════════════════════
func _pass2() -> void:
	print("2차 — 새 프로세스에서 되살린다")
	var w := _load_want()
	_game()
	var runs0 := Save.stat("runs")
	_say(g._run_load(), "되살아났다")
	_eq("상점이 섰다", g.state, g.S.SHOP)

	var got := _snap()
	#  ⚠ 한 칸씩 댄다. 「전부 같다」 한 줄이면 어느 칸이 어긋났는지가 안 남는다.
	for k in got:
		if k == "runs":
			continue          # 아래에서 따로 — 안 올라야 맞는 칸이다
		_eq(k, got[k], w.get_value(WS, String(k), null))

	print("")
	#  ── 공짜 리롤이 아닌가 ──
	_eq("런 수가 안 올랐다 (_new_run 을 안 지났다)", Save.stat("runs"), runs0)
	_eq("배움 게이트가 안 밀렸다 (_open_shop 을 안 지났다)",
			g.shop_seen, w.get_value(WS, "shop_seen", -1))
	_say(g.pending_tags.size() == (w.get_value(WS, "pending_tags", []) as Array).size(),
			"뱃지 줄이 안 줄었다 (_roll_stock 을 안 지났다)",
			"%d장" % g.pending_tags.size())
	#  ── 이미 판 것이 낙하에서도 **끝 상태**인가 ──
	#  _drop_one 은 늘 sold 0 · gone false 로 떨어뜨리고 _drop_extras 가 매
	#  프레임 stock[i].sold 를 폴링해 _drop_leave 를 건다 — 그대로 두면
	#  되살린 첫 0.5초에 지난 구매가 **다시 실려 나간다**(_drop_sold_sync).
	var sold_n := 0
	var bad := 0
	for i in mini(g.stock.size(), g.drop.size()):
		if not bool(g.stock[i].sold):
			continue
		sold_n += 1
		if not bool(g.drop[i].gone):
			bad += 1
	_say(sold_n >= 1, "되살린 상점에 판 칸이 있다", "%d칸" % sold_n)
	_say(bad == 0, "판 매물이 낙하에서도 이미 끝나 있다", "어긋남 %d" % bad)
	#  그리고 **쪽지가 안 뜬다** — 「보드 확장」·「탄창 교체」가 다시 뜨면
	#  지난 구매가 눈앞에서 되풀이된 것이다.
	g.pops.clear()
	for f in 40:
		g._drop_extras(1.0 / 60.0)
	_say(g.pops.is_empty(), "되살린 뒤 지난 구매가 다시 연출되지 않는다",
			"쪽지 %d" % g.pops.size())
	#  ── 판이 실제로 설 수 있는가 ──
	_say(not g.magazine.is_empty() and g.leg_no >= 1, "판이 설 수 있다")


# ══════════════════════════════════════════════════════════
#  3차 — 못 읽는 저장 · 옛 판 · 표가 바뀐 척
# ══════════════════════════════════════════════════════════
func _pass3() -> void:
	print("3차 — 버릴 것을 버린다")
	_game()

	#  성한 저장 하나를 만들어 둔다 — 한 칸씩 망가뜨려 볼 밑감이다.
	Save.wipe()
	g._new_run()
	g.gold = 77
	g._knot("leg")
	var good := {}
	for k in Save._cfg.get_section_keys(Save.S_RUN):
		good[String(k)] = Save.run_get(String(k), null)
	_say(g._run_load(), "성한 저장은 되살아난다")

	var cases := {
		"ver 가 0 이면 버린다": ["ver", 0],
		"ver 가 미래 판이면 버린다": ["ver", 99],
		"매듭이 셋 밖이면 버린다": ["at", "clear"],
		"판 번호가 0 이면 버린다": ["leg_no", 0],
		"판 번호가 표 밖이면 버린다": ["leg_no", GameData.legs_n() + 1],
		"탄창이 비면 버린다": ["magazine", PackedStringArray()],
		#  _run_ok 는 제목에서 매 프레임 돈다 — 자료형이 다른 값 하나가
		#  프레임마다 오류를 뱉으면 안 된다.
		"탄창 자료형이 다르면 버린다": ["magazine", 5],
		"슬롯이 딴 번호면 버린다": ["slot", Save.slot() + 1],
		"다트통 id 가 표에 없으면 버린다": ["pack", "없는통"],
		"리그 id 가 표에 없으면 버린다": ["league", "없는리그"],
	}
	for nm in cases:
		for k in good:
			Save.run_set(k, good[k])
		var pair: Array = cases[nm]
		Save.run_set(String(pair[0]), pair[1])
		Save.flush()
		#  ⚠ **흐리는 술어와 되살리는 술어가 같은가.** 제목 글줄은 _run_ok()
		#  하나로 흐림을 정하므로 여기가 갈리면 「계속하기」가 **밝은 채로
		#  죽는다** — 눌러도 화면이 안 바뀌고 거절도 안 하니 고장으로만
		#  읽힌다. ver 만 보던 때 실제로 그랬다. 2026-09-20
		_say(not g._run_load() and not g._run_ok(), nm)
	#  ver 는 성한데 뼈대가 어긋난 자리 — run_live() 만으로는 못 거르는
	#  것이 있다는 것을 못 박는다.
	for k in good:
		Save.run_set(k, good[k])
	Save.run_set("leg_no", GameData.legs_n() + 1)
	Save.flush()
	_say(Save.run_live() and not g._run_ok(),
			"ver 가 성해도 뼈대가 어긋나면 흐려진다")

	print("")
	#  ── 줄 단위로 떨어뜨리는 것 — 런은 산다 ──
	for k in good:
		Save.run_set(k, good[k])
	Save.run_set("owned", [{"id": "없는것", "gs": 0, "bought": 1},
			{"id": String(GameData.items()[0].id), "gs": 1, "bought": 1}])
	Save.run_set("cons", PackedStringArray(["없는것"]))
	Save.run_set("leg_tags", {1: "없는뱃지"})
	Save.run_set("magazine", PackedStringArray(["없는다트",
			String(GameData.darts()[0].id)]))
	Save.flush()
	g.pops.clear()
	_say(g._run_load(), "표에서 줄이 사라져도 런이 산다")
	_eq("없는 동전 한 장만 떨어졌다", g.owned.size(), 1)
	_eq("없는 사탕이 떨어졌다", g.cons.size(), 0)
	_eq("없는 뱃지가 떨어졌다", g.leg_tags.size(), 0)
	_eq("없는 다트만 떨어졌다", g.magazine.size(), 1)
	#  ⚠ **화면에 아무 말도 안 뜬다.** 「무엇이 없어졌다」는 효과도 값도 아닌
	#  해설이라, 그 수는 개발자 판의 「이어하기 보기」만 적는다.
	_say(g.pops.is_empty(), "사라진 줄을 사람에게 말하지 않는다",
			"%d개" % g.pops.size())

	print("")
	#  ── 못 읽는 파일 ──
	var f := FileAccess.open(Save.path, FileAccess.WRITE)
	if f != null:
		f.store_string("이건 설정 파일이 아니다 [[[ = = ] ] ]\n= 3 ㅋ")
		f.close()
	Save._cfg = null
	Save._at = ""
	_say(not Save.run_live(), "깨진 파일이면 이어하기가 없다")
	_say(not g._run_load(), "깨진 파일로 되살리기가 안 죽는다")
	#  절이 통째로 없는 것도 같은 꼴이어야 한다.
	Save.wipe()
	_say(not Save.run_live() and not g._run_load(), "절이 없으면 이어하기가 없다")


# ══════════════════════════════════════════════════════════
#  4차 — 판 첫머리 매듭을 적고 죽는다 (봉인 · 목표물 · 칸 섞기)
# ══════════════════════════════════════════════════════════
func _boss_leg() -> int:
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			return n
	return 0


func _pass4() -> void:
	print("4차 — 되감는 셋이 걸린 판 첫머리를 적는다")
	Save.wipe()
	Save.run_drop()
	_game()
	#  「목표물」이 판마다 한 칸을 뽑는다(mark_sec).
	GameData.challenge = "mark"
	g._new_run()
	#  봉인(dull)과 칸 섞기(turn)를 **같은 판**에 건다. 셋이 전부 되감을 때
	#  다시 굴려지는 자리다 — run_rng 가 없으면 여기가 통째로 다시 뽑힌다.
	var bn := _boss_leg()
	g.leg_no = bn
	g.boss_mods[bn] = PackedStringArray(["dull", "turn"])
	g.boss_void.erase(bn)
	#  봉인이 **고를 것이 여럿**이어야 「같은 칸인가」가 뜻이 있다.
	for it in GameData.items():
		if g.owned.size() >= 6:
			break
		var cp: Dictionary = it.duplicate()
		cp.erase("w")
		cp.gs = 0
		cp.bought = 1
		g.owned.append(cp)
	g.carry_darts = 2
	g.pending_tags.append({"kind": "dart", "v": 1, "n": "덤",
			"d": "다트 +1", "w": "다음 판", "rar": "common"})
	g._begin_leg()
	_eq("판 첫머리에서 적혔다", String(Save.run_get("at", "")), "pick")
	_say(g.sealed >= 0, "봉인이 걸렸다", "%d번" % g.sealed)
	_say(g.mark_sec >= 0, "목표물 칸이 뽑혔다", "%d번" % g.mark_sec)
	_say(g.sectors != GameData.SECTORS_BASE, "칸이 섞였다")
	var c := ConfigFile.new()
	#  줄기 자리는 **적힌 값**을 그대로 들고 간다 — 5차가 되살린 뒤 다시
	#  적힌 것과 대서, 되살리기가 제 매듭을 망가뜨리지 않는지를 잰다.
	c.set_value(WS, "rng", int(Save.run_get("rng", -1)))
	c.set_value(WS, "sealed", g.sealed)
	c.set_value(WS, "mark_sec", g.mark_sec)
	c.set_value(WS, "sectors", PackedInt32Array(g.sectors))
	c.set_value(WS, "remaining", g.remaining.size())
	c.set_value(WS, "leg_base", g.leg_base)
	c.set_value(WS, "target", g.target)
	c.set_value(WS, "pending_n", g.pending_tags.size())
	c.set_value(WS, "active_n", g.active_mods.size())
	c.save(WANT)
	#  한 발 던진 척한다 — 「판을 던지다 껐다」를 흉내 낸다. 매듭은 이미
	#  적혔으므로 이 뒤의 변화는 저장에 한 글자도 안 남아야 한다.
	g.total = 400
	g.remaining.pop_back()
	print("  … 판 첫머리 매듭을 남기고 죽는다. 5차를 돌려라")


# ══════════════════════════════════════════════════════════
#  5차 — 되감기가 **무르기**인가(리롤이 아닌가)
# ══════════════════════════════════════════════════════════
func _pass5() -> void:
	print("5차 — 되감아도 **같은 판**이 선다")
	var w := _load_want()
	_game()
	_say(g._run_load(), "되살아났다")
	_eq("판이 섰다 — 판 첫머리다", g.state == g.S.PICK or g.state == g.S.AIM_V, true)
	#  ⚠ 이 셋이 붉으면 **껐다 켜기가 곧 봉인 다시 뽑기다.**
	_eq("봉인이 같은 동전에 걸렸다", g.sealed, w.get_value(WS, "sealed", -99))
	_eq("목표물이 같은 칸이다", g.mark_sec, w.get_value(WS, "mark_sec", -99))
	_eq("섞인 차례가 같다", PackedInt32Array(g.sectors),
			w.get_value(WS, "sectors", PackedInt32Array()))
	print("")
	#  ── 두 번 안 먹었는가 — 매듭이 _start_leg **앞**이라는 증거 ──
	_eq("잔탄과 뱃지를 정확히 한 번 먹었다", g.remaining.size(),
			w.get_value(WS, "remaining", -1))
	_eq("판 기본 다트 수가 같다", g.leg_base, w.get_value(WS, "leg_base", -1))
	_eq("뱃지 줄이 같은 만큼 남았다", g.pending_tags.size(),
			w.get_value(WS, "pending_n", -1))
	_eq("잔탄은 다 쓰여 0 이다", g.carry_darts, 0)
	print("")
	#  ── _begin_leg 를 지났는가 (_start_leg 직행이 아니었는가) ──
	_eq("보스 제약이 섰다", g.active_mods.size(), w.get_value(WS, "active_n", -1))
	_eq("목표가 제약을 태운 값이다", g.target, w.get_value(WS, "target", -1))
	_eq("던지다 끈 판은 첫머리로 돌아온다 — 점수 0", g.total, 0)
	print("")
	#  ── 되살린 자리가 **같은 매듭**인가 ────────────────────
	#  ⚠ at·leg_no 만 보던 때 이 자리가 고장을 통과시켰다. 되살리기가 갈림
	#  **뒤**에 매듭을 한 줄로 모아 적었는데, 그 한 줄이 _begin_leg 이
	#  올바른 자리(굴리기 전·먹기 전)에 적어 둔 것을 _start_leg 이 다 쓴
	#  뒤의 값으로 덮어썼다 — 파일의 rng 가 0 에서 굴린 값으로, 잔탄이
	#  2 에서 0 으로, 뱃지가 한 장에서 빈 칸으로 바뀌었다. 2026-09-20
	_eq("불러오자마자 다시 적혔다", String(Save.run_get("at", "")), "pick")
	_eq("다시 적힌 것도 같은 판이다", int(Save.run_get("leg_no", 0)), g.leg_no)
	_eq("다시 적힌 줄기 자리가 그대로다", int(Save.run_get("rng", -1)),
			int(w.get_value(WS, "rng", -2)))
	_eq("다시 적힌 잔탄이 **먹기 전** 값이다",
			int(Save.run_get("carry_darts", -1)), 2)
	var pt2: Array = Save.run_get("pending_tags", [])
	_say(pt2.size() == 1, "다시 적힌 뱃지 줄도 **쓰기 전**이다",
			"%d장" % pt2.size())

	print("")
	#  ── 두 번째 되살리기가 첫 번째와 같은 판을 세우는가 ──
	#  매듭이 제자리를 잃으면 여기서 갈린다 — 되감을 때마다 봉인이 다시
	#  뽑히면 껐다 켜기가 곧 리롤이다.
	var seal1: int = g.sealed
	var mark1: int = g.mark_sec
	var sec1 := PackedInt32Array(g.sectors)
	var rem1: int = g.remaining.size()
	_say(g._run_load(), "두 번째도 되살아난다")
	_eq("두 번 되살려도 같은 동전이 봉인된다", g.sealed, seal1)
	_eq("두 번 되살려도 같은 칸이 목표물이다", g.mark_sec, mark1)
	_eq("두 번 되살려도 섞인 차례가 같다", PackedInt32Array(g.sectors), sec1)
	_eq("두 번 되살려도 다트가 안 줄어든다", g.remaining.size(), rem1)


# ══════════════════════════════════════════════════════════
#  6차 — 지우는 자리 넷과 「로비로 나가기」 · 슬롯
# ══════════════════════════════════════════════════════════
func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	return {}


#  런 하나를 세우고 판 하나를 끝낼 채비를 한다.
func _armed_leg(last: bool, hit: bool) -> void:
	Save.wipe()
	g._new_run()
	g.leg_no = GameData.legs_n() if last else 1
	g._begin_leg()
	g.total = g.target if hit else 0
	g.darts_left = 0
	g.remaining.clear()


func _pass6() -> void:
	print("6차 — 지우는 자리와 로비 · 슬롯")
	_game()

	#  ① 패배
	_armed_leg(false, false)
	g.owned.clear()
	_say(Save.run_live(), "판 첫머리에 이어하기가 있다")
	g._finish_leg()
	_eq("패배 — 상태", g.state, g.S.OVER)
	_say(not Save.run_live(), "패배하면 지워진다")

	#  ② 마지막 판 완주
	_armed_leg(true, true)
	g.owned.clear()
	g._finish_leg()
	_say(g.state == g.S.OVER and g.won, "마지막 판 — 완주")
	_say(not Save.run_live(), "완주하면 지워진다")

	#  ③ NULL 보드 처치 완주
	var nul := _item("l03")
	if not nul.is_empty():
		_armed_leg(false, true)
		nul.gs = 0
		nul.bought = 1
		g.owned = [nul]
		g._finish_leg()
		_say(g.state == g.S.OVER and g.won, "NULL — 보드 처치 완주")
		_say(not Save.run_live(), "보드 처치 완주도 지워진다")

	#  ④ ⚠ **목숨이 마지막 판에서 터진 완주.** 넉 줄뿐인 좁은 갈래고 **거기에만
	#  Save.flush() 가 없다** — run_drop() 이 제 안에서 flush 하는 이유이자,
	#  빠뜨리면 **이긴 런이 되살아나는** 자리다. 손으로는 거의 못 밟는다.
	var life := _item("r09")
	if not life.is_empty():
		_armed_leg(true, false)
		life.gs = 0
		life.bought = 1
		g.owned = [life]
		g.sealed = -1
		g.total = maxi(g.target, 1)      # 목표의 1% 를 넘긴다
		g.target = g.total + 1           # 그래도 목표에는 못 미친다
		g._finish_leg()
		_say(g.state == g.S.OVER and g.won, "목숨이 마지막 판에서 터진 완주",
				"state=%d · won=%s" % [g.state, g.won])
		_say(not Save.run_live(), "그 좁은 갈래도 지워진다")

	#  ⑤ 새 런
	_armed_leg(false, false)
	_say(Save.run_live(), "새 런 전에는 있다")
	g._new_run()
	_say(Save.run_live(), "새 런은 제 매듭을 곧장 적는다")
	_eq("그 매듭은 새 런의 첫 판이다", int(Save.run_get("leg_no", 0)), 1)

	print("")
	#  ── 「로비로 나가기」는 **지우지 않고 적는다** ──
	#  이 검사가 그 결정의 유일한 증인이다.
	Save.wipe()
	g._new_run()
	g.gold = 250
	g._open_shop()
	var st := []
	for s in g.stock:
		st.append(String((s.d as Dictionary).get("id", "")))
	g.pause_from = g.S.SHOP
	g.state = g.S.SETTINGS
	g.lobby_arm = true
	g._click(g._set_rect(g._set_rows().find("lobby")).get_center())
	_eq("로비로 나갔다", g.state, g.S.TITLE)
	_say(Save.run_live(), "나가도 **안 지운다**")
	_eq("상점 자리 그대로다", String(Save.run_get("at", "")), "shop")
	_say(g._run_load(), "돌아와 이을 수 있다")
	var st2 := []
	for s in g.stock:
		st2.append(String((s.d as Dictionary).get("id", "")))
	_eq("매물이 그대로다 — 공짜 리롤이 아니다", st2, st)
	_eq("골드도 그대로다", g.gold, 250)

	print("")
	#  ── 슬롯 ──
	Save.prof_fmt = "user://_resume_slot_%d.cfg"
	Save.path = ""
	Save._cfg = null
	Save._at = ""
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)
	Save._slot = 0
	Save.use_slot(1)
	g._new_run()
	g.gold = 611
	g._knot("leg")
	var unl1 := int(Save.slot_info(1).get("unlocks", -1))
	Save.use_slot(2)
	_say(not Save.run_live(), "2번에는 이어하기가 없다")
	g._new_run()
	g.gold = 12
	g._knot("leg")
	Save.use_slot(1)
	_say(Save.run_live(), "1번은 그대로다")
	_eq("2번이 1번을 안 덮었다", int(Save.run_get("gold", 0)), 611)
	#  ⚠ [해금] 을 세는 자(slot_info)가 [이어하기] 를 안 훑는가. 발견 절이
	#  절을 가른 그 이유를 이 절에도 재는 자리다.
	_eq("프로필 화면의 해금 수가 안 늘었다",
			int(Save.slot_info(1).get("unlocks", -1)), unl1)
	Save.erase_slot(1)
	Save._cfg = null
	Save._at = ""
	_say(not Save.run_live(), "프로필을 지우면 같이 없어진다")
	Save.use_slot(2)
	_say(Save.run_live(), "2번은 아직 있다")
	Save.wipe()
	_say(not Save.run_live(), "저장 통째로 지우기에도 같이 없어진다")
	for i in range(1, Save.SLOTS + 1):
		Save.erase_slot(i)


# ══════════════════════════════════════════════════════════
#  7차 — 제목 자리와 겨눔 · 「글자가 안 늘었다」
# ══════════════════════════════════════════════════════════
func _row_of(name: String) -> int:
	for i in g.TITLE_ROWS.size():
		if String(g.TITLE_ROWS[i].n) == name:
			return i
	return -1


func _title() -> void:
	g.state = g.S.TITLE
	g.pause_from = -1
	g.mouse_at = Vector2(4.0, 4.0)


func _pass7() -> void:
	print("7차 — 제목 자리와 겨눔")
	_game()
	Save.wipe()
	Save.run_drop()

	# ── 자리 ──
	_eq("글줄이 다섯이다", g.TITLE_ROWS.size(), 5)
	_eq("「시작」은 0번 그대로다", _row_of("시작"), 0)
	_eq("「계속하기」는 둘째 줄이다", _row_of("계속하기"), g.TTL_RESUME)
	#  ⚠ 아래끝 300 은 **한 픽셀도 안 바뀐 값**이다(넷이 y184~300 이었다).
	_eq("다섯 줄의 아래끝이 그대로다", g._menu_rect(4).end.y, 300.0)
	var pb: Rect2 = g._prof_badge_rect()
	var box: Rect2 = g._menu_rect(0).merge(g._menu_rect(g.TITLE_ROWS.size() - 1))
	_say(not pb.intersects(box), "프로필 패가 글줄과 안 겹친다",
			"%s · %s" % [pb, box])
	_say(box.position.y > 123.0, "영문 제목 잉크 밑과 안 겹친다",
			"y %.0f" % box.position.y)

	print("")
	# ── 글자가 안 늘었다 ──
	var names := []
	for r in g.TITLE_ROWS:
		names.append(String(r.n))
	var wordy := ""
	for n in names:
		if String(n).find(" ") >= 0 or String(n).find("(") >= 0 \
				or String(n).find(",") >= 0 or String(n).find("·") >= 0:
			wordy = String(n)
	_say(wordy == "", "다섯 줄이 전부 낱말 하나다", " · ".join(names))
	var keyname := ""
	for n in names:
		for k in ["스페이스", "ESC", "TAB", "엔터", "Space", "Esc", "Tab"]:
			if String(n).find(k) >= 0:
				keyname = String(n)
	_say(keyname == "", "글줄에 키 이름이 없다")
	#  「로비로 나가기」 곁줄이 **짧아졌다** — 이어하기가 생기면서 런은 안 버려진다.
	var lob := String(g._set_info("lobby").get("d", ""))
	_say(lob.find("버리") < 0, "로비 곁줄이 런을 버린다고 안 한다", "「%s」" % lob)
	_eq("로비 곁줄이 짧아졌다", lob, "제목 화면으로 돌아간다")

	print("")
	# ── 이어할 것이 없으면 흐리다 ──
	_title()
	for i in 20:
		g._title_tick(1.0 / 60.0)
	_eq("흐린 줄이다", float(g.ttl_e[g.TTL_RESUME]), 0.0)
	#  ⚠ **쉬는 자리에서도 흐려야 한다.** ee 만 0 으로 눌러 두면 쉬는 줄이
	#  어차피 전부 ee 0 이라 다섯이 똑같이 보인다 — 그림을 찍어 보고서야
	#  드러난 구멍이다(2026-09-20). 짙기 축이 따로 있어야 한다.
	_say(g.TTL_DEAD < 1.0, "쉴 때 눌러 둘 짙기가 따로 있다",
			"%.2f" % g.TTL_DEAD)
	g.mouse_at = g._menu_rect(g.TTL_RESUME).get_center()
	for i in 20:
		g._title_tick(1.0 / 60.0)
	_eq("얹혀도 안 산다", float(g.ttl_e[g.TTL_RESUME]), 0.0)
	g.pops.clear()
	g._click(g._menu_rect(g.TTL_RESUME).get_center())
	_eq("눌러도 제목 그대로다", g.state, g.S.TITLE)
	_say(g.pops.is_empty() and g.deny_flash <= 0.0,
			"거절도 안 한다 — 흐린 줄이 이미 말했다")

	# ── 있으면 산다 ──
	g._new_run()
	_say(Save.run_live(), "런이 서면 이어하기가 있다")
	_title()
	g.mouse_at = g._menu_rect(g.TTL_RESUME).get_center()
	for i in 30:
		g._title_tick(1.0 / 60.0)
	_say(float(g.ttl_e[g.TTL_RESUME]) > 0.5, "이어할 것이 있으면 줄이 산다",
			"%.2f" % float(g.ttl_e[g.TTL_RESUME]))
	_title()
	g._click(g._menu_rect(g.TTL_RESUME).get_center())
	_say(g.state != g.S.TITLE, "누르면 되살아난다", "state=%d" % g.state)

	print("")
	# ── 겨눔은 **런을 덮는 그 누름**에 단다 ──
	g._new_run()                       # 이어하기가 있는 상태로 둔다
	_say(Save.run_live(), "덮을 런이 있다")
	_title()
	g._click(g._menu_rect(0).get_center())     # 「시작」
	_eq("제목의 「시작」은 겨눔 없이 새 런 화면", g.state, g.S.NEWRUN)
	_say(not g.start_arm, "되돌릴 수 있는 누름에는 마찰이 없다")
	var runs0 := Save.stat("runs")
	g._click(g._newrun_go().get_center())
	_eq("첫 누름은 겨눈다 — 화면이 그대로다", g.state, g.S.NEWRUN)
	_say(g.start_arm, "겨눴다")
	_eq("런이 아직 안 섰다", Save.stat("runs"), runs0)
	g.start_arm_t = 0.3
	g._click(g._newrun_go().get_center())
	_say(g.start_arm and Save.stat("runs") == runs0,
			"0.4초 안의 둘째 누름은 통째로 삼킨다")
	g.start_arm_t = 0.5
	g._click(g._newrun_go().get_center())
	_say(not g.start_arm and Save.stat("runs") == runs0 + 1,
			"0.4초를 넘으면 확정이다", "runs %d" % Save.stat("runs"))

	#  풀림 — 확정 단추 밖은 전부 풀림이다
	g._open_newrun()
	g._click(g._newrun_go().get_center())
	_say(g.start_arm, "다시 겨눴다")
	g._click(g._newrun_back().get_center())
	_say(not g.start_arm, "「뒤로」를 누르면 풀린다")
	g._open_newrun()
	g._click(g._newrun_go().get_center())
	g.state = g.S.TITLE
	g._set_tick(1.0 / 60.0)
	_say(not g.start_arm, "화면을 뜨면 풀린다")
	g._open_newrun()
	g._click(g._newrun_go().get_center())
	_say(g.start_arm, "또 겨눴다")
	g.start_arm_t = g.START_ARM + 0.1
	g._set_tick(1.0 / 60.0)
	_say(not g.start_arm, "2.5초가 지나면 풀린다")

	#  ⚠ 키도 **같은 문**을 지난다.
	g._open_newrun()
	g.start_arm = false
	var runs1 := Save.stat("runs")
	_key(KEY_SPACE)
	_say(g.start_arm and Save.stat("runs") == runs1, "스페이스도 겨눈다")
	g.start_arm_t = 0.5
	_key(KEY_SPACE)
	_say(not g.start_arm and Save.stat("runs") == runs1 + 1,
			"스페이스 둘째 누름이 확정이다")

	#  이어할 것이 없으면 **겨눔이 아예 안 선다** — 없는 것을 지키느라
	#  모든 손에 마찰을 물리지 않는다.
	Save.run_drop()
	g._open_newrun()
	g.start_arm = false
	var runs2 := Save.stat("runs")
	g._click(g._newrun_go().get_center())
	_say(not g.start_arm and Save.stat("runs") == runs2 + 1,
			"덮을 런이 없으면 한 번 누름 그대로다")

	#  슬롯을 갈면 겨눔이 풀린다 — 남의 런을 덮으면 안 된다.
	g._open_newrun()
	g.start_arm = true
	g._use_profile(Save.slot())
	_say(not g.start_arm, "프로필을 갈아타면 겨눔이 풀린다")


#  키는 InputEventKey 를 만들어 _unhandled_input 에 **바로 넣는다**
#  (qa_over · qa_hudbtn 이 쓰는 그 어법).
func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	g._unhandled_input(e)


# ══════════════════════════════════════════════════════════
#  8차 — 검토가 찾아낸 새 나가는 자리 셋 (2026-09-20)
#
#  셋 다 「값은 이미 나갔는데 매듭은 아직 안 적혔다」는 **같은 모양**이다.
#  한 차수에 모아 두는 이유가 그것이다 — 넷째가 생기면 여기 붙인다.
# ══════════════════════════════════════════════════════════
func _shop_at(kind: String) -> int:
	for i in g.stock.size():
		if String(g.stock[i].type) == kind and g._buy_block(i) == "":
			return i
	return -1


func _pass8() -> void:
	print("8차 — 값은 나갔는데 매듭이 안 적히던 자리들")
	_game()
	Save.wipe()
	Save.run_drop()

	# ── ① 되살리기가 제 매듭을 안 망가뜨린다 ──────────────
	#  되살리기가 갈림 **뒤**에 매듭을 한 줄로 모아 적던 때, "pick" 갈래의
	#  그 한 줄이 _begin_leg 이 올바른 자리에 적어 둔 것을 _start_leg 이 다
	#  쓴 뒤의 값으로 덮어썼다. 한 프로세스 안에서도 드러난다.
	g._new_run()
	g.carry_darts = 2
	g.pending_tags.append({"kind": "dart", "v": 1, "n": "덤",
			"d": "다트 +1", "w": "다음 판", "rar": "common"})
	g._begin_leg()
	var rng0 := int(Save.run_get("rng", -1))
	var carry0 := int(Save.run_get("carry_darts", -1))
	var tags0: int = (Save.run_get("pending_tags", []) as Array).size()
	_eq("적힌 잔탄이 먹기 전 값이다", carry0, 2)
	_eq("적힌 뱃지가 쓰기 전 줄이다", tags0, 1)
	_say(g._run_load(), "되살아났다")
	_eq("되살린 뒤에도 줄기 자리가 그대로다",
			int(Save.run_get("rng", -1)), rng0)
	_eq("되살린 뒤에도 적힌 잔탄이 그대로다",
			int(Save.run_get("carry_darts", -1)), carry0)
	_eq("되살린 뒤에도 적힌 뱃지 줄이 그대로다",
			(Save.run_get("pending_tags", []) as Array).size(), tags0)
	var seal1: int = g.sealed
	var rem1: int = g.remaining.size()
	_say(g._run_load(), "두 번째도 되살아난다")
	_eq("두 번 되감아도 같은 동전이 봉인된다", g.sealed, seal1)
	for i in 8:
		g._run_load()
	_eq("열 번 되감아도 같은 다트 수다", g.remaining.size(), rem1)
	_eq("열 번 되감아도 같은 봉인이다", g.sealed, seal1)

	print("")
	# ── ② 쓸기 중에는 상점을 못 빠져나간다 ────────────────
	#  _reroll 은 골드와 굴린 횟수를 **즉시** 깎는데 매듭은 쓸기가 끝나는
	#  자리에서야 적힌다. 그 사이에 설정으로 빠져나가면 _drop_update 가
	#  state != S.SHOP 에서 즉시 return 이라 쓸기가 **얼어붙고**, 그대로
	#  로비로 나가면 디스크에는 리롤 **전** 매듭이 남았다 — 골드가 돌아오고
	#  매물이 새로 뽑히는 무한 공짜 리롤이다. 2026-09-20
	Save.wipe()
	g._new_run()
	g.gold = 999
	g._open_shop()
	g.drop_fast = false          # ⚠ 느린 길을 지나야 쓸기가 실제로 산다
	#  공짜 리롤 몫을 지나 보낸다 — 값이 0 이면 「값을 즉시 치른다」가
	#  빈 검사가 된다(실제로 그랬다).
	g.rerolls_used = g._free_rerolls() + 2
	g.reroll_cost = g._reroll_price()
	_say(g.reroll_cost > 0, "굴리는 값이 0 이 아니다", "%d골드" % g.reroll_cost)
	var gold0: int = g.gold
	var used0: int = g.rerolls_used
	g._reroll()
	_say(g.sweep_live, "느린 길은 쓸기를 연다")
	_say(g.gold < gold0 and g.rerolls_used == used0 + 1,
			"리롤은 값을 **즉시** 치른다", "%d → %d골드" % [gold0, g.gold])
	_eq("쓸기가 도는 동안에는 매듭이 아직 리롤 전이다",
			int(Save.run_get("gold", -1)), gold0)
	g._pause_open()
	_eq("쓸기 중에는 설정이 안 열린다", g.state, g.S.SHOP)
	_say(not g._hud_btns_on(), "쓸기 중에는 단추도 안 선다")
	#  ⚠ **문을 다시 닫아 놓고** 다음 길을 잰다. 안 그러면 「설정에서 ESC 로
	#  돌아왔다」가 「ESC 가 안 열었다」와 같은 그림이 되어 검사가 헛돈다.
	g.state = g.S.SHOP
	g.pause_from = -1
	_key(KEY_ESCAPE)
	_eq("키도 같은 문을 지난다", g.state, g.S.SHOP)
	g.state = g.S.SHOP
	g.pause_from = -1
	g._click(g._hud_btn_rect(1).get_center())
	_eq("화면 단추도 같은 문을 지난다", g.state, g.S.SHOP)
	#  연출을 끝까지 돌린다 — 끝나는 그 자리에서 적혀야 한다.
	for i in 400:
		if not g.sweep_live:
			break
		g._drop_update(0.02)
	_say(not g.sweep_live, "쓸기가 끝났다")
	_eq("끝나는 자리에서 리롤 결과가 적혔다",
			int(Save.run_get("gold", -1)), g.gold)
	_eq("굴린 횟수도 적혔다", int(Save.run_get("rerolls_used", -1)),
			g.rerolls_used)
	var live := []
	for s in g.stock:
		live.append(String((s.d as Dictionary).get("id", "")))
	var wrote := []
	for s in Save.run_get("stock", []):
		wrote.append(String((s as Dictionary).get("id", "")))
	_eq("굴린 그 판이 적혔다", wrote, live)
	g.drop_fast = true

	print("")
	# ── ③ 팩 내용을 보고 나면 무를 수 없다 ────────────────
	#  _buy 가 골드를 **먼저** 깎고, 내용은 전역 randi 라 다시 사면 매번
	#  다르다. 쏟은 것을 집는 중을 문지기가 막던 때는 「내용을 보고 마음에
	#  안 들면 껐다 켠다」가 곧 팩 다시 굴리기였다. 2026-09-20
	Save.wipe()
	g._new_run()
	g.gold = 999
	g._open_shop()
	var bi := _shop_at("boost")
	if bi < 0:
		#  매물에 팩이 안 떴다 — 굴려서 찾는다. 못 찾으면 이 절만 건너뛴다.
		for i in 40:
			g._reroll()
			bi = _shop_at("boost")
			if bi >= 0:
				break
	_say(bi >= 0, "상점에서 팩을 하나 찾았다")
	if bi >= 0:
		var gold1: int = g.gold
		g._buy(bi)
		_say(g.gold < gold1, "팩 값이 나갔다", "%d → %d골드" % [gold1, g.gold])
		_eq("뜯는 중에는 아직 매듭이 안 적힌다",
				int(Save.run_get("gold", -1)), gold1)
		#  ⚠ 뜯는 동안 설정으로 빠져나가면 _boost_tick 이 그 뒤에서 쏟는데,
		#  state 만 보던 _knot_shop 은 한 글자도 안 적었다 — 돌아와 내용만
		#  보고 끄면 팩이 다시 굴려졌다. 막는 자리가 둘이다: 문을 아예 안
		#  열고(여기), 열렸더라도 덮인 화면의 밑바닥을 본다(아래).
		g._pause_open()
		_eq("뜯는 중에는 설정이 안 열린다", g.state, g.S.SHOP)
		_say(not g._hud_btns_on(), "뜯는 중에는 단추도 안 선다")
		g.state = g.S.SHOP
		g.pause_from = -1
		_key(KEY_ESCAPE)
		_eq("뜯는 중에는 키도 같은 문을 지난다", g.state, g.S.SHOP)
		#  ⚠ 런 정보는 뜯는 중에도 열린다(제 문지기가 boost_t 를 안 본다).
		#  그 뒤에서 쏟아도 매듭이 적혀야 한다 — 덮은 화면의 밑바닥이
		#  상점이면 상점이다(_knot_shop).
		g.run_from = g.S.SHOP
		g.state = g.S.RUNINFO
		g._boost_tick(9.0)        # 뜯기를 끝까지 돌린다 — 안이 쏟아진다
		_eq("런 정보에 덮여 있어도 쏟는 자리에서 적혔다",
				int(Save.run_get("gold", -1)), g.gold)
		g.state = g.S.SHOP
		_say(g.boost_pick > 0, "몫이 섰다", "%d장" % g.boost_pick)
		_eq("쏟는 그 순간 적혔다", int(Save.run_get("gold", -1)), g.gold)
		_eq("남은 몫도 적혔다", int(Save.run_get("boost_pick", -1)),
				g.boost_pick)
		var spill := []
		for s in g.stock:
			if bool(s.get("pack", false)):
				spill.append(String((s.d as Dictionary).get("id", "")))
		_say(spill.size() > 0, "쏟은 것이 테이블에 섰다", "%d개" % spill.size())
		#  ⚠ 여기가 핵심이다 — 내용을 다 보고 되감아도 골드가 안 돌아오고
		#  같은 것이 같은 자리에 선다.
		var pick0: int = g.boost_pick
		_say(g._run_load(), "되살아났다")
		_eq("되감아도 팩 값이 안 돌아온다", g.gold, Save.run_get("gold", -1))
		_eq("되감아도 남은 몫이 그대로다", g.boost_pick, pick0)
		var spill2 := []
		for s in g.stock:
			if bool(s.get("pack", false)):
				spill2.append(String((s.d as Dictionary).get("id", "")))
		_eq("되감아도 **같은 것**이 쏟아져 있다", spill2, spill)
		#  몫을 다 쓰면 나머지가 쓸려 나가고 그 자리도 적힌다.
		var pi := -1
		for i in g.stock.size():
			if bool(g.stock[i].get("pack", false)) and g._buy_block(i) == "":
				pi = i
				break
		if pi >= 0:
			g._buy(pi)
			_eq("집은 뒤에도 남은 몫이 적힌다",
					int(Save.run_get("boost_pick", -1)), g.boost_pick)
		#  상점을 떠나면 매물도 몫도 접힌다 — 파일이 테이블과 다른 말을
		#  하는 자리를 안 남긴다.
		g._next_leg()
		_eq("판 선택 매듭에는 매물이 없다",
				(Save.run_get("stock", []) as Array).size(), 0)
		_eq("판 선택 매듭에는 몫도 없다",
				int(Save.run_get("boost_pick", -1)), 0)
