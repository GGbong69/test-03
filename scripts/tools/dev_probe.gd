extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# ══════════════════════════════════════════════════════════
#  개발자 모드 검사 — 누르는 자리가 실제로 일을 하는가
#
#  실행:  godot --path . --headless --script scripts/tools/dev_probe.gd
#  종료 코드 = 실패 개수
#
#  이 판에는 검사가 없었고, 그래서 다음이 그대로 나갔다:
#    "◀ 값 ▶" 을 오른쪽 정렬로 그려 놓고 줄을 3등분해서 판정했다. 두
#    화살표가 다 오른쪽 3분의 1 안에 들어가 ◀ 가 "다음" 이 되고, 적용은
#    아무것도 안 그려진 가운데 빈 칸을 눌러야 일어났다 — 화살표를 아무리
#    눌러도 게임이 안 바뀌었다.
#
#  그래서 여기서는 **좌표를 만들어 Dev.click 을 부른다.** 값을 직접 박으면
#  이 결함이 안 잡힌다. 못 박는 것:
#    ① 그려지는 화살표 칸과 값 칸이 줄 안에서 안 겹치고 안 삐져나온다
#    ② ◀ 는 뒤로, ▶ 는 앞으로 — 방향이 안 뒤집힌다
#    ③ 누르는 그 순간 게임에 반영된다 (따로 적용을 안 눌러도)
#    ④ 반영된 조준이 판을 넘겨도 남는다 — _start_leg 가 든 동전을
#       다시 읽으므로, 값만 박으면 다음 판에서 조용히 std 로 풀린다
#    ⑤ 여덟 방식을 차례로 다 고를 수 있다
#    ⑥ **미리보기 줄이 판을 안 건드린다.** 「점수 카드 걸음」은 진짜 정산 큐를
#       빌려 타는데, 큐가 비면 _next_step 의 빈 큐 갈래가 한 발이 끝나는 진짜
#       길을 탄다 — 연출을 한 번 다시 보려고 누른 줄이 판 점수를 441,000 올리고
#       Save.peak("best_gain") 을 디스크에 앉혔다(2026-09-18). 코드가 아니라
#       **저장이 상하는** 종류라 눈으로는 한참 뒤에 안다.
# ══════════════════════════════════════════════════════════

var fails := 0
#  ⑥번 블록만 게임의 _process 를 직접 민다. _initialize 는 **트리가 서기 전**이라
#  거기서 밀면 _view_fit 의 get_viewport_rect 가 프레임마다 오류를 뱉는다(게임
#  3548행이 커서에 같은 가드를 이미 달아 둔 그 자리다). 첫 프레임까지 미룬다.
var _g: Node = null
var _done := false


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-36s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_dev_probe.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	_g = g
	root.add_child(g)
	g.set_process(false)
	g._new_run()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	Dev.on = true
	Dev.page = 2

	print("\n── 칸 자리 ───────────────────────────────")
	_geometry(g)
	print("\n── 부딪힘 한 번 ──────────────────────────")
	_smash1(g)
	print("\n── 조준 ──────────────────────────────────")
	_aim(g)
	print("\n── 계산 ──────────────────────────────────")
	_score(g)
	print("\n── 새 줄 여섯 ────────────────────────────")
	_newrows(g)


#  트리가 선 첫 프레임. ⑥번 블록만 여기서 돈다.
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	print("\n── 점수 카드 걸음 ────────────────────────")
	_card(_g)

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "개발자 판 전부 통과"))
	quit(mini(fails, 125))
	return true


func _find(g: Node, label: String) -> int:
	var rows: Array = Dev._rows(g)
	for i in rows.size():
		if String(rows[i].get("n1", "")) == label:
			return i
	return -1


