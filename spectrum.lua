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

local ffi = require("ffi")

--[[ Initialize FFI ]]
ffi.cdef[[
  float* fft(float *samples, int nSamples, int tickCount);
]]
local fft = ffi.load(ffi.os == "Windows" and "fft" or "./libfft.dylib")

--[[ Initialize Variables ]]
-- Variables for FFT.
local visualization = {}
local sampling_size = config.sampling_size
local old_sample = 0
local samples_ptr = nil

-- Variables for drawing the visualization.
local visualizer_type = config.visualization
local tick_amplitude_average = 0
local tick_count = 128
local fade_activated = config.fade
local fade_intensity_multiplier = config.fade_intensity_multiplier

--[[ Functions ]]
--- Reloads visualization variables that affect the menu.
-- Necessary for returning to the main menu.
function visualization.reload()

  -- Variables for FFT.
  old_sample = 0
  samples_ptr = nil

  -- Variables for drawing the visualization.
  tick_amplitude_average = 0
  
end

--- Runs FFT on music file samples and obtains the next waveform.
-- @return table: Waveform output of FFT.
function visualization.generateMusicWaveform()

  local normalized_samples = {}
  local channels = audio.getChannels()

  --[[ Generates sample input for FFT from sound data. Optimized
  to take any number of channels (ex: Mono, Stereo, 5.1, 7.1).
  Not completely supported by Love2D yet. ]]
  local range = 2*audio.getQueueSize()*audio.getDecoderBuffer()/(audio.getBitDepth()/8)
  for i=1, sampling_size do
    -- Obtain necessary samples.
    local new_sample = 0
    for j=0, channels-1 do
      local sample_index = range/2-sampling_size*channels/2+(i-1)*channels+j
      new_sample = new_sample+audio.music.getSample(sample_index)
    end
    
    -- X channels of sound data -> 1 channel of sound data; for FFT input.
    local sample_average = new_sample/channels
    
    -- Build FFT input.
    table.insert(normalized_samples, sample_average)
  end
  
  -- Sample memoization.
  old_sample = audio.music.tellSong('samples')

  --[[ Samples -> Waveform using FFI ]]
  --[[ Allocates and stores samples in memory.  Do
  NOT destroy or allocation won't be maintained. ]]
  samples_ptr = ffi.new("float["..sampling_size.."]", normalized_samples)
  
  -- Lua Variables -> FFI/C Variables
  local sample_count_ptr = ffi.new("int", sampling_size)
  local tick_count_ptr = ffi.new("int", tick_count)

  return fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
  
end

--- Runs FFT on Recording Device samples and obtains the next waveform.
-- @return table: Waveform output of FFT.
function visualization.generateRecordingDeviceWaveform()

  local normalized_samples = {}
  local channels = audio.getChannels()
  
  --[[ Generates sample input for FFT from sound data. Optimized
  to take any number of channels (ex: Mono, Stereo, 5.1, 7.1).
  Not completely supported by Love2D yet. ]]
  for i=1, sampling_size do
    -- Obtain necessary samples.
    local new_sample = 0
    for j=0, channels-1 do
      local sample_index = audio.recordingdevice.getSampleSum()-sampling_size*channels+(i-1)*channels+j
      new_sample = new_sample+audio.recordingdevice.getSample(sample_index)
    end
    
    -- X channels of sound data -> 1 channel of sound data; for FFT input.
    local sample_average = new_sample/channels
    
    -- Build FFT input.
    table.insert(normalized_samples, sample_average)
  end

  --[[ Samples -> Waveform using FFI ]]
  --[[ Allocates and stores samples in memory.  Do
  NOT destroy or allocation won't be maintained. ]]
  samples_ptr = ffi.new("float["..sampling_size.."]", normalized_samples)
  
  -- Lua Variables -> FFI/C Variables
  local sample_count_ptr = ffi.new("int", sampling_size)
  local tick_count_ptr = ffi.new("int", tick_count)

  return fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
  
end

--- Handles all drawing of visualization.
-- @param table: Waveform FFT of samples.
function visualization.draw(waveform)

  local tick_distance
  local tick_width
  local graphics_width = gui.graphics.getWidth()
  local graphics_height = gui.graphics.getHeight()
  
  -- Scales visualization at a decreasing rate.
  local graphics_scaled_height = math.max(71.138*graphics_height^(1/3), graphics_height)

  -- Load properties of bar visualization.
  if visualizer_type == 1 then
    tick_count = 48
    tick_distance = graphics_width/(tick_count*2)
    tick_width = graphics_width/(tick_count*5.5)
  elseif visualizer_type == 2 then
    tick_count = 64
    tick_distance = graphics_width/(tick_count*2)
    tick_width = graphics_width/(tick_count*4.3)
  elseif visualizer_type == 3 then
    tick_count = 128
    local tick_padding = 2
    tick_distance = graphics_width/((tick_count+tick_padding)*2)
    tick_width = tick_distance
  elseif visualizer_type == 4 then
    tick_count = 256
    tick_distance = graphics_width/(tick_count*2)
    tick_width = tick_distance
  end

  if fade_activated then
    gui.graphics.setColor(nil, (.03-tick_amplitude_average)*fade_intensity_multiplier)
  else
    gui.graphics.setColor()
  end
  
  --[[ Draw bar visualization ]]
  -- If no waveform, skip drawing of bar visualization.
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
      graphics_height/2 - tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )
    love.graphics.rectangle(
      'fill', graphics_width/2-(i+1)*tick_distance,
      graphics_height/2 - tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )

    tick_amplitude_sum = tick_amplitude_sum + tick_amplitude
  end

  -- Used to manipulate the degree of fade (if enabled).
  tick_amplitude_average = tick_amplitude_sum/tick_count
  
end

--- Sets the type of bar visualization.
-- @param number: An integer of 1-4.  Each changes the bar visualization properties.
function visualization.set(v)

  visualizer_type = v
  
end

--- Obtains the type of bar visualization.
-- @return number: An integer of 1-4.  The type of bar visualization.
function visualization.get()

  return visualizer_type
  
end

--- Enable/Disable fade.
-- @param boolean: Fade option.
function visualization.setFade(f)

  fade_activated = f
  
  -- If disabled, fade intensity becomes 0.
  if not f then
    gui.graphics.setColor(nil, 0)
  end
  
end

--- Obtains status of fade activation.
-- @return boolean: A boolean representing the status of fade activation.
function visualization.isFading()

  return fade_activated
  
end

--- Determines if the visualization would change if an FFT was performed.
--- Aka, is there any point to running an FFT?
-- Just a bit of FFT memoization for efficiency.
-- @return boolean: True if the visualization would change.  False otherwise.
function visualization.wouldChange()

  -- For when playing music from files.
  if (audio.music.tellSong('samples') ~= old_sample) then
    return true
  end
  
  -- For when using a Recording Device.
  if audio.recordingdevice.isActive() then
    return not audio.isPaused()
  end
  
  return false
  
end

--- Obtains FFT input size of audio being sampled.
-- @returns number: A number representing the sampling size.
function visualization.getSamplingSize()

  return sampling_size
  
end

return visualization