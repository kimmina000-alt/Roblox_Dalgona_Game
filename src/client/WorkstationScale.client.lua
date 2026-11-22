-- 가게 안 손 작업대를 내 화면에서만 1/2로 (2026-11-22 사용자 요청, 판매 세션). 내용은 Making/ViewScale
-- 제작 중에는 MakingClient가 ViewScale.setFull(내 작업대, true)로 원래 크기로 되돌림
local Making = script.Parent:WaitForChild("Making")
require(Making:WaitForChild("ViewScale")).start()
