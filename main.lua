function love.load()
	require 'luafft'

	-- Setup --
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
	-- see love.resize for new variables

	--[[ modify default screen ratio <<TEST>>
	goal is to optimize Drop for screen ratios other than 16/10 ]]
	ratio_width = 16
	ratio_height = 10
	scale_ratio_width = (10/ratio_height)*ratio_width

	graphics_width, graphics_height = love.graphics.getDimensions()
	scrubbar_x = math.floor(graphics_width/(6*scale_ratio_width))
	scrubbar_y = math.floor(graphics_height-graphics_height/7)
	scrubbar_width = graphics_width-math.floor(graphics_width/(3*scale_ratio_width))
	scrubbar_height = math.floor(graphics_height*4/155)
	font_size = math.max(graphics_height/30, 16)
	love.graphics.setFont(love.graphics.newFont(font_size))
	current_font = love.graphics.getFont()

	love.keyboard.setKeyRepeat(true)
	last_frame_time = love.timer.getTime()


	-- Main --
	music_exists = false
	appdata_music = true
	if not love.filesystem.exists("music") then love.filesystem.createDirectory("music") end
	
	waveform = {}
	song_id = 0
	current_song = nil
	visualizer_type = 3
	set_color("g", 255)

	intro_video = love.graphics.newVideo("intro.ogv")
	intro_video:play()
	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle('smooth')

	-- see love.resize for scrub bar variables

	fade_interval_counter = 1
	fade_bool = false
	sleep_counter = 0
	enable_overlay = true
	window_visible = true

	-- to estimate delay for spectrum
	delay_initial_time = 0
	estimate_delay=true
	latency = {}
	delay_average = 0
end

