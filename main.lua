function love.load()
	audio = require 'audio'
	spectrum = require 'spectrum'
	gui = require 'gui'

	---------------------------------- Window/Scaling ----------------------------------
	local desktop_width, desktop_height = love.window.getDesktopDimensions()
	window_width = desktop_width*(2/3)
	window_height = desktop_height*(2/3)

	local window_position_x = (desktop_width-window_width)/2
	local window_position_y = (desktop_height-window_height)*(5/12) --5/12 to account for taskbar/dock
	love.window.setMode(
		window_width, window_height,
		{x=window_position_x, y=window_position_y,
		resizable=true, highdpi=true}
	)
	love.window.setIcon(love.image.newImageData("icon.png"))
	love.window.setTitle("Drop - by nabakin")
	-- see love.resize for new variables

	--[[ modify default screen ratio <<TEST>>
	goal is to optimize Drop for screen ratios other than 16/10 ]]
	ratio_width = 16
	ratio_height = 10
	scale_ratio_width = (10/ratio_height)*ratio_width

	local graphics_width
	local graphics_height
	graphics_width, graphics_height = love.graphics.getDimensions()
	gui.graphics:setWidth(graphics_width)
	gui.graphics:setHeight(graphics_height)
	gui.scrubbar:setX(math.floor(graphics_width/(6*scale_ratio_width)))
	gui.scrubbar:setY(math.floor(graphics_height-graphics_height/7))
	gui.scrubbar:setWidth(graphics_width-math.floor(graphics_width/(3*scale_ratio_width)))
	gui.scrubbar:setHeight(math.floor(graphics_height*4/155))
	normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
	------------------------------------------------------------------------------------
	
	love.graphics.setFont(big_font)
	love.keyboard.setKeyRepeat(true)
	last_frame_time = 0

	-- Main --
	appdata_path = love.filesystem.getAppdataDirectory()
	
	waveform = {}
	visualizer_type = 3
	scrub_head_pause = false
	scrub_head_pressed = false

	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle('smooth')
	
	start_screen = true
	appdata_music = true

	-- see love.resize for scrub bar variables

	fade_interval_counter = 1
	fade_bool = false
	color = "g"
	fade_intensity = 1
	set_color("g", 1)
	sleep_counter = 0
	enable_overlay = true
	window_visible = true

	-- to estimate delay for spectrum
	latency = {}
	delay_average = 0
end

function love.update(dt)
	if not start_screen then
		audio.update()

		if audio.decoder_tell('samples') ~= spectrum.getOldSample() and window_visible then
			-- fft calculations (generates waveform for visualization)
			waveform = spectrum.generate_waveform(delay_average)

			--fade timer: limits fade update every .2 sec
			fade_interval_counter = fade_interval_counter+dt
			if fade_interval_counter >= 0.2 then
				fade_bool = true
			end
		end

		--overlay timer: puts overlay to sleep after 7 sec of inactivity
		if not sleep() then
			sleep_counter = sleep_counter+dt
			if sleep_counter > 7 then
				sleep(true)
				sleep_counter = 0
			end
		end
	end
end