# ── 새 줄 여섯 (2026-09-19) ─────────────────────────────
#  게임에 만든 것은 같은 턴에 개발자 모드에도 길을 낸다.
#  ⚠ 목록형 줄은 **_names 와 _cur_name 에 갈래를 둘 다** 내야 한다.
#  한쪽만 내면 값 칸을 눌렀을 때 고르개가 텅 빈 채로 뜬다 — 「(없음)」이
#  화면에 남는 그 사고를 여기서 자로 굳힌다.
func _newrows(g: Node) -> void:
	var page0 := Dev.page
	#  page 0 「경제·진행」
	Dev.page = 0
	for nm in ["정산 빨리 보기", "빨리 보기 고정", "런 끝 잠금 풀기"]:
		_say(_find(g, nm) >= 0, "page 0 에 「%s」 줄이 있다" % nm)
	#  page 1 「물건」
	Dev.page = 1
	for nm in ["손가락인 척", "판매 단추 세우기", "툴팁 얕게/깊게", "로비 겨눔 세우기"]:
		_say(_find(g, nm) >= 0, "page 1 에 「%s」 줄이 있다" % nm)

	#  고르개가 안 빈다.
	var names := Dev._names("fast")
	_say(names.size() == 4, "「fast」 고르개가 안 빈다", "%s" % [names])
	_say(String(Dev._cur_name(g, {"k": "fast"})).contains("/"),
			"「fast」 값 칸이 「n/4 이름」 꼴이다",
			Dev._cur_name(g, {"k": "fast"}))

	#  누르는 그 순간 게임에 반영된다.
	Dev.page = 0
	var i0 := _find(g, "정산 빨리 보기")
	Dev.pick["fast"] = 0
	Dev._run(g, Dev._rows(g)[i0])
	_say(is_equal_approx(g.fast_mul, 1.0), "사다리 1칸 → 1배",
			"%.1f" % g.fast_mul)
	Dev.pick["fast"] = 3
	Dev._run(g, Dev._rows(g)[i0])
	_say(is_equal_approx(g.fast_mul, 3.0), "사다리 4칸 → 3배",
			"%.1f" % g.fast_mul)
	g.fast_mul = 2.5

	var lock0: bool = g.fast_lock
	Dev._run(g, {"a": "fast_lock"})
	_say(g.fast_lock != lock0, "「빨리 보기 고정」이 뒤집는다")
	Dev._run(g, {"a": "fast_lock"})

	g.over_t = 0.0
	Dev._run(g, {"a": "over_unlock"})
	_say(g._over_live(), "「런 끝 잠금 풀기」가 잠금을 푼다",
			"over_t %.1f" % g.over_t)

	var hv0: bool = g.hover_live
	Dev._run(g, {"a": "touch"})
	_say(g.hover_live != hv0, "「손가락인 척」이 얹힘 길을 끈다",
			"hover_live %s" % g.hover_live)
	#  끈 뒤에라야 층 줄이 뜻을 가진다.
	var lite0: bool = g.tip_lite
	Dev._run(g, {"a": "tip_layer"})
	_say(g.tip_lite != lite0, "「툴팁 얕게/깊게」가 층을 뒤집는다",
			"tip_lite %s" % g.tip_lite)
	Dev._run(g, {"a": "touch"})          # 얹힘을 도로 켠다
	g.tip_lite = false

	Dev._run(g, {"a": "lobby_arm"})
	_say(g.lobby_arm, "「로비 겨눔 세우기」가 겨눔을 세운다")
	Dev._run(g, {"a": "lobby_arm"})
	_say(not g.lobby_arm, "한 번 더 누르면 푼다")

	g.owned.clear()
	for it in GameData.items():
		g.owned.append((it as Dictionary).duplicate())
		break
	Dev._run(g, {"a": "sell_arm"})
	_say(g.sell_sel == 0 and (g._sell_btn_rect() as Rect2).size.x > 0.0,
			"「판매 단추 세우기」가 단추를 세운다", "%s" % g._sell_btn_rect())
	g.sell_sel = -1
	g.owned.clear()
	Dev.page = page0


