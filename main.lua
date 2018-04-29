function love.load()
	audio = require 'audio'
	spectrum = require 'spectrum'
	gui = require 'gui'

  -- Mac only and if not 60hz
	monitor_refresh_rate = 60

  -- load/scale gui
	gui.load()
  
	--------------------------------- Keyboard Actions ---------------------------------
	key_functions = {
		["right"] = function ()
			audio.changeSong(1)
		end,
		["left"] = function ()
			audio.changeSong(-1)
		end,

		-- rgb keys are being used as a test atm.  Not finished
		["r"] = function ()
			setColor("r")
		end,
		["g"] = function ()
			setColor("g")
		end,
		["b"] = function ()
			setColor("b")
		end,
		["1"] = function ()
			spectrum.setVisualization(1)
		end,
		["2"] = function ()
			spectrum.setVisualization(2)
		end,
		["3"] = function ()
			spectrum.setVisualization(3)
		end,
		["4"] = function ()
			spectrum.setVisualization(4)
		end,
		["escape"] = function ()
			love.event.quit()
		end,
		["f"] = function ()
			love.window.setFullscreen(not love.window.getFullscreen())
		end,
		["space"] = function ()
			if audio.isPaused() then
				audio.play()
			else
				audio.pause()
			end
		end,

		-- moves slowly through the visualization by the length of a frame.  Used to compare visualizations
		[","] = function ()
			audio.decoderSeek(audio.decoderTell()-spectrum.getSize()/(audio.getSampleRate()*audio.getChannels()))
		end,
		["."] = function ()
			audio.decoderSeek(audio.decoderTell()+spectrum.getSize()/(audio.getSampleRate()*audio.getChannels()))
		end
	}

	love.keyboard.setKeyRepeat(true)
	------------------------------------------------------------------------------------

	----------------------------------- Main -------------------------------------------
	appdata_path = love.filesystem.getAppdataDirectory()
  operating_system = love.system.getOS()

	waveform = {}
	scrub_head_pause = false
	scrub_head_pressed = false

	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle('smooth')

	appdata_music = true

	-- see love.resize for scrub bar variables

	fade_interval_counter = 1
	fade_bool = false
	color = "g"
	fade_intensity = 1
	setColor("g", 1)
	sleep_counter = 0
	window_visible = true
  last_frame_time = 0
	------------------------------------------------------------------------------------
end

function love.update(dt)
	if audio.musicExists() then
		audio.update()

		if spectrum.wouldChange() and window_visible and not love.window.isMinimized() then
			-- fft calculations (generates waveform for visualization)
			waveform = spectrum.generateWaveform()

			--fade timer: limits fade update every .2 sec
			fade_interval_counter = fade_interval_counter+dt
			if fade_interval_counter >= 0.2 then
				fade_bool = true
			end
		end

		--overlay timer: puts overlay to sleep after 7 sec of inactivity
		if not gui.sleep() then
			sleep_counter = sleep_counter+dt
			if sleep_counter > 7 then
				gui.sleep(true)
				sleep_counter = 0
			end
		end
	end
end

function love.draw()
	if not love.window.isMinimized() then
    spectrum.draw(waveform)
  end

	-- controls visualization fade
	if fade_bool then
		local fade = spectrum.getAverageTickAmplitude()*60+.2

		setColor(nil, 1)--fade) --turned off atm
		fade_bool = false
	end

	-- overlay/start_screen drawing
	if not audio.musicExists() then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(gui.graphics:getBigFont())

		local graphics_width = gui.graphics:getWidth()
		local graphics_height = gui.graphics:getHeight()

		if appdata_music then
			love.graphics.printf("Drag and drop your music here to listen or press any key to listen to songs in \""..appdata_path.."/LOVE/Drop/music.\"", 1, graphics_height/2-3*love.graphics.getFont():getHeight()/2, graphics_width, "center")
		else
			love.graphics.printf("You just tried to play music from your appdata.  Copy songs to \""..appdata_path.."/LOVE/Drop/music\" to make this work or drag and drop music onto this window.", 1, graphics_height/2-3*love.graphics.getFont():getHeight()/2, graphics_width, "center")
		end
	end
  gui.overlay()

	--[[ manual love.window.isVisible for behind windows and minimized.  Only works on Mac.
	Saves a lot of cpu.  Likely error-prone because it's a bad implementation (no other way) ]]
	if love.timer.getFPS() > monitor_refresh_rate+6 and operating_system == "OS X" then
		-- manual fps limiter (fixes background fps/CPU leak) it's 70 instead of 60 so we can detect when behind windows
		if window_visible then last_frame_time = love.timer.getTime() end
		local slack = 1/(monitor_refresh_rate+10) - (love.timer.getTime()-last_frame_time)
		if slack > 0 then love.timer.sleep(slack) end
		last_frame_time = love.timer.getTime()

		window_visible = false
	else
		window_visible = true
	end
end

function setColor(c, f)
	if c and (c == "r" or c == "g" or c == "b") then
		color = c
	end
	if f then
		fade_intensity = math.min(math.max(f, 0), 1)
	end
	if color == "r" then
		love.graphics.setColor(fade_intensity, 0, 0)
	elseif color == "g" then
		love.graphics.setColor(0, fade_intensity, 0)
	elseif color == "b" then
		love.graphics.setColor(0, 0, fade_intensity)
	end
end






-- Input Callbacks --
function love.mousepressed(x, y, button, istouch)
	gui.sleep(false)
	sleep_counter = 0

	-- detects if scrub bar clicked and moves to the corresponding point in time
	if button == 1 and audio.musicExists() and gui.scrubbar:inBoundsX(x) and gui.scrubbar:inBoundsY(y) then
		audio.decoderSeek(gui.scrubbar:getProportion(x)*audio.getDuration())
		scrub_head_pressed = true
	end
end

function love.mousereleased(x, y, button, istouch)
	if scrub_head_pause then
		audio.play()
		scrub_head_pause = false
	end
	scrub_head_pressed = false
end

function love.mousemoved(x, y, dx, dy, istouch)
	gui.sleep(false)
	sleep_counter = 0

	-- makes scrub bar draggable
	if scrub_head_pressed then
		if audio.isPlaying() then
			scrub_head_pause = true
			audio.pause()
		end

		if gui.scrubbar:inBoundsX(x) then
			audio.decoderSeek(gui.scrubbar:getProportion(x)*audio.getDuration())
		end
	end
end

function love.mousefocus(focus)
  if scrub_head_pause then
		audio.play()
		scrub_head_pause = false
	end
	scrub_head_pressed = false
end

function love.keypressed(key, scancode, isrepeat)
	gui.sleep(false)
	sleep_counter = 0

	if not audio.musicExists() then
		appdata_music = audio.loadMusic()
	else
		local function catch_nil() end
		(key_functions[key] or catch_nil)()
	end
end

-- when window resizes, scale
function love.resize(w, h)
  gui.scale()
end

function love.directorydropped(path)
	love.filesystem.mount(path, "music")
  audio.loadMusic()
end

function love.filedropped(file)
  audio.addSong(file)
end

function love.visible(v)
	window_visible = v
end