function love.update(dt)
	if not intro_video:isPlaying() and music_exists then
		-- plays first song
		if current_song == nil then
			love.audio.setVolume(0.5)
			next_song()
		end

		-- when song finished, play next one
		if not current_song:isPlaying() and not current_song:isPaused() then
			next_song()
		end

		if current_song:tell('samples') ~= old_sample and window_visible then
			-- fft calculations (generates waveform for visualization)
			waveform = generate_waveform()

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
	local tick_count
	local tick_distance
	local tick_width
	if visualizer_type == 1 then
		tick_count = 48
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*5.5)
	elseif visualizer_type == 2 then
		tick_count = 64
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*4.3)
	elseif visualizer_type == 3 then
		tick_count = 128
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*2)
	end

	local waveform_average = 0

	-- draw bar visualization
	set_color()
	if #waveform == 0 then tick_count = 0 end
	for i=1, tick_count do
		local tick_amplitude = waveform[i]
		local tick_height = math.ceil(graphics_height*tick_amplitude:abs()*2)

		love.graphics.rectangle(
			'fill', math.ceil(graphics_width/2+(i-1)*tick_distance),
			math.ceil(graphics_height/2 - tick_height/2),
			math.ceil(tick_width), tick_height,
			math.ceil(tick_width/2), math.ceil(tick_width/2)
		)
		love.graphics.rectangle(
			'fill', math.ceil(graphics_width/2-(i-1)*tick_distance),
			math.ceil(graphics_height/2 - tick_height/2),
			math.ceil(tick_width), tick_height,
			math.ceil(tick_width/2), math.ceil(tick_width/2)
		)

		waveform_average = waveform_average + tick_amplitude:abs()
	end

	-- controls visualization fade
	if fade_bool then
		local waveform_average_per_tick = waveform_average/tick_count
		local fade = math.floor(waveform_average_per_tick*15000)+50

		set_color(nil, 255)--fade) turned off atm
		fade_bool = false
	end

	-- estimates delay for waveform
	if not estimate_delay then
		local delay_final_time = love.timer.getTime()
		if #latency >= 20 then
			table.remove(latency, 1)
		end
		latency[#latency+1] = delay_final_time-delay_initial_time
		local total_latency = 0
		for i,v in ipairs(latency) do
			total_latency = total_latency+v
		end
		delay_average = total_latency/#latency
		estimate_delay = true
	end

	-- overlay/video drawing
	if enable_overlay and current_song ~= nil and music_exists then
		overlay()
	elseif intro_video:isPlaying() then
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(
			intro_video, graphics_width/2, graphics_height/2,
			nil, graphics_width/960, graphics_width/960,
			intro_video:getWidth()/2, intro_video:getHeight()/2
		)
		if intro_video:tell() > 1.3 then
			local string = "Press any key to skip"
			love.graphics.print(
				string, graphics_width/2,
				graphics_height-(current_font:getHeight())-80,
				nil, nil, nil, current_font:getWidth(string)/2
			)
		end
	elseif not music_exists then
		love.graphics.setColor(255, 255, 255)
		love.graphics.setFont(love.graphics.newFont(36))
		if appdata_music then
			love.graphics.printf("Drag and drop your music folder(s) here to listen or press any key to only listen to songs in appdata/LOVE/Drop/music.", 1, graphics_height/2, graphics_width, "center")
		else
			love.graphics.printf("There isn't any music in appdata/LOVE/Drop/music.", 1, graphics_height/2, graphics_width, "center")
		end
	end

	--[[ manual love.window.isVisible for behind windows and minimized
	Saves a lot of cpu.  Likely error-prone because it's a bad implementation (no other way) ]]
	if love.timer.getFPS() > 66 then
		window_visible = false
	else
		window_visible = true
	end

	-- manual fps limiter (fixes background fps/CPU leak) it's 70 instead of 60 so we can detect when behind windows
	local slack = 1/70 - (love.timer.getTime()-last_frame_time)
	if slack > 0 then love.timer.sleep(slack) end
	last_frame_time = love.timer.getTime()
end

function overlay()
	love.graphics.setColor(255, 255, 255)
	if song_id ~= 0 then
		love.graphics.print(music_list[song_id][2], 10, 10)
	end

	-- get time from start of song and change time_end in relation to time_start.  Result: both change time simultaneously
	local time_start, minute, second = secondstostring(current_song:tell('seconds'))
	local _, minute_end, second_end = secondstostring(current_song:getDuration('seconds'))
	local minutes = minute_end-minute
	local seconds = second_end-second
	if seconds < 0 then
		seconds = seconds+60
		minutes = minutes-1
	end
	local time_end = string.format("%02d:%02d", minutes, seconds)

	love.graphics.rectangle(
		"line", scrubbar_x, scrubbar_y,
		scrubbar_width, scrubbar_height,
		scrubbar_height/2, scrubbar_height/2
	)
	love.graphics.print(
		time_start, scrubbar_x,
		scrubbar_y-(current_font:getHeight())
	)
	love.graphics.print(
		time_end, scrubbar_x+scrubbar_width-(current_font:getWidth(time_end)),
		scrubbar_y-(current_font:getHeight())
	)
	
	if graphics_height > 360 then
		love.graphics.print(
			"Change time by clicking the scrub bar\tChange songs with the arrow keys\tPress escape to exit\nChange colors with r, g, and b\tToggle Fullscreen with f\tPlay/Pause with the space bar",
			10, graphics_height-(current_font:getHeight()*2)
		)
	end

	local current_time_proportion = current_song:tell('seconds')/current_song:getDuration('seconds')
	love.graphics.circle(
		"fill", current_time_proportion*scrubbar_width+scrubbar_x,
		scrubbar_y+scrubbar_height/2, math.floor(scrubbar_height/2), math.max(3*math.floor(scrubbar_height/2), 3)
	)
end

function generate_waveform()
	local current_sample = current_song:tell('samples')
	local song_size = sound:getSampleCount()
	local wave = {}
	local size = next_possible_size(1024)
	local new_sample = 0
	local delay_seconds = delay_average --estimated optimial delay for music-visual sync
	local sample = current_sample+sample_rate*delay_seconds

	--to estimate delay for spectrum
	if estimate_delay then
		delay_initial_time = love.timer.getTime()
		estimate_delay = false
	end

	--[[ generates wave input for fft from audio
	Optimized to take any number of channels (ex: Mono, Stereo, 5.1, 7.1) and grab
	average samples (makes visualization smoother). Not supported by Love yet ]]
	local sampling_size = 4 --number of samples to average
	local scaled_sampling_size = sampling_size*channels
	for i=sample, sample+size-1 do-- -channels)/channels do
		if i+scaled_sampling_size/2 > song_size then
			i = song_size-scaled_sampling_size/2
		elseif i-scaled_sampling_size/2 < 0 then
			i = sampling_size/2
		end

		for j=1, scaled_sampling_size do
			new_sample = new_sample+sound:getSample(i*channels+j-1-scaled_sampling_size/2) --scales sample size index, centers it, obtains samples, and sums them
		end
		new_sample = new_sample/scaled_sampling_size --averages sample
		table.insert(wave, complex.new(new_sample, 0))
	end
	old_sample = current_sample

	--wave->spectrum takes most CPU usage
	local spectrum = fft(wave,false)

	function divide(list, factor)
		for i,v in ipairs(list) do
			list[i] = list[i] / factor
		end
	end

	--normalizes spectrum
	divide(spectrum, size/2)
	return spectrum
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
		fade_intensity = math.min(math.max(f, 0), 255)
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
	if button == 1 and current_song ~= nil and x <= scrubbar_x+scrubbar_width and x >= scrubbar_x and y <= scrubbar_y+scrubbar_height and y >= scrubbar_y then
		current_song:seek(((x-scrubbar_x)/scrubbar_width)*current_song:getDuration('seconds'), "seconds")
		scrub_head_pressed = true
	end
end

function love.mousereleased(x, y, button, istouch)
	if scrub_head_pause then
		current_song:resume()
		scrub_head_pause = false
	end
	scrub_head_pressed = false
end

function love.mousemoved(x, y, dx, dy, istouch)
	sleep(false)

	-- makes scrub bar draggable
	if love.mouse.isDown(1) and scrub_head_pressed then
		if current_song:isPlaying() then
			scrub_head_pause = true
			current_song:pause()
		end
		if x <= scrubbar_x+scrubbar_width and x >= scrubbar_x then
			current_song:seek(((x-scrubbar_x)/scrubbar_width)*current_song:getDuration('seconds'), "seconds")
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	sleep(false)

	-- rgb keys are being used as a test atm.  Not finished
	if not intro_video:isPlaying() then
		if music_exists == false and appdata_music then
			music_list = recursive_enumerate("music")
			
			music_exists = true
			if next(music_list) == nil then
				music_exists = false
				appdata_music = false
			end
			love.graphics.setFont(love.graphics.newFont(font_size))
		end
		if key == "right" then
			next_song()
		elseif key == "left" then
			prev_song()
		elseif key == "r" then
			set_color("r")
		elseif key == "g" then
			set_color("g")
		elseif key == "b" then
			set_color("b")
		elseif key == "1" then
			visualizer_type = 1
		elseif key == "2" then
			visualizer_type = 2
		elseif key == "3" then
			visualizer_type = 3
		elseif key == "escape" then
			love.event.quit()
		elseif key == "f" then
			if love.window.getFullscreen() then
				love.window.setFullscreen(false)
			else
				love.window.setFullscreen(true)
			end
		elseif key == "space" then
			if current_song:isPaused() then
				current_song:resume()
			else
				current_song:pause()
			end

		-- moves slowly through the visualization by the length of a frame.  Used to compare visualizations
		elseif key == "," then
			local samples_per_frame = (sound:getSampleCount()/current_song:getDuration('seconds'))/60
			current_song:seek(current_song:tell('samples')-samples_per_frame, 'samples')
		elseif key == "." then
			local samples_per_frame = (sound:getSampleCount()/current_song:getDuration('seconds'))/60
			current_song:seek(current_song:tell('samples')+samples_per_frame, 'samples')
		end
	else
		intro_video:getSource():stop()
	end
end

function love.resize(w, h)
	graphics_width, graphics_height = love.graphics.getDimensions()
	scrubbar_x = math.floor(graphics_width/(6*scale_ratio_width))
	scrubbar_y = math.floor(graphics_height-graphics_height/7)
	scrubbar_width = graphics_width-math.floor(graphics_width/(3*scale_ratio_width))
	scrubbar_height = math.floor(graphics_height*4/155)
	font_size = math.max(graphics_height/30, 16)
	love.graphics.setFont(love.graphics.newFont(font_size))
	current_font = love.graphics.getFont()
end

function love.directorydropped(path)
	love.filesystem.mount(path, "music")
	music_list = recursive_enumerate("music")
	
	music_exists = true
	if next(music_list) == nil then
		music_exists = false
	end
	love.graphics.setFont(love.graphics.newFont(font_size))
end

function love.visible(v)
	--window_visible = v
end




-- File Handling --
function recursive_enumerate(folder)
	local format_table = {
		".mp3", ".wav", ".ogg", ".oga", ".ogv",
		".699", ".amf", ".ams", ".dbm", ".dmf",
		".dsm", ".far", ".pat", ".j2b", ".mdl",
		".med", ".mod", ".mt2", ".mtm", ".okt",
		".psm", ".s3m", ".stm", ".ult", ".umx",
		".xm", ".abc", ".mid", ".it"
	}
	
	local lfs = love.filesystem
	local music_table = lfs.getDirectoryItems(folder)
	local complete_music_table = {}
	local valid_format = false
	local index = 1
	
	for i,v in ipairs(music_table) do
		local file = folder.."/"..v
		for j,w in ipairs(format_table) do
			if v:sub(-4) == w then
				valid_format = true
				break
			end
		end
		if lfs.isFile(file) and valid_format then
			complete_music_table[index] = {}
			complete_music_table[index][1] = lfs.newFile(file)
			complete_music_table[index][2] = v:sub(1, -5)
			index = index+1
			valid_format = false
		elseif lfs.isDirectory(file) then
			local recursive_table = recursive_enumerate(file)
			for j,w in ipairs(recursive_table) do
				complete_music_table[index] = {}
				complete_music_table[index][1] = w[1]
				complete_music_table[index][2] = w[2]
				index = index+1
			end
		end
	end
	
	return complete_music_table
end



-- Tools --
function secondstostring(sec)
	local minute = math.floor(sec/60)
	local second = math.floor(((sec/60)-minute)*60)
	local second_string = string.format("%02d:%02d", minute, second)

	return second_string, minute, second
end



-- Song Handling --
function next_song()
	song_id = song_id+1
	-- loops songs
	if song_id > #music_list then
		song_id = 1
	end

	if current_song ~= nil then
		current_song:seek(0, 'seconds')
		waveform = generate_waveform()
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.origin()
		love.draw()
		love.graphics.present()
		current_song:stop()
	end

	sound = love.sound.newSoundData(music_list[song_id][1])
	sample_rate = sound:getSampleRate()
	channels = sound:getChannels()

	current_song = love.audio.newSource(sound)
	current_song:play()
end

function prev_song()
	song_id = song_id-1
	if song_id < 1 then
		song_id = #music_list
	end

	if current_song ~= nil and current_song:isPlaying() then
		current_song:seek(0, 'seconds')
		waveform = generate_waveform()
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.origin()
		love.draw()
		love.graphics.present()
		current_song:stop()
	end

	sound = love.sound.newSoundData(music_list[song_id][1])
	sample_rate = sound:getSampleRate()
	channels = sound:getChannels()

	current_song = love.audio.newSource(sound)
	current_song:play()
end
