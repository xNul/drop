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
	love.window.setIcon(love.image.newImageData("icon.png"))
	love.window.setTitle("Drop - by nabakin")
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
	normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
	love.graphics.setFont(big_font)

	love.keyboard.setKeyRepeat(true)
	last_frame_time = 0


	-- Main --
	music_exists = false
	appdata_music = true
	decoder_buffer = 2048
	seconds_per_buffer = 0
	queue_size = 8
	decoder_array = {}
	appdata_path = love.filesystem.getAppdataDirectory()
	if not love.filesystem.getInfo("music") then love.filesystem.createDirectory("music") end

	waveform = {}
	song_id = 0
	current_song = nil
	is_paused = false
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
	if (intro_video == nil or not intro_video:isPlaying()) and music_exists then
		-- plays first song
		if current_song == nil then
			love.audio.setVolume(0.5)
			next_song()
			if intro_video ~= nil then
				intro_video = nil
				collectgarbage()
			end
		end

		-- when song finished, play next one
		if decoder_array[queue_size-1] == nil then
			next_song()
		elseif not is_paused and not scrub_head_pause and not current_song:isPlaying() then
			current_song:play()
		end

		local check = current_song:getFreeBufferCount()
		if check > 0 then
			time_count = time_count+check*seconds_per_buffer

			for i=0, queue_size-1 do
				decoder_array[i] = decoder_array[i+check]
			end

			while check ~= 0 do
				local tmp = decoder:decode()
				if tmp ~= nil then
					current_song:queue(tmp)
					decoder_array[queue_size-check] = tmp
					check = check-1
				else
					break
				end
			end
		end

		if (current_song:isPlaying() or decoder_tell('samples') ~= old_sample) and window_visible then
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
	elseif intro_video == nil or not intro_video:isPlaying() then
		if intro_video ~= nil then
			intro_video = nil
			collectgarbage()
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
	elseif visualizer_type == 4 then
		tick_count = 48
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
	elseif intro_video ~= nil and intro_video:isPlaying() then
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(
			intro_video, graphics_width/2, graphics_height/2,
			nil, graphics_width/960, graphics_width/960,
			intro_video:getWidth()/2, intro_video:getHeight()/2
		)
		if intro_video:tell() > 1.3 then
			local string = "Press any key to skip"
			local current_font = love.graphics.getFont()
			love.graphics.print(
				string, graphics_width/2,
				graphics_height-(current_font:getHeight())-80,
				nil, nil, nil, current_font:getWidth(string)/2
			)
		end
	elseif not music_exists then
		love.graphics.setColor(255, 255, 255)
		love.graphics.setFont(big_font)
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

function overlay()
	love.graphics.setColor(255, 255, 255)
	if song_id ~= 0 then
		love.graphics.print(music_list[song_id][2], 10, 10)
	end

	-- get time from start of song and change time_end in relation to time_start.  Result: both change time simultaneously
	local time_start, minute, second = secondstostring(decoder_tell())
	local _, minute_end, second_end = secondstostring(decoder:getDuration())
	local minutes = minute_end-minute
	local seconds = second_end-second
	if seconds < 0 then
		seconds = seconds+60
		minutes = minutes-1
	end
	local time_end = string.format("%02d:%02d", minutes, seconds)
	local current_font = love.graphics.getFont()

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

	local current_time_proportion = decoder_tell()/decoder:getDuration()
	love.graphics.circle(
		"fill", current_time_proportion*scrubbar_width+scrubbar_x,
		scrubbar_y+scrubbar_height/2, math.floor(scrubbar_height/2), math.max(3*math.floor(scrubbar_height/2), 3)
	)
end

