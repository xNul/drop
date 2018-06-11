local appdata_path = love.filesystem.getAppdataDirectory()
local operating_system = love.system.getOS()

local waveform
local scrub_head_pause
local scrub_head_pressed

local appdata_music

local button_pressed

local fade_interval_counter
local fade_activated
local color
local fade_intensity
local fade_intensity_multiplier
local sleep_counter
local sleep_time
local window_visible
local last_frame_time
local cursor_hand_activated
local microphone_init
local devices_list
local visualization_update

function love.load()  
  Tserial = require 'Tserial'

  -- Mac only and if not 60hz
  MONITOR_REFRESH_RATE = 60

  local CURRENT_VERSION = 1
  local DEFAULT_CONFIG = {
    version = CURRENT_VERSION, -- every time config format changes 1 is added
    visualization = 3, -- visualization to show on start (session persistent)
    shuffle = false, -- enable/disable shuffle on start (session persistent)
    loop = false, -- enable/disable loop on start (session persistent)
    volume = 0.5, -- volume on start (session persistent)
    mute = false, -- enable/disable mute on start (session persistent)
    fullscreen = false, -- enable/disable fullscreen on start (session persistent)
    fade = false, -- enable/disable fade on start (session persistent)
    fade_intensity_multiplier = 60, -- degree of fading
    session_persistence = false, -- [NOT DONE] options restored from previous session
    color = {0, 1, 0}, -- color of visualization/music controls.  Format: {r, g, b} [0-1]
    fps_cap = 0, -- [NOT DONE] places cap on fps.  0 for no limit
    sleep_time = 7, -- seconds until overlay is put to sleep
    visualization_update = true, -- [NOT DONE] update visualization when dragging scrubhead
    sampling_size = 2048, -- number of audio samples to generate spectrum from (maintain a power of 2)
    window_size_persistence = true, -- window size restored from previous session
    window_size = {1280, 720}, -- size of window on start (window_size_persistence)
    window_location_persistence = false, -- window position restored from previous session
    window_location = {420, 340, 1}, -- location of window on persistence (window_location_persistence)
    init_location = "menu", -- [NOT DONE] where to go on start.  Options: "menu", "sysaudio", or "appdata"
    init_sysaudio_option = 0 -- [NOT DONE] which system audio input to automatically select. Options: 0=show options, 1-infinity=audio input
  }
  local CHECK_VALUES = {
    version = function (v)
      return type(v) == "number" and v >= 0
    end,
    visualization = function (v)
      return type(v) == "number" and v > 0 and v < 5
    end,
    shuffle = function (v)
      return type(v) == "boolean"
    end,
    loop = function (v)
      return type(v) == "boolean"
    end,
    mute = function (v)
      return type(v) == "boolean"
    end,
    fullscreen = function (v)
      return type(v) == "boolean"
    end,
    fade = function (v)
      return type(v) == "boolean"
    end,
    fade_intensity_multiplier = function (v)
      return type(v) == "number" and v >= 0
    end,
    volume = function (v)
      return type(v) == "number" and v >= 0 and v <= 1
    end,
    session_persistence = function (v)
      return type(v) == "boolean"
    end,
    color = function (v)
      return type(v) == "table" and #v == 3 and type(v[1]) == "number" and v[1] >=0 and v[1] <=1 and type(v[2]) == "number" and v[2] >=0 and v[2] <=1 and type(v[3]) == "number" and v[3] >=0 and v[3] <=1
    end,
    fps_cap = function (v)
      return type(v) == "number" and v >= 0
    end,
    sleep_time = function (v)
      return type(v) == "number" and v >= 0
    end,
    visualization_update = function (v)
      return type(v) == "boolean"
    end,
    sampling_size = function (v)
      return type(v) == "number" and v%2 == 0
    end,
    window_size_persistence = function (v)
      return type(v) == "boolean"
    end,
    window_size = function (v)
      return type(v) == "table" and #v == 2 and type(v[1]) == "number" and type(v[2]) == "number"
    end,
    window_location_persistence = function (v)
      return type(v) == "boolean"
    end,
    window_location = function (v)
      return type(v) == "table" and #v == 3 and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
    end,
    init_location = function (v)
      return type(v) == "string" and (v == "menu" or v == "sysaudio" or v == "appdata")
    end,
    init_sysaudio_option = function (v)
      return type(v) == "number" and v >= 0 and v == math.floor(v)
    end
  }
  
  config = Tserial.unpack(love.filesystem.read("config.lua"), true)
  if not config or CURRENT_VERSION < config.version then -- if config.lua doesnt exist, or if config.lua has invalid settings, or if config version is higher than current then replace it
    config = DEFAULT_CONFIG
    love.filesystem.write("config.lua", Tserial.pack(config, false, true))
  end
  
  if CURRENT_VERSION > config.version then
    local dconfig = DEFAULT_CONFIG
    
    for key, value in pairs(config) do
      if dconfig[key] ~= nil and CHECK_VALUES[key](value) then -- and check values
        dconfig[key] = value
      end
    end
    
    dconfig.version = CURRENT_VERSION
    config = dconfig
    love.filesystem.write("config.lua", Tserial.pack(config, false, true))
  else
    if config ~= DEFAULT_CONFIG then
      local invalid = false
      
      for key, value in pairs(config) do
        if not CHECK_VALUES[key](value) then
          config[key] = DEFAULT_CONFIG[key]
          invalid = true
        end
      end
      
      if invalid then love.filesystem.write("config.lua", Tserial.pack(config, false, true)) end
    end
  end
  
  audio = require 'audio'
  spectrum = require 'spectrum'
  gui = require 'gui'
  
  -- load/scale gui
  gui.load()
  
  --------------------------------- Keyboard Actions ---------------------------------
  key_functions = {
    ["up"] = function ()
      -- round to nearest 1st decimal place
      local new_volume = math.floor((love.audio.getVolume()+.1) * 10 + 0.5) / 10
      gui.volume:activate(new_volume)
      love.audio.setVolume(new_volume)
    end,
    ["down"] = function ()
      -- round to nearest 1st decimal place
      local new_volume = math.floor((love.audio.getVolume()-.1) * 10 + 0.5) / 10
      gui.volume:activate(new_volume)
      love.audio.setVolume(new_volume)
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
      setColor(nil, 0)
    end,
    ["m"] = function ()
      audio.mute()
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
  love.graphics.setLineWidth(1)
  love.graphics.setLineStyle('smooth')
  
  reload()
  ------------------------------------------------------------------------------------
end

function reload()
  waveform = {}
  scrub_head_pause = false
  scrub_head_pressed = false

  appdata_music = true
  
  button_pressed = ""
  
  fade_interval_counter = 1
  fade_activated = config.fade
  color = config.color
  fade_intensity = 0
  fade_intensity_multiplier = config.fade_intensity_multiplier
  sleep_counter = 0
  sleep_time = config.sleep_time
  window_visible = true
  last_frame_time = 0
  cursor_hand_activated = false
  microphone_init = false
  devices_list = nil
  visualization_update = config.visualization_update
  
  setColor(config.color)
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

    --overlay timer: puts overlay to sleep after sleep_time sec of inactivity
    if not gui.sleep() then
      sleep_counter = sleep_counter+dt
      if sleep_counter > sleep_time then
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
    setColor(nil, spectrum.getAverageTickAmplitude()*fade_intensity_multiplier)
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
  if operating_system == "OS X" and love.timer.getFPS() > MONITOR_REFRESH_RATE+6 then
    -- manual fps limiter (fixes background fps/CPU leak) it's 70 instead of 60 so we can detect when behind windows
    if window_visible then last_frame_time = love.timer.getTime() end
    local slack = 1/(MONITOR_REFRESH_RATE+10) - (love.timer.getTime()-last_frame_time)
    if slack > 0 then love.timer.sleep(slack) end
    last_frame_time = love.timer.getTime()

    window_visible = false
  else
    window_visible = true
  end
end

function setColor(c, f)
  if f then
    fade_intensity = 1-math.min(math.max(f, 0), 1)
  end
  if type(c) == "table" then
    color = c
  elseif c == "r" then
    color = {1, 0, 0}
  elseif c == "g" then
    color = {0, 1, 0}
  elseif c == "b" then
    color = {0, 0, 1}
  end
  
  local faded_color = {}
  faded_color[1] = math.max(0, color[1]-fade_intensity)
  faded_color[2] = math.max(0, color[2]-fade_intensity)
  faded_color[3] = math.max(0, color[3]-fade_intensity)
  
  love.graphics.setColor(faded_color)
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
        audio.loadMicrophone(devices_list[key_int])
        audio.setSongName("Audio Input: "..devices_list[key_int]:getName())
        microphone_init = false
      end
    elseif key == "1" then
      microphone_init = true
      devices_list = love.audio.getRecordingDevices()
    elseif key == "2" then
      appdata_music = audio.loadMusic()
    else
      local function catch_nil() end
      (key_functions[key] or catch_nil)()
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

-- when exiting drop, save config (for persistence)
function love.quit()
  local write_config = false
  if config.window_size_persistence then
    local new_window_size = {love.graphics.getDimensions()}
    if config.window_size[1] ~= new_window_size[1] or config.window_size[2] ~= new_window_size[2] then
      config.window_size = new_window_size
      write_config = true
    end
  end
  
  if config.window_location_persistence then
    local new_window_location = {love.window.getPosition()}
    if config.window_location[1] ~= new_window_location[1] or config.window_location[2] ~= new_window_location[2] or config.window_location[3] ~= new_window_location[3] then
      config.window_location = new_window_location
      write_config = true
    end
  end
  
  if write_config then
    love.filesystem.write("config.lua", Tserial.pack(config, false, true))
  end
  
  return false
end