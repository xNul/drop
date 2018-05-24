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
    ["up"] = function ()
      local new_volume = math.floor((love.audio.getVolume()+.1) * 10 + 0.5) / 10 -- round to nearest 1st decimal place
      
      if new_volume <= 1 then
        if new_volume == 0.6 then
          gui.volume:activate("volume3")
        elseif new_volume == 0.1 then
          gui.volume:activate("volume2")
          previous_volume = 0
        end
        
        love.audio.setVolume(new_volume)
      end
    end,
    ["down"] = function ()
      local new_volume = math.floor((love.audio.getVolume()-.1) * 10 + 0.5) / 10 -- round to nearest 1st decimal place
      
      if new_volume ~= -0.1 then
        if new_volume == 0.5 then
          gui.volume:activate("volume2")
        elseif new_volume == 0 then
          gui.volume:activate("volume1")
        end
        
        love.audio.setVolume(new_volume)
      end
    end,
		["right"] = function ()
			gui.right:activate()
		end,
		["left"] = function ()
			gui.left:activate()
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
    ["s"] = function ()
			gui.shuffle:activate()
		end,
    ["l"] = function ()
			gui.loop:activate()
		end,
    ["i"] = function ()
      fade_activated = not fade_activated
      setColor(nil, 1)
    end,
    ["m"] = function ()
      local current_volume = love.audio.getVolume()
      
      if current_volume == 0 and previous_volume ~= 0 then
        if previous_volume > 0 and previous_volume < 0.6 then
          gui.volume:activate("volume2")
        else
          gui.volume:activate("volume3")
        end
      
        love.audio.setVolume(previous_volume)
        previous_volume = 0
      else
        gui.volume:activate("volume1")
        love.audio.setVolume(0)
        previous_volume = current_volume
      end
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
      if love.window.getFullscreen() then
        gui.fullscreen:activate()
      end
		end,
		["f"] = function ()
			gui.fullscreen:activate()
		end,
		["space"] = function ()
			gui.playback:activate()
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

  button_pressed = ""
  
	fade_interval_counter = 1
	fade_bool = false
  fade_activated = false
	color = "g"
	fade_intensity = 1
	setColor("g", 1)
	sleep_counter = 0
	window_visible = true
  last_frame_time = 0
  cursor_hand_activated = false
  previous_volume = 0
  microphone_init = false
  devices_list = nil
	------------------------------------------------------------------------------------
end

function reload()
  waveform = {}
	scrub_head_pause = false
	scrub_head_pressed = false

	appdata_music = true
  
	fade_interval_counter = 1
	fade_bool = false
  fade_activated = false
	color = "g"
	fade_intensity = 1
	setColor("g", 1)
	sleep_counter = 0
	window_visible = true
  last_frame_time = 0
  cursor_hand_activated = false
  previous_volume = 0
  microphone_init = false
  devices_list = nil
end

function love.update(dt)
	if audio.musicExists() or audio.isPlayingMicrophone() then
		if audio.isPlayingMicrophone() then audio.updateMicrophone() else audio.update() end

		if spectrum.wouldChange() and window_visible and not love.window.isMinimized() then
			-- fft calculations (generates waveform for visualization)
			if audio.isPlayingMicrophone() then
        waveform = spectrum.generateMicrophoneWaveform()
      else
        waveform = spectrum.generateWaveform()
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
	if fade_activated then
		setColor(nil, spectrum.getAverageTickAmplitude()*120)
	end

	-- overlay/start_screen drawing
	if not audio.musicExists() and not audio.isPlayingMicrophone() then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(gui.graphics:getBigFont())

		local graphics_width = gui.graphics:getWidth()
		local graphics_height = gui.graphics:getHeight()

    if not microphone_init then
      if appdata_music then
        love.graphics.printf("Drop music here or press the corresponding number:\n1) Play system audio\n2) Play music in appdata", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      else
        love.graphics.printf("You just tried to play music from your appdata.  Copy songs to \""..appdata_path.."/LOVE/Drop/music\" to make this work or just drag and drop music onto this window.", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      end
    else
      local input_string = "Choose audio input:\n"
      for i,v in ipairs(devices_list) do
        input_string = input_string..tostring(i)..") "..v:getName().."\n"
      end
      love.graphics.printf(input_string, graphics_width/80, graphics_height/2-2.5*love.graphics.getFont():getHeight(), graphics_width, "left")
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
function love.mousepressed(x, y, key, istouch)
	gui.sleep(false)
	sleep_counter = 0
  
  local button_table = {"left", "playback", "right", "shuffle", "loop", "volume", "fullscreen", "menu"}
  
  local button
  for i,v in ipairs(button_table) do
    button = gui[v]
    
    if button:inBoundsX(x) and button:inBoundsY(y) then
      button_pressed = v
      break
    end
  end
  
	-- detects if scrub bar clicked and moves to the corresponding point in time
	if key == 1 and audio.musicExists() and gui.scrubbar:inBoundsX(x) and gui.scrubbar:inBoundsY(y) then
    if audio.isPlaying() then
			scrub_head_pause = true
			audio.pause()
		end
  
		audio.decoderSeek(gui.scrubbar:getProportion(x)*audio.getDuration())
		scrub_head_pressed = true
	end
end

function love.mousereleased(x, y, key, istouch)
  if button_pressed ~= "" and gui[button_pressed]:inBoundsX(x) and gui[button_pressed]:inBoundsY(y) then
    gui[button_pressed]:activate()
  end
  button_pressed = ""

	if scrub_head_pause then
		audio.play()
		scrub_head_pause = false
	end
	scrub_head_pressed = false
end

function love.mousemoved(x, y, dx, dy, istouch)
	gui.sleep(false)
	sleep_counter = 0
  
  if (gui.left:inBoundsY(y) and ((gui.scrubbar:inBoundsY(y) and gui.scrubbar:inBoundsX(x)) or gui.leftPanel:inBoundsX(x) or gui.rightPanel:inBoundsX(x))) or (gui.menu:inBoundsX(x) and gui.menu:inBoundsY(y)) then
    if not cursor_hand_activated then love.mouse.setCursor(love.mouse.getSystemCursor("hand")) end
    cursor_hand_activated = true
  elseif cursor_hand_activated then
    love.mouse.setCursor(love.mouse.getSystemCursor("arrow"))
    cursor_hand_activated = false
  end

	-- makes scrub bar draggable
	if scrub_head_pressed and gui.scrubbar:inBoundsX(x) then
		audio.decoderSeek(gui.scrubbar:getProportion(x)*audio.getDuration())
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

  if not audio.musicExists() and not audio.isPlayingMicrophone() then
    if microphone_init then
      local key_int = tonumber(key)
      if key_int ~= nil and key_int > 0 and key_int <= #devices_list then
        audio.playMicrophone(devices_list[key_int])
        audio.setSongName("Audio Input: "..devices_list[key_int]:getName())
        microphone_init = false
      end
    elseif key == "1" then
      microphone_init = true
      devices_list = love.audio.getRecordingDevices()
    elseif key == "2" then
      appdata_music = audio.loadMusic()
    end
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
