extends SceneTree
#  술집에서 눈을 뜬다 — 그 장면의 소리 일곱(인광 점 속으로 bar_phos · 2026-10-28 · 2026-10-25 · scripts/tools/sfx_bar.py 가 굽는다). 화면 없이 돈다. 못 박는 것:
#    ① 일곱이 game.gd SFX 표에 있고 게임 길(_sfx_file)로 이름만 대서 읽힌다 — 16비트 PCM · 44.1k · 모노 · 길이
#    ② 순환 넷은 사본에 LOOP_FORWARD 를 걸어(창밖 비와 같은 길) 끝 너머로 돌고, 원본은 안 바뀐다 · 한 번 소리는 끝나면 멎는다
#    ③ 방 소리 로패스 — 버스를 코드로 세우고(BarAmb · SFX 밑 · AudioEffectLowPassFilter — default_bus_layout.tres 는 안
#       건드린다) 눈 뜨는 정도로 컷오프를 밀고, 걷으면 그 이름이 사라지고 버스 수가 처음으로 돌아온다
#   godot --headless --path . --script scripts/tools/qa_barsfx.gd
const LEN := {"bar_room": 8.0, "bar_clink": 1.3, "bar_polish": 3.0, "bar_glass_down": 0.8,
		"bar_tv_static": 4.0, "bar_tv_hum": 4.0, "bar_phos": 1.13}
const LOOP := ["bar_room", "bar_polish", "bar_tv_static", "bar_tv_hum"]
const AMB := ["bar_room", "bar_clink", "bar_polish", "bar_glass_down"]   # 방 소리 — 로패스 밑 · TV 둘은 SFX 그대로
var ok := 0
var bad := 0
var g: Node = null
var pl := {}
var lpf: AudioEffectLowPassFilter = null
var bus0 := 0
var t := 0.0
var step := 0


func _chk(c: bool, s: String) -> void:
	if c:
		ok += 1
		print("  ok  " + s)
	else:
		bad += 1
		print("  XX  " + s)


func _initialize() -> void:
	var G = load("res://scripts/game.gd")
	g = G.new()            # 트리에 안 넣는다 — _ready 없이 _sfx_file(이름 → 파일) 길만 빌린다
	print("① 이름으로 읽는다")
	for nm in LEN:
		_chk(G.SFX.has(nm), "%s — SFX 표에 줄이 있다" % nm)
		var st := g._sfx_file(nm) as AudioStreamWAV
		_chk(st != null, "%s — _sfx_file 이 AudioStreamWAV 를 낸다" % nm)
		if st == null:
			continue
		_chk(st.format == AudioStreamWAV.FORMAT_16_BITS and st.mix_rate == 44100 and not st.stereo,
				"%s — 16비트 · 44.1k · 모노" % nm)
		_chk(absf(st.get_length() - float(LEN[nm])) < 0.01, "%s — %.2f초 (%.2f)" % [nm, st.get_length(), LEN[nm]])
		_chk(st.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s — 원본은 한 번만 난다(.import loop 0)" % nm)
	#  ③ 버스 — 게임에서는 _bus_setup 이 SFX 를 이미 세웠다. 여기는 화면 없는 도구라 없으면 세운다.
	if AudioServer.get_bus_index("SFX") < 0:
		var si := AudioServer.bus_count
		AudioServer.add_bus(si)
		AudioServer.set_bus_name(si, "SFX")
	bus0 = AudioServer.bus_count
	var bi := AudioServer.bus_count
	AudioServer.add_bus(bi)
	AudioServer.set_bus_name(bi, "BarAmb")
	AudioServer.set_bus_send(bi, "SFX")
	lpf = AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 500.0
	AudioServer.add_bus_effect(bi, lpf)
	print("② 튼다 (방 소리는 BarAmb · TV 는 SFX)")
	for nm in LEN:
		var st := g._sfx_file(nm) as AudioStreamWAV
		if st == null:
			continue
		if LOOP.has(nm):
			st = st.duplicate() as AudioStreamWAV
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(st.get_length() * float(st.mix_rate))
		var p := AudioStreamPlayer.new()
		p.bus = "BarAmb" if AMB.has(nm) else "SFX"
		p.stream = st
		root.add_child(p)
		pl[nm] = p
	_chk((g._sfx_file("bar_room") as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"사본에 건 순환이 캐시 원본에 안 샌다")


func _process(d: float) -> bool:
	if step == 0 and t == 0.0:
		for nm in pl:
			(pl[nm] as AudioStreamPlayer).play()     # 트리에 든 뒤(첫 프레임)라야 난다
	t += d
	#  눈 뜨는 정도 k(0 감김 → 1 뜸) 로 컷오프를 로그로 민다 — 500Hz → 16kHz
	lpf.cutoff_hz = 500.0 * pow(16000.0 / 500.0, clampf(t / 2.0, 0.0, 1.0))
	if step == 0 and t > 0.5:
		step = 1
		for nm in pl:
			var p: AudioStreamPlayer = pl[nm]
			_chk(p.playing and p.get_playback_position() > 0.0,
					"%s — 돈다 (%.2f초에 %.2f)" % [nm, t, p.get_playback_position()])
	if step == 1 and t > 3.6:
		step = 2
		var bi := AudioServer.get_bus_index("BarAmb")
		_chk(AudioServer.get_bus_effect(bi, 0) == lpf and lpf.cutoff_hz > 15000.0,
				"BarAmb 로패스가 다 열렸다 (%.0fHz)" % lpf.cutoff_hz)
		for nm in pl:
			var p: AudioStreamPlayer = pl[nm]
			if LOOP.has(nm):
				_chk(p.playing, "%s — 순환이 돈다 (%.2f)" % [nm, p.get_playback_position()])
			else:
				_chk(not p.playing, "%s — 한 번 나고 멎었다" % nm)
		var pp := (pl["bar_polish"] as AudioStreamPlayer).get_playback_position()
		_chk(pp > 0.0 and pp < 1.0, "bar_polish — 3초 끝을 넘어 머리로 돌았다 (%.2f)" % pp)
		#  걷기 — 자리를 먼저 걷고 버스를 이름으로 찾아 지운다(지우면 뒤 버스 번호가 당겨진다)
		for nm in pl:
			(pl[nm] as Node).free()
		pl.clear()
		AudioServer.remove_bus(AudioServer.get_bus_index("BarAmb"))
		_chk(AudioServer.get_bus_index("BarAmb") < 0 and AudioServer.bus_count == bus0,
				"BarAmb 를 걷으니 버스 수가 처음(%d)으로" % bus0)
		g.free()
		print("\n맞음 %d · 틀림 %d" % [ok, bad])
		quit(1 if bad > 0 else 0)
	return false
