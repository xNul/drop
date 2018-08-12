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

local audio = {
  music = {},
  recordingdevice = {}
}

local id3 = require("id3")

local sample_sum = 0
local sample_counts = {0, 0, 0, 0, 0, 0, 0, 0}
local sounddata_array = {}
local decoder_buffer = 2048
local decoder = nil
local channels = 0
local bit_depth = 0
local sample_rate = 0
local queue_size = 0
local seconds_per_buffer = 0
local free_buffers_old = 0
local end_of_song = false

local current_song = nil
local music_list = nil
local song_id = 0
local audio_title = nil
local time_count = 0
local recording_device = nil
local rd_active = false
local rd_sample_rate = config.rd_sample_rate
local rd_bit_depth = config.rd_bit_depth
local rd_channels = config.rd_channels
local music_volume = config.volume
local init_mute = config.mute
local init_volume = config.volume
local unmute_volume = 0
local is_paused = false
local loop_toggle = config.loop
local shuffle_toggle = config.shuffle
local shuffle_history = {}

if not love.filesystem.getInfo("music") then
  love.filesystem.createDirectory("music")
end
if not love.filesystem.getInfo("mount") then
  love.filesystem.createDirectory("mount")
end

--- Reloads audio variables that affect the menu.
-- Necessary for returning to the main menu.
function audio.reload()

  if audio.music.exists() then
    music_volume = love.audio.getVolume()
  end
  if current_song then
    audio.stop()
  end
  
  sample_sum = 0
  sample_counts = {0, 0, 0, 0, 0, 0, 0, 0}
  sounddata_array = {}
  decoder = nil
  channels = 0
  bit_depth = 0
  sample_rate = 0
  queue_size = 0
  seconds_per_buffer = 0
  free_buffers_old = 0
  end_of_song = false
  
  current_song = nil
  music_list = nil
  song_id = 0
  audio_title = nil
  time_count = 0
  recording_device = nil
  rd_active = false
  is_paused = false
  shuffle_history = {}
  
end

--- Attempts to load music in the folder "mount".
-- @return boolean: True if successful.  False otherwise.
function audio.music.load()

  if rd_active then
    return
  end

  shuffle_history = {}
  music_list = audio.music.recursiveEnumerate("mount")

  if not next(music_list) then
    music_list = nil
    print(os.date('[%H:%M] ').."Failed to load music.")
    
    return false
  end

  return true
  
end

--- Adds a single music file to playlist.
-- @param file File: Music file object.
function audio.music.addSong(file)

  if rd_active then
    return
  end
  
  if not music_list then
    music_list = {}
  end
  
  local format_table = {
    ".mp3", ".wav", ".ogg", ".oga", ".ogv",
    ".699", ".amf", ".ams", ".dbm", ".dmf",
    ".dsm", ".far", ".pat", ".j2b", ".mdl",
    ".med", ".mod", ".mt2", ".mtm", ".okt",
    ".psm", ".s3m", ".stm", ".ult", ".umx",
    ".abc", ".mid"
  }
  
  -- Check for supported audio format.
  local filename = file:getFilename()
  local valid_format = false
  for i,v in ipairs(format_table) do
    if filename:sub(-4) == v then
      valid_format = true
      break
    end
  end
  
  -- Add music file to playlist.
  if valid_format then
    local index = #music_list+1
    music_list[index] = {}
    music_list[index][1] = file
    -- Remove file path from string and save it as the song's title.
    music_list[index][2] = filename:sub((string.find(filename, "\\[^\\]*$") or string.find(filename, "/[^/]*$") or 0)+1, -5)
  
  -- Throw error when not a valid format.
  else
    print(os.date('[%H:%M] ').."Failed to add song to music.  Invalid format "..filename:sub(-3)..".")
  end
  
end

--- Processes music file samples and maintains sounddata table.
function audio.music.update()

  -- Plays first song.
  if not current_song then
    if init_mute then
      unmute_volume = init_volume
      gui.buttons.volume.activate("volume1")
    else
      gui.buttons.volume.activate(music_volume)
    end
    
    audio.music.changeSong(1)
  end
  
  -- If window was dragged, restart audio.
  if not is_paused and not current_song:isPlaying() then
    audio.play()
  end

  --[[ Manage decoder processing and audio queue. ]]
  -- If new sounddata available, process it.
  local free_buffers = current_song:getFreeBufferCount()
  if free_buffers > 0 and not is_paused then
    if end_of_song then
      -- Update time_count for the last final miliseconds of the song.
      time_count = time_count+(free_buffers-free_buffers_old)*seconds_per_buffer
      free_buffers_old = free_buffers
    else
      time_count = time_count+free_buffers*seconds_per_buffer
    end

    -- Time to make room for new sounddata.  Shift everything.
    for i=1, 2*queue_size do
      sounddata_array[i] = sounddata_array[i+free_buffers]
    end

    -- Retrieve new sounddata.
    while free_buffers > 0 do
      local sounddata = decoder:decode()
      if sounddata then
        current_song:queue(sounddata)
      elseif not end_of_song then
        time_count = time_count-free_buffers*seconds_per_buffer
        free_buffers_old = free_buffers
        end_of_song = true
      end
      
      sounddata_array[2*queue_size-free_buffers+1] = sounddata
      free_buffers = free_buffers-1
    end
  end
  
  -- When song finished, play next one.
  if current_song:getFreeBufferCount() >= queue_size and not is_paused then
    audio.music.changeSong(1)
  end
  
