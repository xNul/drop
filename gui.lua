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
local window_width = config.window_size[1]
local window_height = config.window_size[2]
local init_fullscreen = config.fullscreen
local fps_cap = config.fps_cap
local visualization_update = config.visualization_update
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

local desktop_width, desktop_height = love.window.getDesktopDimensions()
window_position_x = (config.window_location[1] == -1) and (desktop_width-window_width)/2 or config.window_location[1]
window_position_y = (config.window_location[2] == -1) and (desktop_height-window_height)*(5/12) or config.window_location[2] --5/12 to account for taskbar/dock
display_location = (config.window_location[3] == -1) and 1 or config.window_location[3]

--- Reloads gui variables that affect the menu.
-- Necessary for returning to the main menu.
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

--- Load the GUI elements.
function gui.load()

  -------------------------------------- Window --------------------------------------
  love.window.setMode(
    window_width, window_height,
    {x=window_position_x, y=window_position_y, display=display_location, resizable=true,
    highdpi=true, fullscreen=init_fullscreen, vsync=(fps_cap == 0)}
  )
  love.window.setIcon(love.image.newImageData("images/icon.png"))
  love.window.setTitle("Drop - by nabakin")

  graphics_width, graphics_height = love.graphics.getDimensions()
  ------------------------------------------------------------------------------------


  --------------------------------- Sprites/Scaling ----------------------------------
  -- Load sprite images.
  local music_control_image = love.graphics.newImage("images/music_control_sprites.png")
  local shuffle_image = love.graphics.newImage("images/shuffle_sprite.png")
  local loop_image = love.graphics.newImage("images/loop_sprite.png")
  music_control_image:setFilter("nearest", "linear")
  shuffle_image:setFilter("nearest", "linear")
  loop_image:setFilter("nearest", "linear")
  local mc_image_width = music_control_image:getWidth()
  local mc_image_height = music_control_image:getHeight()

  -- Define boundaries of each sprite.
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

  -- Create sprite batches.
  sprite_batch = love.graphics.newSpriteBatch(music_control_image, 10)
  shuffle_sprite = love.graphics.newSpriteBatch(shuffle_image, 1)
  loop_sprite = love.graphics.newSpriteBatch(loop_image, 1)
  local gui_scaling_multiplier = math.max(graphics_height, 480)
  local gui_height = graphics_height-7*gui_scaling_multiplier/240

  sprites = {}

  -- Scaling of all elements.
  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))

  -- For positioning GUI elements.
  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60

  local left_height = graphics_height-sprite_square_side_length-11*small_spacing/8
  local right_height = graphics_height-sprite_square_side_length-medium_spacing

  -- Calculate and set the x coordinate of all GUI elements.
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

  -- Scrubbar position to be handled later.
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
  -- Standard fonts.
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
  big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
  love.graphics.setFont(big_font)
  
  local normal_timestamp_width = normal_font:getWidth("00:00")
  local normal_timestamp_height = normal_font:getHeight("00:00")

  -- Calculate scrubbar area.
  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_timestamp_width

  --[[ Set location of individual elements. ]]
  scrubhead_radius = gui_scaling_multiplier/96
  timestamp_start_x = offset_x
  timestamp_start_y = gui_height-normal_timestamp_height/2
  timestamp_end_x = offset
  timestamp_end_y = gui_height-normal_timestamp_height/2

  scrubbar_x1 = offset_x+normal_timestamp_width+large_spacing
  scrubbar_y1 = gui_height
  scrubbar_x2 = offset-large_spacing
  scrubbar_y2 = gui_height

  click_area_y = graphics_height-gui_scaling_multiplier/16
  menu_y = scale_x*240+10+medium_spacing
  ------------------------------------------------------------------------------------
  
end

--- Update the GUI elements to the window resolution.
function gui.scale()

  -------------------------------------- Sprites -------------------------------------
  graphics_width, graphics_height = love.graphics.getDimensions()
  local gui_scaling_multiplier = math.max(graphics_height, 480)

  -- Scaling of all elements.
  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))

  -- For positioning GUI elements.
  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60

  local left_height = graphics_height-sprite_square_side_length-11*small_spacing/8
  local right_height = graphics_height-sprite_square_side_length-medium_spacing

  -- Calculate and set the x coordinate of all GUI elements.
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

  -- Scrubbar position to be handled later.
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
  -- Standard fonts.
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
  big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
  
  local normal_timestamp_width = normal_font:getWidth("00:00")
  local normal_timestamp_height = normal_font:getHeight("00:00")
  
  -- Calculate scrubbar area.
  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_timestamp_width
  local gui_height = graphics_height-7*gui_scaling_multiplier/240

  --[[ Set location of individual elements. ]]
  scrubhead_radius = gui_scaling_multiplier/96
  timestamp_start_x = offset_x
  timestamp_start_y = gui_height-normal_timestamp_height/2
  timestamp_end_x = offset
  timestamp_end_y = gui_height-normal_timestamp_height/2

  scrubbar_x1 = offset_x+normal_timestamp_width+large_spacing
  scrubbar_y1 = gui_height
  scrubbar_x2 = offset-large_spacing
  scrubbar_y2 = gui_height

  click_area_y = graphics_height-gui_scaling_multiplier/16
  menu_y = scale_x*240+10+medium_spacing
  ------------------------------------------------------------------------------------
  
