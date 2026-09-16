extends SceneTree
# 음악 파일 넷이 명세의 에셋 계약을 맞추는가.
#     godot --headless --script scripts/tools/probe_music_assets.gd
#     godot --headless --script scripts/tools/probe_music_assets.gd -- assets/music
#
# 실제 편곡을 새로 받았을 때 **켜도 되는지 먼저 재는 자리**다. 길이가
# 0.001초를 넘어 어긋나면 MusicManager 가 시작을 통째로 거절하므로, 그걸
# 게임에서 만나기 전에 여기서 만난다.
#
# 못 재는 것이 하나 있다 — 넷이 정말 같은 곡의 편곡인지는 파형을 비교해야
# 알 수 있고 그건 여기 밖이다. 여기는 길이·형식·루프까지만 본다.

const TOL := 0.001

func _init() -> void:
	var dir := "audio/music/tracks"
	var names := ["main", "shop", "aim", "final"]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
		if dir.find("assets/music") >= 0:
			names = ["lobby", "select", "game", "boss"]

	print("고닷 %s · AudioStreamSynchronized %s"
			% [Engine.get_version_info().string,
			ClassDB.class_exists("AudioStreamSynchronized")])
	print("보는 곳: res://%s" % dir)
	print("")
	print("%-8s %10s %10s %8s %6s %s" % ["이름", "길이", "기준과 차", "Hz", "채널", "루프"])
	print("-".repeat(62))

	var base := -1.0
	var bad := []
	for n in names:
		var hit := ""
		for ext in ["wav", "ogg", "mp3"]:
			var p := "res://%s/%s.%s" % [dir, n, ext]
			if ResourceLoader.exists(p):
				hit = p
				break
		if hit == "":
			bad.append("%s — 파일이 없다" % n)
			print("%-8s %10s" % [n, "없다"])
			continue
		var st: AudioStream = load(hit)
		if st == null:
			bad.append("%s — 못 읽었다" % n)
			continue
		var l := st.get_length()
		if base < 0.0:
			base = l
		var d := l - base
		var hz := 0
		var ch := 1
		var loop := "?"
		if st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			hz = w.mix_rate
			ch = 2 if w.stereo else 1
			loop = "꺼짐" if w.loop_mode == AudioStreamWAV.LOOP_DISABLED else "켜짐"
		elif st is AudioStreamOggVorbis:
			loop = "켜짐" if (st as AudioStreamOggVorbis).loop else "꺼짐"
		elif st is AudioStreamMP3:
			var m := st as AudioStreamMP3
			hz = m.get_sample_rate() if m.has_method("get_sample_rate") else 0
			loop = "켜짐" if m.loop else "꺼짐"
		print("%-8s %9.4fs %+9.4fs %8d %6d %s" % [n, l, d, hz, ch, loop])
		if absf(d) > TOL:
			bad.append("%s — 길이가 %.4f초 어긋난다(허용 %.3f)" % [n, absf(d), TOL])
		if loop == "꺼짐":
			bad.append("%s — 루프가 꺼져 있다" % n)
		if st is AudioStreamMP3:
			bad.append("%s — mp3 는 명세의 검증 대상 밖이다(ogg 나 wav 로)" % n)

	print("")
	if bad.is_empty():
		print("계약을 맞춘다. MUS_ADAPTIVE 를 켜도 된다.")
		print("(다만 넷이 **같은 곡의 편곡**인지는 여기서 못 잰다 — 그건 귀와 파형의 몫이다)")
	else:
		print("계약을 못 맞춘다 — %d건" % bad.size())
		for b in bad:
			print("  · " + b)
	quit(0 if bad.is_empty() else 1)
