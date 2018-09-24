--  MIT License
--
--  Copyright (c) 2018 nabakin
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to deal
--  in the Software without restriction, including without limitation the rights
--  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--  copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in all
--  copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--  SOFTWARE.

--[[ Initialize Variables ]]
main = {}

local TSerial = require 'TSerial'

local MONITOR_REFRESH_RATE = 60
local KEY_FUNCTIONS = {}

local appdata_path = love.filesystem.getAppdataDirectory()
local operating_system = love.system.getOS()
local sleep_counter = 0
local sleep_time = 0
local fps_cap = 0
local last_frame_time = 0
local button_pressed = nil
local appdata_music_success = true
local rd_option_pressed = false
local rd_list = nil
local rd_string = ""
local rd_option = 0
local dragndrop = false

--- Reloads variables that affect the menu.
-- Necessary for returning to the main menu.
function main.reload()

  sleep_counter = 0
  button_pressed = nil
  appdata_music_success = true
  rd_option_pressed = false
  rd_list = nil
  rd_string = ""
  dragndrop = false
  
  rd_option = 0
  
end

--[[ Core Function Callbacks ]]
--- Initializes core elements of Drop.
-- Callback for main Love2D thread.
function love.load()

  --[[ Configuration ]]
  -- Config initialization
  local CURRENT_VERSION = 3
  local DEFAULT_CONFIG = {
    version = CURRENT_VERSION, -- Every time config format changes, 1 is added.
    visualization = "bar", -- Visualization to show on start. (session persistent)
    shuffle = false, -- Enable/disable shuffle on start. (session persistent)
    loop = false, -- Enable/disable loop on start. (session persistent)
    volume = 0.5, -- Volume on start. (session persistent)
    mute = false, -- Enable/disable mute on start. (session persistent)
    fullscreen = false, -- Enable/disable fullscreen on start. (session persistent)
    session_persistence = false, -- Options restored from previous session.
    color = {0, 1, 0}, -- Color of visualization/music controls.  Format: {r, g, b} [0-1]
    fps_cap = 0, -- Places cap on fps (looks worse, but less cpu intensive).  0 for vsync.
    sleep_time = 7, -- Seconds until overlay is put to sleep.
    visualization_update = true, -- Update visualization when dragging scrubhead (false=less cpu intensive).
    window_size_persistence = false, -- Window size restored from previous session.
    window_size = {1280, 720}, -- Size of window on start. (window size persistent)
    window_location_persistence = false, -- Window position restored from previous session.
    window_location = {-1, -1, -1}, -- Location of window on start. (window location persistent)
    init_location = "menu", -- Where to go on start.  Options: "menu", "dragndrop", "sysaudio", or "appdata".
    init_sysaudio_option = 0, -- Which system audio input to automatically select. Options: 0=show options, 1-infinity=audio input.
    rd_sample_rate = 44100, -- [EXPERT] Audio input device's sample rate (in hz). Change only if having issues visualizing audio.
    rd_bit_depth = 16, -- [EXPERT] Audio input device's bit depth. Change only if having issues visualizing audio.
    rd_channels = 1 -- [EXPERT] Audio input device's number of channels. Change only if having issues visualizing audio.
  }
  local CHECK_VALUES = {
    version = function (v)
      return type(v) == "number" and v >= 0
    end,
    visualization = function (v)
      return type(v) == "string"
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
    end,
    rd_sample_rate = function (v)
      return type(v) == "number" and v > 0 and v == math.floor(v)
    end,
    rd_bit_depth = function (v)
      return type(v) == "number" and v > 0 and v == math.floor(v) and v%2 == 0
    end,
    rd_channels = function (v)
      return type(v) == "number" and v > 0 and v <= 2 and v == math.floor(v)
    end
  }
  
  -- config.lua -> config table
  config = TSerial.unpack(love.filesystem.read("config.lua"), true)
  
  -- Validating config table.
  if not config or CURRENT_VERSION < config.version then
    print(os.date('[%H:%M] ').."config.lua is either missing, corrupt, or from a newer version.  Recreating file...")
    
    -- Use default config.
    config = DEFAULT_CONFIG
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
    
    print(os.date('[%H:%M] ').."Done.")
  elseif CURRENT_VERSION > config.version then
    print(os.date('[%H:%M] ').."Old config.lua found.  Updating it to the latest version...")
    
    -- Transfer compatible configurations from old config to new config.
    local dconfig = DEFAULT_CONFIG
    for key, value in pairs(config) do
      if dconfig[key] ~= nil and CHECK_VALUES[key](value) then
        dconfig[key] = value
      end
    end
    
    -- Finalize config update.
    dconfig.version = CURRENT_VERSION
    config = dconfig
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
    
    print(os.date('[%H:%M] ').."Done.")
  else
    local invalid = false
    
    -- Validate configurations.  Resets configuration to default if invalid.
    for key, value in pairs(config) do
      if CHECK_VALUES[key] ~= nil and not CHECK_VALUES[key](value) then
        print(os.date('[%H:%M] ').."Error: Invalid "..key.." value detected in config.lua.  Resetting to default.")
      
        config[key] = DEFAULT_CONFIG[key]
        invalid = true
        
        print(os.date('[%H:%M] ').."Done.")
      end
    end
    
    -- Finalize config fix.
    if invalid then
      love.filesystem.write("config.lua", TSerial.pack(config, false, true))
    end
  end
  
  --------------------------------- Keyboard Actions ---------------------------------
  KEY_FUNCTIONS = {
    ["up"] = function ()
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        local new_volume_rounded = math.floor((love.audio.getVolume()+.1)*10+0.5)/10
        gui.buttons.volume.activate(new_volume_rounded)
      else
        visualization.next()
      end
    end,
    ["down"] = function ()
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        local new_volume_rounded = math.floor((love.audio.getVolume()-.1)*10+0.5)/10
        gui.buttons.volume.activate(new_volume_rounded)
      else
        visualization.previous()
      end
    end,
    ["right"] = function ()
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        audio.music.seekSong(audio.music.tellSong()+5)
      else
        gui.buttons.right.activate()
      end
    end,
    ["left"] = function ()
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        audio.music.seekSong(audio.music.tellSong()-5)
      else
        gui.buttons.left.activate()
      end
    end,
    ["s"] = function ()
      gui.buttons.shuffle.activate()
    end,
    ["l"] = function ()
      gui.buttons.loop.activate()
    end,
    ["m"] = function ()
      audio.toggleMute()
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

    -- Moves slowly through the visualization by the length of a frame.  Used to compare visualizations.
    [","] = function ()
      audio.music.seekSong(audio.music.tellSong()-visualization.getSamplingSize()/(audio.getSampleRate()*audio.getChannels()))
    end,
    ["."] = function ()
      audio.music.seekSong(audio.music.tellSong()+visualization.getSamplingSize()/(audio.getSampleRate()*audio.getChannels()))
    end
  }
  ------------------------------------------------------------------------------------

  
  ----------------------------------- Main -------------------------------------------
  audio = require 'audio'
  visualization = require 'visualization'
  gui = require 'gui'
  
  sleep_time = config.sleep_time
  fps_cap = config.fps_cap
  rd_option = config.init_sysaudio_option
  love.keyboard.setKeyRepeat(true)
  
  gui.load()
  
  -- If refresh rate can be determined, use it.
  local potential_refresh_rate = ({love.window.getMode()})[3].refreshrate
  if potential_refresh_rate ~= 0 then
    MONITOR_REFRESH_RATE = potential_refresh_rate
  end
  
  --[[ Init Location Jumping ]]
  if config.init_location == "sysaudio" then
    rd_option_pressed = true
    rd_list = love.audio.getRecordingDevices()
    
    -- Check for valid option.
    if rd_option > 0 and rd_option <= #rd_list then
      audio.recordingdevice.load(rd_list[rd_option])
      rd_option_pressed = false
    else
      -- Prepare audio input list.
      rd_string = "Choose audio input:\n"
      for i,v in ipairs(rd_list) do
        rd_string = rd_string..tostring(i)..") "..v:getName().."\n"
      end
    end
  elseif config.init_location == "appdata" then
    appdata_music_success = audio.music.load("music")
  elseif config.init_location == "dragndrop" then
    dragndrop = true
  end
  ------------------------------------------------------------------------------------
  