# ── ① 그려지는 자리와 눌리는 자리 ────────────────────────
func _geometry(g: Node) -> void:
	var bad := []
	for pg in Dev.PAGES.size():
		Dev.page = pg
		var rows: Array = Dev._rows(g)
		for i in rows.size():
			if String(rows[i].get("t", "")) != "list":
				continue
			var r: Rect2 = Dev._row(i)
			var la: Rect2 = Dev._arrow(r, false)
			var ra: Rect2 = Dev._arrow(r, true)
			var vb: Rect2 = Dev._val_box(r)
			var who := "%s쪽 %s" % [pg, rows[i].get("n1", "")]
			if not r.encloses(la) or not r.encloses(ra) or not r.encloses(vb):
				bad.append(who + "(줄 밖)")
			if la.intersects(vb) or ra.intersects(vb) or la.intersects(ra):
				bad.append(who + "(겹침)")
			if la.position.x >= ra.position.x:
				bad.append(who + "(좌우 뒤바뀜)")
	Dev.page = 2
	_say(bad.is_empty(), "화살표·값 칸이 줄 안에서 안 겹친다", "어긋난 줄 " + str(bad))


# ── ②③④⑤ 조준 ─────────────────────────────────────────
func _aim(g: Node) -> void:
	var i := _find(g, "조준 방식")
	if i < 0:
		_say(false, "판·조준 쪽에 조준 줄이 있다")
		return
	var r: Rect2 = Dev._row(i)
	var la: Rect2 = Dev._arrow(r, false)
	var ra: Rect2 = Dev._arrow(r, true)
	Dev.pick["aim"] = 0
	Dev.click(g, ra.get_center())            # 처음부터 한 칸 앞으로
	var first := String(g.aim_mode)
	_say(first == String(GameData.AIM_MODES[1]),
			"▶ 를 누르면 그 자리에서 다음 방식이 된다",
			"기대 %s · 실제 %s" % [GameData.AIM_MODES[1], first])

	Dev.click(g, la.get_center())            # 다시 뒤로
	_say(g.aim_mode == String(GameData.AIM_MODES[0]),
			"◀ 는 뒤로 간다 (방향이 안 뒤집힌다)",
			"기대 %s · 실제 %s" % [GameData.AIM_MODES[0], g.aim_mode])

	# 여덟을 차례로 다 지나 제자리로 돌아온다
	var seen := {}
	for k in GameData.AIM_MODES.size():
		Dev.click(g, ra.get_center())
		seen[String(g.aim_mode)] = true
	_say(seen.size() == GameData.AIM_MODES.size() and g.aim_mode == "std",
			"여덟 방식을 차례로 다 고를 수 있다",
			"지나온 방식 %d · 한 바퀴 뒤 %s" % [seen.size(), g.aim_mode])

	# 판을 넘겨도 남는다 — 이것이 값만 박으면 안 되는 자리다
	Dev.click(g, ra.get_center())
	var want := String(g.aim_mode)
	g._start_leg()
	_say(g.aim_mode == want, "고른 조준이 판을 넘겨도 남는다",
			"고른 %s · 판 넘긴 뒤 %s" % [want, g.aim_mode])
	_say(g._aim_from_items() == want, "동전이 그 방식을 쥐고 있다",
			g._aim_from_items())

	# 겹쳐 고르면 앞엣것이 남지 않는다 — 조준 동전은 한 장뿐이어야 한다
	Dev.click(g, ra.get_center())
	Dev.click(g, ra.get_center())
	var held := 0
	for it in g.owned:
		if String(it.get("aim", "")) != "":
			held += 1
	_say(held <= 1, "조준 동전이 겹쳐 쌓이지 않는다", "쥔 장 %d" % held)
	_say(g.owned.size() <= GameData.max_items(), "동전 슬롯이 안 넘친다",
			"%d / %d" % [g.owned.size(), GameData.max_items()])

	# std 로 돌아온다. 값 칸은 이제 **전체 목록을 편다** — 화살표는 옆칸을
	# 볼 때 쓰고 멀리 있는 것은 목록에서 바로 집는 규약이라, 돌아가는 길도
	# 그 길이다. 여기서 목록을 안 닫으면 뒤따르는 클릭을 고르개가 통째로
	# 삼켜 다음 검사(계산 방식)가 통으로 죽는다 — 실제로 그랬다.
	Dev.click(g, Dev._val_box(r).get_center())
	_say(Dev.open_k == "aim", "값 칸을 누르면 목록이 열린다",
			"열린 갈래 '%s'" % Dev.open_k)
	Dev.click(g, Dev._pick_cell(0).get_center())
	var left := 0
	for it in g.owned:
		if String(it.get("aim", "")) != "":
			left += 1
	_say(g.aim_mode == "std" and left == 0 and Dev.open_k == "",
			"목록에서 기본을 집으면 동전도 떨어진다",
			"방식 %s · 남은 조준 동전 %d · 고르개 '%s'"
			% [g.aim_mode, left, Dev.open_k])