function love.draw()
	spectrum.draw(waveform)

	-- controls visualization fade
	if fade_bool then
		local fade = spectrum.getAverageTickAmplitude()*60+.2
		
		set_color(nil, 1)--fade) --turned off atm
		fade_bool = false
	end

	-- estimated optimial delay for music-visual sync
	local delay_final_time = love.timer.getTime()
	if #latency >= 20 then
		table.remove(latency, 1)
	end
	latency[#latency+1] = delay_final_time-spectrum.getDelayInitialTime()
	local total_latency = 0
	for i,v in ipairs(latency) do
		total_latency = total_latency+v
	end
	delay_average = total_latency/#latency

	-- overlay/video drawing
	if enable_overlay and not start_screen then
		gui.overlay()
	elseif start_screen then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(big_font)
		
		local graphics_width = gui.graphics:getWidth()
		local graphics_height = gui.graphics:getHeight()
		
		if appdata_music then
			love.graphics.printf("Drag and drop your music folder(s) here to listen or press any key to only listen to songs in \""..appdata_path.."/LOVE/Drop/music.\"", 1, graphics_height/2, graphics_width, "center")
		else
			love.graphics.printf("There aren't any songs in \""..appdata_path.."/LOVE/Drop/music\" yet.  If you copy some there, this feature will work.", 1, graphics_height/2, graphics_width, "center")
		end
	end

	--[[ manual love.window.isVisible for behind windows and minimized.  Only works on Mac.
	Saves a lot of cpu.  Likely error-prone because it's a bad implementation (no other way) ]]
	if love.timer.getFPS() > 66 then
		-- manual fps limiter (fixes background fps/CPU leak) it's 70 instead of 60 so we can detect when behind windows
		if window_visible then last_frame_time = love.timer.getTime() end
		local slack = 1/70 - (love.timer.getTime()-last_frame_time)
		if slack > 0 then love.timer.sleep(slack) end
		last_frame_time = love.timer.getTime()

		window_visible = false
	else
		window_visible = true
	end
end

function sleep(bool)
	if bool ~= nil then
		if bool then
			love.mouse.setVisible(false)
			enable_overlay = false
		else
			love.mouse.setVisible(true)
			enable_overlay = true
			sleep_counter = 0
		end
	end

	return not love.mouse.isVisible()
end

function set_color(c, f)
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
	sleep(false)

	-- detects if scrub bar clicked and moves to the corresponding point in time
	if button == 1 and not start_screen and x <= gui.scrubbar:getX()+gui.scrubbar:getWidth() and x >= gui.scrubbar:getX() and y <= gui.scrubbar:getY()+gui.scrubbar:getHeight() and y >= gui.scrubbar:getY() then
		audio.decoderSeek(((x-gui.scrubbar:getX())/gui.scrubbar:getWidth())*audio.getDuration())
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
	sleep(false)

	-- makes scrub bar draggable
	if love.mouse.isDown(1) and scrub_head_pressed then
		if audio.isPlaying() then
			scrub_head_pause = true
			audio.pause()
		end
		
		-- check x-axis bounds for scrub bar
		if x <= gui.scrubbar:getX()+gui.scrubbar:getWidth() and x >= gui.scrubbar:getX() then
			audio.decoderSeek(((x-gui.scrubbar:getX())/gui.scrubbar:getWidth())*audio.getDuration())
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	sleep(false)

	local key_functions = {
		["right"] = function ()
			next_song()
		end,
		["left"] = function ()
			prev_song()
		end,

		-- rgb keys are being used as a test atm.  Not finished
		["r"] = function ()
			set_color("r")
		end,
		["g"] = function ()
			set_color("g")
		end,
		["b"] = function ()
			set_color("b")
		end,
		["1"] = function ()
			visualizer_type = 1
		end,
		["2"] = function ()
			visualizer_type = 2
		end,
		["3"] = function ()
			visualizer_type = 3
		end,
		["4"] = function ()
			visualizer_type = 4
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
			--[[local samples_per_frame = (sound:getSampleCount()/current_song:getDuration('seconds'))/60
			current_song:seek(current_song:tell('samples')-samples_per_frame, 'samples')]]
		end,
		["."] = function ()
			--[[local samples_per_frame = (sound:getSampleCount()/current_song:getDuration('seconds'))/60
			current_song:seek(current_song:tell('samples')+samples_per_frame, 'samples')]]
		end
	}

	if start_screen then
		appdata_music = audio.loadMusic()
		start_screen = false
		love.graphics.setFont(normal_font)
	else
		local function catch_nil()
		end
		(key_functions[key] or catch_nil)()
	end
end

function love.resize(w, h)
	local graphics_width
	local graphics_height
	graphics_width, graphics_height = love.graphics.getDimensions()
	gui.graphics:setWidth(graphics_width)
	gui.graphics:setHeight(graphics_height)
	gui.scrubbar:setX(math.floor(graphics_width/(6*scale_ratio_width)))
	gui.scrubbar:setY(math.floor(graphics_height-graphics_height/7))
	gui.scrubbar:setWidth(graphics_width-math.floor(graphics_width/(3*scale_ratio_width)))
	gui.scrubbar:setHeight(math.floor(graphics_height*4/155))
	normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
end

function love.directorydropped(path)
	love.filesystem.mount(path, "music")
	start_screen = not audio.loadMusic()
end

function love.visible(v)
	--window_visible = v
end