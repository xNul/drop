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
local waveform = {}
local sampling_size = config.sampling_size
local old_sample = 0
local samples_ptr = nil

-- Variables for drawing the visualization.
local default_visualizer = config.visualization
local tick_count = 128
local fade_activated = config.fade
local fade_intensity_multiplier = config.fade_intensity_multiplier

if not love.filesystem.getInfo("visualizers") then
  love.filesystem.createDirectory("visualizers")
end

local visualizers = love.filesystem.getDirectoryItems("visualizers")

--[[ Functions ]]
--- Reloads visualization variables that affect the menu.
-- Necessary for returning to the main menu.
function visualization.reload()

  -- Variables for FFT.
  waveform = {}
  old_sample = 0
  samples_ptr = nil
  
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

  waveform = fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
  
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

  waveform = fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
  
end

function visualization.load()

  -- if not default set then,
  visualizer = require("visualizers/"..visualizers[1].."/"..visualizers[1])
  visualizer:load()

end

--- Handles all drawing of visualization.
-- @param waveform table: Waveform FFT of samples.
function visualization.draw()

  visualizer:draw(waveform)
  
end

--- Sets the visualization.
-- @param name string: The name of the visualization.
function visualization.set(name)

  visualizers = love.filesystem.getDirectoryItems("visualizers")

  for i,v in ipairs(visualizers) do
    if v == name then
      visualizer = require("visualizers/"..visualizers[name].."/"..visualizers[name])
      return
    end
  end
  
  print(os.date('[%H:%M] ').."Unable to set visualizer to: "..name)
  
end

--- Obtains the type of bar visualization.
-- @return number: An integer of 1-4.  The type of bar visualization.
function visualization.getName()

  return visualizer:getInfo().name
  
end

--- Enable/Disable fade.
-- @param f boolean: Fade option.
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