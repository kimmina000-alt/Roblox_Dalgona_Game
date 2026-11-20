-- 누름판 손으로 들고 다니기 (사용자 요청 2026-11-18):
--   자동으로 날아오지 않음. 누름판을 눌러 잡고 끌어서 가져옴 (손가락 = 누름판 손잡이, 위에서 봄).
--   반죽(목표) 위에서 손가락을 꾹 멈추고 있어야 누름 (pressing). 누르다가 옆으로 끌면 들려서 따라옴.
--   손을 떼면 그 자리에 떠 있음 (다시 잡아서 계속).
-- Press(펴기)와 Stamp(모양 찍기)가 같이 쓴다.

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Grab = {}
Grab.__index = Grab

local STILL_SPEED = 150 -- 픽셀/초: 이보다 느리면 멈춘 것 (손가락 떨림에도 눌리게, 2026-11-19 "잘 안 눌림")
local STILL_TIME = 0.1 -- 이만큼 멈춰 있으면 누르기 시작
local DRAG_OFF = 30 -- 누르는 중 처음 자리에서 이만큼(픽셀) 끌면 들림
local PICK_PX = 90 -- 누름판 화면 위치에서 이만큼 안을 눌러야 잡힘

-- S: Station, P: Pointer, start: 지금 누름판 바닥 가운데(Vector3)
-- opts.anywhere: 화면 어디를 눌러도 누름판을 잡음 (모양 찍기처럼 누름판 말고 쓸 도구가 없을 때)
function Grab.new(S, P, start, opts)
	local presser = S.Presser
	local self = setmetatable({}, Grab)
	self.S, self.P = S, P
	self.rot = S.rest.Presser - S.rest.Presser.Position
	self.discHalf = presser.Disc.Size.X / 2
	self.pos = Vector3.new(start.X, 0, start.Z) -- 누름판 가운데 (XZ만)
	self.bottom = start.Y
	self.grabbed = false
	self.pressing = false
	self.seen = P.presses
	self.speed = 0
	self.still = 0
	self.anchor = nil
	self.lastPos = nil
	self.missHint = false
	self.anywhere = opts and opts.anywhere or false
	return self
end

-- 누름판 바닥 가운데를 (pos.X, bottom, pos.Z)에 그림
function Grab:draw()
	self.S.Presser:PivotTo(CFrame.new(self.pos.X, self.bottom + self.discHalf, self.pos.Z) * self.rot)
end

function Grab:worldBottom()
	return Vector3.new(self.pos.X, self.bottom, self.pos.Z)
end

-- 손가락 처리. carryY = 들고 다닐 때 누름판 바닥 높이. canPress(pos) = 이 자리에서 누를 수 있나
-- 반환: 이번 프레임에 누르기가 끝났으면 true (손 뗌 또는 옆으로 끌어서)
function Grab:update(dt, carryY, canPress)
	local P = self.P
	local ended = false
	if P.down and not self.grabbed and P.presses ~= self.seen then
		self.seen = P.presses
		local cam = workspace.CurrentCamera
		-- Pointer.pos 는 WorldToScreenPoint 좌표 (ScreenPointToRay 와 같은 기준)
		local sp = cam:WorldToScreenPoint(self:worldBottom() + Vector3.new(0, self.discHalf * 2, 0))
		local d = (Vector2.new(sp.X, sp.Y) - P.pos).Magnitude
		if d < PICK_PX or self.missHint or self.anywhere then
			-- 한 번 빗나가면 다음엔 어디를 눌러도 잡힘 (작은 화면 배려)
			self.grabbed = true
			Sfx.play("pop", 0.5, 1.0)
			self.lastPos = nil
			self.still = 0
			self.speed = 0
		else
			self.missHint = true
			return false, "miss"
		end
	end
	if not self.grabbed then
		return false
	end
	-- 손가락 빠르기 (화면 픽셀/초, 부드럽게)
	if self.lastPos and dt > 0 then
		local v = (P.pos - self.lastPos).Magnitude / dt
		self.speed += (v - self.speed) * (1 - math.exp(-dt / 0.07))
	end
	self.lastPos = P.pos
	if not P.down then
		self.grabbed = false
		if self.pressing then
			self.pressing = false
			ended = true
		end
		return ended
	end
	if self.pressing then
		if (P.pos - self.anchor).Magnitude > DRAG_OFF then
			-- 누르다가 옆으로 끌면 들어 올려 따라옴
			self.pressing = false
			self.still = 0
			ended = true
		end
	else
		local f = P.toPlane(carryY + self.discHalf * 2)
		local target = Vector3.new(f.X, 0, f.Z)
		self.pos = self.pos:Lerp(target, 1 - math.exp(-25 * dt))
		if self.speed < STILL_SPEED then
			self.still += dt
		else
			self.still = 0
		end
		if self.still >= STILL_TIME and canPress(self.pos) then
			self.pressing = true
			self.anchor = P.pos
		end
	end
	return ended
end

return Grab
