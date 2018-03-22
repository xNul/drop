local gui = {scrubbar = {}, graphics = {}}
local scrubbar_x = 0
local scrubbar_y = 0
local scrubbar_width = 0
local scrubbar_height = 0
local graphics_width = 0
local graphics_height = 0

function gui.overlay()
	if not gui.sleep() then
		love.graphics.setColor(255, 255, 255)
		love.graphics.setFont(normal_font)
		if audio.getSongName() ~= nil then
			love.graphics.print(audio.getSongName(), 10, 10)
		end

		-- calculate song position and change both timestamps simultaneously
		local time_start, minute, second = secondsToString(audio.decoderTell())
		local _, minute_end, second_end = secondsToString(audio.getDuration())
		local minutes = minute_end-minute
		local seconds = second_end-second
		if seconds < 0 then
			seconds = seconds+60
			minutes = minutes-1
		end
		local time_end = string.format("%02d:%02d", minutes, seconds)
		local current_font = love.graphics.getFont()

		-- draw ui elements
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

		local current_time_proportion = audio.decoderTell()/audio.getDuration()
		love.graphics.circle(
			"fill", current_time_proportion*scrubbar_width+scrubbar_x,
			scrubbar_y+scrubbar_height/2, math.floor(scrubbar_height/2), math.max(3*math.floor(scrubbar_height/2), 3)
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

function gui.scrubbar:setX(x)
	scrubbar_x = x
	return scrubbar_x
end

function gui.scrubbar:getX()
	return scrubbar_x
end

function gui.scrubbar:setY(y)
	scrubbar_y = y
end

function gui.scrubbar:getY()
	return scrubbar_y
end

function gui.scrubbar:setWidth(width)
	scrubbar_width = width
end

function gui.scrubbar:getWidth()
	return scrubbar_width
end

function gui.scrubbar:setHeight(height)
	scrubbar_height = height
end

function gui.scrubbar:getHeight()
	return scrubbar_height
end

function gui.scrubbar:inBounds(x, y)
	return x <= scrubbar_x+scrubbar_width and x >= scrubbar_x and y <= scrubbar_y+scrubbar_height and y >= scrubbar_y
end

function gui.scrubbar:getProportion(x)
	return (x-scrubbar_x)/scrubbar_width
end

function gui.graphics:setHeight(height)
	graphics_height = height
end

function gui.graphics:getHeight()
	return graphics_height
end

function gui.graphics:getScaledHeight()
	return math.max(71.138*graphics_height^(1/3), graphics_height)
end

function gui.graphics:setWidth(width)
	graphics_width = width
end

function gui.graphics:getWidth()
	return graphics_width
end

function gui.graphics:getScaledWidth()
	return math.max(97.315*graphics_width^(1/3), graphics_width)
end

function secondsToString(sec)
	local minute = math.floor(sec/60)
	local second = math.floor(((sec/60)-minute)*60)
	local second_string = string.format("%02d:%02d", minute, second)

	return second_string, minute, second
end

return gui