end

--- Draws the overlay to the screen.
function gui.overlay()

  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(normal_font)
  
  if audio.getTitle() then
    love.graphics.print(audio.getTitle(), 10, 10)
  end
  
  local scrubhead_x
  if visualization_update or not scrubbar_active then
    scrubhead_x = (audio.music.tellSong()/audio.music.getDuration())*(scrubbar_x2-scrubbar_x1)+scrubbar_x1
    timestamp_start_time = gui.extra.secondsToString(audio.music.tellSong())
  else
    scrubhead_x = gui.buttons.scrubbar.getProportion(scrubhead_position)*(scrubbar_x2-scrubbar_x1)+scrubbar_x1
    timestamp_start_time = gui.extra.secondsToString(gui.buttons.scrubbar.getProportion(scrubhead_position)*audio.music.getDuration())
  end

  --[[ Draw all GUI elements ]]
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

--- Gets the width of the window.
-- @return number: Width of the window.
function gui.graphics.getWidth()

  return graphics_width
  
end

--- Gets the height of the window.
-- @return number: Height of the window.
function gui.graphics.getHeight()

  return graphics_height
  
end

--- Gets the window dimensions of the nonfullscreen window.
-- @return number, number: Width and height of nonfullscreen window.
function gui.graphics.getWindowedDimensions()

  return window_width, window_height
  
end

--- Gets the window position of the nonfullscreen window.
-- @return number, number, number: x coordinate of
-- screen, y coordinate of screen, and display number.
function gui.graphics.getWindowedPosition()

  return window_position_x, window_position_y, display_location
  
end

--- Gets the scaled big font.
-- @return Font: Scaled big font.
function gui.graphics.getBigFont()

  return big_font
  
end

--- Gets the scaled normal font.
-- @return Font: Scaled normal font.
function gui.graphics.getNormalFont()

  return normal_font
  
end

--- Sets the default color to c with f fade intensity or simply resets to default color.
-- @param[opt] c table or string: A table of 3 numbers
-- ranging from 0 to 1 or a string with "r", "g", or "b".
-- @param[opt] f number: Fade intensity from 0 to 1.
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

--- Controls sleep function of overlay.
-- @param[opt] bool boolean: True disables the overlay.  False otherwise.
-- @return boolean: True if asleep.  False otherwise.
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

--- Seconds -> Formatted string.
-- @param sec number: Time in number of seconds.
-- @return string: Time in string format.
function gui.extra.secondsToString(sec)

  local minute = math.floor(sec/60)
  local second = math.floor(((sec/60)-minute)*60)
  local second_string = string.format("%02d:%02d", minute, second)

  return second_string
  
end

--- Checks if there is a button at (x, y).
-- @param x number: x coordinate of window.
-- @param y number: y coordinate of window.
-- @return boolean: True if there is a button at (x, y).  False otherwise.
function gui.buttons.inBounds(x, y)

  for label, button in pairs(gui.buttons) do
    if type(button) == "table" and button.inBoundsX(x) and button.inBoundsY(y) then
      return true
    end
  end

  return false
  
end

--- Gets the button at (x, y).
-- @param x number: x coordinate of window.
-- @param y number: y coordinate of window.
-- @return table: Button at (x, y).
function gui.buttons.getButton(x, y)

  for label, button in pairs(gui.buttons) do
    if type(button) == "table" and button.inBoundsX(x) and button.inBoundsY(y) then
      return button
    end
  end
  
  return nil
  
end

--- Sets the correct cursor icon for (x, y).
-- @param x number: x coordinate of window.
-- @param y number: y coordinate of window.
function gui.buttons.setCursorIcon(x, y)

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

--- Checks if menu button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if menu button is at x.  False otherwise.
function gui.buttons.menu.inBoundsX(x)

  return x <= graphics_width and x >= menu_x
  
