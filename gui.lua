local gui = {
  graphics = {},
  extra = {},
  buttons = {
    menu = {},
    left = {},
    playback = {},
    right = {},
    shuffle = {},
    loop = {},
    scrubbar = {},
    volume = {},
    fullscreen = {}
  }
}

local sprite_quads = {}
local sprite_batch = nil
local sprites = {}
local normal_font = nil
local big_font = nil

local graphics_width = 0
local graphics_height = 0
local window_position_x = 0
local window_position_y = 0
local display_location = 0
local window_width = 0
local window_height = 0
local fade_intensity = 0
local color = config.color

local cursor_hand_activated = false
local click_area_y = 0
local menu_x = 0
local menu_y = 0
local left_x = 0
local playback_x = 0
local playback_quad = "pause"
local right_x = 0
local shuffle_x = 0
local shuffle_sprite = nil
local shuffle_activate = config.shuffle
local loop_x = 0
local loop_x_end = 0
local loop_sprite = nil
local loop_activate = config.loop
local scrubbar_x1 = 0
local scrubbar_y1 = 0
local scrubbar_x2 = 0
local scrubbar_y2 = 0
local scrubbar_active = false
local scrubhead_radius = 0
local scrubhead_position = 0
local scrubhead_pause = false
local timestamp_start_x = 0
local timestamp_start_y = 0
local timestamp_start_time = "00:00"
local timestamp_end_x = 0
local timestamp_end_y = 0
local timestamp_end_time = "00:00"
local volume_x = 0
local volume_quad = "volume3"
local fullscreen_x = 0
local fullscreen_quad = "fullscreen"

function gui.reload()
  fade_intensity = 0

  playback_quad = "pause"
  scrubbar_active = false
  scrubhead_position = 0
  scrubhead_pause = false
  timestamp_start_time = "00:00"
  timestamp_end_time = "00:00"
  volume_quad = "volume3"
  
  gui.graphics.setColor()
  gui.buttons.volume.activate(1)
  gui.buttons.playback.scale("pause")
end

