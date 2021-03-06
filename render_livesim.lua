-- DEPLS2 Render mode. Render frame by frame, and render audio to WAV
-- It's your turn to encode the image frames to videos and mix the audio
-- Only supported in Desktop environment, unless you have a beast phone.

assert(jit, "Render mode is unavailable in Lua 5.1")

local love = love
local lsys = require("love.system")
local ffi = require("ffi")
local bit = require("bit")
local reg = debug.getregistry()
local RenderMode = {
	DeltaTime = 50 / 3,
	ElapsedTime = 0,
	Frame = 0
}
local AudioMixer = {
	NewSource = love.audio.newSource,
	SoundDataMetatable = reg.SoundData,
	SourceMetatable = reg.Source,
	
	SourceList = {},
	SoundDataBuffer = {
		Position = 0
	}
}
local VideoManager = {
	VideoMetatable = reg.Video,
	NewVideo = love.graphics.newVideo,
	
	VideoList = {}
}
local RenderManager = {
	Threads = {}
}

do
	local c = lsys.getProcessorCount()
	print("Processors", c)
	c = c * 2
	print("Using "..c.." threads")
	
	for i = 1, c do
		RenderManager.Threads[i] = {Thread = love.thread.newThread [[
local id, out = ...	-- [1] = ImageData, [2] = output name
local li = require("love.image")
local encode = getmetatable(li.newImageData(1, 1)).encode

local f = assert(io.open(out, "wb"))
f:write(encode(id, "png"):getString())
f:close()
]]}
	end
end

-- len is the sample length
local function mono_to_stereo(dest, src, len)
	len = len - 1
	
	for i = 0, len do
		dest[i * 2] = src[i]
		dest[i * 2 + 1] = src[i]
	end
end

-- Both data must be in stereo
local function resample_data(oldsd, newsd)
	local len = newsd:getSampleCount() - 1
	local oldlen = oldsd:getSampleCount() - 2
	local ratemul = oldsd:getSampleRate() / 44100
	
	for i = 0, len do
		counter = i
		
		local interp = i * ratemul
		local mo = interp % 1
		local idx = math.floor(interp)
		
		if interp < oldlen then
			newsd:setSample(i * 2, (1 - mo) * oldsd:getSample(idx * 2 + 1) + oldsd:getSample(idx * 2 + 3) * mo)
			newsd:setSample(i * 2 + 1, (1 - mo) * oldsd:getSample(idx * 2 + 1) + oldsd:getSample(idx * 2 + 3) * mo)
		else
			newsd:setSample(i * 2, (1 - mo) * oldsd:getSample(idx * 2 + 1))
			newsd:setSample(i * 2 + 1, (1 - mo) * oldsd:getSample(idx * 2 + 1))
		end
	end
end

-- Sample must be range in -1..1
local function mix_audio_signal(a, b)
	return math.max(math.min(a + b, 1), -1)
end

-- Override love.audio.newSource
function love.audio.newSource(tgt)
	-- All datas must be in static
	local tgt_type = type(tgt)
	local tgt_objtype = tgt_type == "userdata" and tgt:type() or ""
	
	assert(tgt_type == "string" or (tgt_type == "userdata" and (
		tgt_objtype == "File" or
		tgt_objtype == "FileData" or
		tgt_objtype == "SoundData" or
		tgt_objtype == "Decoder"
	)), "Render: not supported audio arg")
	
	local sounddata

	if tgt_type == "userdata" and tgt_objtype == "SoundData" then
		sounddata = tgt
	else
		sounddata = love.sound.newSoundData(tgt)
	end
	
	local sc = sounddata:getSampleCount()
	local rate = sounddata:getSampleRate()
	local sourcetbl = {}
	
	sourcetbl.Position = 0		-- In samples
	sourcetbl.Playing = false
	
	assert(rate <= 44100, "Sample rate higher than 44KHz is not supported")
	
	if sounddata:getChannels() == 1 then
		-- Make it stereo
		local asd = love.sound.newSoundData(sounddata:getSampleCount(), rate)
		
		mono_to_stereo(ffi.cast("uint16_t*", asd:getPointer()), ffi.cast("uint16_t*", sounddata:getPointer()), sc)
		
		sounddata = asd
	end
	
	if rate < 44100 then
		-- Resample
		local asd = love.sound.newSoundData(math.floor(sounddata:getSampleCount() * 44100 / rate))
		
		resample_data(sounddata, asd)
		sounddata = asd
	end
	
	sourcetbl.SoundData = sounddata
	sourcetbl.MaxSamples = sounddata:getSampleCount()
	
	local sourcedata = AudioMixer.NewSource(sounddata)
	
	AudioMixer.SourceList[sourcedata] = sourcetbl
	return sourcedata
end

