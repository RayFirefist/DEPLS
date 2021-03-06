-- Beatmap selection
-- Part of DEPLS2

local SelectBeatmap = {}
local BeatmapList = {}
local CurrentPage = 0
local BeatmapSelectedIndex = 0
local MouseState = {X = 0, Y = 0, Pressed = {}}

local com_button_14
local com_button_14di
local com_button_14se
local com_win_02
local s_button_03
local s_button_03se
local liveback_1

local BackImage
local BackButton
local BackButtonSe

local MTLmr3m
local FontDesc

function SelectBeatmap.Start(arg)
	local noteloader = love.filesystem.load("note_loader.lua")()
	BeatmapList = noteloader.Enumerate()
	
	com_button_14 = love.graphics.newImage("image/com_button_14.png")
	com_button_14di = love.graphics.newImage("image/com_button_14di.png")
	com_button_14se = love.graphics.newImage("image/com_button_14se.png")
	
	com_win_02 = love.graphics.newImage("image/com_win_02.png")
	s_button_03 = love.graphics.newImage("image/s_button_03.png")
	s_button_03se = love.graphics.newImage("image/s_button_03se.png")
	liveback_1 = love.graphics.newImage("image/liveback_1.png")
	
	BackImage = love.graphics.newImage("image/com_win_02.png")
	BackButton = love.graphics.newImage("image/com_button_01.png")
	BackButtonSe = love.graphics.newImage("image/com_button_01se.png")
	
	MTLmr3m = FontManager.GetFont("MTLmr3m.ttf", 14)
	FontDesc = FontManager.GetFont("MTLmr3m.ttf", 22)
	
	if arg[1] then
		for i = 1, #BeatmapList do
			if BeatmapList[i].name == arg[1] then
				BeatmapSelectedIndex = i
				CurrentPage = math.floor((i - 1) / 40)
				
				break
			end
		end
	end
end

function SelectBeatmap.Update()
end

local draw = love.graphics.draw
local drawtext = love.graphics.print
local setFont = love.graphics.setFont
local setColor = love.graphics.setColor

function SelectBeatmap.Draw()
	-- Grid: 4x10 beatmap list. Starts at 48x100px
	
	draw(liveback_1)
	setFont(FontDesc)
	draw(BackImage, -98, 0)
	setColor(0, 0, 0)
	drawtext("Select Beatmap", 95, 13)
	setColor(255, 255, 255)
	setFont(MTLmr3m)
	
	if
		MouseState.Pressed[1] and
		MouseState.X >= 0 and MouseState.X <= 86 and
		MouseState.Y >= 0 and MouseState.Y <= 58
	then
		draw(BackButtonSe)
	else
		draw(BackButton)
	end
	
	for i = CurrentPage * 40 + 1, (CurrentPage + 1) * 40 do
		local beatmap_info = BeatmapList[i]
		
		if beatmap_info then
			local xpos = 48 + ((i - 1 - CurrentPage * 40) % 4) * 216
			local ypos = 100 + math.floor((i - 1 - CurrentPage * 40) * 0.25) * 40
			
			if BeatmapSelectedIndex == i then
				draw(s_button_03, xpos, ypos, 0, 0.5, 0.5)
				setColor(255, 255, 255, 127)
				draw(s_button_03se, xpos, ypos, 0, 0.5, 0.5)
				setColor(255, 255, 255, 255)
				setFont(FontDesc)
				drawtext("Type: ", 118, 536)
				drawtext(beatmap_info.type, 174, 536)
				setFont(MTLmr3m)
			elseif MouseState.X >= xpos and MouseState.X < xpos + 216 and
			   MouseState.Y >= ypos and MouseState.Y < ypos + 40 then
				draw(s_button_03se, xpos, ypos, 0, 0.5, 0.5)
			else
				draw(s_button_03, xpos, ypos, 0, 0.5, 0.5)
			end
			
			
			drawtext(beatmap_info.name, xpos + 8, ypos + 8)
		end
	end
	
	if BeatmapSelectedIndex > 0 then
		if MouseState.X >= 760 and MouseState.X <= 904 and
		   MouseState.Y >= 530 and MouseState.Y <= 588 and
		   MouseState.Pressed[1]
		then
			draw(com_button_14se, 760, 530)
		else
			draw(com_button_14, 760, 530)
		end
	else
		draw(com_button_14di, 760, 530)
	end
end

function love.mousepressed(x, y, button)
	x, y = CalculateTouchPosition(x, y)
	MouseState.X, MouseState.Y = x, y
	MouseState.Pressed[button] = true
end

function love.mousemoved(x, y)
	x, y = CalculateTouchPosition(x, y)
	MouseState.X, MouseState.Y = x, y
end

function love.mousereleased(x, y, button)
	x, y = CalculateTouchPosition(x, y)
	MouseState.X, MouseState.Y = x, y
	MouseState.Pressed[button] = false
	
	if x >= 0 and x <= 86 and y >= 0 and y <= 58 then
		LoadEntryPoint("main_menu.lua")
		return
	end
	
	do
		-- Check if Ok button is pressed
		if BeatmapSelectedIndex > 0 and
		   x >= 760 and x <= 904 and
		   y >= 530 and y <= 588
		then
			-- Start livesim
			LoadEntryPoint("livesim.lua", {BeatmapList[BeatmapSelectedIndex].name})
			return
		end
	end
	
	do
		-- Get beatmap index from x and y
		local bm_idx
		local bm_idx_y
		local bm_idx_x = math.floor((x - 48) / 216)
		
		if bm_idx_x < 0 or bm_idx_x > 3 then
			BeatmapSelectedIndex = 0
			return
		end
		
		bm_idx_y = math.floor((y - 100) / 40)
		
		if bm_idx_y < 0 or bm_idx_y > 9 then
			BeatmapSelectedIndex = 0
			return
		end
		
		local bm_idx = CurrentPage * 40 + 1 + bm_idx_y * 4 + bm_idx_x
		
		if BeatmapList[bm_idx] then
			BeatmapSelectedIndex = bm_idx
		else
			BeatmapSelectedIndex = 0
		end
	end
end

return SelectBeatmap