function gui.load()
  -------------------------------------- Window --------------------------------------
  local desktop_width, desktop_height = love.window.getDesktopDimensions()

  local window_width = config.window_size[1]
  local window_height = config.window_size[2]

  if config.window_location_persistence then
    window_position_x = config.window_location[1]
    window_position_y = config.window_location[2]
    display_location = config.window_location[3]
  else
    window_position_x = (desktop_width-window_width)/2
    window_position_y = (desktop_height-window_height)*(5/12) --5/12 to account for taskbar/dock
    display_location = 1
  end
  
  love.window.setMode(
    window_width, window_height,
    {x=window_position_x, y=window_position_y, display=display_location, resizable=true,
    highdpi=true, fullscreen=config.fullscreen, vsync=(config.fps_cap == 0)}
  )
  love.window.setIcon(love.image.newImageData("images/icon.png"))
  love.window.setTitle("Drop - by nabakin")
  -- see love.resize for new variables

  graphics_width, graphics_height = love.graphics.getDimensions()
  ------------------------------------------------------------------------------------


  --------------------------------- Sprites/Scaling ----------------------------------
  local music_control_image = love.graphics.newImage("images/music_control_sprites.png")
  local shuffle_image = love.graphics.newImage("images/shuffle_sprite.png")
  local loop_image = love.graphics.newImage("images/loop_sprite.png")
  music_control_image:setFilter("nearest", "linear")
  shuffle_image:setFilter("nearest", "linear")
  loop_image:setFilter("nearest", "linear")
  local mc_image_width = music_control_image:getWidth()
  local mc_image_height = music_control_image:getHeight()

  sprite_quads = {}
  sprite_quads["play"] = love.graphics.newQuad(0, 0, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["pause"] = love.graphics.newQuad(240, 0, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["left"] = love.graphics.newQuad(480, 0, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["right"] = love.graphics.newQuad(720, 0, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["fullscreen"] = love.graphics.newQuad(0, 240, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["fullscreen_exit"] = love.graphics.newQuad(240, 240, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["volume1"] = love.graphics.newQuad(480, 240, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["volume2"] = love.graphics.newQuad(720, 240, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["volume3"] = love.graphics.newQuad(0, 480, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["menu"] = love.graphics.newQuad(240, 480, 240, 240, mc_image_width, mc_image_height)
  sprite_quads["loop"] = love.graphics.newQuad(0, 0, 300, 240, loop_image:getWidth(), loop_image:getHeight())
  sprite_quads["shuffle"] = love.graphics.newQuad(0, 0, 300, 240, shuffle_image:getWidth(), shuffle_image:getHeight())

  sprite_batch = love.graphics.newSpriteBatch(music_control_image, 10)
  shuffle_sprite = love.graphics.newSpriteBatch(shuffle_image, 1)
  loop_sprite = love.graphics.newSpriteBatch(loop_image, 1)
  local gui_scaling_multiplier = math.max(graphics_height, 480)
  local ui_height = graphics_height-7*gui_scaling_multiplier/240

  sprites = {}

  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))

  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60

  local left_height = graphics_height-sprite_square_side_length-11*small_spacing/8
  local right_height = graphics_height-sprite_square_side_length-medium_spacing

  local offset = small_spacing
  left_x = 0
  sprites["left"] = sprite_batch:add(sprite_quads["left"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing/2
  playback_x = offset
  sprites["playback"] = sprite_batch:add(sprite_quads[playback_quad], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing/2
  right_x = offset
  sprites["right"] = sprite_batch:add(sprite_quads["right"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing+small_spacing/2
  shuffle_x = offset-3*small_spacing/2
  sprites["shuffle"] = shuffle_sprite:add(sprite_quads["shuffle"], offset, left_height, 0, scale_x)
  offset = offset+sprite_rectangle_side_length+large_spacing+small_spacing/2
  loop_x = offset-3*small_spacing/2
  loop_x_end = offset+sprite_rectangle_side_length+3*small_spacing/2
  sprites["loop"] = loop_sprite:add(sprite_quads["loop"], offset, left_height, 0, scale_x)

  local offset_x = offset

  offset = graphics_width-sprite_square_side_length-medium_spacing-small_spacing
  fullscreen_x = offset-medium_spacing
  menu_x = offset-large_spacing
  sprites["fullscreen"] = sprite_batch:add(sprite_quads[fullscreen_quad], offset, right_height, 0, scale_x*.93)
  sprites["menu"] = sprite_batch:add(sprite_quads["menu"], offset, 10, 0, scale_x)
  offset = offset-sprite_square_side_length-large_spacing-small_spacing/2
  volume_x = offset-3*small_spacing/2
  sprites["volume"] = sprite_batch:add(sprite_quads[volume_quad], offset, right_height, 0, scale_x)
  ------------------------------------------------------------------------------------


  ------------------------------------- Scaling --------------------------------------
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
  big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
  love.graphics.setFont(big_font)

  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_font:getWidth("00:00")

  scrubhead_radius = gui_scaling_multiplier/96
  timestamp_start_x = offset_x
  timestamp_start_y = ui_height-normal_font:getHeight("00:00")/2
  timestamp_end_x = offset
  timestamp_end_y = ui_height-normal_font:getHeight("00:00")/2

  scrubbar_x1 = offset_x+normal_font:getWidth("00:00")+large_spacing
  scrubbar_y1 = ui_height
  scrubbar_x2 = offset-large_spacing
  scrubbar_y2 = ui_height

  click_area_y = graphics_height-gui_scaling_multiplier/16
  menu_y = scale_x*240+10+medium_spacing
  ------------------------------------------------------------------------------------
end

function gui.scale()
  -------------------------------------- Sprites -------------------------------------
  graphics_width, graphics_height = love.graphics.getDimensions()
  local gui_scaling_multiplier = math.max(graphics_height, 480)

  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))

  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60

  local left_height = graphics_height-sprite_square_side_length-11*small_spacing/8
  local right_height = graphics_height-sprite_square_side_length-medium_spacing

  local offset = small_spacing
  left_x = 0
  sprite_batch:set(sprites["left"], sprite_quads["left"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing/2
  playback_x = offset
  sprite_batch:set(sprites["playback"], sprite_quads[playback_quad], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing/2
  right_x = offset
  sprite_batch:set(sprites["right"], sprite_quads["right"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing+small_spacing/2
  shuffle_x = offset-3*small_spacing/2
  shuffle_sprite:set(sprites["shuffle"], sprite_quads["shuffle"], offset, left_height, 0, scale_x)
  offset = offset+sprite_rectangle_side_length+large_spacing+small_spacing/2
  loop_x = offset-3*small_spacing/2
  loop_x_end = offset+sprite_rectangle_side_length+3*small_spacing/2
  loop_sprite:set(sprites["loop"], sprite_quads["loop"], offset, left_height, 0, scale_x)

  local offset_x = offset

  offset = graphics_width-sprite_square_side_length-medium_spacing-small_spacing
  fullscreen_x = offset-medium_spacing
  menu_x = offset-large_spacing
  sprite_batch:set(sprites["fullscreen"], sprite_quads[fullscreen_quad], offset, right_height, 0, scale_x*.93)
  sprite_batch:set(sprites["menu"], sprite_quads["menu"], offset, 10, 0, scale_x)
  offset = offset-sprite_square_side_length-large_spacing-small_spacing/2
  volume_x = offset-3*small_spacing/2
  sprite_batch:set(sprites["volume"], sprite_quads[volume_quad], offset, right_height, 0, scale_x)
  ------------------------------------------------------------------------------------


  ------------------------------------- Scrubbar -------------------------------------
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
  big_font = love.graphics.newFont(math.max(graphics_height/20, 24))

  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_font:getWidth("00:00")
  local ui_height = graphics_height-7*gui_scaling_multiplier/240

  scrubhead_radius = gui_scaling_multiplier/96
  timestamp_start_x = offset_x
  timestamp_start_y = ui_height-normal_font:getHeight("00:00")/2
  timestamp_end_x = offset
  timestamp_end_y = ui_height-normal_font:getHeight("00:00")/2

  scrubbar_x1 = offset_x+normal_font:getWidth("00:00")+large_spacing
  scrubbar_y1 = ui_height
  scrubbar_x2 = offset-large_spacing
  scrubbar_y2 = ui_height

  click_area_y = graphics_height-gui_scaling_multiplier/16
  menu_y = scale_x*240+10+medium_spacing
  ------------------------------------------------------------------------------------
end

function gui.overlay()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(normal_font)
  if audio.getTitle() ~= nil then
    love.graphics.print(audio.getTitle(), 10, 10)
  end
  
  local scrubhead_x
  if config.visualization_update or not scrubbar_active then
    scrubhead_x = (audio.music.tellSong()/audio.music.getDuration())*(scrubbar_x2-scrubbar_x1)+scrubbar_x1
    timestamp_start_time = gui.extra.secondsToString(audio.music.tellSong())
  else
    scrubhead_x = gui.buttons.scrubbar.getProportion(scrubhead_position)*(scrubbar_x2-scrubbar_x1)+scrubbar_x1
    timestamp_start_time = gui.extra.secondsToString(gui.buttons.scrubbar.getProportion(scrubhead_position)*audio.music.getDuration())
  end

  -- draw ui elements
  love.graphics.line(
    scrubbar_x1, scrubbar_y1,
    scrubbar_x2, scrubbar_y2
  )
  love.graphics.print(
    timestamp_start_time, timestamp_start_x,
    timestamp_start_y
  )
  love.graphics.print(
    timestamp_end_time, timestamp_end_x,
    timestamp_end_y
  )

  love.graphics.draw(sprite_batch)

  if shuffle_activate then
    gui.graphics.setColor()
  end
  love.graphics.draw(shuffle_sprite)

  if loop_activate and not shuffle_activate then
    gui.graphics.setColor()
  elseif shuffle_activate and not loop_activate then
    love.graphics.setColor(1, 1, 1)
  end
  love.graphics.draw(loop_sprite)

  if not loop_activate then
    gui.graphics.setColor()
  end
  
  love.graphics.line(
    scrubbar_x1, scrubbar_y1,
    scrubhead_x, scrubbar_y1
  )
  love.graphics.circle(
    "fill", scrubhead_x,
    scrubbar_y1, scrubhead_radius, math.max(3*scrubhead_radius, 3)
  )
end

function gui.graphics.setWidth(width)
  graphics_width = width
end

function gui.graphics.getWidth()
  return graphics_width
end

function gui.graphics.setHeight(height)
  graphics_height = height
end

function gui.graphics.getHeight()
  return graphics_height
end

function gui.graphics.getWindowedDimensions()
  return window_width, window_height
end

function gui.graphics.getWindowedPosition()
  return window_position_x, window_position_y, display_location
end

function gui.graphics.getBigFont()
  return big_font
end

function gui.graphics.getNormalFont()
  return normal_font
end

function gui.graphics.setColor(c, f)
  if f then
    fade_intensity = math.min(math.max(f, 0), 1)
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

function gui.extra.sleep(bool)
  if bool ~= nil then
    if bool then
      love.mouse.setVisible(false)
    else
      love.mouse.setVisible(true)
    end
  end

  return not love.mouse.isVisible()
end

function gui.extra.secondsToString(sec)
  local minute = math.floor(sec/60)
  local second = math.floor(((sec/60)-minute)*60)
  local second_string = string.format("%02d:%02d", minute, second)

  return second_string, minute, second
end

function gui.buttons.inBounds(x, y)
  for label, button in pairs(gui.buttons) do
    if type(button) == "table" and button.inBoundsX(x) and button.inBoundsY(y) then
      return true
    end
  end

  return false
end

function gui.buttons.getButton(x, y)
  for label, button in pairs(gui.buttons) do
    if type(button) == "table" and button.inBoundsX(x) and button.inBoundsY(y) then
      return button
    end
  end
  
  return nil
end

function gui.buttons.setCursor(x, y)
  if gui.buttons.inBounds(x, y) then
    if not cursor_hand_activated then
      love.mouse.setCursor(love.mouse.getSystemCursor("hand"))
      cursor_hand_activated = true
    end
  elseif cursor_hand_activated then
    love.mouse.setCursor(love.mouse.getSystemCursor("arrow"))
    cursor_hand_activated = false
  end
end

function gui.buttons.menu.inBoundsX(x)
  return x <= graphics_width and x >= menu_x
end

function gui.buttons.menu.inBoundsY(y)
  return y >= 0 and y <= menu_y
end

function gui.buttons.menu.isActive()
  return not audio.music.exists() and not audio.microphone.isActive() and not audio.isPlaying()
end

function gui.buttons.menu.activate()

  audio.reload()
  spectrum.reload()
  gui.reload()
  main.reload()
  
end

function gui.buttons.left.inBoundsX(x)
  return x <= playback_x and x >= left_x
end

function gui.buttons.left.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.left.activate()
  audio.music.changeSong(-1)
end

function gui.buttons.playback.inBoundsX(x)
  return x <= right_x and x >= playback_x
end

function gui.buttons.playback.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.playback.scale(pquad)
  playback_quad = pquad
  
  local gui_scaling_multiplier = math.max(graphics_height, 480)
  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local left_height = graphics_height-sprite_square_side_length-11*small_spacing/8
  local offset = small_spacing+sprite_square_side_length+small_spacing/2
  
  sprite_batch:set(sprites["playback"], sprite_quads[pquad], offset, left_height, 0, scale_x)
end

function gui.buttons.playback.activate()
  if audio.isPaused() then
    audio.play()
    gui.buttons.playback.scale("pause")
  elseif audio.isPlaying() or audio.microphone.isActive() then
    audio.pause()
    gui.buttons.playback.scale("play")
  end
end

function gui.buttons.right.inBoundsX(x)
  return x <= shuffle_x and x >= right_x
end

function gui.buttons.right.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.right.activate()
  audio.music.changeSong(1)
end

function gui.buttons.shuffle.inBoundsX(x)
  return x <= loop_x and x >= shuffle_x
end

function gui.buttons.shuffle.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.shuffle.activate()
  shuffle_activate = not shuffle_activate
  audio.toggleShuffle()
end

function gui.buttons.loop.inBoundsX(x)
  return x <= loop_x_end and x >= loop_x
end

function gui.buttons.loop.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.loop.activate()
  loop_activate = not loop_activate
  audio.toggleLoop()
end

function gui.buttons.scrubbar.inBoundsX(x)
  return x <= scrubbar_x2+scrubhead_radius and x >= scrubbar_x1-scrubhead_radius
end

function gui.buttons.scrubbar.inBoundsY(y)
  return y <= scrubbar_y1+scrubhead_radius and y >= scrubbar_y1-scrubhead_radius
end

function gui.buttons.scrubbar.getProportion(x)
  return (x-scrubbar_x1)/(scrubbar_x2-scrubbar_x1)
end

function gui.buttons.scrubbar.getScrubheadPosition()
  return scrubhead_position
end

function gui.buttons.scrubbar.setTimestampStart(t)
  timestamp_start_time = gui.extra.secondsToString(t)
end

function gui.buttons.scrubbar.setTimestampEnd(t)
  timestamp_end_time = gui.extra.secondsToString(t)
end

function gui.buttons.scrubbar.isActive()
  return scrubbar_active
end

function gui.buttons.scrubbar.activate(x)
  if x == nil then return end

  if audio.isPlaying() then
    audio.pause()
    scrubhead_pause = true
  end

  if config.visualization_update then
    audio.music.seekSong(gui.buttons.scrubbar.getProportion(x)*audio.music.getDuration())
  else
    scrubhead_position = x
  end
  
  scrubbar_active = true
end

function gui.buttons.scrubbar.deactivate(x)
  if x == nil then return end

  if scrubhead_pause then
    audio.play()
    scrubhead_pause = false
  end
  
  if not config.visualization_update and scrubbar_active then
    audio.music.seekSong(gui.buttons.scrubbar.getProportion(x)*audio.music.getDuration())
  end
  
  scrubbar_active = false
end

function gui.buttons.volume.inBoundsX(x)
  return x <= fullscreen_x and x >= volume_x
end

function gui.buttons.volume.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.volume.scale(vquad)
  volume_quad = vquad

  local gui_scaling_multiplier = math.max(graphics_height, 480)

  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))

  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60

  local right_height = graphics_height-sprite_square_side_length-medium_spacing

  local offset = small_spacing
  offset = offset+sprite_square_side_length+small_spacing/2
  offset = offset+sprite_square_side_length+small_spacing/2
  offset = offset+sprite_square_side_length+small_spacing+small_spacing/2
  offset = offset+sprite_rectangle_side_length+large_spacing+small_spacing/2
  offset = graphics_width-sprite_square_side_length-medium_spacing-small_spacing
  offset = offset-sprite_square_side_length-large_spacing-small_spacing/2
  
  sprite_batch:set(sprites["volume"], sprite_quads[vquad], offset, right_height, 0, scale_x)
end

function gui.buttons.volume.activate(v)
  local vquad
  local scale = true
  
  if v == nil then
    local volume_rotation = {
      ["volume1"] = function ()
        vquad = "volume2"
        love.audio.setVolume(0.5)
      end,
      ["volume2"] = function ()
        vquad = "volume3"
        love.audio.setVolume(1)
      end,
      ["volume3"] = function ()
        vquad = "volume1"
        love.audio.setVolume(0)
      end
    }

    volume_rotation[volume_quad]()
  elseif type(v) == "string" then
    local volume_set = {
      ["volume1"] = function ()
        love.audio.setVolume(0)
      end,
      ["volume2"] = function ()
        love.audio.setVolume(0.5)
      end,
      ["volume3"] = function ()
        love.audio.setVolume(1)
      end
    }
  
    volume_set[v]()
    vquad = v
  elseif type(v) == "number" then
    if v >= 0 and v <= 1 then
      if v == 0 then
        vquad = "volume1"
      elseif v <= 0.5 then
        vquad = "volume2"
      else
        vquad = "volume3"
      end
      
      love.audio.setVolume(v)
    else
      scale = false
    end
  end
  
  if scale then gui.buttons.volume.scale(vquad) end
end

function gui.buttons.fullscreen.inBoundsX(x)
  return x <= graphics_width and x >= fullscreen_x
end

function gui.buttons.fullscreen.inBoundsY(y)
  return y <= graphics_height and y >= click_area_y
end

function gui.buttons.fullscreen.activate()
  local init_fullscreen = love.window.getFullscreen()
  local fullscreen_rotation = {
    ["fullscreen"] = "fullscreen_exit",
    ["fullscreen_exit"] = "fullscreen"
  }
  fullscreen_quad = fullscreen_rotation[fullscreen_quad]
  
  local win_x1, win_y1, display = love.window.getPosition()
  if not init_fullscreen then
    window_width, window_height = love.graphics.getDimensions()
    window_position_x, window_position_y, display_location = win_x1, win_y1, display
  end
  
  local x, y = love.mouse.getPosition()
  love.window.setFullscreen(not init_fullscreen)
  
  local win_x2, win_y2
  if init_fullscreen then
    -- have to do this bc window position wont be correct if starting Drop with fullscreen
    love.window.setPosition(window_position_x, window_position_y, display_location)
    win_x2, win_y2 = window_position_x, window_position_y
  else
    win_x2, win_y2 = love.window.getPosition()
  end
  love.mouse.setPosition(win_x1+x-win_x2, win_y1+y-win_y2)
end

return gui