local id3 = require("id3")

local audio = {}
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
local song_name = nil
local time_count = 0
local microphone_device = nil
local microphone_active = false
local music_volume = config.volume
local previous_volume = 0
local is_paused = false
local loop_toggle = config.loop
local shuffle_toggle = config.shuffle
local shuffle_history = {}

if not love.filesystem.getInfo("music") then
  love.filesystem.createDirectory("music")
end

function audio.reload()
  if audio.musicExists() then music_volume = love.audio.getVolume() end
  if current_song ~= nil then audio.stop() end
  
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
  song_name = nil
  time_count = 0
  microphone_device = nil
  microphone_active = false
  is_paused = false
  shuffle_history = {}
end

function audio.loadMusic()
  if microphone_active then return end

  shuffle_history = {}
  music_list = audio.recursiveEnumerate("music")

  if next(music_list) == nil then
    music_list = nil
    return false
  end

  return true
end

function audio.addSong(file)
  if microphone_active then return end

  if music_list == nil then
    music_list = {}
  end
  
  local format_table = {
    ".mp3", ".wav", ".ogg", ".oga", ".ogv",
    ".699", ".amf", ".ams", ".dbm", ".dmf",
    ".dsm", ".far", ".pat", ".j2b", ".mdl",
    ".med", ".mod", ".mt2", ".mtm", ".okt",
    ".psm", ".s3m", ".stm", ".ult", ".umx",
    ".xm", ".abc", ".mid", ".it"
  }
  
  local filename = file:getFilename()
  local valid_format = false
  for i,v in ipairs(format_table) do
    if filename:sub(-4) == v then
      valid_format = true
      break
    end
  end
  
  if valid_format then
    local index = #music_list+1
    music_list[index] = {}
    music_list[index][1] = file
    music_list[index][2] = filename:sub((string.find(filename, "\\[^\\]*$") or string.find(filename, "/[^/]*$") or 0)+1, -5)
  end
end

function audio.loadMicrophone(device)
  device:start(2048, 44100, 16, 1)
  microphone_active = true
  microphone_device = device
  
  song_name = "Audio Input: "..device:getName()
  
  -- setup sounddata info
  sample_rate = device:getSampleRate()
  bit_depth = device:getBitDepth()
  channels = device:getChannelCount()
  
  queue_size = 8
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  gui.buttons.volume.activate("volume1")
end

function audio.isMicrophoneActive()
  return microphone_active
end

function audio.update()
  -- plays first song
  if current_song == nil then
    if config.mute then
      previous_volume = config.volume
      gui.buttons.volume.activate("volume1")
    else
      gui.buttons.volume.activate(music_volume)
    end
    audio.changeSong(1)
  end
  
  -- if window was dragged, restart song
  if not is_paused and not current_song:isPlaying() then
    audio.play()
  end

  -- manage decoder processing and audio queue
  local free_buffers = current_song:getFreeBufferCount()
  if free_buffers > 0 and not is_paused then
    if end_of_song then
      -- update time_count for the last final miliseconds of the song
      time_count = time_count+(free_buffers-free_buffers_old)*seconds_per_buffer
      free_buffers_old = free_buffers
    else
      time_count = time_count+free_buffers*seconds_per_buffer
    end

    -- time to make room for new sounddata.  Shift everything.
    for i=1, 2*queue_size do
      sounddata_array[i] = sounddata_array[i+free_buffers]
    end

    -- retrieve new sounddata
    while free_buffers > 0 do
      local sounddata = decoder:decode()
      if sounddata ~= nil then
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
  
  -- when song finished, play next one
  if current_song:getFreeBufferCount() >= queue_size and not is_paused then
    audio.changeSong(1)
  end
end

function audio.updateMicrophone()
  -- manage decoder processing and audio queue
  local current_sample_count = microphone_device:getSampleCount()
  if current_sample_count >= 448 and not is_paused then
    sample_sum = sample_sum+current_sample_count-sample_counts[1]
  
    -- time to make room for new sounddata.  Shift everything.
    for i=1, queue_size do
      sounddata_array[i] = sounddata_array[i+1]
      sample_counts[i] = sample_counts[i+1]
    end

    local sounddata = microphone_device:getData()
    sounddata_array[queue_size] = sounddata
    sample_counts[queue_size] = current_sample_count
    current_song:queue(sounddata)
    
    if not current_song:isPlaying() then current_song:play() end
  end
end

-- finds sample using decoders
function audio.getDecoderSample(buffer)
  local sample_range = decoder_buffer/(bit_depth/8)
  local sample = buffer/sample_range
  local index = math.floor(sample)
  
  -- finds sample using decoders
  if audio.decoderTell('samples')+buffer < decoder:getDuration()*sample_rate then
    return sounddata_array[index+1]:getSample((sample-index)*sample_range)
  else
    return 0
  end
end

function audio.getMicrophoneSample(buffer)
  local sample
  local index
  local found_flag = false
  local sum = 0
  
  for i=1, #sample_counts do
    sum = sum+sample_counts[i]
    if buffer < sum then
      index = i
      sample = buffer-(sum-sample_counts[i])
      found_flag = true
      break
    end
  end
  
  if not found_flag then return 0 end
  
  -- finds sample using decoders
  return sounddata_array[index]:getSample(sample)
end

function audio.play()
  is_paused = false
  if microphone_active then
    microphone_device:start(2048, 44100, 16, 1)
  end
  current_song:play()
end

function audio.isPlaying()
  return (current_song ~= nil) and current_song:isPlaying() or false
end

function audio.pause()
  is_paused = true
  if microphone_active then
    microphone_device:stop()
  end
  current_song:pause()
end

function audio.isPaused()
  return is_paused
end

