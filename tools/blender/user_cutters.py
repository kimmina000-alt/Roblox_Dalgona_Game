# 사용자가 Blender로 만든 모양 틀(레퍼런스/3D.blend의 "모형틀1~8")을 게임 틀로 쓰기 위한 정보와 외곽선 추출.
# 모형틀은 선(바닥 꼭짓점 경로)을 위로 세운 벽 메시이고, 모양 + 아래로 뻗은 손잡이 + 끝 고리가 한 줄로 이어져 있다.
# bpy 없이 동작 (cutters.py가 Blender 안에서 부르고, 검사용으로 그냥 python에서도 부를 수 있다).

import math

BLEND = "레퍼런스/3D.blend"

# 모형틀 이름 → 도안 id (shapes.py SHAPES의 id). bone은 기획서에 없는 추가 도안.
USER_CUTTERS = {
    "모형틀1": "Circle",
    "모형틀2": "Triangle",
    "모형틀3": "Square",
    "모형틀4": "Star",
    "모형틀5": "Heart",
    "모형틀6": "Umbrella",
    "모형틀7": "Bone",
    "모형틀8": "Flower",
}
EXTRA_SHAPES = [("Bone", "뼈다귀", "Normal")]  # 기획서 18종 밖, 사용자 모형틀에만 있는 도안

MERGE = 2e-3


def bottom_graph(verts, edges):
    """바닥(z가 낮은 쪽) 꼭짓점만 모아 겹친 점을 합친 2D 그래프."""
    zmin = min(v[2] for v in verts)
    nodes, rep = [], {}
    for i, p in enumerate(verts):
        if p[2] > zmin + 0.05:
            continue
        for k, (x, y) in enumerate(nodes):
            if abs(x - p[0]) < MERGE and abs(y - p[1]) < MERGE:
                rep[i] = k
                break
        else:
            rep[i] = len(nodes)
            nodes.append((p[0], p[1]))
    adj = {k: set() for k in range(len(nodes))}
    for a, b in edges:
        if a in rep and b in rep and rep[a] != rep[b]:
            adj[rep[a]].add(rep[b])
            adj[rep[b]].add(rep[a])
    return nodes, adj


def _component(adj, start):
    seen, stack = {start}, [start]
    while stack:
        for j in adj[stack.pop()]:
            if j not in seen:
                seen.add(j)
                stack.append(j)
    return seen


def _find_cycle(adj, comp):
    """comp 안의 순환 하나를 순서대로 (없으면 None)."""
    parent, depth = {}, {}
    for root in comp:
        if root in parent:
            continue
        parent[root], depth[root] = None, 0
        stack = [root]
        while stack:
            u = stack.pop()
            for w in adj[u]:
                if w == parent[u]:
                    continue
                if w in parent:
                    # u..w 경로 = 순환
                    a, b, pa, pb = u, w, [u], [w]
                    while depth[a] > depth[b]:
                        a = parent[a]; pa.append(a)
                    while depth[b] > depth[a]:
                        b = parent[b]; pb.append(b)
                    while a != b:
                        a = parent[a]; pa.append(a)
                        b = parent[b]; pb.append(b)
                    return pa + pb[-2::-1]
                parent[w], depth[w] = u, depth[u] + 1
                stack.append(w)
    return None


def _walk(adj, comp, start):
    path, prev = [start], None
    while True:
        nxt = [j for j in adj[path[-1]] if j != prev and j in comp and j not in path]
        if not nxt:
            return path
        prev = path[-1]
        path.append(nxt[0])


def extract(verts, edges):
    """반환: outline [(x, y)...] (닫힌 외곽선, 반시계), junction (x, y) = 손잡이가 붙는 점.
    좌표는 입력(월드) 그대로."""
    nodes, adj = bottom_graph(verts, edges)
    # 1) 짧게 튀어나온 찌꺼기 선 정리 (길이 0.03 미만 막다른 가지)
    changed = True
    while changed:
        changed = False
        for k in list(adj):
            if len(adj[k]) == 1:
                (j,) = adj[k]
                if math.dist(nodes[k], nodes[j]) < 0.03 and len(adj[j]) > 2:
                    adj[j].discard(k)
                    adj[k].clear()
                    changed = True
    # 2) 손잡이 = 0.2 이상 긴 세로 선분 중 가장 아래까지 내려가는 것 (사각형 옆변과 구분)
    best = None
    for a in adj:
        for b in adj[a]:
            (xa, ya), (xb, yb) = nodes[a], nodes[b]
            if ya - yb > 0.2 and abs(xa - xb) < 0.25 * (ya - yb):
                if best is None or yb < best[2]:
                    best = (a, b, yb)
    top, bot, _ = best
    adj[top].discard(bot)
    adj[bot].discard(top)
    comp = _component(adj, top)
    # 3) 모양 부분: 순환이 있으면 그 순환(우산 갓 등), 없으면 끝점에서 끝점까지 걸은 경로(틈이 있는 고리)
    cyc = _find_cycle(adj, comp)
    if cyc:
        order = cyc
    else:
        ends = [k for k in comp if len(adj[k]) == 1]
        start = max(ends, key=lambda k: nodes[k][1]) if ends else top
        order = _walk(adj, comp, start)
    pts = [nodes[k] for k in order]
    area = sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts)))
    if area < 0:
        pts.reverse()
    return pts, nodes[top]