end

--- Checks if menu button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if menu button is at y.  False otherwise.
function gui.buttons.menu.inBoundsY(y)

  return y >= 0 and y <= menu_y
  
end

--- Determines whether or not the menu is being used.
-- @return boolean: True if the menu is being used.  False otherwise.
function gui.buttons.menu.isActive()

  return not audio.music.exists() and not audio.recordingdevice.isActive() and not audio.isPlaying()
  
end

--- Return to menu and reload all menu option-specific variables.
function gui.buttons.menu.activate()

  audio.reload()
  visualization.reload()
  gui.reload()
  main.reload()
  
end

--- Checks if left button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if left button is at x.  False otherwise.
function gui.buttons.left.inBoundsX(x)

  return x <= playback_x and x >= left_x
  
end

--- Checks if left button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if left button is at y.  False otherwise.
function gui.buttons.left.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Plays the previous song.
function gui.buttons.left.activate()

  audio.music.changeSong(-1)
  
end

--- Checks if playback button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if playback button is at x.  False otherwise.
function gui.buttons.playback.inBoundsX(x)

  return x <= right_x and x >= playback_x
  
end

--- Checks if playback button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if playback button is at y.  False otherwise.
function gui.buttons.playback.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Perform calculations necessary to update playback sprite.
-- @param pquad string: Playback sprite to display.
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

--- Toggles playback (Pause/Play).
function gui.buttons.playback.activate()

  if audio.isPaused() then
    audio.play()
    gui.buttons.playback.scale("pause")
  elseif audio.isPlaying() or audio.recordingdevice.isActive() then
    audio.pause()
    gui.buttons.playback.scale("play")
  end
  
end

--- Checks if right button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if right button is at x.  False otherwise.
function gui.buttons.right.inBoundsX(x)

  return x <= shuffle_x and x >= right_x
  
end

--- Checks if right button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if right button is at y.  False otherwise.
function gui.buttons.right.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Plays the next song.
function gui.buttons.right.activate()

  audio.music.changeSong(1)
  
end

--- Checks if shuffle button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if shuffle button is at x.  False otherwise.
function gui.buttons.shuffle.inBoundsX(x)

  return x <= loop_x and x >= shuffle_x
  
end

--- Checks if shuffle button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if shuffle button is at y.  False otherwise.
function gui.buttons.shuffle.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Toggles shuffle.
function gui.buttons.shuffle.activate()

  shuffle_activate = not shuffle_activate
  audio.toggleShuffle()
  
end

--- Checks if loop button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if loop button is at x.  False otherwise.
function gui.buttons.loop.inBoundsX(x)

  return x <= loop_x_end and x >= loop_x
  
end

--- Checks if loop button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if loop button is at y.  False otherwise.
function gui.buttons.loop.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Toggles loop.
function gui.buttons.loop.activate()

  loop_activate = not loop_activate
  audio.toggleLoop()
  
end

--- Checks if scrubbar is at x.
-- @param x number: x coordinate.
-- @return boolean: True if scrubbar is at x.  False otherwise.
function gui.buttons.scrubbar.inBoundsX(x)

  return x <= scrubbar_x2+scrubhead_radius and x >= scrubbar_x1-scrubhead_radius
  
end

--- Checks if scrubbar is at y.
-- @param y number: y coordinate.
-- @return boolean: True if scrubbar is at y.  False otherwise.
function gui.buttons.scrubbar.inBoundsY(y)

  return y <= scrubbar_y1+scrubhead_radius and y >= scrubbar_y1-scrubhead_radius
  
end

--- Gets the proportion of scrubbar length covered.
-- @param x number: x coordinate in window.
function gui.buttons.scrubbar.getProportion(x)

  return (x-scrubbar_x1)/(scrubbar_x2-scrubbar_x1)
  
end

--- Gets the x coordinate of the scrubhead.
-- @return number: x coordinate of the scrubhead.
function gui.buttons.scrubbar.getScrubheadPosition()

  return scrubhead_position
  
end

--- Sets the time on the left timestamp.
-- @param t number: Time to set on the timestamp.
function gui.buttons.scrubbar.setTimestampStart(t)

  timestamp_start_time = gui.extra.secondsToString(t)
  
end

--- Sets the time on the right timestamp.
-- @param t number: Time to set on the timestamp.
function gui.buttons.scrubbar.setTimestampEnd(t)

  timestamp_end_time = gui.extra.secondsToString(t)
  
end

--- Determines whether or not the scrubbar is being modified.
-- @return boolean: True if scrubbar is being modified.  False otherwise.
function gui.buttons.scrubbar.isActive()

  return scrubbar_active
  
