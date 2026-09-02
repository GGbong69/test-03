extends SceneTree

# 곡선 식을 data.gd 와 똑같이 다시 쓴다 — tuning 을 안 건드리고 대안을 재려고.
func T(a: int, first: float, last: float, bow: float, N := 8) -> float:
	if a == 1: return first
	if a == N: return last
	var t := float(a-1)/float(N-1)
	var lg := log(first)/log(10.0)
	var le := log(last)/log(10.0)
	var k := float(a-1)*float(N-a)
	var b := bow * k / (float((N-1)*(N-1))/4.0)
	return pow(10.0, lg + t*(le-lg) + b)

func row(name: String, first: float, last: float, bow: float) -> void:
	var s := "%-28s" % name
	for a in range(1, 9):
		s += " %8.0f" % T(a, first, last, bow)
	print(s)

func _initialize() -> void:
	print("배부름 계수 k(a) = (a-1)(8-a)/12.25  — bow 가 각 앤티에 실리는 무게")
	var s1 := "  k(a)     "
	var s2 := "  t(a)     "
	for a in range(1,9):
		s1 += " %8.4f" % (float(a-1)*float(8-a)/12.25)
		s2 += " %8.4f" % (float(a-1)/7.0)
	print(s1); print(s2)
	print("\n  → k 는 4.5 를 축으로 좌우대칭이다 (k2=k7, k3=k6, k4=k5).")
	print("  → 그러나 t 는 단조증가다. 두 벡터가 **일차독립**이므로")
	print("     (Δlog last, Δbow) 두 손잡이로 임의의 두 앤티를 반대로 움직일 수 있다.\n")

	print("%-28s %8s %8s %8s %8s %8s %8s %8s %8s" % ["", "A1","A2","A3","A4","A5","A6","A7","A8"])
	row("현재 25/4000/+0.10", 25.0, 4000.0, 0.10)
	row("주장(2)가 불가능하다는 것", 25.0, 4000.0, 0.10)
	print("")
	# 해석해: 0.142857x + 0.489796y < 0  이고  0.714286x + 0.816327y > 0
	# y = -0.10 (bow 0.10 → 0.00) 이면  x ∈ (0.1143, 0.3429)
	for x in [0.15, 0.20, 0.25, 0.30]:
		var nl := 4000.0 * pow(10.0, x)
		row("last=%.0f  bow=0.00" % nl, 25.0, nl, 0.00)
	print("")
	for pair in [[-0.10, 0.30], [-0.20, 0.45], [-0.30, 0.60]]:
		var y: float = pair[0]
		var x: float = pair[1]
		var nl := 4000.0 * pow(10.0, x)
		row("last=%.0f  bow=%+.2f" % [nl, 0.10+y], 25.0, nl, 0.10+y)

	print("\n── 현재 대비 변화율 ──────────────────────────────")
	for cand in [[6340.0, 0.00], [7118.0, 0.00], [8000.0, -0.10], [11270.0, -0.20], [15887.0, -0.30]]:
		var nl: float = cand[0]
		var nb: float = cand[1]
		var s := "last=%-7.0f bow=%+.2f  " % [nl, nb]
		for a in range(1,9):
			s += " A%d %+6.1f%%" % [a, 100.0*(T(a,25.0,nl,nb)/T(a,25.0,4000.0,0.10) - 1.0)]
		print(s)
	quit(0)