function generate_waveform()
	local wave = {}
	local size = next_possible_size(1024)
	local delay_seconds = delay_average --estimated optimial delay for music-visual sync
	local sample = sample_rate*delay_seconds

	--to estimate delay for spectrum
	if estimate_delay then
		delay_initial_time = love.timer.getTime()
		estimate_delay = false
	end

	--[[ generates wave input for fft from audio
	Optimized to take any number of channels (ex: Mono, Stereo, 5.1, 7.1) and grab
	average samples (makes visualization smoother). Not supported by Love yet ]]
	local sampling_size = bit_depth/4 --number of samples to average
	local range = queue_size*decoder_buffer/(bit_depth/8)-1
	local scaled_sampling_size = sampling_size*channels
	for i=sample, sample+size-1 do
		local new_sample = 0
		for j=1, scaled_sampling_size do
			--m = i*channels+j-1-scaled_sampling_size/2
			local x = math.min(i*channels+j-1-scaled_sampling_size/2, range)
			new_sample = new_sample+get_decoder_sample(math.max(x, 0)) --scales sample size index, centers it, obtains samples, and sums them
		end
		new_sample = new_sample/scaled_sampling_size --averages sample
		table.insert(wave, complex.new(new_sample, 0))
	end
	old_sample = decoder_tell('samples')

	--wave->spectrum takes most CPU usage
	local spectrum = fft(wave, false)

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
		time_count = ((x-scrubbar_x)/scrubbar_width)*decoder:getDuration()
		decoder:seek(time_count)
		scrub_head_pressed = true
	end
end

function love.mousereleased(x, y, button, istouch)
	if scrub_head_pause then
		current_song:play()
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
			time_count = ((x-scrubbar_x)/scrubbar_width)*decoder:getDuration()
			decoder:seek(time_count)
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
			if is_paused then
				current_song:play()
			else
				current_song:pause()
			end
			is_paused = not is_paused
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

	if intro_video == nil or not intro_video:isPlaying() then
		if not music_exists and appdata_music then
			music_list = recursive_enumerate("music")

			music_exists = true
			if next(music_list) == nil then
				music_exists = false
				appdata_music = false
			end
			love.graphics.setFont(normal_font)
		else
			local function catch_nil()
			end
			(key_functions[key] or catch_nil)()
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
	normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
end

function love.directorydropped(path)
	love.filesystem.mount(path, "music")
	music_list = recursive_enumerate("music")

	music_exists = true
	if next(music_list) == nil then
		music_exists = false
	end
	love.graphics.setFont(normal_font)
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
		if lfs.getInfo(file)["type"] == "file" and valid_format then
			complete_music_table[index] = {}
			complete_music_table[index][1] = lfs.newFile(file)
			complete_music_table[index][2] = v:sub(1, -5)
			index = index+1
			valid_format = false
		elseif lfs.getInfo(file)["type"] == "directory" then
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

function get_decoder_sample(buffer)
	local sample_range = decoder_buffer/(bit_depth/8)

	if buffer < 0 or buffer >= sample_range*queue_size then
		love.errhand("buffer out of bounds "..buffer)
	end

	local sample = buffer/sample_range
	local index = math.floor(sample)

	if decoder_tell('samples')+buffer < decoder:getDuration()*sample_rate then
		return decoder_array[index]:getSample((sample-index)*sample_range)
	else
		return 0
	end
end

function decoder_tell(unit)
	if unit == 'samples' then
		return time_count*sample_rate
	else
		return time_count
	end
end




-- Song Handling --
function next_song()
	song_id = song_id+1
	-- loops songs
	if song_id > #music_list then
		song_id = 1
	end

	decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
	sample_rate = decoder:getSampleRate()
	bit_depth = decoder:getBitDepth()
	channels = decoder:getChannelCount()
	seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

	current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
	local check = current_song:getFreeBufferCount()
	time_count = check*seconds_per_buffer
	while check ~= 0 do
		local tmp = decoder:decode()
		if tmp ~= nil then
			current_song:queue(tmp)
			decoder_array[queue_size-check] = tmp
			check = check-1
		end
	end

	current_song:play()
end

function prev_song()
	song_id = song_id-1
	-- loops songs
	if song_id < 1 then
		song_id = #music_list
	end

	decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
	sample_rate = decoder:getSampleRate()
	bit_depth = decoder:getBitDepth()
	channels = decoder:getChannelCount()
	seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

	current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
	local check = current_song:getFreeBufferCount()
	time_count = check*seconds_per_buffer
	while check ~= 0 do
		local tmp = decoder:decode()
		if tmp ~= nil then
			current_song:queue(tmp)
			decoder_array[queue_size-check] = tmp
			check = check-1
		end
	end

	current_song:play()
end