# ── 「부딪힘 한 번」이 누를 때마다 같은 것을 낸다 ────────
#
#  이 줄은 _sweep_begin 을 안 부른다 — 그래서 _sweep_reset 도 안 돈다.
#  소리 문(smash_snd_n)을 안 열어 두면 **다섯 번째 누름부터 영영 무음**이
#  된다: 직전 쓸기가 상한(SMASH.snd_max)을 다 쓴 채로 남아 있기 때문이다
#  (2026-09-18 에 실제로 그랬다). 줄이 제 주석에 적어 둔 것 — 「조각 · 먼지 ·
#  턱 자국 · 소리를 한 번에 세워 놓고」 — 을 **누를 때마다** 다 내는지 여기서
#  못 박는다. 턱 자국은 sweep_live 가 아니라 open(상점 안인가)으로 걸리므로
#  쓸기를 안 열어도 뜬다(game.gd _chute_draw).
func _smash1(g: Node) -> void:
	Dev.page = 1
	var i := _find(g, "부딪힘 한 번")
	if i < 0:
		_say(false, "물건 쪽에 부딪힘 줄이 있다")
		Dev.page = 2
		return
	var c: Vector2 = Dev._row(i).get_center()
	var mute := []                 # 소리가 안 난 누름
	var no_mark := []              # 자국이 안 남은 누름
	var no_shard := []             # 조각이 안 난 누름
	var seeds := {}                # 눌러도 같은 조각이 나면 여기가 안 는다
	#  여섯 번 — 상한(SMASH.snd_max)이 넷이라 다섯째부터가 옛 무음 구간이다.
	for k in 6:
		Dev.click(g, c)
		if g.smash_snd_n <= 0:
			mute.append(k + 1)
		if g.lip_marks.is_empty():
			no_mark.append(k + 1)
		if g.shards.is_empty():
			no_shard.append(k + 1)
		seeds[int(g.smash_seed)] = true
	_say(mute.is_empty(), "누를 때마다 소리가 난다", "무음이던 누름 " + str(mute))
	_say(no_mark.is_empty(), "누를 때마다 턱 자국이 남는다",
			"자국이 빈 누름 " + str(no_mark))
	_say(no_shard.is_empty(), "누를 때마다 조각이 난다",
			"조각이 빈 누름 " + str(no_shard))
	_say(seeds.size() == 6, "누를 때마다 다른 조각이 난다",
			"여섯 번에 씨 %d 벌" % seeds.size())
	Dev.page = 2


func _score(g: Node) -> void:
	var i := _find(g, "계산 방식")
	if i < 0:
		_say(false, "판·조준 쪽에 계산 줄이 있다")
		return
	var ra: Rect2 = Dev._arrow(Dev._row(i), true)
	Dev.pick["score"] = 0
	var seen := {}
	for k in GameData.SCORE_MODES.size():
		Dev.click(g, ra.get_center())
		seen[String(g.score_mode)] = true
	_say(seen.size() == GameData.SCORE_MODES.size(),
			"계산 방식도 눌러서 다 고를 수 있다",
			"지나온 방식 %d / %d" % [seen.size(), GameData.SCORE_MODES.size()])


# ── ⑥ 미리보기 줄이 판을 안 건드린다 ──────────────────────
#  「점수 카드 걸음」은 진짜 정산 큐를 빌려 탄다. 빌린 것을 **돌려놓는지**가
#  여기서 갈린다 — 안 돌려놓으면 판 점수가 오르고, 다 쓴 동전이 지워지고,
#  Save 가 디스크에 앉는다.
func _card_spin(g: Node, cap := 1200) -> int:
	var n := 0
	while Dev.card_ph > 0 and n < cap:
		g._process(1.0 / 60.0)
		n += 1
	return n


