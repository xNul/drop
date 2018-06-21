main = {}

local TSerial = require 'TSerial'

local MONITOR_REFRESH_RATE = 60
local KEY_FUNCTIONS = {}

local appdata_path = love.filesystem.getAppdataDirectory()
local operating_system = love.system.getOS()
local waveform = {}
local sleep_counter = 0
local last_frame_time = 0
local button_pressed = nil
local appdata_music_possible = true
local microphone_option_pressed = false
local devices_list = nil
local devices_string = ""
local device_option = 0
local dragndrop = false

function main.reload()

  waveform = {}
  sleep_counter = 0
  button_pressed = nil
  appdata_music_possible = true
  microphone_option_pressed = false
  devices_list = nil
  devices_string = ""
  device_option = 0 -- not attached to config.init_sysaudio_option bc init location should only work on init, not after
  dragndrop = false
  
end

function love.load()

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
    fade_intensity_multiplier = 30, -- degree of fading
    session_persistence = false, -- options restored from previous session
    color = {0, 1, 0}, -- color of visualization/music controls.  Format: {r, g, b} [0-1]
    fps_cap = 0, -- places cap on fps (looks worse, but less cpu intensive).  0 for vsync
    sleep_time = 7, -- seconds until overlay is put to sleep
    visualization_update = true, -- update visualization when dragging scrubhead (false=less cpu intensive)
    sampling_size = 2048, -- number of audio samples to generate spectrum from (maintain a power of 2)
    window_size_persistence = true, -- window size restored from previous session
    window_size = {1280, 720}, -- size of window on start (window size persistent)
    window_location_persistence = false, -- window position restored from previous session
    window_location = {420, 340, 1}, -- location of window when persistent (window location persistent)
    init_location = "menu", -- where to go on start.  Options: "menu", "dragndrop", "sysaudio", or "appdata"
    init_sysaudio_option = 0 -- which system audio input to automatically select. Options: 0=show options, 1-infinity=audio input
  }
  local CHECK_VALUES = {
    version = function (v)
      return type(v) == "number" and v >= 0
    end,
    visualization = function (v)
      return type(v) == "number" and v >= 1 and v <= 4 and v == math.floor(v)
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
      return type(v) == "number" and v == math.floor(v) and v%2 == 0
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
      return type(v) == "string" and (v == "menu" or v == "sysaudio" or v == "appdata"  or v == "dragndrop")
    end,
    init_sysaudio_option = function (v)
      return type(v) == "number" and v >= 0 and v == math.floor(v) and v <= #(love.audio.getRecordingDevices())
    end
  }
  
  config = TSerial.unpack(love.filesystem.read("config.lua"), true)
  if not config or CURRENT_VERSION < config.version then -- if config.lua doesnt exist, or if config.lua has invalid settings, or if config version is higher than current then replace it
    config = DEFAULT_CONFIG
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
  elseif CURRENT_VERSION > config.version then
    local dconfig = DEFAULT_CONFIG
    
    for key, value in pairs(config) do
      if dconfig[key] ~= nil and CHECK_VALUES[key](value) then -- and check values
        dconfig[key] = value
      end
    end
    
    dconfig.version = CURRENT_VERSION
    config = dconfig
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
  else
    local invalid = false
    
    for key, value in pairs(config) do
      if not CHECK_VALUES[key](value) then
        config[key] = DEFAULT_CONFIG[key]
        invalid = true
      end
    end
    
    if invalid then love.filesystem.write("config.lua", TSerial.pack(config, false, true)) end
  end
  
  --------------------------------- Keyboard Actions ---------------------------------
  KEY_FUNCTIONS = {
    ["up"] = function ()
      -- round to nearest 1st decimal place
      local new_volume = math.floor((love.audio.getVolume()+.1) * 10 + 0.5) / 10
      gui.buttons.volume.activate(new_volume)
    end,
    ["down"] = function ()
      -- round to nearest 1st decimal place
      local new_volume = math.floor((love.audio.getVolume()-.1) * 10 + 0.5) / 10
      gui.buttons.volume.activate(new_volume)
    end,
    ["right"] = function ()
      gui.buttons.right.activate()
    end,
    ["left"] = function ()
      gui.buttons.left.activate()
    end,

    -- rgb keys are being used as a test atm.  Not finished
    ["r"] = function ()
      gui.graphics.setColor("r")
    end,
    ["g"] = function ()
      gui.graphics.setColor("g")
    end,
    ["b"] = function ()
      gui.graphics.setColor("b")
    end,
    ["s"] = function ()
      gui.buttons.shuffle.activate()
    end,
    ["l"] = function ()
      gui.buttons.loop.activate()
    end,
    ["i"] = function ()
      spectrum.setFade(not spectrum.isFading())
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
        gui.buttons.fullscreen.activate()
      end
    end,
    ["f"] = function ()
      gui.buttons.fullscreen.activate()
    end,
    ["space"] = function ()
      gui.buttons.playback.activate()
    end,

    -- moves slowly through the visualization by the length of a frame.  Used to compare visualizations
    [","] = function ()
      audio.music.seekSong(audio.music.tellSong()-spectrum.getSize()/(audio.getSampleRate()*audio.getChannels()))
    end,
    ["."] = function ()
      audio.music.seekSong(audio.music.tellSong()+spectrum.getSize()/(audio.getSampleRate()*audio.getChannels()))
    end
  }
  ------------------------------------------------------------------------------------

  
  ----------------------------------- Main -------------------------------------------
  audio = require 'audio'
  spectrum = require 'spectrum'
  gui = require 'gui'
  
  device_option = config.init_sysaudio_option
  love.keyboard.setKeyRepeat(true)
  
  -- load/scale gui
  gui.load()
  
  MONITOR_REFRESH_RATE = ({love.window.getMode()})[3].refreshrate
  
  if config.init_location == "sysaudio" then
    microphone_option_pressed = true
    devices_list = love.audio.getRecordingDevices()
    
    if device_option > 0 and device_option <= #devices_list then
      audio.microphone.load(devices_list[device_option])
      microphone_option_pressed = false
    else
      devices_string = "Choose audio input:\n"
      for i,v in ipairs(devices_list) do
        devices_string = devices_string..tostring(i)..") "..v:getName().."\n"
      end
    end
  elseif config.init_location == "appdata" then
    appdata_music_possible = audio.music.load()
  elseif config.init_location == "dragndrop" then
    dragndrop = true
  end
  ------------------------------------------------------------------------------------
