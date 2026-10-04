extends SceneTree
#  끌 때 세그폴트 (2026-10-04)
#  헤드리스 프로브가 결과를 다 찍은 뒤 몇 판에 한 번 139 로 죽었다. 오디오 스레드가 끄는 길에
#  풀린 AudioStreamGenerator 를 읽은 것이다 — 재생이 발생기를 날 포인터로 쥐는데, 트리가
#  지워지며 발생기가 풀린 뒤에도 서버가 내려갈 때까지 스레드는 멈춘 재생을 한 번 더 섞는다.
#  game.gd 가 발생기를 AudioServer 메타(synth_gen)에 쥐여 서버와 같이 풀리게 한다.
#
#  ① 게임을 띄우고 합성음 플레이어의 발생기를 서버가 쥐고 있는지 잰다.
#  ② 몇 프레임 뒤 끈다 — 이 끄기가 곧 재현이다. 한 판으로는 못 잡으니 여러 번,
#     실제 드라이버(WASAPI)로 디버거 밑에서 돌린다(고치기 전 120 판에 15 번):
#       python scripts/tools/crash_dbg.py -n 40 -- --headless --audio-driver WASAPI --path . --script scripts/tools/exit_probe.gd
#
#  godot --headless --path . --script scripts/tools/exit_probe.gd

const Save = preload("res://scripts/save.gd")
const FRAMES := 30

var g = null
var n := 0
var fail := 0


func _initialize() -> void:
	Save.gpath = "user://_exit_probe_g.cfg"
	Save.path = "user://_exit_probe.cfg"
	Save.wipe()
	#  스피커로 안 나가게 — 게임은 Master 를 안 만진다(_apply_vol). 섞기는 그대로 돈다.
	AudioServer.set_bus_mute(0, true)
	AudioServer.set_bus_volume_db(0, -80.0)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(nm: String, c: bool, d := "") -> void:
	if not c:
		fail += 1
	print("  %s %-36s %s" % ["통과" if c else "실패", nm, d])


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		#  _ready 는 첫 프레임에 돈다 — 플레이어는 여기서부터 있다.
		var gen: AudioStreamGenerator = null
		for c in g.find_children("*", "AudioStreamPlayer", true, false):
			if c.stream is AudioStreamGenerator:
				gen = c.stream
		_ok("합성음 발생기가 있다", gen != null)
		_ok("발생기를 오디오 서버가 쥔다", gen != null and AudioServer.get_meta("synth_gen", null) == gen)
	if n < FRAMES:
		return false
	print("\n통과 %d · 실패 %d" % [2 - fail, fail])
	quit(fail)
	return true