end

--- Grabs scrubhead, pauses music file, and updates scrubhead position.
-- @param x number: x coordinate of window.
function gui.buttons.scrubbar.activate(x)

  if not x then return end

  if audio.isPlaying() then
    audio.pause()
    scrubhead_pause = true
  end

  if visualization_update then
    audio.music.seekSong(gui.buttons.scrubbar.getProportion(x)*audio.music.getDuration())
  else
    scrubhead_position = x
  end
  
  scrubbar_active = true
  
end

--- Stops grabbing scrubhead and plays music file at scrubhead position.
-- @param x number: x coordinate of window.
function gui.buttons.scrubbar.deactivate(x)

  if not x then return end

  if scrubhead_pause then
    audio.play()
    scrubhead_pause = false
  end
  
  -- Updates the song position in the event it wasn't updated previously.
  if not visualization_update and scrubbar_active then
    audio.music.seekSong(gui.buttons.scrubbar.getProportion(x)*audio.music.getDuration())
  end
  
  scrubbar_active = false
  
end

--- Checks if volume button is at x.
-- @param y number: x coordinate.
-- @return boolean: True if volume button is at x.  False otherwise.
function gui.buttons.volume.inBoundsX(x)

  return x <= fullscreen_x and x >= volume_x
  
end

--- Checks if volume button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if volume button is at y.  False otherwise.
function gui.buttons.volume.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Perform calculations necessary to update volume sprite.
-- @param vquad string: Volume sprite to display.
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

  -- Calculate x coordinate of sprite.
  local offset = small_spacing
  offset = offset+sprite_square_side_length+small_spacing/2
  offset = offset+sprite_square_side_length+small_spacing/2
  offset = offset+sprite_square_side_length+small_spacing+small_spacing/2
  offset = offset+sprite_rectangle_side_length+large_spacing+small_spacing/2
  offset = graphics_width-sprite_square_side_length-medium_spacing-small_spacing
  offset = offset-sprite_square_side_length-large_spacing-small_spacing/2
  
  sprite_batch:set(sprites["volume"], sprite_quads[vquad], offset, right_height, 0, scale_x)
  
end

--- Cycles through volume options or activates volume option v.
-- @param[opt] v string or number: Volume option
-- to activate or a volume to set (updates GUI too).
function gui.buttons.volume.activate(v)

  local vquad
  
  if not v then
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

    -- Cycle through volume options.
    volume_rotation[volume_quad]()
  elseif type(v) == "string" then
    local volume_set = {
      ["volume1"] = 0,
      ["volume2"] = 0.5,
      ["volume3"] = 1
    }
  
    love.audio.setVolume(volume_set[v])
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
      return
    end
  end
  
  gui.buttons.volume.scale(vquad)
  
end

--- Checks if fullscreen button is at x.
-- @param x number: x coordinate.
-- @return boolean: True if fullscreen button is at x.  False otherwise.
function gui.buttons.fullscreen.inBoundsX(x)

  return x <= graphics_width and x >= fullscreen_x
  
end

--- Checks if fullscreen button is at y.
-- @param y number: y coordinate.
-- @return boolean: True if fullscreen button is at y.  False otherwise.
function gui.buttons.fullscreen.inBoundsY(y)

  return y <= graphics_height and y >= click_area_y
  
end

--- Toggles fullscreen.
function gui.buttons.fullscreen.activate()

  local init_fullscreen = love.window.getFullscreen()
  local fullscreen_rotation = {
    ["fullscreen"] = "fullscreen_exit",
    ["fullscreen_exit"] = "fullscreen"
  }
  fullscreen_quad = fullscreen_rotation[fullscreen_quad]
  
  -- If switching to fullscreen, save windowed state.
  local win_x1, win_y1, display = love.window.getPosition()
  if not init_fullscreen then
    window_width, window_height = love.graphics.getDimensions()
    window_position_x, window_position_y, display_location = win_x1, win_y1, display
  end
  
  local x, y = love.mouse.getPosition()
  love.window.setFullscreen(not init_fullscreen)
  
  -- If switched to windowed, restore windowed state.
  local win_x2, win_y2
  if init_fullscreen then
    love.window.setPosition(window_position_x, window_position_y, display_location)
    win_x2, win_y2 = window_position_x, window_position_y
  else
    win_x2, win_y2 = love.window.getPosition()
  end
  
  -- Fix mouse location shift.
  love.mouse.setPosition(win_x1+x-win_x2, win_y1+y-win_y2)
  
end

return gui