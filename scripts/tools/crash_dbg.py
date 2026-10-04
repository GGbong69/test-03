# -*- coding: utf-8 -*-
u"""Godot 를 디버거 밑에서 여러 번 돌려 터지는 자리를 잡는다 (2026-10-04).

    python scripts/tools/crash_dbg.py -n 40 -- --headless --audio-driver WASAPI --path . --script scripts/tools/exit_probe.gd

끌 때 세그폴트(139)는 Godot 의 크래시 핸들러가 한 줄도 못 남긴다 — 다른 스레드에서,
엔진이 반쯤 내려간 뒤에 터지기 때문이다. 여기서는 Win32 디버그 API 로 직접 붙어
접근 위반이 나는 순간의 스레드 · 모듈+오프셋 · 스택(StackWalk64, .pdata 로 푼다)과
그때 메인 스레드의 스택을 적는다. godot.exe 에는 심볼이 없으니 오프셋은
dumpbin /disasm 으로 그 함수가 참조하는 문자열(ERR_ 매크로의 파일 · 함수 이름)을 보고 짚는다.

  -n N     N 번 돌린다(기본 1). 터진 판만 적고 맨 끝에 「터짐 k / N」.
  GODOT    환경 변수로 실행 파일을 바꾼다.
디버그 힙은 끈다(_NO_DEBUG_HEAP=1) — 켜 두면 종료 정리가 몇 분씩 걸려 멈춘 것처럼 보인다.
"""
import ctypes
import ctypes.wintypes as W
import os
import struct
import subprocess
import sys
import time