end

function love.update(dt)

  if audio.music.exists() or audio.microphone.isActive() then
    if audio.microphone.isActive() then audio.microphone.update() else audio.music.update() end

    if spectrum.wouldChange() and not love.window.isMinimized() then
    
      -- fft calculations (generates waveform for visualization)
      if audio.microphone.isActive() then
        if audio.microphone.isReady() then
          waveform = spectrum.generateMicrophoneWaveform()
        end
      else
        waveform = spectrum.generateWaveform()
      end
    end

    --overlay timer: puts overlay to sleep after sleep_time sec of inactivity
    if not gui.extra.sleep() then
      sleep_counter = sleep_counter+dt
      
      if sleep_counter > config.sleep_time then
        gui.extra.sleep(true)
        sleep_counter = 0
      end
    end
  end
  
end

function love.draw()

  -- overlay/start_screen drawing
  if gui.buttons.menu.isActive() then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(gui.graphics.getBigFont())

    local graphics_width = gui.graphics.getWidth()
    local graphics_height = gui.graphics.getHeight()

    if microphone_option_pressed then
      love.graphics.printf(devices_string, graphics_width/80, graphics_height/2-2.5*love.graphics.getFont():getHeight(), graphics_width, "left")
    else
      if dragndrop then
        love.graphics.printf("Drag and drop music files/folders here", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "center")
      elseif appdata_music_possible then
        love.graphics.printf("Drop music files/folders here or press the corresponding number:\n1) Play system audio\n2) Play music in appdata", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      else
        love.graphics.printf("Failed to play music from your appdata.  Copy songs to \""..appdata_path.."/LOVE/Drop/music\" to make this work or just drag and drop music onto this window.", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      end
    end
  elseif not love.window.isMinimized() then
    spectrum.draw(waveform)
  end
  
  if not gui.extra.sleep() then
    gui.overlay()
  end
  
  if config.fps_cap > 0 then
    local slack = 1/config.fps_cap - (love.timer.getTime()-last_frame_time)
    if slack > 0 then love.timer.sleep(slack) end
    last_frame_time = love.timer.getTime()
  
  --[[ manual love.window.isVisible for behind windows and minimized.  Only works on Mac.
  Saves a lot of cpu.  Likely error-prone because it's a bad implementation (no other way) ]]
  elseif operating_system == "OS X" and love.timer.getFPS() > MONITOR_REFRESH_RATE+6 then
    local slack = 1/(MONITOR_REFRESH_RATE+10) - (love.timer.getTime()-last_frame_time)
    if slack > 0 then love.timer.sleep(slack) end
    last_frame_time = love.timer.getTime()
  end
  
end





-- Input Callbacks --
function love.mousepressed(x, y, key, istouch)
  gui.extra.sleep(false)
  sleep_counter = 0
  
  if key == 1 then
    button_pressed = gui.buttons.getButton(x, y)
    
    -- detects if scrub bar clicked and moves to the corresponding point in time
    if audio.music.exists() and gui.buttons.scrubbar.inBoundsX(x) and gui.buttons.scrubbar.inBoundsY(y) then
      gui.buttons.scrubbar.activate(x)
    end
  end
end

function love.mousereleased(x, y, key, istouch)
  if key == 1 and button_pressed ~= nil and button_pressed.inBoundsX(x) and button_pressed.inBoundsY(y) then
    button_pressed:activate()
  end
  button_pressed = nil

  if gui.buttons.scrubbar.isActive() then gui.buttons.scrubbar.deactivate(x) end
end

function love.mousemoved(x, y, dx, dy, istouch)
  gui.extra.sleep(false)
  sleep_counter = 0
  
  gui.buttons.setCursor(x, y)

  -- makes scrub bar draggable
  if gui.buttons.scrubbar.isActive() and gui.buttons.scrubbar.inBoundsX(x) then
    gui.buttons.scrubbar.activate(x)
  end
end

function love.mousefocus(focus)
  if gui.buttons.scrubbar.isActive() then
    gui.buttons.scrubbar.deactivate(gui.buttons.scrubbar.getScrubheadPosition())
  end
end

function love.keypressed(key, scancode, isrepeat)
  gui.extra.sleep(false)
  sleep_counter = 0

  local key_int = tonumber(key)
  if gui.buttons.menu.isActive() and key_int ~= nil and not dragndrop then
    if microphone_option_pressed then
      if key_int > 0 and key_int <= #devices_list then
        audio.microphone.load(devices_list[key_int])
        microphone_option_pressed = false
      end
    else
      if key_int == 1 then
        microphone_option_pressed = true
        devices_list = love.audio.getRecordingDevices()
        
        if device_option > 0 and device_option <= #devices_list then
          audio.microphone.load(devices_list[device_option])
          microphone_option_pressed = false
        else
          devices_string = "Choose audio input:\n"
          for i,v in ipairs(devices_list) do
            devices_string = devices_string..tostring(i)..") "..v:getName().."\n"
          end
        end
      elseif key_int == 2 then
        appdata_music_possible = audio.music.load()
      end
    end
  else
    local function catch_nil() end
    (KEY_FUNCTIONS[key] or catch_nil)()
  end
end

-- when window resizes, scale
function love.resize(w, h)
  gui.scale()
end

function love.directorydropped(path)
  love.filesystem.mount(path, "music")
  audio.music.load()
end

function love.filedropped(file)
  audio.music.addSong(file)
end

-- when exiting drop, save config (for persistence)
function love.quit()
  local write_config = false
  
  if config.window_size_persistence then
    local new_window_size
    if love.window.getFullscreen() then
      new_window_size = {gui.graphics.getWindowedDimensions()}
    else
      new_window_size = {love.graphics.getDimensions()}
    end
    if config.window_size[1] ~= new_window_size[1] or config.window_size[2] ~= new_window_size[2] then
      config.window_size = new_window_size
      write_config = true
    end
  end
  
  if config.window_location_persistence then
    local new_window_location
    if love.window.getFullscreen() then
      new_window_location = {gui.graphics.getWindowedPosition()}
    else
      new_window_location = {love.window.getPosition()}
    end
    if config.window_location[1] ~= new_window_location[1] or config.window_location[2] ~= new_window_location[2] or config.window_location[3] ~= new_window_location[3] then
      config.window_location = new_window_location
      write_config = true
    end
  end
  
  if config.session_persistence then
    local visualization = spectrum.getVisualization()
    local shuffle = audio.isShuffling()
    local loop = audio.isLooping()
    local mute = audio.isMuted()
    local volume = math.floor((mute and audio.getPreviousVolume() or not audio.music.exists() and audio.music.getVolume() or love.audio.getVolume()) * 10 + 0.5) / 10
    local fullscreen = love.window.getFullscreen()
    local fade = spectrum.isFading()
    
    if config.visualization ~= visualization or config.shuffle ~= shuffle or config.loop ~= loop or config.volume ~= volume or config.mute ~= mute or config.fullscreen ~= fullscreen or config.fade ~= fade then
      config.visualization = visualization
      config.shuffle = shuffle
      config.loop = loop
      config.volume = volume
      config.mute = mute
      config.fullscreen = fullscreen
      config.fade = fade
      
      write_config = true
    end
  end
  
  if write_config then
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
  end
  
  return false
end