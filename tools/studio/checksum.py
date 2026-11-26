# Studio 동기화용 체크섬 (로컬 쪽). Studio 쪽은 같은 폴더의 studio_checksum.lua를 execute_luau로 돌림.
# 식: x = (x*31 + byte) % 2147483647, CRLF → LF로 바꿔서 셈 (CLAUDE.md "Studio 동기화").
#
# 실행: python tools/studio/checksum.py [저장소 루트] [--json 저장할 파일]
#   - 스크립트마다 "Studio 경로  종류  체크섬" 한 줄씩 출력 (경로 순 정렬)
#   - 마지막 줄 "combined <값> <개수>" = 전체를 한 숫자로 (studio_checksum.lua 마지막 줄과 같아야 함)
# 경로 규칙은 default.project.json과 같음: src/shared → ReplicatedStorage.Shared, src/server → ServerScriptService.Server,
#   src/client → StarterPlayer.StarterPlayerScripts.Client. 파일 이름 .server.lua = Script, .client.lua = LocalScript, 나머지 .lua = ModuleScript.
import json
import os
import sys

ROOTS = {
    "src/shared": "ReplicatedStorage.Shared",
    "src/server": "ServerScriptService.Server",
    "src/client": "StarterPlayer.StarterPlayerScripts.Client",
}


def ck(data: bytes) -> int:
    x = 0
    for c in data.replace(b"\r\n", b"\n"):
        x = (x * 31 + c) % 2147483647
    return x


def scan(root: str) -> dict:
    out = {}
    for rel, base in ROOTS.items():
        full = os.path.join(root, rel)
        for dp, _, fn in os.walk(full):
            for f in fn:
                if not f.endswith(".lua"):
                    continue
                name, kind = f[:-4], "ModuleScript"
                if name.endswith(".server"):
                    name, kind = name[:-7], "Script"
                elif name.endswith(".client"):
                    name, kind = name[:-7], "LocalScript"
                sub = os.path.relpath(dp, full).replace(os.sep, "/")
                path = base + ("" if sub == "." else "." + sub.replace("/", ".")) + "." + name
                p = os.path.join(dp, f)
                with open(p, "rb") as fh:
                    out[path] = {"kind": kind, "ck": ck(fh.read()), "file": os.path.relpath(p, root).replace(os.sep, "/")}
    return out


def main():
    args = [a for a in sys.argv[1:]]
    out_json = None
    if "--json" in args:
        i = args.index("--json")
        out_json = args[i + 1]
        del args[i : i + 2]
    root = args[0] if args else "."
    table = scan(root)
    combined = 0
    for path in sorted(table):
        e = table[path]
        print(f"{path} {e['kind']} {e['ck']}")
        combined = (combined * 31 + e["ck"]) % 2147483647
    print(f"combined {combined} {len(table)}")
    if out_json:
        with open(out_json, "w", encoding="utf-8") as fh:
            json.dump(table, fh, ensure_ascii=False, indent=0)


if __name__ == "__main__":
    main()