end

--- Obtains specified music file sample from sounddata table.
-- @param buffer number: Sample from stored sounddata. Range: 1-sample_range
function audio.music.getSample(buffer)

  local sample_range = decoder_buffer/(bit_depth/8)
  local sample = buffer/sample_range
  local index = math.floor(sample)
  
  -- Finds requested sample in decoder sounddata.
  if audio.music.tellSong('samples')+buffer < decoder:getDuration()*sample_rate then
    return sounddata_array[index+1]:getSample((sample-index)*sample_range)
  else
    return 0
  end
  
end

--- Play next or previous music file.
-- @param number number: -1 for previous, 0 for current, 1 for next.
function audio.music.changeSong(number)

  if rd_active or not audio.music.exists() then
    return
  end
  
  -- Handles loop and shuffle.
  if not loop_toggle then
    if shuffle_toggle then
      -- Recall last song and select it.
      if number == -1 then
        if #shuffle_history > 1 then
          song_id = shuffle_history[#shuffle_history-1]
          shuffle_history[#shuffle_history] = nil
        end
      
      -- Select random new song and remember the past one.
      elseif number == 1 then
        song_id = math.random(1, #music_list)
        if #shuffle_history >= 10 then
          table.remove(shuffle_history, 1)
        end
        
        shuffle_history[#shuffle_history+1] = song_id
      end
    else
      song_id = song_id+number
    end
  end

  -- Cycles playlist.
  if song_id < 1 then
    song_id = #music_list
  elseif song_id > #music_list then
    song_id = 1
  end

  -- Setups decoder info.
  decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
  sample_rate = decoder:getSampleRate()
  bit_depth = decoder:getBitDepth()
  channels = decoder:getChannelCount()
  seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

  -- Start song queue.
  queue_size = 4+math.max(math.floor(2*visualization.getSamplingSize()/(decoder_buffer/(bit_depth/8))), 1)
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- Music initialization.
  time_count = 0
  end_of_song = false
  free_buffers_old = 0
  audio_title = music_list[song_id][2]
  gui.buttons.scrubbar.setTimestampEnd(audio.music.getDuration())
  
  -- Populates queue and sounddata table.
  local sounddata = decoder:decode()
  for i=1, queue_size+1 do
    sounddata_array[i] = sounddata
  end
  
  current_song:queue(sounddata)
  
  local free_buffers = current_song:getFreeBufferCount()
  for i=queue_size-free_buffers+1, queue_size do
    sounddata = decoder:decode()
    if sounddata then
      current_song:queue(sounddata)
    end
    
    sounddata_array[queue_size+i] = sounddata
  end

  if is_paused then
    audio.pause()
  else
    audio.play()
  end
  
end

--- Move to 't' position in music file.
-- @param t number: Time to seek to in music file.
function audio.music.seekSong(t)

  time_count = t
  
  -- Account for when t is out-of-bounds.
  if t < 0 then
    audio.music.changeSong(-1)
    audio.music.seekSong(audio.music.getDuration())
    return
  end
  
  if t > audio.music.getDuration() then
    audio.music.changeSong(1)
    audio.music.seekSong(0)
    return
  end
  
  -- Fill sounddata table with dummy data for negative points in time.
  local start = 1
  local offset_time = t-queue_size*seconds_per_buffer
  if offset_time < 0 then
    decoder:seek(0)
    
    local sounddata = decoder:decode()
    local queue_pos = math.ceil((offset_time*-1)/seconds_per_buffer)
    for i=start, queue_pos+1 do
      sounddata_array[i] = sounddata
    end
    
    start = queue_pos+2
    offset_time = queue_pos*seconds_per_buffer+offset_time
  end
  
  decoder:seek(offset_time)
  
  -- Fill remaining first half of sounddata table with valid sounddata.
  for i=start, queue_size do
    local sounddata = decoder:decode()
    if sounddata then
      sounddata_array[i] = sounddata
    else
      break
    end
  end
  
  -- Clear queued audio.
  current_song:stop()
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- Fill audio queue and remaining half of sounddata table with valid sounddata.
  for i=1, queue_size do
    local sounddata = decoder:decode()
    if sounddata then
      current_song:queue(sounddata)
    end
    
    sounddata_array[queue_size+i] = sounddata
  end
  
end

--- Recursively enumerate through all subdirectories,
--- loading all compatible music files.
-- @param folder string: Path to folder tree that needs indexed.
-- @return table: A table containing references to all
-- compatible music file File objects and their titles.
function audio.music.recursiveEnumerate(folder)

  local format_table = {
    ".mp3", ".wav", ".ogg", ".oga", ".ogv",
    ".699", ".amf", ".ams", ".dbm", ".dmf",
    ".dsm", ".far", ".pat", ".j2b", ".mdl",
    ".med", ".mod", ".mt2", ".mtm", ".okt",
    ".psm", ".s3m", ".stm", ".ult", ".umx",
    ".abc", ".mid"
  }

  local lfs = love.filesystem
  local music_table = lfs.getDirectoryItems(folder)
  local complete_music_table = {}
  local valid_format = false
  local index = 1

  -- Loop through directory items.
  for i,v in ipairs(music_table) do
    -- Check for supported audio format.
    local file = folder.."/"..v
    for j,w in ipairs(format_table) do
      if v:sub(-4) == w then
        valid_format = true
        break
      end
    end
    
    -- Add music file to playlist.
    if lfs.getInfo(file)["type"] == "file" and valid_format then
      complete_music_table[index] = {}
      complete_music_table[index][1] = lfs.newFile(file)
      local song_title = v:sub(1, -5)
      
      -- Generate song title from ID3 metadata supported file types.
      if v:sub(-4) == ".mp3" then
        local tags = id3.readtags(complete_music_table[index][1])
        if tags and tags.title and tags.title ~= "" and tags.artist and tags.artist ~= "" then
          song_title = tags.artist:gsub("[^\x20-\x7E]", '').." - "..tags.title:gsub("[^\x20-\x7E]", '')
        end
      end
      complete_music_table[index][2] = song_title

      index = index+1
      valid_format = false
    
    -- Recursively search subdirectory and add found music files to playlist.
    elseif lfs.getInfo(file)["type"] == "directory" then
      local recursive_table = audio.music.recursiveEnumerate(file)
      for j,w in ipairs(recursive_table) do
        complete_music_table[index] = {}
        complete_music_table[index][1] = w[1]
        complete_music_table[index][2] = w[2]
        
        index = index+1
      end
    end
  end

  return complete_music_table
  
end

--- Gets specified sample from stored sounddata.
-- @param[opt] unit string: Unit in which to return.
-- @return number: Current position in music file (seconds or samples).
function audio.music.tellSong(unit)

  if unit == 'samples' then
    return time_count*sample_rate
  else
    return time_count
  end
  
end

--- Gets whether or not any music files have been loaded.
-- @return boolean: True if any music files have been loaded.  False otherwise.
function audio.music.exists()

  return music_list ~= nil
  
end

--- Gets the duration of currently playing music file.
-- @return number: The duration of currently playing music file.
function audio.music.getDuration()

  return decoder ~= nil and decoder:getDuration() or 0
  
end

--- Gets the volume of music option.
-- When switching from playing music files to playing a
-- Recording Device, the volume is stored in music_volume.
-- @return number: Volume of music option.
function audio.music.getVolume()

  return music_volume
  
end






--- Initializes specified Recording Device.
-- @param device RecordingDevice: Recording Device to load.
function audio.recordingdevice.load(device)

  device:start(2048, rd_sample_rate, rd_bit_depth, rd_channels)
  rd_active = true
  recording_device = device
  
  audio_title = "Audio Input: "..device:getName()
  
  -- Setup sounddata info.
  sample_rate = device:getSampleRate()
  bit_depth = device:getBitDepth()
  channels = device:getChannelCount()
  
  queue_size = 8
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  gui.buttons.volume.activate("volume1")
  
end

--- Processes Recording Device samples and maintains sounddata table.
function audio.recordingdevice.update()

  -- Manage decoder processing and audio queue.
  local current_sample_count = recording_device:getSampleCount()
  if current_sample_count >= 448 and not is_paused then
    sample_sum = sample_sum+current_sample_count-sample_counts[1]
  
    -- Time to make room for new sounddata.  Shift everything.
    for i=1, queue_size do
      sounddata_array[i] = sounddata_array[i+1]
      sample_counts[i] = sample_counts[i+1]
    end

    local sounddata = recording_device:getData()
    sounddata_array[queue_size] = sounddata
    sample_counts[queue_size] = current_sample_count
    current_song:queue(sounddata)
    
    if not current_song:isPlaying() then
      current_song:play()
    end
  end
  
end

--- Gets specified sample from stored sounddata.
-- @param buffer number: Sample from stored sounddata. Range: 1-sample_sum
-- @return number: Specified sample.
function audio.recordingdevice.getSample(buffer)

  local sample
  local index
  local found_flag = false
  local sum = 0
  
  --[[ Determines which sounddata object and which
  sample within that sounddata needs to be accessed. ]]
  for i=1, #sample_counts do
    sum = sum+sample_counts[i]
    if buffer < sum then
      index = i
      sample = buffer-(sum-sample_counts[i])
      found_flag = true
      break
    end
  end
  
  -- When buffer > sample_sum.  Aka requesting a sample we don't have.
  if not found_flag then
    return 0
  end
  
  -- Finds requested sample in decoder sounddata.
  return sounddata_array[index]:getSample(sample)
  
end

--- Determines if there's enough Recording Device sounddata to produce a waveform.
-- @return boolean: True if there's enough sounddata.  False otherwise.
function audio.recordingdevice.isReady()

  return (sample_sum >= visualization.getSamplingSize()*channels) and rd_active
  
end

--- Determines if a Recording Device is being used.
-- @return boolean: True if is being used.  False otherwise.
function audio.recordingdevice.isActive()

  return rd_active
  
end

--- Gets the amount of Recording Device sounddata in the sounddata table.
-- @return number: Number of samples.
function audio.recordingdevice.getSampleSum()

  return sample_sum
  
end










--- Plays audio.
function audio.play()

  is_paused = false
  if rd_active then
    recording_device:start(2048, rd_sample_rate, rd_bit_depth, rd_channels)
  end
  
  current_song:play()
  
end

--- Determines if audio is playing.
-- @return boolean: True for playing.  False otherwise.
function audio.isPlaying()

  return (current_song ~= nil) and current_song:isPlaying()
  
end

--- Pauses audio.
function audio.pause()

  is_paused = true
  if rd_active then
    recording_device:stop()
  end
  
  current_song:pause()
  
end

--- Determines if audio is paused.
-- @return boolean: True for paused.  False otherwise.
function audio.isPaused()

  return is_paused
  
end

--- Toggles mute.
function audio.toggleMute()

  if audio.isMuted() then
    gui.buttons.volume.activate(unmute_volume)
    unmute_volume = 0
  else
    unmute_volume = love.audio.getVolume()
    gui.buttons.volume.activate("volume1")
  end
  
end

--- Determines if audio is muted.
-- @return boolean: True for muted.  False otherwise.
function audio.isMuted()

  return love.audio.getVolume() == 0 and unmute_volume ~= 0
  
end

--- Stops playback of current audio.
function audio.stop()

  current_song:stop()
  if rd_active then
    recording_device:stop()
    rd_active = false
  end
  
  gui.buttons.scrubbar.setTimestampStart(0)
  gui.buttons.scrubbar.setTimestampEnd(0)
  
end

--- Gets the number of samples in a decoder buffer.
-- @return number: Samples in a decoder buffer.
function audio.getDecoderBuffer()

  return decoder_buffer
  
end

--- Gets the number of channels in current audio.
-- @return number: Channels in current audio.
function audio.getChannels()

  return channels
  
end

--- Gets the bit depth of current audio.
-- @return number: Bit depth of current audio.
function audio.getBitDepth()

  return bit_depth
  
end

--- Gets the sample rate of current audio.
-- @return number: Sample rate of current audio.
function audio.getSampleRate()

  return sample_rate
  
end

--- Gets how many decoder buffers can be queued.
-- @return number: How many decoder buffers can be queued.
function audio.getQueueSize()

  return queue_size
  
end

--- Gets title of the current audio playing.
-- @return string: Title of the current audio playing.
function audio.getTitle()

  return audio_title
  
end

--- Gets the volume from before muted.
-- @return number: Volume before muted.
function audio.getUnmuteVolume()

  return unmute_volume
  
end

--- Toggles loop.
function audio.toggleLoop()

  loop_toggle = not loop_toggle
  
end

--- Determines if loop is activated.
-- @return boolean: True for activated.  False otherwise.
function audio.isLooping()

  return loop_toggle
  
end

--- Toggles shuffle.
function audio.toggleShuffle()

  shuffle_toggle = not shuffle_toggle
  
end

--- Determines if shuffle is activated.
-- @return boolean: True for activated.  False otherwise.
function audio.isShuffling()

  return shuffle_toggle
  
end

return audio