-- Override Source:play
function AudioMixer.SourceMetatable.play(audio)
	local sourcetbl = assert(AudioMixer.SourceList[audio], "Invalid audio passed")
	
	print("Source play", audio)
	sourcetbl.Playing = true
end

-- Override Source:isPlaying
function AudioMixer.SourceMetatable.isPlaying(audio)
	return assert(AudioMixer.SourceList[audio], "Invalid audio passed").Playing
end

-- Override Source:clone
function AudioMixer.SourceMetatable.clone(audio)
	local sourcetbl = assert(AudioMixer.SourceList[audio], "Invalid audio passed")
	local sourcetbl2 = {}
	
	sourcetbl2.Playing = false
	sourcetbl2.MaxSamples = sourcetbl.MaxSamples
	sourcetbl2.SoundData = sourcetbl.SoundData
	sourcetbl2.Position = sourcetbl.Position
	
	local sourceobj = AudioMixer.NewSource(sourcetbl.SoundData)
	AudioMixer.SourceList[sourceobj] = sourcetbl2
	
	return sourceobj
end

-- Override Source:seek
local SourceSeek = AudioMixer.SourceMetatable.seek
local SourceTell = AudioMixer.SourceMetatable.tell
function AudioMixer.SourceMetatable.seek(audio, pos, timeunit)
	local sourcetbl = assert(AudioMixer.SourceList[audio], "Invalid audio passed")
	
	SourceSeek(audio, pos, timeunit)
	sourcetbl.Position = SourceTell(audio, "samples")
end

-- Override Source:tell
function AudioMixer.SourceMetatable.tell(audio, timeunit)
	local sourcetbl = assert(AudioMixer.SourceList[audio], "Invalid audio passed")
	
	if timeunit == "samples" then
		return sourcetbl.Position
	else
		return sourcetbl.Position / 44100
	end
end

-- Override love.graphics.newVideo
-- Audio is not supported atm
function love.graphics.newVideo(vid)
	local video = VideoManager.NewVideo(vid)
	local vidtbl = {}
	
	vidtbl.Position = 0	-- In seconds
	vidtbl.Playing = false
	
	VideoManager.VideoList[video] = vidtbl
	return video
end

-- Override Video:play
function VideoManager.VideoMetatable.play(video)
	local vidtbl = assert(VideoManager.VideoList[video], "Invalid video passed")
	
	vidtbl.Playing = true
end

-- Override Video:pause
function VideoManager.VideoMetatable.pause(video)
	local vidtbl = assert(VideoManager.VideoList[video], "Invalid video passed")
	
	vidtbl.Playing = false
end

-- Override Video:isPlaying
function VideoManager.VideoMetatable.isPlaying(video)
	return assert(VideoManager.VideoList[video], "Invalid video passed").Playing
end

-- Override Video:seek
local VideoSeek = VideoManager.VideoMetatable.seek
function VideoManager.VideoMetatable.seek(video, sec)
	local vidtbl = assert(VideoManager.VideoList[video], "Invalid video passed")
	
	vidtbl.Position = sec
	VideoSeek(video, sec)
end

-- Override Video:rewind
function VideoManager.VideoMetatable(video)
	local vidtbl = assert(VideoManager.VideoList[video], "Invalid video passed")
	
	vidtbl.Position = 0
	VideoSeek(video, 0)
end

-- Render manager
function RenderManager.HasFreeThreads()
	for i = 1, #RenderManager.Threads do
		if RenderManager.Threads[i].Thread:isRunning() == false then
			RenderManager.Threads[i].Image = nil
			
			return true
		end
	end
	
	return false
end

function RenderManager.IsIdle()
	for i = 1, #RenderManager.Threads do
		if RenderManager.Threads[i].Thread:isRunning() then
			return false
		else
			RenderManager.Threads[i].Image = nil
		end
	end
	
	return true
end

function RenderManager.EncodeFrame(id, frame)
	for i = 1, #RenderManager.Threads do
		local t = RenderManager.Threads[i]
		if t.Thread:isRunning() == false then
			t.Image = id
			t.Thread:start(id, string.format("%s/%010d.png", RenderMode.Destination, frame))
			return
		end
	end
	
	assert(false, "No free threads")
end