func _card(g: Node) -> void:
	Dev.page = 0
	var i := _find(g, "점수 카드 걸음")
	if i < 0:
		_say(false, "경제·진행 쪽에 점수 카드 줄이 있다")
		Dev.page = 2
		return
	var r: Rect2 = Dev._row(i)
	# 화살표도 값 칸도 아닌 자리 — 고른 단을 그대로 실행한다.
	var run_at := Vector2(r.position.x + 4.0, r.get_center().y)

	# 이름이 「(없음)」으로 뜨는 함정. _list("cardfx") 가 빈 배열이라
	# _cur_name 에 제 갈래가 없으면 화면에 아무것도 안 뜬다.
	var names := []
	for ci in 3:
		Dev.pick["cardfx"] = ci
		#  _cur_name 은 2026-09-18 에 g 를 받게 됐다(조준 저울 줄이 상점 풀을
		#  실제로 굴려 보기 때문이다). 여기는 그 갈래를 안 타지만 서명은 같이 따른다.
		names.append(Dev._cur_name(g, {"t": "list", "k": "cardfx", "n": 3}))
	_say(not String(names[0]).contains("없음") and names[0] != names[2],
			"고른 단 이름이 화면에 뜬다", str(names))

	for ci in 3:
		g._start_leg()
		g._swap_skip()
		g.state = g.S.AIM_V
		Save.wipe()
		# 앞 발이 남긴 값이 있는 자리에서 눌러 본다 — 0 에서 시작하면
		# 「안 돌려놨다」와 「원래 0 이었다」가 구별이 안 된다.
		g.cur_chip = 77
		g.cur_mult = 5
		g.last_gain = 385
		g.owned.append({"n": "닳는 것", "k": "chip", "c": "always", "v": 1,
				"grow": "tdec", "gstep": 1, "gs": 1, "id": "_probe", "price": 0})
		var tot0: int = g.total
		var own0: int = g.owned.size()
		var st0: int = g.state
		Dev.pick["cardfx"] = ci
		Dev.click(g, run_at)
		var fr := _card_spin(g)
		var nm := String(Dev.CARDFX_STEPS[ci])
		_say(fr < 1200, "%s — 미리보기가 스스로 끝난다" % nm, "%d 프레임" % fr)
		_say(g.total == tot0, "%s — 판 점수가 안 오른다" % nm,
				"%d → %d" % [tot0, g.total])
		_say(Save.stat("best_gain") == 0 and Save.stat("best_score") == 0,
				"%s — 개인 기록이 안 앉는다" % nm,
				"best_gain %d · best_score %d"
				% [Save.stat("best_gain"), Save.stat("best_score")])
		_say(g.owned.size() == own0, "%s — 다 쓴 동전이 안 지워진다" % nm,
				"%d → %d장" % [own0, g.owned.size()])
		_say(g.state == st0, "%s — 누르기 전 자리로 돌아온다" % nm,
				"%d → %d" % [st0, g.state])
		_say(g.cur_chip == 77 and g.cur_mult == 5 and g.last_gain == 385,
				"%s — 카드에 적힌 수도 돌아온다" % nm,
				"%d × %d · +%d" % [g.cur_chip, g.cur_mult, g.last_gain])
		g.owned.clear()

	# 진행 중인 진짜 정산 위에서 누르면 그 발의 남은 걸음이 통째로 날아간다.
	g._start_leg()
	g._swap_skip()
	g.state = g.S.RESOLVE
	g.queue.clear()
	g.queue.append({"k": "chip", "v": 7})
	g.queue.append({"k": "total"})
	Dev.pick["cardfx"] = 0
	Dev.click(g, run_at)
	_say(g.queue.size() == 2 and Dev.card_ph == 0,
			"진행 중인 진짜 정산 위에서는 안 열린다", "남은 걸음 %d" % g.queue.size())
	Dev.page = 2
