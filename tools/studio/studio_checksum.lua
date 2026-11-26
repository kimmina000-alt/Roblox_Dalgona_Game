-- Studio 쪽 체크섬 (Studio MCP execute_luau, datamodel Edit로 붙여 넣어 실행). 로컬 쪽은 tools/studio/checksum.py.
-- 출력: 스크립트마다 "경로 종류 체크섬" 한 줄 (경로 순) + 마지막 줄 "combined <값> <개수>".
-- 로컬 마지막 줄과 같으면 src/와 Studio가 완전히 같음. 다르면 줄끼리 비교해 다른 스크립트만 multi_edit로 고친다.
local function ck(s)
	s = s:gsub("\r\n", "\n")
	local x = 0
	for i = 1, #s do
		x = (x * 31 + string.byte(s, i)) % 2147483647
	end
	return x
end
local roots = {
	game:GetService("ReplicatedStorage"):FindFirstChild("Shared"),
	game:GetService("ServerScriptService"):FindFirstChild("Server"),
	game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client"),
}
local list = {}
for _, r in ipairs(roots) do
	if r then
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				table.insert(list, { d:GetFullName(), d.ClassName, ck(d.Source) })
			end
		end
		task.wait() -- 긴 작업 중 Studio가 멈추지 않게
	end
end
table.sort(list, function(a, b)
	return a[1] < b[1]
end)
local lines, combined = {}, 0
for _, e in ipairs(list) do
	table.insert(lines, e[1] .. " " .. e[2] .. " " .. e[3])
	combined = (combined * 31 + e[3]) % 2147483647
end
table.insert(lines, "combined " .. combined .. " " .. #list)
return table.concat(lines, "\n")
