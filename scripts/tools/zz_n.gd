extends SceneTree
func T(a: int, first: float, last: float, bow: float, N: int) -> float:
	if a == 1: return first
	if a == N: return last
	var t := float(a-1)/float(N-1)
	var lg := log(first)/log(10.0)
	var le := log(last)/log(10.0)
	var k := float(a-1)*float(N-a)
	return pow(10.0, lg + t*(le-lg) + bow * k / (float((N-1)*(N-1))/4.0))

func _initialize() -> void:
	print("antes.csv 에 줄을 더하면 (엔드리스) 기존 앤티가 어떻게 되나 — first=25 last=4000 bow=0.10")
	print("%-6s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s" % ["N","A1","A2","A3","A4","A5","A6","A7","A8","A9","A10"])
	for N in [8, 9, 10, 12]:
		var s := "N=%-4d" % N
		for a in range(1, 11):
			if a > N: s += "        -"
			else: s += " %8.0f" % T(a, 25.0, 4000.0, 0.10, N)
		print(s)
	print("\n앤티 8 목표: N=8 → 4000 · N=9 → %.0f (%.0f%% 하락) · N=10 → %.0f · N=12 → %.0f"
			% [T(8,25.0,4000.0,0.10,9), 100.0*(1.0-T(8,25.0,4000.0,0.10,9)/4000.0),
			T(8,25.0,4000.0,0.10,10), T(8,25.0,4000.0,0.10,12)])

	print("\n── 통계: 완주 5/24 vs 2/24 (초기하 정확검정) ──")
	var tot := 0.0
	var p2 := 0.0
	var ps := []
	for k in range(0, 8):
		var v := _c(24,k) * _c(24,7-k) / _c(48,7)
		ps.append(v); tot += v
		if k == 2: p2 = v
	var pv := 0.0
	for k in range(0, 8):
		if ps[k] <= p2 + 1e-12: pv += ps[k]
	print("  P(X=2) = %.5f · 양측 p = %.4f  (합계검산 %.6f)" % [p2, pv, tot])
	print("  → p = %.2f. 24런 대 24런으로는 19%%와 8%%를 구별 못 한다." % pv)
	# 필요 표본
	var pb := 0.135
	var n := pow(1.96*sqrt(2.0*pb*(1.0-pb)) + 0.8416*sqrt(0.19*0.81 + 0.08*0.92), 2.0) / pow(0.11, 2.0)
	print("  → 19%% vs 8%% 를 검정력 80%%로 잡으려면 팔당 약 %.0f 런이 필요하다." % ceil(n))

	print("\n── 생존 편향: 앤티별로 몇 런이 들어섰나 (보고된 통과율 역산) ──")
	var alive := 24.0
	var pr := {1:[1.0,1.0,1.0], 2:[0.88,0.71,0.67], 3:[0.90,0.67,0.83],
			4:[1.0,1.0,0.60], 5:[1.0,1.0,1.0], 6:[1.0,1.0,1.0],
			7:[1.0,0.67,1.0], 8:[1.0,1.0,1.0]}
	for a in range(1, 9):
		var enter := alive
		for p in pr[a]: alive *= p
		print("  앤티 %d  들어선 런 %4.1f → 나온 런 %4.1f" % [a, enter, alive])
	print("  → 앤티 5·6 의 「사망 0」은 런 %d개 표본이다. 0/3 의 사망률 95%% 상한 = %.0f%%."
			% [3, 100.0*(1.0 - pow(0.05, 1.0/3.0))])
	quit(0)

func _c(n: int, k: int) -> float:
	var r := 1.0
	for i in range(k): r = r * float(n - i) / float(i + 1)
	return r
