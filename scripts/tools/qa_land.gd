extends SceneTree

#  등장 프로브 — 「등급이 앉는 순간」이 수로도 성립하는가  (2026-09-20)
#
#  지금까지 아무도 이 자리를 안 재고 있었다. qa_shoproll 은 머리말이 스스로
#  「동전 갈래 안의 저울은 여기가 안 본다」고 적었고(갈래만 센다), qa_aimroll
#  만 조준 바닥을 보며, qa_rank 는 **서 있는 상태**만 잰다. 이 검사가 그
#  사이의 빈칸 — **나타나는 순간** — 을 메운다.
#
#  재는 것: 등급마다 나는가 · 일반에서 조용한가 · 튐마다 다시 안 드는가 ·
#  박자가 0 인가 · 상한이 박혀 있는가 · 리롤 연타로 안 누적되는가 ·
#  **확률이 한 톨도 안 움직였는가** · 부풂이 두 함수 다 타는가 ·
#  글자가 0자인가 · 입력이 안 막히는가 · 팩에서도 문이 도는가 ·
#  모션 끄기에서 갈리는가 · 소리와 화면이 같은 프레임인가 · 되살리기.
#
#  ── 소리를 어떻게 가로채는가 ────────────────────────────
#  게임의 _sfx 는 sfx_pool 이 비어 있지 않으면 AudioStreamPlayer 에 stream 과
#  pitch_scale 을 **박고** play() 한다. 그래서 풀을 우리가 깔아 두면 **무엇이
#  어느 음으로 났는지**가 그 노드에 그대로 남는다 — 자가 그림을 안 읽고
#  파일 이름과 실제 피치를 대조하는 유일한 길이다. sfx_next 가 어디까지
#  돌았는지로 이번 프레임에 난 것만 걷는다.
#
#  실행:  godot --headless --path . --script scripts/tools/qa_land.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var step := 0
var fails := 0
var seed_v := 20260920

var _snd_at := 0          # 지난번에 걷어 간 sfx_next
var _snd_log := []        # {n: 이름, p: 피치, f: 실제 Hz, k: 프레임 번호}
var _frame := 0
var _done := false


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-30s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


# ══ 소리 가로채기 ═══════════════════════════════════════════
func _snd_setup() -> void:
	for sp in g.sfx_pool:
		sp.queue_free()
	g.sfx_pool.clear()
	#  풀을 **열여섯으로** 깐다(게임은 넷). 관찰용이다 — 한 프레임에 넷이
	#  한꺼번에 나면(팩) 넷짜리 풀은 sfx_next 가 제자리로 돌아와 **난 것을
	#  통째로 못 본다.** 문(land_snd_n · LAND.max)은 게임 상태라 풀 크기와
	#  무관하므로, 넓힌 풀이 재는 값을 안 바꾼다.
	for i in 16:
		var sp := AudioStreamPlayer.new()
		sp.bus = "SFX"
		g.add_child(sp)
		g.sfx_pool.append(sp)
	g.sfx_next = 0
	_snd_at = 0
	_snd_log.clear()


#  이번 프레임에 난 소리를 걷는다. sfx_next 가 돈 만큼만 읽는다.
func _snd_drain() -> void:
	var n: int = g.sfx_pool.size()
	if n <= 0:
		return
	var cur: int = g.sfx_next
	var k: int = _snd_at
	var guard := 0
	while k != cur and guard < 32:
		guard += 1
		var pl: AudioStreamPlayer = g.sfx_pool[k]
		var nm := ""
		if pl.stream != null:
			nm = String(pl.stream.resource_path).get_file().get_basename()
		#  **실제로 나는 음은 pitch_scale x 그 파일의 밑음**이다 — SFX_BASE 가
		#  아니다. _sfx 는 pitch_scale = f/SFX_BASE 로 밀 뿐이고, 파일이 제
		#  밑음으로 구워져 있으므로 들리는 음은 밑음에 그 배수가 걸린 값이다.
		#  여기를 SFX_BASE 로 쓰면 coin_plaque(밑음 262 · 피치 1.0)가 392 로
		#  잘못 찍힌다 — 표의 f 가 곧 구운 밑음이다(sfx_bake 가 그 값으로 짓는다).
		var base: float = float(g.SFX_BASE)
		if g.SFX.has(nm) and (g.SFX[nm] as Dictionary).has("f"):
			base = float(g.SFX[nm].f)
		_snd_log.append({"n": nm, "p": float(pl.pitch_scale),
				"f": float(pl.pitch_scale) * base, "k": _frame})
		k = (k + 1) % n
	_snd_at = cur


func _snd_reset() -> void:
	_snd_at = g.sfx_next
	_snd_log.clear()


func _names() -> Array:
	var o := []
	for e in _snd_log:
		o.append(String(e.n))
	return o


# ══ 딜링 하나를 감는다 ══════════════════════════════════════
#  게임이 까는 그 길을 그대로 탄다(_open_shop → _roll_stock → stock 교체 →
#  _drop_roll). dev.gd 의 _form_table 과 같은 어법이다 — 공짜 칸을 **안
#  건너뛴다**: 레전더리는 그 공짜 칸이 곧 제 무대라, 건너뛰면 줄이 거짓말이 된다.
func _setup(ids: Array) -> void:
	if g.state != g.S.SHOP:
		g._open_shop()
	g._roll_stock()
	for i in ids.size():
		if i >= g.stock.size():
			break
		var d := _item_by(String(ids[i]))
		if d.is_empty():
			continue
		var fr: bool = bool(g.stock[i].get("free", false))
		var e := {"type": "item", "d": d, "sold": false,
				"cost": 0 if fr else int(d.get("cost", 0))}
		if fr:
			e["free"] = true
		g.stock[i] = e


