extends SceneTree
# 소리표의 이름마다 파일이 있는가 · 그 파일이 손에 맞게 붙는가.
#     godot --headless --script scripts/tools/probe_sfx.gd
#
# 파일이 들어오면 표의 수치는 안 쓰인다. 그래서 여기서 재는 것은 표와의
# 어긋남이 아니라 **손에 닿는 느낌 둘**이다.
#
#   닿는 때(atk) — 누른 뒤 소리가 서기까지. 둘이 섞여 있다.
#                  앞에 붙은 무음은 임포트의 edit/trim 이 지운다. 그런데
#                  **부푸는 소리**(스와이프 같은 것)는 트림이 못 줄인다 —
#                  첫 샘플부터 소리가 나긴 나는데 작을 뿐이라 잘릴 게 없다.
#                  그래서 트림을 켜고도 여기 걸리는 이름이 남는다. 그건
#                  파일을 고칠 게 아니라 **자리를 옮길 신호**다.
#   여운(len)     — 소리가 끝날 때까지. 늦게 오는 것과는 다른 문제다.
#                  자리가 넷뿐이라(sfx_pool) 여운 안에 다섯 번 누르면
#                  앞엣것이 끊긴다. 연타하는 자리에서만 아프다.
#
# 정산 걸음은 pitch 를 미는 자리라 따로 본다 — 거긴 길이가 아니라 대역이
# 문제다.

const POOL := 4           # game.gd 의 sfx_pool 크기
const LATE_MS := 30.0     # 이보다 늦게 서면 누른 것과 따로 논다


# 파일에서 닿는 때와 여운을 잰다. 16비트 PCM 만 본다 — 임포트를
# compress/mode=0 으로 두는 한 전부 이 형식이다.
func _measure(st: AudioStreamWAV) -> Dictionary:
	var out := {"atk": -1.0, "len": st.get_length()}
	if st.format != AudioStreamWAV.FORMAT_16_BITS:
		return out
	var d := st.data
	var ch := 2 if st.stereo else 1
	var n := d.size() / (2 * ch)
	if n <= 0:
		return out
	# 봉우리를 먼저 찾고, 그 절반에 처음 닿는 데까지를 닿는 때로 본다.
	var peak := 0
	for i in n:
		var v: int = absi(d.decode_s16(i * 2 * ch))
		if v > peak:
			peak = v
	if peak <= 0:
		return out
	var half := peak / 2
	for i in n:
		if absi(d.decode_s16(i * 2 * ch)) >= half:
			out.atk = float(i) / float(st.mix_rate)
			break
	return out


func _init() -> void:
	var g = load("res://scripts/game.gd")
	var names: Array = g.SFX.keys()
	names.sort()

	var n_file := 0
	var warn := []

	print("이름 %d 개 · 자리 %d 개" % [names.size(), POOL])
	print("")
	print("%-16s %8s %8s  %s" % ["이름", "닿는때", "여운", "말"])
	print("-".repeat(60))

	for nm in names:
		var path := "res://sfx/%s.wav" % nm
		if not ResourceLoader.exists(path):
			continue
		var st = load(path)
		if st == null:
			warn.append("%s — 파일은 있는데 못 읽었다" % nm)
			continue
		n_file += 1
		var m := _measure(st)
		var atk := float(m.atk)
		var dur := float(m.len)
		var atk_ms := atk * 1000.0
		var say := ""
		if atk < 0.0:
			say = "못 쟀다(16비트 PCM 이 아니다)"
		elif atk_ms > LATE_MS:
			say = "누르고 %.0fms 뒤에 선다 — 부푸는 소리다. 즉시 서야 하는 자리엔 안 맞는다" % atk_ms
			warn.append("%s — %s" % [nm, say])
		elif dur >= 0.30:
			say = "여운이 기니 %.2f초 안에 %d번 누르면 앞엣것이 끊긴다" % [dur, POOL + 1]
		print("%-16s %7.0fms %7.0fms  %s"
				% [nm, atk_ms, dur * 1000.0, say])

	print("")
	print("파일 %d · 합성음 %d" % [n_file, names.size() - n_file])

	# ── 정산 사다리 ───────────────────────────────────
	# 파일이 있으면 f/392 배만큼 pitch 가 밀린다(상한 4배 = 24반음).
	# 소리의 알맹이가 높은 대역에 있으면 사다리 중턱에서 귀 밖으로 나간다 —
	# 길이로는 안 보이는 고장이라 이름으로만 짚어 둔다.
	print("")
	print("- 정산 사다리 -")
	for nm in ["settle_step", "settle_pierce", "settle_item"]:
		var has := ResourceLoader.exists("res://sfx/%s.wav" % nm)
		print("%-16s %s" % [nm,
				"파일 — pitch 를 24반음까지 민다. 알맹이가 5kHz 위면 중턱에서 사라진다"
				if has else "합성음 — 표대로 반음씩 오른다"])

	if not warn.is_empty():
		print("")
		print("- 볼 것 -")
		for w in warn:
			print("  " + w)
	quit()
