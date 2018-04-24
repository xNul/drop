local gui = {scrubbar = {}, graphics = {}, timestamp_start = {}, timestamp_end = {}, scrubhead = {}}
local scrubbar_x1 = 0
local scrubbar_y1 = 0
local scrubbar_x2 = 0
local scrubbar_y2 = 0
local scrubhead_radius = 0
local timestamp_start_x = 0
local timestamp_start_y = 0
local timestamp_start_value = "00:00"
local timestamp_end_x = 0
local timestamp_end_y = 0
local timestamp_end_value = "00:00"
local graphics_width = 0
local graphics_height = 0

function gui.load()
  -------------------------------------- Window --------------------------------------
	local desktop_width
  local desktop_height
  desktop_width, desktop_height = love.window.getDesktopDimensions()
  
	local window_width = desktop_width*(2/3)
	local window_height = desktop_height*(2/3)

	local window_position_x = (desktop_width-window_width)/2
	local window_position_y = (desktop_height-window_height)*(5/12) --5/12 to account for taskbar/dock
	love.window.setMode(
		window_width, window_height,
		{x=window_position_x, y=window_position_y,
		resizable=true, highdpi=true}
	)
	love.window.setIcon(love.image.newImageData("images/icon.png"))
	love.window.setTitle("Drop - by nabakin")
	-- see love.resize for new variables

	--[[ modify default screen ratio <<TEST>>
	goal is to optimize Drop for screen ratios other than 16/10 ]]
	local ratio_width = 16
	local ratio_height = 10
	scale_ratio_width = (10/ratio_height)*ratio_width

	local graphics_width
	local graphics_height
  graphics_width, graphics_height = love.graphics.getDimensions()
	------------------------------------------------------------------------------------

  
  ------------------------------------- Sprites/Scaling --------------------------------------
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
  sprite_quads["loop"] = love.graphics.newQuad(0, 0, 300, 240, loop_image:getWidth(), loop_image:getHeight())
  sprite_quads["shuffle"] = love.graphics.newQuad(0, 0, 300, 240, shuffle_image:getWidth(), shuffle_image:getHeight())
  
  sprite_batch = love.graphics.newSpriteBatch(music_control_image, 9)
  shuffle_sprite = love.graphics.newSpriteBatch(shuffle_image, 1)
  loop_sprite = love.graphics.newSpriteBatch(loop_image, 1)
  local gui_scaling_multiplier = math.max(graphics_height, 480)
  
  sprites = {}
  
  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))
  
  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60
  
  local left_height = graphics_height-sprite_square_side_length-small_spacing
  local right_height = graphics_height-sprite_square_side_length-medium_spacing
  
  local offset = 0
  sprites["left"] = sprite_batch:add(sprite_quads["left"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length
  sprites["playback"] = sprite_batch:add(sprite_quads["pause"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length
  sprites["right"] = sprite_batch:add(sprite_quads["right"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing
  sprites["shuffle"] = shuffle_sprite:add(sprite_quads["shuffle"], offset, left_height, 0, scale_x)
  offset = offset+sprite_rectangle_side_length+large_spacing
  sprites["loop"] = loop_sprite:add(sprite_quads["loop"], offset, left_height, 0, scale_x)
  
  local offset_x = offset
  
  offset = graphics_width-sprite_square_side_length-medium_spacing
  sprites["fullscreen"] = sprite_batch:add(sprite_quads["fullscreen"], offset, right_height, 0, scale_x)
  offset = offset-sprite_square_side_length-large_spacing
  sprites["volume"] = sprite_batch:add(sprite_quads["volume3"], offset, right_height, 0, scale_x)
  ------------------------------------------------------------------------------------
  
  
  ------------------------------------- Scaling --------------------------------------
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
	love.graphics.setFont(big_font)
  
  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_font:getWidth("00:00")
  local ui_height = graphics_height-7*gui_scaling_multiplier/240
  
  gui.scrubhead:setRadius(gui_scaling_multiplier/96)
  gui.timestamp_start:setPosition(offset_x, ui_height-normal_font:getHeight("00:00")/2)
  gui.timestamp_end:setPosition(offset, ui_height-normal_font:getHeight("00:00")/2)
  
  gui.graphics:setWidth(graphics_width)
	gui.graphics:setHeight(graphics_height)
	gui.scrubbar:setPosition(
    offset_x+normal_font:getWidth("00:00")+large_spacing,
    ui_height,
    offset-large_spacing,
    ui_height
  )
  ------------------------------------------------------------------------------------
end

function gui.update()
  local graphics_width
	local graphics_height
	graphics_width, graphics_height = love.graphics.getDimensions()
  local gui_scaling_multiplier = math.max(graphics_height, 480)
    
  local icon_height = 40
  local scale_x = gui_scaling_multiplier/(960/(icon_height/240))
  local sprite_square_side_length = gui_scaling_multiplier/(960/icon_height)
  local sprite_rectangle_side_length = gui_scaling_multiplier/(960/(300*(icon_height/240)))
  
  local small_spacing = (icon_height/240)*5*gui_scaling_multiplier/120
  local medium_spacing = (icon_height/240)*5*gui_scaling_multiplier/96
  local large_spacing = (icon_height/240)*5*gui_scaling_multiplier/60
  
  local left_height = graphics_height-sprite_square_side_length-small_spacing
  local right_height = graphics_height-sprite_square_side_length-medium_spacing
  
  local offset = 0
  sprite_batch:set(sprites["left"], sprite_quads["left"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length
  sprite_batch:set(sprites["playback"], sprite_quads["pause"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length
  sprite_batch:set(sprites["right"], sprite_quads["right"], offset, left_height, 0, scale_x)
  offset = offset+sprite_square_side_length+small_spacing
  shuffle_sprite:set(sprites["shuffle"], sprite_quads["shuffle"], offset, left_height, 0, scale_x)
  offset = offset+sprite_rectangle_side_length+large_spacing
  loop_sprite:set(sprites["loop"], sprite_quads["loop"], offset, left_height, 0, scale_x)
  
  local offset_x = offset
  
  offset = graphics_width-sprite_square_side_length-medium_spacing
  sprite_batch:set(sprites["fullscreen"], sprite_quads["fullscreen"], offset, right_height, 0, scale_x)
  offset = offset-sprite_square_side_length-large_spacing
  sprite_batch:set(sprites["volume"], sprite_quads["volume3"], offset, right_height, 0, scale_x)
  
  normal_font = love.graphics.newFont(math.max(graphics_height/30, 16))
	big_font = love.graphics.newFont(math.max(graphics_height/20, 24))
  
  offset_x = offset_x+sprite_rectangle_side_length+3*large_spacing
  offset = offset-3*large_spacing-normal_font:getWidth("00:00")
  local ui_height = graphics_height-7*gui_scaling_multiplier/240
  
  gui.scrubhead:setRadius(gui_scaling_multiplier/96)
  gui.timestamp_start:setPosition(offset_x, ui_height-normal_font:getHeight("00:00")/2)
  gui.timestamp_end:setPosition(offset, ui_height-normal_font:getHeight("00:00")/2)
  
	gui.graphics:setWidth(graphics_width)
	gui.graphics:setHeight(graphics_height)
	gui.scrubbar:setPosition(
    offset_x+normal_font:getWidth("00:00")+large_spacing,
    ui_height,
    offset-large_spacing,
    ui_height
  )
end

function gui.overlay()
	if not gui.sleep() then
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(normal_font)
		if audio.getSongName() ~= nil then
			love.graphics.print(audio.getSongName(), 10, 10)
		end

		timestamp_start_value = secondsToString(audio.decoderTell())

		-- draw ui elements
		love.graphics.line(
			scrubbar_x1, scrubbar_y1,
			scrubbar_x2, scrubbar_y2
		)
		love.graphics.print(
			timestamp_start_value, timestamp_start_x,
			timestamp_start_y
		)
		love.graphics.print(
			timestamp_end_value, timestamp_end_x,
			timestamp_end_y
		)
    
    love.graphics.draw(sprite_batch)
    love.graphics.draw(shuffle_sprite)
    love.graphics.draw(loop_sprite)

    setColor()
		local scrubhead_x = (audio.decoderTell()/audio.getDuration())*(scrubbar_x2-scrubbar_x1)+scrubbar_x1
    love.graphics.line(
			scrubbar_x1, scrubbar_y1,
			scrubhead_x, scrubbar_y1
		)
		love.graphics.circle(
			"fill", scrubhead_x,
			scrubbar_y1, scrubhead_radius, math.max(3*scrubhead_radius, 3)
		)
	end
end

function gui.sleep(bool)
	if bool ~= nil then
		if bool then
			love.mouse.setVisible(false)
		else
			love.mouse.setVisible(true)
		end
	end

	return not love.mouse.isVisible()
end

function gui.scrubhead:setRadius(r)
  scrubhead_radius = r
end

function gui.scrubhead:getRadius()
  return scrubhead_radius
end

function gui.timestamp_start:setValue(value)
  timestamp_start_value = secondsToString(value)
end

function gui.timestamp_start:getValue()
  return timestamp_start_value
end

function gui.timestamp_start:setPosition(x, y)
  timestamp_start_x = x
  timestamp_start_y = y
end

function gui.timestamp_start:getPosition()
  return timestamp_start_x, timestamp_start_y
end

function gui.timestamp_end:setValue(value)
  timestamp_end_value = secondsToString(value)
end

function gui.timestamp_end:getValue()
  return timestamp_end_value
end

function gui.timestamp_end:setPosition(x, y)
  timestamp_end_x = x
  timestamp_end_y = y
end

function gui.timestamp_end:getPosition()
  return timestamp_end_x, timestamp_end_y
end

function gui.scrubbar:setPosition(x1, y1, x2, y2)
	scrubbar_x1 = x1
  scrubbar_y1 = y1
  scrubbar_x2 = x2
  scrubbar_y2 = y2
end

function gui.scrubbar:getPosition()
	return scrubbar_x1, scrubbar_y1, scrubbar_x2, scrubbar_y2
end

function gui.scrubbar:inBoundsX(x)
  return x <= scrubbar_x2+scrubhead_radius and x >= scrubbar_x1-scrubhead_radius
end

function gui.scrubbar:inBoundsY(y)
  return y <= scrubbar_y1+scrubhead_radius and y >= scrubbar_y1-scrubhead_radius
end

function gui.scrubbar:getProportion(x)
	return (x-scrubbar_x1)/(scrubbar_x2-scrubbar_x1)
end

function gui.graphics:setHeight(height)
	graphics_height = height
end

function gui.graphics:getHeight()
	return graphics_height
end

function gui.graphics:setWidth(width)
	graphics_width = width
end

function gui.graphics:getWidth()
	return graphics_width
end

function secondsToString(sec)
	local minute = math.floor(sec/60)
	local second = math.floor(((sec/60)-minute)*60)
	local second_string = string.format("%02d:%02d", minute, second)

	return second_string, minute, second
end

return gui