#  한 딜링을 프레임 폭 dt 로 감는다. _drop_update 의 차례 그대로 —
#  물리만 acc 에 이월해 sub 으로 쪼개고, _drop_extras 는 프레임 폭으로.
#  suppress 면 첫 착지 갈래를 통째로 막는다(land 를 미리 세운다) — 「LAND 를
#  끈 기준선」이 그것이고, 물리가 같아야 박자 0 이 증명된다.
func _wind(frames: int, dt: float) -> void:
	var sub: float = float(g.DROP.sub)
	for k in frames:
		_frame += 1
		#  ⚠ **_drop_update 의 문을 그대로 쓴다.** 이 guard 가 없으면 다 잠든
		#  뒤에도 drop_t 가 계속 자라 t_max(2.6)를 넘고, 「낙하가 t_max 에 안
		#  닿는다」가 검사 제 탓으로 거짓이 된다.
		if g.drop_awake or g.sweep_live:
			g.drop_acc += dt
			var n := 0
			while g.drop_acc >= sub and n < int(g.DROP.sub_max):
				g.drop_acc -= sub
				g.drop_t += sub
				g._drop_step(sub)
				n += 1
			if g.drop_t > float(g.DROP.t_max) and g.drop_awake:
				g._drop_settle()
		g._drop_extras(dt)
		#  흔들림 감쇠 — _process 가 하던 몫이다(_draw 6911 둘레의 d*34).
		g.shake = maxf(g.shake - dt * 34.0, 0.0)
		_snd_drain()


func _deal(ids: Array, suppress := false, frames := 120,
		dt := 1.0 / 60.0) -> void:
	_setup(ids)
	g.leg_fx_seen.clear()
	g.shake = 0.0
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	g.leg_vig = 0.0
	g.leg_vig_up = false
	g.leg_cue_t = -1.0
	g._drop_roll()
	if suppress:
		for it in g.drop:
			it.land = true
		g.leg_cue_t = -1.0
		g.leg_cue_n = 0
	_snd_reset()
	_wind(frames, dt)