-- Render mode
function RenderMode.Start(arg)
	RenderMode.Destination = arg[1]
	RenderMode.Duration = assert(tonumber(arg[2]), "Please specify max render duration in seconds")
	
	-- Prevent window resizing
	do
		local w, h, flgs = love.window.getMode()
		
		flgs.resizable = false
		if flgs.fullscreen then
			w, h = 960, 640
			flgs.fullscreen = false
		end
		
		love.window.setTitle("Live Simulator: 2 (Rendering Mode)")
		love.window.setMode(w, h, flgs)
		local x = math.random()
	end
	
	-- Init DEPLS
	RenderMode.DEPLS = love.filesystem.load("livesim.lua")()
	RenderMode.DEPLS.RenderingMode = true
	RenderMode.DEPLS.Start({arg[3], arg[4]})
	
	-- Set audio
	RenderMode.DEPLS.Sound.BeatmapAudio = AudioMixer.SourceList[RenderMode.DEPLS.Sound.LiveAudio].SoundData
	
	-- Create canvas
	RenderMode.Canvas = love.graphics.newCanvas()
	
	-- Post-init
	print("SoundData buffer", RenderMode.Duration * 44100 + 735)
	
	AudioMixer.SoundDataBuffer.Handle = love.sound.newSoundData(math.floor(RenderMode.Duration * 44100 + 735.5))
	RenderMode.Duration = RenderMode.Duration * 1000
end

local function SetSampleBreak(i, l, r)
	if pcall(AudioMixer.SoundDataMetatable.setSample, AudioMixer.SoundDataBuffer.Handle, i, l, r) == false then
		assert(false, "Sample out-of-range index "..i)
	end
end

function RenderMode.Update(deltaT)
	if RenderMode.ElapsedTime >= RenderMode.Duration or RenderManager.HasFreeThreads() == false then
		if RenderManager.IsIdle() then
			love.event.quit()
		end
		
		return
	end
	
	-- On render mode, always use deltaT 60FPS
	RenderMode.DEPLS.Update(RenderMode.DeltaTime)
	RenderMode.ElapsedTime = RenderMode.ElapsedTime + RenderMode.DeltaTime
	
	-- Step video
	local DeltaTime = RenderMode.DeltaTime / 1000
	for n, v in pairs(VideoManager.VideoList) do
		if v.Playing then
			v.Position = v.Position + DeltaTime
			VideoSeek(n, v.Position)
		end
	end
	
	-- Mix any audios. Process 735 samples at time
	for i = 1, 735 do
		local as_l, as_r = 0, 0
		
		for n, v in pairs(AudioMixer.SourceList) do
			if v.Playing then
				local sd = v.SoundData
				
				if v.Position < v.MaxSamples then
					local vol = n:getVolume() * 0.8
					local sl, sr = sd:getSample(v.Position * 2) * vol, sd:getSample(v.Position * 2 + 1) * vol
					
					as_l, as_r = mix_audio_signal(as_l, sl), mix_audio_signal(as_r, sr)
					
					v.Position = v.Position + 1
				else
					v.Playing = false
				end
			end
		end
		
		SetSampleBreak(AudioMixer.SoundDataBuffer.Position * 2, as_l)
		SetSampleBreak(AudioMixer.SoundDataBuffer.Position * 2 + 1, as_r)
		AudioMixer.SoundDataBuffer.Position = AudioMixer.SoundDataBuffer.Position + 1
	end
	
	collectgarbage("collect")
end

function RenderMode.Draw(deltaT)
	if RenderManager.HasFreeThreads() and RenderMode.ElapsedTime < RenderMode.Duration then
		love.graphics.setCanvas(RenderMode.Canvas)
		love.graphics.clear()
		RenderMode.DEPLS.Draw(RenderMode.DeltaTime)
		love.graphics.setCanvas(nil)
		RenderMode.Frame = RenderMode.Frame + 1
		
		RenderManager.EncodeFrame(RenderMode.Canvas:newImageData(), RenderMode.Frame)
		
		print("Rendering Frame", RenderMode.Frame)
	end
	
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(RenderMode.Canvas, -LogicalScale.OffX, -LogicalScale.OffY)
	love.graphics.setBlendMode("alpha")
	RenderMode.DEPLS.DrawDebugInfo()
end

local function dwordu2string(num)
	return
		string.char(bit.band(num, 0xFF)) ..
		string.char(bit.rshift(bit.band(num, 0xFF00), 8)) ..
		string.char(bit.rshift(bit.band(num, 0xFF0000), 16)) ..
		string.char(bit.rshift(bit.band(num, 0xFF000000), 24))
end

function love.quit()
	repeat
		love.timer.sleep(0.1)
	until RenderManager.IsIdle()
	
	print("Saving audio")
	local audio_wav = assert(io.open(RenderMode.Destination.."/audio.wav", "wb"))
	local current_pos = (AudioMixer.SoundDataBuffer.Position + 1) * 4
	
	audio_wav:write("RIFF\0\0\0\0WAVEfmt \16\0\0\0\1\0\2\0\68\172\0\0\16\177\2\0\4\0\16\0data")
	audio_wav:write(dwordu2string(current_pos))
	audio_wav:write(ffi.string(AudioMixer.SoundDataBuffer.Handle:getPointer(), current_pos))
	
	local filelen = audio_wav:seek() - 8
	
	audio_wav:seek("set", 4)
	audio_wav:write(dwordu2string(filelen))
	audio_wav:close()
	
	return false
end

return RenderMode
