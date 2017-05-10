-- Result screen. Original by RayFirefist. Edited by AuahDark
-- Part of Live Simulator: 2

local love = love
local DEPLS, AquaShine = ...
local tween = require("tween")
local ResultScreen = {}

local Yohane = require("Yohane")

--UI Stuff
local Font = AquaShine.LoadFont("MTLmr3m.ttf", 36)
local background = AquaShine.LoadImage("assets/image/live/l_win_23.png")
local comboWin = AquaShine.LoadImage("assets/image/live/l_win_07.png")
local scoreLogo = AquaShine.LoadImage("assets/image/live/l_etc_09.png")
local comboLogo = AquaShine.LoadImage("assets/image/live/l_etc_08.png")
local perfectLogo = AquaShine.LoadImage("assets/image/live/l_etc_11.png")
local greatLogo = AquaShine.LoadImage("assets/image/live/l_etc_12.png")
local goodLogo = AquaShine.LoadImage("assets/image/live/l_etc_13.png")
local badLogo = AquaShine.LoadImage("assets/image/live/l_etc_14.png")
local missLogo = AquaShine.LoadImage("assets/image/live/l_etc_15.png")
local liveClearLogo = AquaShine.LoadImage("assets/image/live/ef_330_000_1.png")

-- 4.0 UI thing (BETA)
if true then
	comboWin = {
		combo = AquaShine.LoadImage("assets/image/live/new/l_win_07.png"),
		score = AquaShine.LoadImage("assets/image/live/new/l_win_08.png")
	}
end

-- Optional render

local dir = "assets/image/units/render/live_clear.png"
local f = io.open(dir,"r")
local render

if not(f == nil) then
	render = {exists = true, render = AquaShine.LoadImage(dir)}
	print("Found at "..dir)
else
	render = {exists = false}
	print("Not found. Check "..dir)
end

-- Animation things
local FlashEffect = Yohane.newFlashFromFilename("assets/flash/ui/live/live_ef_02.flsh", "ef_322") -- Animation


local combo

local Status = {Opacity = 0}
Status.Tween = tween.new(1000, Status, {Opacity = 255})

function ResultScreen.Update(deltaT)
	if not(combo) then
		local ninfo = DEPLS.NoteManager
		
		combo = {
			Perfect = string.format("%04d", ninfo.Perfect),
			Great = string.format("%04d", ninfo.Great),
			Good = string.format("%04d", ninfo.Good),
			Bad = string.format("%04d", ninfo.Bad),
			Miss = string.format("%04d", ninfo.Miss),
			MaxCombo = string.format("%04d", ninfo.HighestCombo)
		}
		
	end
	
	FlashEffect:update(deltaT * 1000)
	
	ResultScreen.CanExit = Status.Tween:update(deltaT)
end

function ResultScreen.Draw()
	if not(combo) then return end
	
	if true then --4.0 UI
	
	local coorComboWin = {
		x = 560,
		y = 260
	}
	
	local coorScoreWin = {
		x = 410 - 350,
		y = 340 + 120
	}
	
	--local resultCombo = {-85,-25}
	
	local score = string.format("%010d", DEPLS.Routines.ScoreUpdate.CurrentScore)
	
	love.graphics.setFont(Font)
	
	love.graphics.setColor(0, 0, 0, Status.Opacity * 0.75)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(255, 255, 255, Status.Opacity)
	if render.exists == true then
		love.graphics.draw(render.render, -150, -90, 0, 0.750, 0.750)
	end
	love.graphics.draw(comboWin.combo, coorComboWin.x, coorComboWin.y)
	love.graphics.draw(comboWin.score, coorScoreWin.x, coorScoreWin.y)
	love.graphics.draw(scoreLogo, coorScoreWin.x + 122, coorScoreWin.y + 35)
	love.graphics.draw(comboLogo, coorComboWin.x + 37, coorComboWin.y + 9)
	love.graphics.draw(perfectLogo, coorComboWin.x + 20, coorComboWin.y + 68)
	love.graphics.draw(greatLogo, coorComboWin.x + 48, coorComboWin.y + 114)
	love.graphics.draw(goodLogo, coorComboWin.x + 60, coorComboWin.y + 160)
	love.graphics.draw(badLogo, coorComboWin.x + 85, coorComboWin.y + 206)
	love.graphics.draw(missLogo, coorComboWin.x + 70, coorComboWin.y + 252)
	love.graphics.draw(liveClearLogo, 480, 25, 0, 0.75, 0.75, 250, 0)

	love.graphics.setColor(0, 0, 0, Status.Opacity)
	love.graphics.print(combo.Perfect, coorComboWin.x + 228, coorComboWin.y + 69)
	love.graphics.print(combo.Great, coorComboWin.x + 228, coorComboWin.y + 115)
	love.graphics.print(combo.Good, coorComboWin.x + 228, coorComboWin.y + 161)
	love.graphics.print(combo.Bad, coorComboWin.x + 228, coorComboWin.y + 207)
	love.graphics.print(combo.Miss, coorComboWin.x + 228, coorComboWin.y + 253)
	love.graphics.print(score, coorScoreWin.x + 270, coorScoreWin.y + 33)
	love.graphics.print(combo.MaxCombo, coorComboWin.x + 228, coorComboWin.y + 6)
	love.graphics.setColor(255, 255, 255)
	
	FlashEffect:draw(coorScoreWin.x - 75 , coorScoreWin.y - 50)
	
	else -- Old pre-4.0 UI
	love.graphics.setColor(0, 0, 0, Status.Opacity * 0.75)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(255, 255, 255, Status.Opacity)
	love.graphics.draw(comboWin, 127, 400, 0, 1.25, 1.25)
	love.graphics.draw(scoreLogo, 150, 555)
	love.graphics.draw(comboLogo, 530, 555)
	love.graphics.draw(perfectLogo, 150, 420, 0, 0.75, 0.75)
	love.graphics.draw(greatLogo, 300, 420, 0, 0.75, 0.75)
	love.graphics.draw(goodLogo, 440, 420, 0, 0.75, 0.75)
	love.graphics.draw(badLogo, 580, 420, 0, 0.75, 0.75)
	love.graphics.draw(missLogo, 700, 420, 0, 0.75, 0.75)
	love.graphics.draw(liveClearLogo, 480, 25, 0, 0.75, 0.75, 250, 0)

	love.graphics.setColor(0, 0, 0, Status.Opacity)
	love.graphics.print(combo.Perfect, 150, 460)
	love.graphics.print(combo.Great, 300, 460)
	love.graphics.print(combo.Good, 440, 460)
	love.graphics.print(combo.Bad, 580, 460)
	love.graphics.print(combo.Miss, 700, 460)
	love.graphics.print(DEPLS.Routines.ScoreUpdate.CurrentScore, 300, 550)
	love.graphics.print(combo.MaxCombo, 700, 550)
	love.graphics.setColor(255, 255, 255)
	end
	
	--[[
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("5000", 150, 460)
	love.graphics.print("3000", 300, 460)
	love.graphics.print("2000", 440, 460)
	love.graphics.print("1000", 580, 460)
	love.graphics.print("0000", 700, 460)
	love.graphics.print("1234567890", 300, 550)
	love.graphics.print("1234", 700, 550)
	love.graphics.setColor(255, 255, 255)
	]]
end

return ResultScreen