static func _item_by(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it
	return {}


static func _first_of(rar: String) -> String:
	for it in GameData.items():
		if String(it.get("rarity", "")) == rar:
			return String(it.id)
	return ""


func _process(_d: float) -> bool:
	step += 1
	if step < 12:
		return false
	#  런타임 오류가 나면 _process 가 중간에 끊기고 다음 프레임에 **처음부터
	#  다시** 돈다 — 한 번만 돌게 못 박는다.
	if _done:
		return true
	_done = true
	seed(seed_v)
	g.set_process(false)
	g.drop_fast = false
	_snd_setup()

	var c0 := _first_of("common")
	var u0 := _first_of("uncommon")
	var r0 := _first_of("rare")
	var l0 := "l02"

	print("== 등장 프로브 — 등급이 앉는 소리·빛 ==")
	print("  쓰는 장: 일반 %s · 희귀 %s · 레어 %s · 레전더리 %s"
			% [c0, u0, r0, l0])

	# ── ① 등급마다 난다 ─────────────────────────────────
	#  **자가 그림을 안 읽고 LAND 표를 읽는다.**
	print("\n-- ① 등급마다 난다 --")
	var want := {
		"common": ["", 0.0],
		"uncommon": ["coin_land", 392.0],
		"rare": ["coin_land", 523.0],
		"legendary": ["coin_plaque", 262.0],
	}
	for rar in ["common", "uncommon", "rare", "legendary"]:
		var id := _first_of(String(rar))
		if String(rar) == "legendary":
			id = l0
		_deal([id, c0, c0, c0])
		#  **마지막** 소리가 착지다 — 레전더리는 앞에 예고 톡 셋이 먼저 난다
		#  (0.111 · 0.211 · 0.341 은 착지 0.411 보다 앞이다). 나머지 셋은
		#  일반이라 침묵이라 이 뒤로 아무것도 안 난다.
		var li: int = _snd_log.size() - 1
		var nm := "" if li < 0 else String(_snd_log[li].n)
		var hz := 0.0 if li < 0 else float(_snd_log[li].f)
		var w: Array = want[rar]
		var okn: bool = nm == String(w[0])
		var okf: bool = absf(hz - float(w[1])) < 1.0 if String(w[0]) != "" else true
		var bloom: float = g._land_bloom(String(rar))
		var wb: float = float((g.LAND[rar] as Array)[2])
		_ok("등급 %s" % rar, okn and okf and absf(bloom - wb) < 0.001,
				"소리 '%s' %.0fHz (바람 '%s' %.0fHz) · 부풂 x%.2f"
				% [nm, hz, String(w[0]), float(w[1]), 1.0 + bloom])

	# ── ② 일반에서 조용한가 ─────────────────────────────
	print("\n-- ② 일반은 침묵이 표식이다 --")
	_deal([c0, c0, c0, c0])
	var lg_max := 0.0
	for it in g.drop:
		lg_max = maxf(lg_max, float(it.get("lg", 0.0)))
	_ok("일반 넷 — 소리 0 · 빛 0", _snd_log.is_empty()
			and lg_max <= 0.0 and g.leg_vig <= 0.0 and g.shake <= 0.001,
			"소리 %d건 · 부풂 최대 %.3f · 비네트 %.3f · 흔들림 %.2f"
			% [_snd_log.size(), lg_max, float(g.leg_vig), float(g.shake)])
	#  _glow_of("common").a == 0 (qa_shoproll ⑧) 규약의 **소리 쪽 짝**이다.
	_ok("빛 규약과 짝이 맞다", float(g._glow_of("common").a) == 0.0
			and String((g.LAND.common as Array)[0]) == "",
			"_glow_of(common).a = 0 이고 LAND.common 소리 이름이 빈 문자열")

	# ── ③ 한 번만 난다 (튐마다 다시 안 든다) ────────────
	print("\n-- ③ 첫 착지 한 번뿐 --")
	#  튀는 동전은 v_land 를 여러 번 넘는다(e_item 0.34 에서 첫 충돌 rv≈189,
	#  둘째 64, 셋째 22). land 플래그가 실제로 일하는가.
	_deal([r0, r0, r0, r0], false, 180)
	var n_rare: int = _snd_log.size()
	var all_land := true
	for it in g.drop:
		if not bool(it.get("land", false)):
			all_land = false
	_ok("레어 넷 — 소리가 넷뿐", n_rare == 4 and all_land,
			"소리 %d건 (물건 4개) · 전부 land=true %s" % [n_rare, all_land])
	#  **두 갈래 다 걸었는가.** DROP 은 const 라 못 고친다(읽기 전용 사전) —
	#  대신 **물건 하나를 아랫갈래 조건으로 손수 세운다**: vh −10 이면
	#  rv = 10 x e_item 0.34 = 3.4 로 v_land 42 밑이라 else 갈래로 간다.
	#  지금 값에서는 첫 착지가 늘 윗갈래지만, 나중에 누가 v_land 나 e 를
	#  만지면 조용히 이쪽으로 넘어온다 — 그 회귀를 여기서 막는다.
	g.land_snd_n = 0
	g.land_snd_t = 0.0
	g.hush_t = 0.0
	var it0: Dictionary = g.drop[0]
	it0.land = false
	it0.air = true
	it0.sleep = false
	it0.h = 0.0001
	it0.vh = -10.0
	var rv_lo: float = 10.0 * float(it0.e)
	_snd_reset()
	g._drop_step(float(g.DROP.sub))
	_snd_drain()
	var n_lo: int = _snd_log.size()
	var nm_lo := "" if n_lo == 0 else String(_snd_log[0].n)
	_ok("아랫갈래도 한 번", n_lo == 1 and nm_lo == "coin_land"
			and bool(it0.land),
			"rv %.1f < v_land %.0f → else 갈래 · 소리 %d건 '%s'"
			% [rv_lo, float(g.DROP.v_land), n_lo, nm_lo])

	# ── ④ 박자 0 ────────────────────────────────────────
	print("\n-- ④ 박자 +0.000초 --")
	#  같은 씨로 두 번 감는다: LAND 를 켠 채와 끈 채. 물리 상수를 한 자도
	#  안 건드렸으므로 정착 시각도 자리도 **소수점까지** 같아야 한다.
	var pos_on := []
	var pos_off := []
	var t_on := 0.0
	var t_off := 0.0
	for pass_i in 2:
		seed(seed_v + 77)
		_deal([l0, r0, u0, c0], pass_i == 1, 240)
		var arr := []
		for it in g.drop:
			arr.append(Vector2(float(it.u), float(it.w)))
		if pass_i == 0:
			pos_on = arr
			t_on = float(g.drop_t)
		else:
			pos_off = arr
			t_off = float(g.drop_t)
	var same := pos_on.size() == pos_off.size()
	var dmax := 0.0
	if same:
		for i in pos_on.size():
			dmax = maxf(dmax, (pos_on[i] - pos_off[i]).length())
	_ok("정착 자리가 같다", same and dmax == 0.0,
			"물건 %d개 · 최대 위치차 %.9fpx · drop_t %.5f 대 %.5f"
			% [pos_on.size(), dmax, t_on, t_off])
	_ok("낙하가 t_max 에 안 닿는다", t_on < float(g.DROP.t_max),
			"drop_t %.3f < t_max %.2f" % [t_on, float(g.DROP.t_max)])
	#  ── 첫 착지가 언제인가 — **연출 예산이 이 수에서 나온다** ──
	#  h·vh 에서 역산한다(qa_smash 의 _land_t 와 같은 식). 딜링 t=0 부터
	#  여기까지가 비어 있는 시간이고, 레전더리 예고 0.341초가 그 안에 든다.
	var lo := 1.0e9
	var hi := 0.0
	var sum := 0.0
	var cnt := 0
	var gv: float = float(g.DROP.g)
	for r in 300:
		seed(seed_v + 900 + r)
		_setup([r0, c0, c0, c0])
		g.leg_fx_seen.clear()
		g._drop_roll()
		var it: Dictionary = g.drop[0]
		var hh: float = float(it.h)
		var vv: float = float(it.vh)
		var tt: float = float(it.t0) + (vv + sqrt(vv * vv + 2.0 * gv * hh)) / gv
		lo = minf(lo, tt)
		hi = maxf(hi, tt)
		sum += tt
		cnt += 1
	var avg: float = sum / maxf(float(cnt), 1.0)
	_ok("예고가 첫 착지 앞에 다 든다", float(g.LAND.cue[2]) < lo,
			"첫 착지 %.3f~%.3f초(평균 %.3f · %d롤) · 마지막 톡 %.3f 가 그 앞이다"
			% [lo, hi, avg, cnt, float(g.LAND.cue[2])])

	# ── ⑤ 상한이 박혀 있다 ──────────────────────────────
	print("\n-- ⑤ 상한 여섯 --")
	_deal([l0, r0, u0, c0], false, 240)
	var cue_n: int = g.leg_cue_n
	var cue_snd := 0
	var plq := 0
	for e in _snd_log:
		if String(e.n) == "coin_plaque":
			plq += 1
	#  예고 톡 셋은 coin_land 를 294/330/392 로 민 것이다.
	for e in _snd_log:
		if String(e.n) == "coin_land" and float(e.f) < 400.0:
			cue_snd += 1
	_ok("예고 톡이 정확히 셋", cue_n == 3 and cue_snd >= 3,
			"leg_cue_n %d · 400Hz 아래 톡 %d건" % [cue_n, cue_snd])
	_ok("예고 상한 lead", float(g.LAND.lead) >= float(g.LAND.cue[2])
			and float(g.LAND.lead) < 0.50,
			"lead %.3f ≥ 마지막 톡 %.3f" % [float(g.LAND.lead),
					float(g.LAND.cue[2])])
	_ok("플라크는 딜링당 하나", plq == 1, "coin_plaque %d건" % plq)
	_ok("딜링당 소리 ≤ max", g.land_snd_n <= int(g.LAND.max),
			"land_snd_n %d ≤ LAND.max %d" % [g.land_snd_n, int(g.LAND.max)])
	#  흔들림 — 리롤 6.0 을 안 넘는 것이 계약이다.
	var sh_peak := 0.0
	seed(seed_v + 5)
	_setup([l0, c0, c0, c0])
	g.leg_fx_seen.clear()
	g.shake = 0.0
	g._drop_roll()
	_snd_reset()
	for k in 240:
		_frame += 1
		g.drop_acc += 1.0 / 60.0
		var ns := 0
		while g.drop_acc >= float(g.DROP.sub) and ns < int(g.DROP.sub_max):
			g.drop_acc -= float(g.DROP.sub)
			g.drop_t += float(g.DROP.sub)
			g._drop_step(float(g.DROP.sub))
			ns += 1
		g._drop_extras(1.0 / 60.0)
		sh_peak = maxf(sh_peak, float(g.shake))
		g.shake = maxf(g.shake - (1.0 / 60.0) * 34.0, 0.0)
		_snd_drain()
	_ok("흔들림이 리롤 밑이다", sh_peak <= float(g.LAND.shake) + 0.001
			and sh_peak < 6.0,
			"최대 %.2f ≤ LAND.shake %.1f < 리롤 6.0" % [sh_peak,
					float(g.LAND.shake)])
	_ok("부풂 수명 ≤ cap", float((g.LAND.legendary as Array)[3])
			<= float(g.LAND.cap)
			and float((g.LAND.rare as Array)[3]) <= float(g.LAND.cap),
			"레전더리 %.2f · 레어 %.2f ≤ cap %.2f"
			% [float((g.LAND.legendary as Array)[3]),
					float((g.LAND.rare as Array)[3]), float(g.LAND.cap)])
	_ok("gap 이 SMASH 와 stag 사이", float(g.LAND.gap) > float(g.SMASH.snd_gap)
			and float(g.LAND.gap) < float(g.DROP.stag),
			"SMASH.snd_gap %.3f < LAND.gap %.3f < DROP.stag %.3f"
			% [float(g.SMASH.snd_gap), float(g.LAND.gap), float(g.DROP.stag)])

	# ── ⑥ 리롤 연타 — 한 상점에서 드러냄은 한 벌 ────────
	print("\n-- ⑥ 리롤이 드러냄을 누적하지 않는다 --")
	seed(seed_v + 11)
	g.leg_no = 3
	g.leg_fx_seen.clear()
	var cue_on := 0
	var vig_on := 0
	var shk_on := 0
	var knk_on := 0
	var plq_on := 0
	for r in 8:
		_setup([l0, c0, c0, c0])
		g.shake = 0.0
		g._drop_roll()
		if g.leg_cue_t >= 0.0:
			cue_on += 1
		_snd_reset()
		#  ⚠ **감는 동안의 최대값으로 잰다.** _wind(90) = 1.5초 **뒤**에 보면
		#  비네트는 이미 0 이고 흔들림도 죽어 있다 — 그 자리에서 재면 여덟
		#  번 나도 0 으로 보인다. 전에 vig_on 이 단언 한 줄 없는 **죽은
		#  변수**였던 것이 정확히 이 착각 위에 있었다(2026-09-20).
		var vg_pk := 0.0
		var sh_pk2 := 0.0
		var kn_pk := 0.0
		for k in 90:
			_frame += 1
			if g.drop_awake or g.sweep_live:
				g.drop_acc += 1.0 / 60.0
				var ns6 := 0
				while g.drop_acc >= float(g.DROP.sub) and ns6 < int(g.DROP.sub_max):
					g.drop_acc -= float(g.DROP.sub)
					g.drop_t += float(g.DROP.sub)
					g._drop_step(float(g.DROP.sub))
					ns6 += 1
			g._drop_extras(1.0 / 60.0)
			vg_pk = maxf(vg_pk, float(g.leg_vig))
			sh_pk2 = maxf(sh_pk2, float(g.shake))
			#  _knock(17290)이 쥐는 값은 lv 다 — ⑫ 가 같은 열쇠를 본다.
			if g.drop.size() > 0:
				kn_pk = maxf(kn_pk, absf(float(g.drop[0].get("lv", 0.0))))
			g.shake = maxf(g.shake - (1.0 / 60.0) * 34.0, 0.0)
			_snd_drain()
		if vg_pk > 0.001:
			vig_on += 1
		if sh_pk2 > 0.001:
			shk_on += 1
		if kn_pk > 0.001:
			knk_on += 1
		for nm6 in _names():
			if String(nm6) == "coin_plaque":
				plq_on += 1
	_ok("여덟 딜링에 예고 한 번", cue_on == 1,
			"예고가 켜진 딜링 %d/8" % cue_on)
	#  ⚠ **예고만 잠그면 안 된다.** 전에는 비네트·흔들림·튕김이 문 밖에
	#  있어 예고 1회에 **비네트 8회 · 흔들림 8회**가 났다 — 세 줄이 그
	#  회귀를 잠근다.
	_ok("여덟 딜링에 비네트 한 번", vig_on == 1,
			"비네트가 오른 딜링 %d/8" % vig_on)
	_ok("여덟 딜링에 흔들림 한 번", shk_on == 1,
			"흔들림이 오른 딜링 %d/8" % shk_on)
	_ok("여덟 딜링에 튕김 한 번", knk_on == 1,
			"_knock 이 든 딜링 %d/8" % knk_on)
	#  소리·번짐·바닥 빛은 **계속 난다** — 사건이 사라지면 안 된다.
	_ok("착지 소리는 딜링마다 난다", plq_on == 8,
			"플라크 %d/8 — 다시 선 장은 소리·번짐·바닥 빛만 받는다" % plq_on)
	#  ── 장 id 로 잠근다 — 판이 바뀌어도 같은 장은 안 다시 난다 ──
	#  공짜 한 장은 손에 넣기 전까지 **상점마다 다시 선다**(2311 주석의
	#  「슬롯이 꽉 차서 못 받았으면 다음 상점에 또 와야 한다」). 판 번호로
	#  잠갔더니 남은 상점 스물셋에서 한 벌이 다시 났다.
	g.leg_no = 4
	_setup([l0, c0, c0, c0])
	g._drop_roll()
	_ok("판이 바뀌어도 같은 장은 한 번",
			g.leg_cue_t < 0.0 and not bool(g.leg_fx_arm),
			"leg_no 4 · 같은 %s — 예고 %s · 자격 %s"
			% [l0, g.leg_cue_t >= 0.0, bool(g.leg_fx_arm)])
	#  다른 장이면 난다 — 드러냄은 **장마다** 한 번이다.
	var l1 := ""
	for it6 in GameData.items():
		if String(it6.get("rarity", "")) == "legendary" and String(it6.id) != l0:
			l1 = String(it6.id)
			break
	_setup([l1, c0, c0, c0])
	g._drop_roll()
	_ok("다른 장이면 다시 난다",
			l1 != "" and g.leg_cue_t >= 0.0 and bool(g.leg_fx_arm),
			"%s 에서 예고 켜짐 %s" % [l1, g.leg_cue_t >= 0.0])
	#  ── 마지막 칸이어도 난다 ────────────────────────────
	#  개발자 판의 「등급마다 등장」줄이 사다리 넷을 한 테이블에 세우므로
	#  레전더리가 3번 칸에 선다. 0번 자리만 보면 그 줄에서 한 벌이 통째로
	#  안 나 **재는 줄이 거짓말을 한다.**
	g.leg_fx_seen.clear()
	_setup([c0, u0, r0, l0])
	g.shake = 0.0
	g._drop_roll()
	var tail_arm: bool = bool(g.leg_fx_arm)
	var tail_vig := 0.0
	for k7 in 120:
		_frame += 1
		if g.drop_awake or g.sweep_live:
			g.drop_acc += 1.0 / 60.0
			var ns7 := 0
			while g.drop_acc >= float(g.DROP.sub) and ns7 < int(g.DROP.sub_max):
				g.drop_acc -= float(g.DROP.sub)
				g.drop_t += float(g.DROP.sub)
				g._drop_step(float(g.DROP.sub))
				ns7 += 1
		g._drop_extras(1.0 / 60.0)
		tail_vig = maxf(tail_vig, float(g.leg_vig))
		_snd_drain()
	_ok("마지막 칸이어도 한 벌이 난다", tail_arm and tail_vig > 0.5,
			"자격 %s · 비네트 최대 %.2f (사다리 넷 · 레전더리 3번 칸)"
			% [tail_arm, tail_vig])

	# ── ⑦ 확률이 한 톨도 안 움직였다 ────────────────────
	print("\n-- ⑦ 확률 불변 --")
	var leg_seen := 0
	for nxt in range(1, 25):
		for it in g._stock_items(nxt):
			if String(it.get("rarity", "")) == "legendary":
				leg_seen += 1
	_ok("상점 저울에 레전더리 0", leg_seen == 0,
			"nxt 1~24 전부 훑어 레전더리 %d건 (가중치 0 문)" % leg_seen)
	var lw_bad := 0
	for it in GameData.items():
		if String(it.get("rarity", "")) == "legendary":
			if GameData.item_weight(it) != 0.0:
				lw_bad += 1
	_ok("item_weight 레전더리 0.00", lw_bad == 0,
			"0 이 아닌 레전더리 %d장" % lw_bad)
	#  등급 몫 — 표를 박아 두면 밸런스 자물쇠가 자동으로 잠긴다.
	#  (어긋나면 이 표가 아니라 게임이 맞다 — 그때는 표를 다시 잰다.)
	for probe in [[2, 82.623, 16.066, 1.311], [23, 78.750, 15.312, 5.937]]:
		var nxt: int = int(probe[0])
		var pool: Array = g._stock_items(nxt)
		var tot := 0.0
		var by := {"common": 0.0, "uncommon": 0.0, "rare": 0.0}
		for it in pool:
			var w: float = float(it.get("w", GameData.item_weight(it)))
			tot += w
			var rr := String(it.get("rarity", "common"))
			if by.has(rr):
				by[rr] += w
		var pc: float = 100.0 * by.common / maxf(tot, 0.0001)
		var pu: float = 100.0 * by.uncommon / maxf(tot, 0.0001)
		var pr: float = 100.0 * by.rare / maxf(tot, 0.0001)
		var okp: bool = (absf(pc - float(probe[1])) < 0.05
				and absf(pu - float(probe[2])) < 0.05
				and absf(pr - float(probe[3])) < 0.05)
		_ok("등급 몫 nxt %d" % nxt, okp,
				"일반 %.3f%% · 희귀 %.3f%% · 레어 %.3f%% (풀합 %.2f)"
				% [pc, pu, pr, tot])

	# ── ⑧ 부풂이 두 함수 다 탄다 ────────────────────────
	print("\n-- ⑧ 번짐 부풂이 두 갈래 다 탄다 --")
	#  레전더리는 plaque 라 _rar_glow 를 **한 번도 안 지난다** — 부풂이 닿는
	#  함수는 _coin_glow 다. rank_off 에서는 _coin_form 이 disc 로 떨어져
	#  _rar_glow 로 간다. **두 갈래 다 고쳤는지가 여기서 드러난다.**
	var ld := _item_by(l0)
	var ti: int = g._stk_ti("legendary")
	var tier: Dictionary = g.STK_TIERS[ti]
	g.rank_off = false
	var form_on: String = g._coin_form(ld, tier)
	g.rank_off = true
	var form_off: String = g._coin_form(ld, tier)
	g.rank_off = false
	var fam_on := String(g.FORMS[form_on].get("fam", "disc"))
	var fam_off := String(g.FORMS[form_off].get("fam", "disc"))
	_ok("레전더리가 두 갈래를 다 쓴다", fam_on == "plaque" and fam_off == "disc",
			"기본 '%s'(%s → _coin_glow) · rank_off '%s'(%s → _rar_glow)"
			% [form_on, fam_on, form_off, fam_off])
	#  알파가 1.0 을 안 넘는가 — 두 함수 다 minf 로 자른다.
	var rim: float = float(g.GLOW.rim)
	var bl: float = g._land_bloom("legendary")
	var raw: float = rim * (1.0 + float(tier.pulse_a)) * (1.0 + bl)
	_ok("rim 이 잘려야 하는 자리다", raw > 1.0,
			"자르기 전 %.2f > 1.0 — minf(…,1.0) 가 없으면 범위 밖이다" % raw)
	#  도달은 정의상 안 움직인다 — GLOW.n·step 을 한 자도 안 건드렸다.
	_ok("번짐 도달 불변", int(g.GLOW.n) == 7
			and absf(float(g.GLOW.step) - 2.6) < 0.001,
			"GLOW.n %d · step %.1f → 도달 18.2px (qa_rank ⓥ)"
			% [int(g.GLOW.n), float(g.GLOW.step)])

	# ── ⑨ 글자가 0자다 ──────────────────────────────────
	print("\n-- ⑨ 글자 0자 --")
	g.pops.clear()
	_deal([l0, r0, u0, c0], false, 240)
	_ok("레전더리 딜링에 글자 0", g.pops.is_empty(),
			"pops %d개 — 「레전더리!」 같은 외침도 글이다" % g.pops.size())

	# ── ⑩ 입력이 안 막힌다 ──────────────────────────────
	print("\n-- ⑩ 입력이 안 막힌다 --")
	var sweep_bad := 0
	var stop_bad := 0
	seed(seed_v + 21)
	_setup([l0, r0, u0, c0])
	g.leg_fx_seen.clear()
	g._drop_roll()
	_snd_reset()
	for k in 240:
		_frame += 1
		g.drop_acc += 1.0 / 60.0
		var ns2 := 0
		while g.drop_acc >= float(g.DROP.sub) and ns2 < int(g.DROP.sub_max):
			g.drop_acc -= float(g.DROP.sub)
			g.drop_t += float(g.DROP.sub)
			g._drop_step(float(g.DROP.sub))
			ns2 += 1
		g._drop_extras(1.0 / 60.0)
		if g.sweep_live:
			sweep_bad += 1
		if float(g.hitstop) != 0.0:
			stop_bad += 1
		_snd_drain()
	_ok("sweep_live 를 안 세운다", sweep_bad == 0,
			"켜진 프레임 %d — 상점에서 입력을 통째로 삼키는 유일한 값이다"
			% sweep_bad)
	_ok("hitstop 0건", stop_bad == 0,
			"0 이 아닌 프레임 %d — i=0 이라 나머지 셋이 아직 공중이다" % stop_bad)
	#  건너뛰기 — _drop_settle 이 같은 _drop_step 을 감아 전부 한 프레임에 앉힌다.
	seed(seed_v + 31)
	_setup([l0, r0, u0, c0])
	g.leg_fx_seen.clear()
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	g._drop_roll()
	_snd_reset()
	g._drop_settle()
	_snd_drain()
	var air_left := 0
	for it in g.drop:
		if float(it.h) > 0.0 or not bool(it.sleep):
			air_left += 1
	var skip_names := _names()
	var skip_plq := 0
	for nm2 in skip_names:
		if String(nm2) == "coin_plaque":
			skip_plq += 1
	_ok("건너뛰기 = 한 소리", skip_plq == 1 and skip_names.size() == 1,
			"난 소리 %s — 레전더리는 문을 건너뛰고 나머지는 문에 막힌다"
			% str(skip_names))
	_ok("건너뛰기 뒤 공중 0", air_left == 0,
			"공중에 남은 물건 %d개" % air_left)

	# ── ⑪ 팩에서도 문이 돈다 ────────────────────────────
	print("\n-- ⑪ 팩 — t0 가 없어 넷이 한 프레임에 앉는다 --")
	seed(seed_v + 41)
	if g.state != g.S.SHOP:
		g._open_shop()
	g._roll_stock()
	g.stock.clear()
	g.drop.clear()
	g.boost_spill = []
	for rr5 in ["legendary", "rare", "uncommon", "common"]:
		var id5 := l0 if String(rr5) == "legendary" else _first_of(String(rr5))
		g.boost_spill.append({"type": "item", "d": _item_by(id5)})
	#  봉투 색 — 레전더리가 들었을 때만 ef86c6 다.
	var has_leg := false
	for e in g.boost_spill:
		if String(e.d.get("rarity", "")) == "legendary":
			has_leg = true
	g.boost_card = {"pick": 1}
	g.leg_cue_t = -1.0
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	_snd_reset()
	g._boost_spill()
	var cue_pack: bool = g.leg_cue_t >= 0.0
	var t0s := []
	for it in g.drop:
		t0s.append(float(it.t0))
	var all_zero := true
	for v in t0s:
		if float(v) != 0.0:
			all_zero = false
	_wind(240, 1.0 / 60.0)
	var pk_names := _names()
	var pk_plq := 0
	var pk_land := 0
	for nm3 in pk_names:
		if String(nm3) == "coin_plaque":
			pk_plq += 1
		elif String(nm3) == "coin_land":
			pk_land += 1
	var pk_bloom := 0
	for i in g.drop.size():
		if i < g.stock.size() and float(g.drop[i].get("lgt", 0.0)) > 0.0:
			pk_bloom += 1
	_ok("팩 — 넷이 t0 0 으로 같이 앉는다", all_zero and g.drop.size() == 4,
			"t0 %s · 물건 %d개" % [str(t0s), g.drop.size()])
	_ok("팩 — 예고가 켜진다", cue_pack and has_leg,
			"레전더리 들었다 %s · 예고 %s" % [has_leg, cue_pack])
	_ok("팩 — 플라크 하나 · 소리 ≤ max", pk_plq == 1
			and pk_plq + pk_land <= int(g.LAND.max) + 3,
			"플라크 %d · 착지/톡 %d (톡 셋 포함)" % [pk_plq, pk_land])
	#  소리는 뭉쳐도 **빛은 넷 다 난다** — 레어·레전더리만 부풂을 받는다.
	_ok("팩 — 빛은 제 등급대로", pk_bloom == 2,
			"부풂을 받은 물건 %d개 (레어+레전더리 둘)" % pk_bloom)
	_ok("팩 — drop_toss 계약 그대로", bool(g.drop_toss) == false
			or g._drop_busy() == false,
			"클릭을 안 삼킨다(_drop_busy 가 끝까지 거짓)")

	# ── ⑫ motion_off 에서 갈린다 ────────────────────────
	print("\n-- ⑫ 모션 끄기 — 움직임만 꺼지고 빛·소리는 남는다 --")
	g.motion_off = true
	_deal([l0, c0, c0, c0], false, 240)
	var mo_names := _names()
	var mo_plq := 0
	for nm4 in mo_names:
		if String(nm4) == "coin_plaque":
			mo_plq += 1
	var mo_lv := 0.0
	for it in g.drop:
		mo_lv = maxf(mo_lv, absf(float(it.get("lv", 0.0))))
	var mo_bloom := false
	for i in g.drop.size():
		if float(g.drop[i].get("lgt", 0.0)) > 0.0:
			mo_bloom = true
	g.motion_off = false
	_ok("모션 끄면 knock·shake 만 꺼진다", mo_plq == 1 and mo_bloom
			and mo_lv <= 0.001,
			"플라크 %d건 · 부풂 %s · knock 속도 %.3f · 흔들림 %.2f"
			% [mo_plq, mo_bloom, mo_lv, float(g.shake)])

	# ── ⑬ 소리와 화면이 같은 프레임이다 ─────────────────
	print("\n-- ⑬ 소리와 빛이 같은 프레임 --")
	seed(seed_v + 51)
	_setup([r0, c0, c0, c0])
	g.leg_fx_seen.clear()
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	g._drop_roll()
	_snd_reset()
	var f_snd := -1
	var f_lg := -1
	for k in 240:
		_frame += 1
		g.drop_acc += 1.0 / 60.0
		var ns3 := 0
		while g.drop_acc >= float(g.DROP.sub) and ns3 < int(g.DROP.sub_max):
			g.drop_acc -= float(g.DROP.sub)
			g.drop_t += float(g.DROP.sub)
			g._drop_step(float(g.DROP.sub))
			ns3 += 1
		if f_lg < 0 and float(g.drop[0].get("lg", 0.0)) > 0.0:
			f_lg = k
		var before := _snd_log.size()
		_snd_drain()
		if f_snd < 0 and _snd_log.size() > before:
			f_snd = k
		g._drop_extras(1.0 / 60.0)
	_ok("같은 프레임에 난다", f_snd >= 0 and f_lg >= 0 and f_snd == f_lg,
			"소리 프레임 %d · 부풂 프레임 %d (12ms 안)" % [f_snd, f_lg])

	# ── ⑭ 되살리기에서 한 번만 · 산 장은 조용하다 ───────
	print("\n-- ⑭ 되살리기 --")
	seed(seed_v + 61)
	_setup([l0, r0, u0, c0])
	#  이미 산 장은 _drop_sold_sync 가 sold 를 세우기 **전에** 떨어진다.
	g.stock[1]["sold"] = true
	g.leg_fx_seen.clear()
	g.hush_t = 0.0
	g.land_snd_t = 0.0
	g._drop_roll()
	_snd_reset()
	_wind(240, 1.0 / 60.0)
	var sold_lg: float = float(g.drop[1].get("lg", 0.0))
	var rv_names := _names()
	var rv_land := 0
	for nm5 in rv_names:
		if String(nm5) == "coin_land" and float(nm5.length()) > 0.0:
			rv_land += 1
	_ok("산 장은 빛도 소리도 없다", sold_lg <= 0.0,
			"팔린 레어의 부풂 %.3f — _land_fx 가 stock[i].sold 를 본다" % sold_lg)

	# ── ⑮ 사진 테이블은 등장이 아니다 ───────────────────
	#  _photo_open(14876)이 매물을 치우고 **내가 이미 가진 동전**을 깔면서
	#  _drop_roll 을 부른다. 문이 없으면 보유 레전더리가 사진을 열 때마다
	#  한 벌을 다시 내고, 닫을 때 매물이 다시 깔려 **한 번에 두 번** 난다.
	#  사진은 상점마다 쓸 수 있으니 「프로필당 네 번」이 거기서 무제한이 된다.
	print("\n-- ⑮ 사진 테이블은 조용하다 --")
	seed(seed_v + 71)
	if g.state != g.S.SHOP:
		g._open_shop()
	g._roll_stock()
	g.leg_fx_seen.clear()
	g.owned = [_item_by(l0).duplicate(), _item_by(r0).duplicate(),
			_item_by(u0).duplicate(), _item_by(c0).duplicate()]
	g.shake = 0.0
	g.leg_vig = 0.0
	g.leg_vig_up = false
	_snd_reset()
	g._photo_open("burn", 2)
	var ph_cue: bool = g.leg_cue_t >= 0.0
	var ph_arm: bool = bool(g.leg_fx_arm)
	_wind(180, 1.0 / 60.0)
	var ph_snd := 0
	for nm7 in _names():
		if String(nm7) == "coin_plaque" or String(nm7) == "coin_land":
			ph_snd += 1
	var ph_lg := 0.0
	for it7 in g.drop:
		ph_lg = maxf(ph_lg, float(it7.get("lg", 0.0)))
	_ok("보유 동전은 등장하지 않는다",
			not ph_cue and not ph_arm and ph_snd == 0
			and ph_lg <= 0.0 and float(g.leg_vig) <= 0.0
			and float(g.shake) <= 0.001,
			"예고 %s · 자격 %s · 착지 소리 %d건 · 부풂 %.3f · 비네트 %.3f"
			% [ph_cue, ph_arm, ph_snd, ph_lg, float(g.leg_vig)])
	g._photo_close()
	_snd_reset()
	_wind(180, 1.0 / 60.0)
	g.owned = []

	# ── ⑯ 상점을 떠나도 비네트가 안 얼어붙는다 ──────────
	#  _drop_update(18822)가 `if state != S.SHOP: return` 으로 돌아가므로
	#  _drop_extras 가 안 돈다 — 첫 착지 직후 판으로 나가면 leg_vig 와
	#  leg_vig_up 이 **그 자리에 언다.** 나가기 단추는 _drop_busy() 앞에서
	#  처리되므로(5131) 낙하 중에도 눌린다. 다음 상점에서 _drop_extras 가
	#  다시 돌기 시작하면 up 이 참인 채라 **레전더리가 한 장도 없는 딜링
	#  위에서 가장자리가 가득 차올랐다가** 빠진다(2026-09-20 고침).
	print("\n-- ⑯ 떠난 뒤 값이 안 얼어붙는다 --")
	seed(seed_v + 81)
	_setup([l0, c0, c0, c0])
	g.leg_fx_seen.clear()
	g._drop_roll()
	_wind(30, 1.0 / 60.0)          # 첫 착지 직후 — 비네트가 도는 중이다
	var mid_vig: float = float(g.leg_vig)
	var mid_up: bool = bool(g.leg_vig_up)
	#  판으로 나간 셈 친다 — _drop_extras 가 안 도는 구간이다.
	var st_back = g.state
	g.state = g.S.LEG
	for k8 in 600:
		g._drop_update(1.0 / 60.0)
	g.state = st_back
	var froze: bool = float(g.leg_vig) > 0.001 or bool(g.leg_vig_up)
	#  다음 상점의 첫 딜링 — 일반 넷이다.
	_setup([c0, c0, c0, c0])
	g.leg_no += 1
	g.shake = 0.0
	g._drop_roll()
	var nx_vig := 0.0
	for k9 in 120:
		_frame += 1
		if g.drop_awake or g.sweep_live:
			g.drop_acc += 1.0 / 60.0
			var ns9 := 0
			while g.drop_acc >= float(g.DROP.sub) and ns9 < int(g.DROP.sub_max):
				g.drop_acc -= float(g.DROP.sub)
				g.drop_t += float(g.DROP.sub)
				g._drop_step(float(g.DROP.sub))
				ns9 += 1
		g._drop_extras(1.0 / 60.0)
		nx_vig = maxf(nx_vig, float(g.leg_vig))
		_snd_drain()
	_ok("떠난 뒤 다음 딜링이 조용하다", nx_vig <= 0.001,
			"떠날 때 비네트 %.3f(up %s) → 얼었나 %s → 다음 딜링 최대 %.3f"
			% [mid_vig, mid_up, froze, nx_vig])

	# ── ⑰ 새 런이 기록을 비운다 ─────────────────────────
	#  leg_no 가 _new_run 에서 1 로 돌아가는데 드러냄 기록을 안 지우면,
	#  런 A 에서 본 장이 런 B 에서 **아무 표시 없이 조용히 안 난다** —
	#  프로필 통틀어 네 번뿐인 사건 하나를 표시 없이 잃는다.
	print("\n-- ⑰ 런 경계 --")
	g.leg_fx_seen.clear()
	g.leg_fx_seen["l02"] = true
	g.leg_vig = 0.7
	g.leg_vig_up = true
	g.leg_cue_t = 0.2
	g.hush_t = 0.2
	g.land_snd_t = 0.02
	g.land_snd_n = 3
	g._new_run()
	_ok("_new_run 이 여덟을 다 누른다",
			g.leg_fx_seen.is_empty() and not bool(g.leg_fx_arm)
			and g.leg_cue_t < 0.0 and float(g.leg_vig) <= 0.0
			and not bool(g.leg_vig_up) and float(g.hush_t) <= 0.0
			and float(g.land_snd_t) <= 0.0 and int(g.land_snd_n) == 0,
			"seen %d · arm %s · cue %.2f · vig %.2f · up %s · hush %.2f"
			% [g.leg_fx_seen.size(), bool(g.leg_fx_arm), float(g.leg_cue_t),
					float(g.leg_vig), bool(g.leg_vig_up), float(g.hush_t)])

	print("\n%s" % ["검사 전부 통과" if fails == 0 else "실패 %d건" % fails])
	quit(fails)
	return true
