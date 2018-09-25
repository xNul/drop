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
local sampling_size = 2048
local old_sample = 0
local samples_ptr = nil

-- Variables for drawing the visualization.
local visualizer
local visualizer_objects = {}
local visualizer_configs = {}
local visualizer_name = config.visualization
local visualizer_names = {}
local visualizer_index = 1
local waveform_size = 128

--[[ Functions ]]
--- Reloads visualization variables that affect the menu.
-- Necessary for returning to the main menu.
function visualization.reload()

  -- Variables for FFT.
  waveform = {}
  old_sample = 0
  samples_ptr = nil
  
  -- Variables for visualization
  visualization.quitAll()
  visualizer_objects = {}
  visualizer_configs = {}
  visualizer_names = {}
  
end

--- Runs FFT on music file samples and obtains the next waveform.
-- @return table: Waveform output of FFT.
local function generateMusicWaveform()

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
  local waveform_size_ptr = ffi.new("int", waveform_size)

  waveform = fft.fft(samples_ptr, sample_count_ptr, waveform_size_ptr)
  
end

--- Runs FFT on Recording Device samples and obtains the next waveform.
-- @return table: Waveform output of FFT.
local function generateRecordingDeviceWaveform()

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
  local waveform_size_ptr = ffi.new("int", waveform_size)

  waveform = fft.fft(samples_ptr, sample_count_ptr, waveform_size_ptr)
  
end

function visualization.generateWaveform()

  -- Performs FFT to generate waveform.
  if audio.recordingdevice.isActive() then
    if audio.recordingdevice.isReady() then
      generateRecordingDeviceWaveform()
    end
  else
    generateMusicWaveform()
  end

end

local function prepareVisualizers()
  -- Ensure there is always at least one visualizer available.
  if not love.filesystem.getInfo("visualizers") then
    love.filesystem.createDirectory("visualizers")
    love.filesystem.createDirectory("visualizers/bar")
    love.filesystem.write("visualizers/bar/bar.lua", love.filesystem.read("bar.lua"))
  else
    local vis_found = false

    for i,v in ipairs(love.filesystem.getDirectoryItems("visualizers")) do
      if love.filesystem.getInfo("visualizers/"..v, "directory") and love.filesystem.getInfo("visualizers/"..v.."/"..v..".lua", "file") then
        -- Updates bar visualizer.
        if v == "bar" then
          local appdata_bar_chunk, errormsg = love.filesystem.load("visualizers/bar/bar.lua")
          local appdata_bar = appdata_bar_chunk()
          local main_bar_chunk, errormsg = love.filesystem.load("bar.lua")
          local main_bar = main_bar_chunk()
          
          if appdata_bar:getInfo().version < main_bar:getInfo().version then
            love.filesystem.write("visualizers/bar/bar.lua", love.filesystem.read("bar.lua"))
          end
        end
        
        vis_found = true
        break
      end
    end

    -- Creates missing files.
    if not vis_found then
      love.filesystem.createDirectory("visualizers/bar")
      love.filesystem.write("visualizers/bar/bar.lua", love.filesystem.read("bar.lua"))
    end
  end
end

function visualization.load()

  prepareVisualizers()
  visualizer_names = love.filesystem.getDirectoryItems("visualizers")

  if not (visualizer_name and love.filesystem.getInfo("visualizers/"..visualizer_name, "directory") and love.filesystem.getInfo("visualizers/"..visualizer_name.."/"..visualizer_name..".lua", "file")) then
    visualizer_name = visualizer_names[1]
    visualizer_index = 1
  else
    for i,v in ipairs(visualizer_names) do
      if v == visualizer_name then
        visualizer_index = i
        break
      end
    end
  end
  
  local visualizer_chunk, errormsg = love.filesystem.load("visualizers/"..visualizer_name.."/"..visualizer_name..".lua")
  visualizer = visualizer_chunk()
  visualization.callback("load")

end

function visualization.getWaveform()

  return waveform
  
end

--- Obtains the current visualizer's name.
-- @return string: The name of the current visualizer.
function visualization.getName()

  return visualizer_name
  
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

function visualization.callback(callback, ...)

  local function catch_nil() end
  ((visualizer ~= nil) and visualizer[callback] or catch_nil)(...)

end

function visualization.quitAll()

  local function catch_nil()end
  for key, value in pairs(visualizer_objects) do
    (value["quit"] or catch_nil)()
  end
  ((visualizer ~= nil) and visualizer["quit"] or catch_nil)()

end

function visualization.setWaveformSize(n)

  waveform_size = n

end

local function setVisualizer(index)

  if visualizer_index == index then
    return
  end

  visualization.callback("away")
  if not visualizer_configs[visualizer_index] or visualizer_configs[visualizer_index][1] then
    visualizer_objects[visualizer_index] = visualizer
  end
  visualizer_name = visualizer_names[index]
  visualizer_object_storing_enabled = true
  
  if visualizer_objects[index] then
    visualizer = visualizer_objects[index]
    visualizer_objects[index] = nil
    visualizer_index = index
    visualization.callback("back")
  else
    visualizer_index = index
    local visualizer_chunk, errormsg = love.filesystem.load("visualizers/"..visualizer_name.."/"..visualizer_name..".lua")
    visualizer = visualizer_chunk()
    
    if visualizer_configs[visualizer_index] and not visualizer_configs[visualizer_index][1] then
      visualization.callback("back")
    else
      visualization.callback("load")
    end
  end
  
end

function visualization.next()

  local index

  if visualizer_index+1 > #visualizer_names then
    index = 1
  else
    index = visualizer_index+1
  end
  
  setVisualizer(index)

end

function visualization.previous()

  local index
  
  if visualizer_index-1 < 1 then
    index = #visualizer_names
  else
    index = visualizer_index-1
  end
  
  setVisualizer(index)

end

function visualization.storeConfig(config_table)

  if not visualizer_configs[visualizer_index] then
    visualizer_configs[visualizer_index] = {true}
  end
  visualizer_configs[visualizer_index][2] = config_table

end

function visualization.retrieveConfig()

  return visualizer_configs[visualizer_index][2]

end

function visualization.setObjectStoring(option)

  if not visualizer_configs[visualizer_index] then
    visualizer_configs[visualizer_index] = {}
  end
  visualizer_configs[visualizer_index][1] = option

end

function visualization.setSamplingSize(ss)
  
  if ss ~= sampling_size and audio.exists() then
    if audio.recordingdevice.isActive() then
      audio.recordingdevice.resizeQueue(ss)
    else
      audio.music.resizeQueue(ss)
    end
    
    sampling_size = ss
  end

end

function visualization.getWaveformSize()

  return waveform_size

end

return visualization