GODOT = os.environ.get("GODOT", r"D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
TMO = 400
DEBUG_ONLY_THIS_PROCESS = 0x2
DBG_CONTINUE = 0x00010002
DBG_EXCEPTION_NOT_HANDLED = 0x80010001
FATAL = (0xC0000005, 0xC0000374, 0xC0000409, 0xC000001D, 0xC0000096)

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.WaitForDebugEvent.argtypes = [ctypes.c_void_p, W.DWORD]
k32.ContinueDebugEvent.argtypes = [W.DWORD, W.DWORD, W.DWORD]
k32.ReadProcessMemory.argtypes = [W.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                  ctypes.POINTER(ctypes.c_size_t)]
k32.GetThreadContext.argtypes = [W.HANDLE, ctypes.c_void_p]
k32.SuspendThread.argtypes = [W.HANDLE]
k32.GetFinalPathNameByHandleW.argtypes = [W.HANDLE, W.LPWSTR, W.DWORD, W.DWORD]
k32.CloseHandle.argtypes = [W.HANDLE]
k32.TerminateProcess.argtypes = [W.HANDLE, W.UINT]
dh = ctypes.WinDLL("dbghelp", use_last_error=True)
dh.SymInitializeW.argtypes = [W.HANDLE, W.LPCWSTR, W.BOOL]
dh.SymCleanup.argtypes = [W.HANDLE]
dh.StackWalk64.argtypes = [W.DWORD, W.HANDLE, W.HANDLE, ctypes.c_void_p, ctypes.c_void_p,
                           ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]


class Run:
    def __init__(self, args):
        self.args = args
        self.hproc = None
        self.mods = {}       # base -> (이름, 크기)
        self.threads = {}    # tid -> [핸들, 시작 주소, 살아 있나]
        self.main_tid = None
        self.sym = False
        self.report = []

    def rd(self, addr, n):
        buf = ctypes.create_string_buffer(n)
        got = ctypes.c_size_t(0)
        if not k32.ReadProcessMemory(self.hproc, ctypes.c_void_p(addr), buf, n, ctypes.byref(got)):
            return b""
        return buf.raw[:got.value]

    def img_size(self, base):
        h = self.rd(base, 0x1000)
        if len(h) < 0x40:
            return 0
        nt = struct.unpack_from("<I", h, 0x3C)[0]
        return struct.unpack_from("<I", h, nt + 0x50)[0] if nt + 0x54 <= len(h) else 0

    def where(self, a):
        for base, (nm, sz) in self.mods.items():
            if base <= a < base + sz:
                return "%s+0x%x" % (nm, a - base)
        return hex(a)

    def stack(self, tid, suspend=False):
        h = W.HANDLE(self.threads[tid][0])
        if suspend:
            k32.SuspendThread(h)
        raw = ctypes.create_string_buffer(1232 + 16)
        ctx = (ctypes.addressof(raw) + 15) & ~15          # CONTEXT 는 16 바이트 정렬
        cb = (ctypes.c_char * 1232).from_address(ctx)
        ctypes.memset(ctx, 0, 1232)
        struct.pack_into("<I", cb, 0x30, 0x10000B)          # CONTEXT_FULL
        if not k32.GetThreadContext(h, ctypes.c_void_p(ctx)):
            return ["    (GetThreadContext 실패 %d)" % ctypes.get_last_error()]
        if not self.sym:
            self.sym = bool(dh.SymInitializeW(W.HANDLE(self.hproc), None, True))
        rip, rsp = struct.unpack_from("<Q", cb, 0xF8)[0], struct.unpack_from("<Q", cb, 0x98)[0]
        fr = ctypes.create_string_buffer(1024)              # STACKFRAME64
        for off, v in ((0, rip), (32, rsp), (48, rsp)):     # AddrPC · AddrFrame · AddrStack, 평평한 주소
            struct.pack_into("<QHxxI", fr, off, v, 0, 3)
        fta = ctypes.cast(dh.SymFunctionTableAccess64, ctypes.c_void_p)
        gmb = ctypes.cast(dh.SymGetModuleBase64, ctypes.c_void_p)
        out = []
        for i in range(48):
            if not dh.StackWalk64(0x8664, W.HANDLE(self.hproc), h, fr, ctypes.c_void_p(ctx), None, fta, gmb, None):
                break
            pc = struct.unpack_from("<Q", fr, 0)[0]
            if pc == 0:
                break
            out.append("    #%d %s" % (i, self.where(pc)))
        return out

    def on_fatal(self, tid, code, addr, info):
        r = self.report
        r.append("예외 0x%08x — 스레드 %d%s · %s" % (code, tid, " (메인)" if tid == self.main_tid else "",
                                              self.where(addr)))
        if code == 0xC0000005:
            r.append("  %s 0x%x" % ({0: "읽기", 1: "쓰기", 8: "실행"}.get(info[0], info[0]), info[1]))
        if tid in self.threads:
            r.append("  스레드 시작 %s" % self.where(self.threads[tid][1]))
            r.extend(self.stack(tid))
        if self.main_tid != tid and self.threads.get(self.main_tid, [0, 0, False])[2]:
            r.append("  그때 메인 스레드:")
            r.extend(self.stack(self.main_tid, True))

    def go(self, log):
        env = dict(os.environ, _NO_DEBUG_HEAP="1")
        p = subprocess.Popen([GODOT] + self.args, stdout=log, stderr=subprocess.STDOUT, env=env,
                             creationflags=DEBUG_ONLY_THIS_PROCESS)
        ev = ctypes.create_string_buffer(256)
        t0 = time.time()
        first = True
        code = None
        while True:
            if not k32.WaitForDebugEvent(ev, 1000):
                if self.hproc and time.time() - t0 > TMO:
                    self.report.append("%d 초가 넘어 끊었다" % TMO)
                    k32.TerminateProcess(self.hproc, 124)
                continue
            c, pid, tid = struct.unpack_from("<III", ev.raw, 0)
            u = 16
            cont = DBG_CONTINUE
            if c == 3:      # CREATE_PROCESS
                hfile, hp, ht, base = struct.unpack_from("<QQQQ", ev.raw, u)
                self.hproc, self.main_tid = hp, tid
                k32.CloseHandle(hfile)
                self.mods[base] = ("godot.exe", self.img_size(base))
                self.threads[tid] = [ht, struct.unpack_from("<Q", ev.raw, u + 48)[0], True]
            elif c == 6:    # LOAD_DLL
                hfile, base = struct.unpack_from("<QQ", ev.raw, u)
                b = ctypes.create_unicode_buffer(1024)
                n = k32.GetFinalPathNameByHandleW(hfile, b, 1024, 0) if hfile else 0
                if hfile:
                    k32.CloseHandle(hfile)
                self.mods[base] = (os.path.basename(b.value) if n else "?", self.img_size(base))
            elif c == 2:    # CREATE_THREAD
                ht, _tls, start = struct.unpack_from("<QQQ", ev.raw, u)
                self.threads[tid] = [ht, start, True]
            elif c == 4:    # EXIT_THREAD
                if tid in self.threads:
                    self.threads[tid][2] = False
            elif c == 1:    # EXCEPTION
                ecode, _fl, _rec, eaddr = struct.unpack_from("<IIQQ", ev.raw, u)
                info = struct.unpack_from("<15Q", ev.raw, u + 32)
                if ecode in (0x80000003, 0x4000001F):           # 로더의 첫 중단점
                    cont = DBG_CONTINUE
                else:
                    cont = DBG_EXCEPTION_NOT_HANDLED
                    if ecode in FATAL and first:
                        first = False
                        self.on_fatal(tid, ecode, eaddr, info)
            elif c == 5:    # EXIT_PROCESS
                code = struct.unpack_from("<I", ev.raw, u)[0]
                k32.ContinueDebugEvent(pid, tid, DBG_CONTINUE)
                break
            k32.ContinueDebugEvent(pid, tid, cont)
        p.wait()
        if self.sym:
            dh.SymCleanup(W.HANDLE(self.hproc))
        return code, time.time() - t0


def main():
    a = sys.argv[1:]
    n = 1
    if a[:1] == ["-n"]:
        n = int(a[1])
        a = a[2:]
    if a[:1] == ["--"]:
        a = a[1:]
    log_path = os.path.join(os.environ.get("TEMP", "."), "crash_dbg_last.log")
    hit = 0
    for i in range(n):
        r = Run(a)
        with open(log_path, "wb") as log:
            code, dt = r.go(log)
        if r.report:
            hit += 1
            print("── %d 번째 판 · 끝 코드 0x%x · %.1f 초" % (i + 1, code or 0, dt))
            print("\n".join(r.report))
            sys.stdout.flush()
    print("터짐 %d / %d" % (hit, n))


if __name__ == "__main__":
    main()
