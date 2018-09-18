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

local visualizer = {}
local fade_activated = config.fade
local tick_amplitude_average = 0
local fade_intensity_multiplier = config.fade_intensity_multiplier

--[[if config.visualization == 1 then
  visualization.setTickCount(48)
elseif config.visualization == 2 then
  visualization.setTickCount(64)
elseif config.visualization == 3 then
  visualization.setTickCount(128)
elseif config.visualization == 4 then
  visualization.setTickCount(256)
end]]
visualization.setTickCount(128)

local KEY_FUNCTIONS = {
  ["i"] = function ()
    fade_activated = not fade_activated
    
    -- If disabled, fade intensity becomes 0.
    if not fade_activated then
      gui.graphics.setColor(nil, 0)
    end
  end,
  ["1"] = function ()
    visualization.setTickCount(48)
  end,
  ["2"] = function ()
    visualization.setTickCount(64)
  end,
  ["3"] = function ()
    visualization.setTickCount(128)
  end,
  ["4"] = function ()
    visualization.setTickCount(256)
  end
}

function visualizer:getInfo()
  
  return {
    ["name"] = "bar",
    ["author"] = "nabakin",
    ["version"] = "1.0"
  }

end

function visualizer:draw(waveform)

  local tick_distance
  local tick_width
  local tick_count = visualization.getTickCount()
  local graphics_width = gui.graphics.getWidth()
  local graphics_height = gui.graphics.getHeight()
  
  -- Scales visualization at a decreasing rate.
  local graphics_scaled_height = math.max(71.138*graphics_height^(1/3), graphics_height)

  -- Load properties of bar visualization.
  if tick_count == 48 then
    tick_distance = graphics_width/(tick_count*2)
    tick_width = graphics_width/(tick_count*5.5)
  elseif tick_count == 64 then
    tick_distance = graphics_width/(tick_count*2)
    tick_width = graphics_width/(tick_count*4.3)
  elseif tick_count == 128 then
    local tick_padding = 2
    tick_distance = graphics_width/((tick_count+tick_padding)*2)
    tick_width = tick_distance
  elseif tick_count == 256 then
    tick_distance = graphics_width/(tick_count*2)
    tick_width = tick_distance
  end

  if fade_activated then
    gui.graphics.setColor(nil, (.03-tick_amplitude_average)*fade_intensity_multiplier)
  else
    gui.graphics.setColor()
  end
  
  local waveform = visualization.getWaveform()
  
  --[[ Draw bar visualizer ]]
  -- If no waveform, skip drawing of bar visualizer.
  if not waveform[0] then
    tick_count = 0
  end
  
  -- Draw bars.
  local tick_amplitude_sum = 0
  for i=0, tick_count-1 do
    local tick_amplitude = waveform[i]
    local tick_height = math.max(graphics_scaled_height*tick_amplitude*2, tick_width/2)

    love.graphics.rectangle(
      'fill', graphics_width/2+i*tick_distance,
      graphics_height/2-tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )
    love.graphics.rectangle(
      'fill', graphics_width/2-(i+1)*tick_distance,
      graphics_height/2-tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )

    tick_amplitude_sum = tick_amplitude_sum+tick_amplitude
  end

  -- Used to manipulate the degree of fade (if enabled).
  tick_amplitude_average = tick_amplitude_sum/tick_count

end

function visualizer:keypressed(key, scancode, isrepeat)

  local function catch_nil() end
  (KEY_FUNCTIONS[key] or catch_nil)()

end

return visualizer