function audio.mute()
  if audio.isMuted() then
    gui.buttons.volume.activate(previous_volume)
    previous_volume = 0
  else
    previous_volume = love.audio.getVolume()
    gui.buttons.volume.activate("volume1")
  end
end

function audio.isMuted()
  return love.audio.getVolume() == 0 and previous_volume ~= 0
end

function audio.stop()
  current_song:stop()
  if microphone_active then
    microphone_device:stop()
    microphone_active = false
  end
  
  gui.buttons.scrubbar.setTimestampStart(0)
  gui.buttons.scrubbar.setTimestampEnd(0)
end

-- returns position in song
function audio.decoderTell(unit)
  if unit == 'samples' then
    return time_count*sample_rate
  else
    return time_count
  end
end

function audio.getDuration()
  return decoder ~= nil and decoder:getDuration() or 0
end

function audio.getSampleSum()
  return sample_sum
end

function audio.getDecoderBuffer()
  return decoder_buffer
end

function audio.getChannels()
  return channels
end

function audio.getBitDepth()
  return bit_depth
end

function audio.getSampleRate()
  return sample_rate
end

function audio.getQueueSize()
  return queue_size
end

function audio.musicExists()
  return music_list ~= nil
end

function audio.getSongName()
  return song_name
end

function audio.getMusicVolume()
  return music_volume
end

function audio.getPreviousVolume()
  return previous_volume
end

function audio.toggleLoop()
  loop_toggle = not loop_toggle
end

function audio.isLooping()
  return loop_toggle
end

function audio.toggleShuffle()
  shuffle_toggle = not shuffle_toggle
end

function audio.isShuffling()
  return shuffle_toggle
end

-- Song Handling --
-- only pass 0, 1, and -1 for now
function audio.changeSong(number)
  if microphone_active or not audio.musicExists() then return end

  if not loop_toggle then
    if shuffle_toggle then
      if number == -1 then
        if #shuffle_history > 1 then
          song_id = shuffle_history[#shuffle_history-1]
          shuffle_history[#shuffle_history] = nil
        end
      else
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

  -- loops song table
  if song_id < 1 then
    song_id = #music_list
  elseif song_id > #music_list then
    song_id = 1
  end

  -- setup decoder info
  decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
  sample_rate = decoder:getSampleRate()
  bit_depth = decoder:getBitDepth()
  channels = decoder:getChannelCount()
  seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

  -- start song queue
  queue_size = 4+math.max(math.floor(2*spectrum.getSize()/(decoder_buffer/(bit_depth/8))), 1)
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- song/decoder initialization
  song_name = music_list[song_id][2]
  time_count = 0
  gui.buttons.scrubbar.setTimestampEnd(audio.getDuration())
  end_of_song = false
  free_buffers_old = 0
  
  -- populates queue and decoder array
  local sounddata = decoder:decode()
  for i=1, queue_size+1 do
    sounddata_array[i] = sounddata
  end
  current_song:queue(sounddata)
  
  local free_buffers = current_song:getFreeBufferCount()
  for i=queue_size-free_buffers+1, queue_size do
    sounddata = decoder:decode()
    if sounddata ~= nil then
      current_song:queue(sounddata)
    end
    sounddata_array[queue_size+i] = sounddata
  end

  if is_paused then audio.pause() else audio.play() end
end

-- goes to position in song
function audio.decoderSeek(t)
  time_count = t
  
  if t < 0 then
    audio.changeSong(-1)
    audio.decoderSeek(audio.getDuration())
    return
  end
  
  if t > audio.getDuration() then
    audio.changeSong(1)
    audio.decoderSeek(0)
    return
  end
  
  -- fill sounddata_array with dummy data
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
  
  -- fill with new sounddata
  for i=start, queue_size do
    local sounddata = decoder:decode()
    if sounddata ~= nil then
      sounddata_array[i] = sounddata
    else
      break
    end
  end
  
  -- clear queued audio
  current_song:stop()
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- fill with new sounddata
  for i=1, queue_size do
    local sounddata = decoder:decode()
    if sounddata ~= nil then
      current_song:queue(sounddata)
    end
    sounddata_array[queue_size+i] = sounddata
  end
end

-- File Handling --
function audio.recursiveEnumerate(folder)
  local format_table = {
    ".mp3", ".wav", ".ogg", ".oga", ".ogv",
    ".699", ".amf", ".ams", ".dbm", ".dmf",
    ".dsm", ".far", ".pat", ".j2b", ".mdl",
    ".med", ".mod", ".mt2", ".mtm", ".okt",
    ".psm", ".s3m", ".stm", ".ult", ".umx",
    ".xm", ".abc", ".mid", ".it"
  }

  local lfs = love.filesystem
  local music_table = lfs.getDirectoryItems(folder)
  local complete_music_table = {}
  local valid_format = false
  local index = 1

  for i,v in ipairs(music_table) do
    local file = folder.."/"..v
    for j,w in ipairs(format_table) do
      if v:sub(-4) == w then
        valid_format = true
        break
      end
    end
    if lfs.getInfo(file)["type"] == "file" and valid_format then
      complete_music_table[index] = {}
      complete_music_table[index][1] = lfs.newFile(file)
      local song_title = v:sub(1, -5)
      if v:sub(-4) == ".mp3" then
        local tags = id3.readtags(complete_music_table[index][1])
        if tags ~= nil and tags.title ~= nil and tags.title ~= "" and tags.artist ~= nil and tags.artist ~= "" then
          song_title = tags.artist:gsub("[^\x20-\x7E]", '').." - "..tags.title:gsub("[^\x20-\x7E]", '')
        end
      end
      complete_music_table[index][2] = song_title

      index = index+1
      valid_format = false
    elseif lfs.getInfo(file)["type"] == "directory" then
      local recursive_table = audio.recursiveEnumerate(file)
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

return audio