end

--- Contains all time-oriented operations. Physics, audio playback, etc.
-- Callback for main Love2D thread.
-- @param dt number: Delta time between current call and last.
function love.update(dt)

  if audio.music.exists() or audio.recordingdevice.isActive() then
    -- Update queueable audio and sampling table.
    if audio.recordingdevice.isActive() then
      audio.recordingdevice.update()
    else
      audio.music.update()
    end

    if visualization.wouldChange() and not love.window.isMinimized() then
      visualization.generateWaveform()
    end

    -- Sleep timer for overlay.
    if not gui.extra.sleep() then
      sleep_counter = sleep_counter+dt
      
      if sleep_counter > sleep_time then
        gui.extra.sleep(true)
        sleep_counter = 0
      end
    end
  end
  
  visualization.callback("update", dt)
  
end

--- Contains all graphics drawing operations.
-- Callback for main Love2D thread.
function love.draw()

  --[[ Menu/Visualization drawing ]]
  if gui.buttons.menu.isActive() then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(gui.graphics.getBigFont())

    local graphics_width = gui.graphics.getWidth()
    local graphics_height = gui.graphics.getHeight()

    if rd_option_pressed then
      love.graphics.printf(rd_string, graphics_width/80, graphics_height/2-2.5*love.graphics.getFont():getHeight(), graphics_width, "left")
    else
      if dragndrop then
        love.graphics.printf("Drag and drop music files/folders here", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "center")
      elseif appdata_music_success then
        love.graphics.printf("Drop music files/folders here or press the corresponding number:\n1) Play system audio\n2) Play music in appdata", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      else
        love.graphics.printf("Failed to play music from your appdata.  Copy songs to \""..appdata_path.."/LOVE/Drop/music\" to make this work or just drag and drop music onto this window.", graphics_width/80, graphics_height/2-5*love.graphics.getFont():getHeight()/2, graphics_width, "left")
      end
    end
  elseif not love.window.isMinimized() then
    visualization.callback("draw")
  end
  
  --[[ Overlay drawing ]]
  if not gui.extra.sleep() then
    gui.overlay()
  end
  
  -- FPS Limiter
  if fps_cap > 0 then
    local slack = 1/fps_cap - (love.timer.getTime()-last_frame_time)
    if slack > 0 then love.timer.sleep(slack) end
    last_frame_time = love.timer.getTime()
  
  --[[ Manual detection for when behind windows or minimized.  Only works on Mac.
  Saves a lot of cpu.  Likely error-prone because it's a bad implementation (no other way). ]]
  elseif operating_system == "OS X" and love.timer.getFPS() > MONITOR_REFRESH_RATE+6 then
    local slack = 1/(MONITOR_REFRESH_RATE+10) - (love.timer.getTime()-last_frame_time)
    if slack > 0 then love.timer.sleep(slack) end
    last_frame_time = love.timer.getTime()
  end
  
end





--[[ Input Function Callbacks ]]
--- Handles all mouse button press input.
-- Callback for main Love2D thread.
-- @param x number: x coordinate of mouse.
-- @param y number: y coordinate of mouse.
-- @param key number: Mouse button pressed.
-- @param istouch boolean: True when touchscreen press.  False otherwise.
-- @param presses number: Number of presses in a short time frame.
function love.mousepressed(x, y, key, istouch, presses)

  -- Reset sleep counter.
  gui.extra.sleep(false)
  sleep_counter = 0
  
  if key == 1 then
    button_pressed = gui.buttons.getButton(x, y)
    
    -- Detects if scrub bar clicked and moves to the corresponding point in time.
    if audio.music.exists() and gui.buttons.scrubbar.inBoundsX(x) and gui.buttons.scrubbar.inBoundsY(y) then
      gui.buttons.scrubbar.activate(x)
    end
  end
  
  visualization.callback("mousepressed", x, y, key, istouch, presses)
  
end

--- Handles all mouse button release input.
-- Callback for main Love2D thread.
-- @param x number: x coordinate of mouse.
-- @param y number: y coordinate of mouse.
-- @param key number: Mouse button released.
-- @param istouch boolean: True when touchscreen release.  False otherwise.
-- @param presses number: Number of releases in a short time frame.
function love.mousereleased(x, y, key, istouch, presses)

  -- Verifies releasing on the same button as pressed with some polymorphism.
  if key == 1 and button_pressed and button_pressed.inBoundsX(x) and button_pressed.inBoundsY(y) then
    button_pressed.activate()
  end
  button_pressed = nil

  -- If scrubbar is being dragged, stop.
  if gui.buttons.scrubbar.isActive() then
    gui.buttons.scrubbar.deactivate(x)
  end
  
  visualization.callback("mousereleased", x, y, key, istouch, presses)
  
end

--- Handles all mouse movement input.
-- Callback for main Love2D thread.
-- @param x number: x coordinate of mouse.
-- @param y number: y coordinate of mouse.
-- @param dx number: Distance along x since last call.
-- @param dy number: Distance along y since last call.
-- @param istouch boolean: True when touchscreen press.  False otherwise.
function love.mousemoved(x, y, dx, dy, istouch)

  -- Reset sleep counter.
  gui.extra.sleep(false)
  sleep_counter = 0
  
  gui.buttons.setCursorIcon(x, y)

  -- Update scrubhead/music position.  Makes scrubhead draggable.
  if gui.buttons.scrubbar.isActive() and gui.buttons.scrubbar.inBoundsX(x) then
    gui.buttons.scrubbar.activate(x)
  end
  
  visualization.callback("mousemoved", x, y, dx, dy, istouch)
  
end

--- Called when mouse loses/gains window focus.
-- Callback for main Love2D thread.
-- @param focus boolean: True when gains.  False otherwise.
function love.mousefocus(focus)

  -- If scrubbar is being dragged, stop.
  if gui.buttons.scrubbar.isActive() then
    gui.buttons.scrubbar.deactivate(gui.buttons.scrubbar.getScrubheadPosition())
  end
  
  visualization.callback("mousefocus", focus)
  
end

--- Handles all key press input.
-- Callback for main Love2D thread.
-- @param key string: Key pressed.
-- @param scancode number: Number representation of key.
-- @param isrepeat boolean: True if keypress event repeats.  False otherwise.
function love.keypressed(key, scancode, isrepeat)

  -- Reset sleep counter.
  gui.extra.sleep(false)
  sleep_counter = 0

  -- Menu controls.
  local key_int = tonumber(key)
  if gui.buttons.menu.isActive() and key_int and not dragndrop then
    -- Audio input options.
    if rd_option_pressed then
      if key_int > 0 and key_int <= #rd_list then
        visualization.load()
        audio.recordingdevice.load(rd_list[key_int])
        rd_option_pressed = false
      end
    
    -- Menu options.
    else
      -- Select system audio.
      if key_int == 1 then
        rd_list = love.audio.getRecordingDevices()
        
        -- If init_sysaudio_option configured in config, use.  Start RD instantly.
        if rd_option > 0 and rd_option <= #rd_list then
          visualization.load()
          audio.recordingdevice.load(rd_list[rd_option])
          rd_option_pressed = false
        
        -- Obtain user input.  Have user select from audio input options.
        else
          rd_option_pressed = true
          rd_string = "Choose audio input:\n"
          
          for i,v in ipairs(rd_list) do
            rd_string = rd_string..tostring(i)..") "..v:getName().."\n"
          end
        end
      
      -- Select music from appdata.
      elseif key_int == 2 then
        appdata_music_success = audio.music.load("music")
        
        if appdata_music_success then
          visualization.load()
        end
      end
    end
    
  -- Player controls.
  else
    local function catch_nil()
      visualization.callback("keypressed", key, scancode, isrepeat)
    end
    (KEY_FUNCTIONS[key] or catch_nil)()
  end
  
end

--- Called on window resize.
-- Callback for main Love2D thread.
-- @param w number: Width window resized to.
-- @param h number: Height window resized to.
function love.resize(w, h)

  gui.scale()
  visualization.callback("resize", w, h)
  
end

--- Called when directory dropped onto window.
-- Callback for main Love2D thread.
-- @param path string: Path of directory dropped.
function love.directorydropped(path)

  if audio.music.load(path) then
    visualization.load()
  end
  visualization.callback("directorydropped", path)
  
end

--- Called when file dropped onto window.
-- Callback for main Love2D thread.
-- @param file File: Love2D object representing dropped file.
function love.filedropped(file)

  audio.music.addSong(file)
  visualization.callback("filedropped", file)
  
end

--- Called when exiting Drop.
-- Callback for main Love2D thread.
-- @return boolean: True to cancel and keep Drop alive.  False to quit.
function love.quit()

  visualization.callback("quit")
  
  --[[ Save config (for session persistence) ]]
  local write_config = false
  
  -- If need to update config values, set flag to true and save new values.
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
  
  -- If need to update config values, set flag to true and save new values.
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
  
  -- If need to update config values, set flag to true and save new values.
  if config.session_persistence then
    local visualization_name = visualization.getName()
    local shuffle = audio.isShuffling()
    local loop = audio.isLooping()
    local mute = audio.isMuted()
    local volume = math.floor((mute and audio.getUnmuteVolume() or not audio.music.exists() and audio.music.getVolume() or love.audio.getVolume())*10+0.5)/10
    local fullscreen = love.window.getFullscreen()
    
    if config.visualization ~= visualization_name or config.shuffle ~= shuffle or config.loop ~= loop or config.volume ~= volume or config.mute ~= mute or config.fullscreen ~= fullscreen then
      config.visualization = visualization_name
      config.shuffle = shuffle
      config.loop = loop
      config.volume = volume
      config.mute = mute
      config.fullscreen = fullscreen
      
      write_config = true
    end
  end
  
  -- If config has been changed, update config file.
  if write_config then
    love.filesystem.write("config.lua", TSerial.pack(config, false, true))
  end
  
  return false
  
end






--[[ Additional Visualization Function Callbacks ]]
function love.keyreleased(...)

  visualization.callback("keyreleased", ...)

end

function love.lowmemory(...)

  visualization.callback("lowmemory", ...)

end

function love.textedited(...)

  visualization.callback("textedited", ...)

end

function love.textinput(...)

  visualization.callback("textinput", ...)

end

function love.threaderror(...)

  visualization.callback("threaderror", ...)

end

function love.touchmoved(...)

  visualization.callback("touchmoved", ...)

end

function love.touchpressed(...)

  visualization.callback("touchpressed", ...)

end

function love.touchreleased(...)

  visualization.callback("touchreleased", ...)

end

function love.visible(...)

  visualization.callback("visible", ...)

end

function love.wheelmoved(...)

  visualization.callback("wheelmoved", ...)

end

function love.gamepadaxis(...)

  visualization.callback("gamepadaxis", ...)

end

function love.gamepadpressed(...)

  visualization.callback("gamepadpressed", ...)

end

function love.gamepadreleased(...)

  visualization.callback("gamepadreleased", ...)

end

function love.joystickadded(...)

  visualization.callback("joystickadded", ...)

end

function love.joystickaxis(...)

  visualization.callback("joystickaxis", ...)

end

function love.joystickhat(...)

  visualization.callback("joystickhat", ...)

end

function love.joystickpressed(...)

  visualization.callback("joystickpressed", ...)

end

function love.joystickreleased(...)

  visualization.callback("joystickreleased", ...)

end

function love.joystickremoved(...)

  visualization.callback("joystickremoved", ...)

end