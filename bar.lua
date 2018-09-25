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
local config = {
  ["fade_activated"] = false,
  ["sampling_size"] = 2048,
  ["visualization_type"] = 3,
  ["bar_amplitude_average"] = 0,
  ["fade_intensity_multiplier"] = 30
}

local KEY_FUNCTIONS = {
  ["i"] = function ()
    config.fade_activated = not config.fade_activated
    
    -- If disabled, fade intensity becomes 0.
    if not config.fade_activated then
      gui.graphics.setColor(nil, 0)
    end
  end,
  ["1"] = function ()
    visualization.setWaveformSize(48)
    visualization.generateWaveform()
  end,
  ["2"] = function ()
    visualization.setWaveformSize(64)
    visualization.generateWaveform()
  end,
  ["3"] = function ()
    visualization.setWaveformSize(128)
    visualization.generateWaveform()
  end,
  ["4"] = function ()
    visualization.setWaveformSize(256)
    visualization.generateWaveform()
  end
}

function visualizer:getInfo()
  
  return {
    ["name"] = "bar",
    ["author"] = "nabakin",
    ["version"] = 1
  }

end

function visualizer:load()

  if config.visualization_type == 1 then
    visualization.setWaveformSize(48)
  elseif config.visualization_type == 2 then
    visualization.setWaveformSize(64)
  elseif config.visualization_type == 3 then
    visualization.setWaveformSize(128)
  elseif config.visualization_type == 4 then
    visualization.setWaveformSize(256)
  end
  visualization.setSamplingSize(config.sampling_size)
  visualization.generateWaveform()

end

function visualizer:draw()

  local bar_distance
  local bar_width
  local waveform_size = visualization.getWaveformSize()
  local graphics_width = gui.graphics.getWidth()
  local graphics_height = gui.graphics.getHeight()
  
  -- Scales visualization at a decreasing rate.
  local graphics_scaled_height = math.max(71.138*graphics_height^(1/3), graphics_height)

  -- Load properties of bar visualization.
  if waveform_size == 48 then
    bar_distance = graphics_width/(waveform_size*2)
    bar_width = graphics_width/(waveform_size*5.5)
  elseif waveform_size == 64 then
    bar_distance = graphics_width/(waveform_size*2)
    bar_width = graphics_width/(waveform_size*4.3)
  elseif waveform_size == 128 then
    local bar_padding = 2
    bar_distance = graphics_width/((waveform_size+bar_padding)*2)
    bar_width = bar_distance
  elseif waveform_size == 256 then
    bar_distance = graphics_width/(waveform_size*2)
    bar_width = bar_distance
  end

  if config.fade_activated then
    gui.graphics.setColor(nil, (.03-config.bar_amplitude_average)*config.fade_intensity_multiplier)
  else
    gui.graphics.setColor()
  end
  
  local waveform = visualization.getWaveform()
  
  --[[ Draw bar visualizer ]]
  -- If no waveform, skip drawing of bar visualizer.
  if not waveform[0] then
    waveform_size = 0
  end
  
  -- Draw bars.
  local bar_amplitude_sum = 0
  for i=0, waveform_size-1 do
    local bar_amplitude = waveform[i]
    local bar_height = math.max(graphics_scaled_height*bar_amplitude*2, bar_width/2)

    love.graphics.rectangle(
      'fill', graphics_width/2+i*bar_distance,
      graphics_height/2-bar_height/2,
      bar_width, bar_height,
      bar_width/2, bar_width/2
    )
    love.graphics.rectangle(
      'fill', graphics_width/2-(i+1)*bar_distance,
      graphics_height/2-bar_height/2,
      bar_width, bar_height,
      bar_width/2, bar_width/2
    )

    bar_amplitude_sum = bar_amplitude_sum+bar_amplitude
  end

  -- Used to manipulate the degree of fade (if enabled).
  config.bar_amplitude_average = bar_amplitude_sum/waveform_size

end

function visualizer:away()

  visualization.setObjectStoring(false)
  visualization.storeConfig(config)

end

function visualizer:back()

  config = visualization.retrieveConfig()
  visualizer:load()

end

function visualizer:keypressed(key, scancode, isrepeat)

  local function catch_nil() end
  (KEY_FUNCTIONS[key] or catch_nil)()

end

return visualizer