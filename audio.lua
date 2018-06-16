id3 = require("id3")

local audio = {}
local decoder_buffer
local seconds_per_buffer
local queue_size
local sample_sum
local decoder_array
local sample_count
local check_old
local end_of_song
local song_id
local song_name
local is_paused
local current_song
local decoder
local time_count
local music_list
local loop_toggle
local shuffle_toggle
local microphone_active
local microphone_device
local previous_volume

function audio.reload()
  if current_song ~= nil then audio.stop() end
  
  decoder_buffer = 2048
  seconds_per_buffer = 0
  queue_size = 0
  sample_sum = 0
  decoder_array = {0,0,0,0,0,0,0}
  decoder_array[0] = 0
  sample_count = {0,0,0,0,0,0,0}
  sample_count[0] = 0
  check_old = 0
  end_of_song = false
  song_id = 0
  song_name = nil
  is_paused = false
  current_song = nil
  decoder = nil
  time_count = 0
  music_list = nil
  microphone_active = false
  microphone_device = nil
  previous_volume = 0
end

if not love.filesystem.getInfo("music") then love.filesystem.createDirectory("music") end
audio.reload()
loop_toggle = config.loop
shuffle_toggle = config.shuffle

function audio.update()
  -- plays first song
  if current_song == nil then
    if config.mute then
      previous_volume = config.volume
      love.audio.setVolume(0)
      gui.volume:activate("volume1")
    else
      gui.volume:activate(config.volume)
      love.audio.setVolume(config.volume)
    end
    audio.changeSong(1)
  end
  
  -- when song finished, play next one
  if decoder_array[queue_size] == nil then
    audio.changeSong(1)
  elseif decoder_array[0] == nil then
    audio.changeSong(-1)
    audio.decoderSeek(audio.getDuration())
  elseif not is_paused and not current_song:isPlaying() then
    audio.play()
  end


  -- manage decoder processing and audio queue
  local check = current_song:getFreeBufferCount()
  if check > 0 and not is_paused then
    if end_of_song then
      -- update time_count for the last final miliseconds of the song
      time_count = time_count+(check-check_old)*seconds_per_buffer
      check_old = check
    else
      time_count = time_count+check*seconds_per_buffer
    end

    -- time to make room for new sounddata.  Shift everything.
    for i=0, 2*queue_size-1 do
      decoder_array[i] = decoder_array[i+check]
    end

    -- retrieve new sounddata
    while check > 0 do
      local tmp = decoder:decode()
      if tmp ~= nil then
        current_song:queue(tmp)
        decoder_array[2*queue_size-check] = tmp
        check = check-1
      else
        end_of_song = true
        decoder_array[2*queue_size-check] = tmp
        check = check-1
      end
    end
  end
end

function audio.updateMicrophone()
  -- manage decoder processing and audio queue
  local check = microphone_device:getSampleCount()
  if check >= 448 and not is_paused then
    sample_sum = sample_sum+check-sample_count[0]
  
    -- time to make room for new sounddata.  Shift everything.
    for i=0, 2*queue_size-2 do
      decoder_array[i] = decoder_array[i+1]
      sample_count[i] = sample_count[i+1]
    end

    local tmp = microphone_device:getData()
    decoder_array[2*queue_size-1] = tmp
    sample_count[2*queue_size-1] = check
    current_song:queue(tmp)
    if not current_song:isPlaying() then current_song:play() end
  end
end

function audio.isPlayingMicrophone()
  return microphone_active
end

function audio.getSampleSum()
  return sample_sum
end

function audio.loadMusic()
  if microphone_active then return end

  music_list = recursiveEnumerate("music")

  local music_exists = true
  if next(music_list) == nil then
    music_exists = false
    music_list = nil
  end

  return music_exists
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

function audio.musicExists()
  return music_list ~= nil
end

function audio.isPaused()
  return is_paused
end

function audio.getSongName()
  return song_name
end

function audio.setSongName(n)
  song_name = n
end

function audio.play()
  is_paused = false
  if microphone_active then
    microphone_device:start(2048, 44100)
  end
  current_song:play()
end

function audio.mute()
  local current_volume = love.audio.getVolume()
  
  if current_volume == 0 and previous_volume ~= 0 then
    gui.volume:activate(previous_volume)
    love.audio.setVolume(previous_volume)
    previous_volume = 0
  else
    gui.volume:activate("volume1")
    love.audio.setVolume(0)
    previous_volume = current_volume
  end
end

function audio.getPreviousVolume()
  return previous_volume
end

function audio.stop()
  current_song:stop()
  if microphone_active then
    microphone_device:stop()
    microphone_active = false
  end
end

function audio.toggleLoop()
  loop_toggle = not loop_toggle
end

function audio.toggleShuffle()
  shuffle_toggle = not shuffle_toggle
end

function audio.isLooping()
  return loop_toggle
end

function audio.isShuffling()
  return shuffle_toggle
end

function audio.isPlaying()
  return ((current_song ~= nil) and current_song:isPlaying()) or false
end

function audio.getDuration()
  return decoder ~= nil and decoder:getDuration() or 0
end

function audio.getQueueSize()
  return queue_size
end

function audio.getDecoderBuffer()
  return decoder_buffer
end

function audio.loadMicrophone(device)
  device:start(2048, 44100)
  microphone_active = true
  microphone_device = device
  
  -- setup sounddata info
  sample_rate = device:getSampleRate()
  bit_depth = device:getBitDepth()
  channels = device:getChannelCount()
  
  queue_size = 4
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  gui.volume:activate("volume1")
  love.audio.setVolume(0)
end

-- goes to position in song
function audio.decoderSeek(t)
  time_count = t
  
  -- prevent errors at the beginning of the song
  -- generate nil data (indicates to change song)
  local start = 0
  local offset_time = t-queue_size*seconds_per_buffer
  if t <= 0 then
    local queue_pos = math.ceil((t*-1)/seconds_per_buffer)
    for i=0, queue_pos+1 do
      decoder_array[i] = nil
      start = i+1
    end
    offset_time = t+offset_time
  end
  
  -- fill decoder_array with dummy data
  if offset_time < 0 then
    decoder:seek(0)
    local tmp = decoder:decode()
    local queue_pos = math.ceil((offset_time*-1)/seconds_per_buffer)
    for i=start, queue_pos do
      decoder_array[i] = tmp
      start = i+1
    end
    offset_time = queue_pos+offset_time
  end
  
  decoder:seek(offset_time)
  
  -- fill with new sounddata
  for i=start, queue_size-1 do
    local tmp = decoder:decode()
    if tmp ~= nil then
      decoder_array[i] = tmp
    else
      break
    end
  end
  
  -- clear queued audio
  current_song:stop()
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- fill with new sounddata
  local check = queue_size
  while check > 0 do
    local tmp = decoder:decode()
    if tmp ~= nil then
      current_song:queue(tmp)
    end
    decoder_array[2*queue_size-check] = tmp
    check = check-1
  end
end

function audio.getBitDepth()
  return bit_depth
end

function audio.pause()
  is_paused = true
  if microphone_active then
    microphone_device:stop()
  end
  current_song:pause()
end

function audio.getChannels()
  return channels
end

function audio.getSampleRate()
  return sample_rate
end

-- finds sample using decoders
function audio.getDecoderSample(buffer)
  local sample_range = decoder_buffer/(bit_depth/8)

  -- some defensive code..
  if buffer < 0 or buffer >= 2*sample_range*queue_size then
    love.errhand("buffer out of bounds "..buffer)
  end

  local sample = buffer/sample_range
  local index = math.floor(sample)
  
  -- finds sample using decoders
  if audio.decoderTell('samples')+buffer < decoder:getDuration()*sample_rate then
    return decoder_array[index]:getSample((sample-index)*sample_range)
  else
    return 0
  end
end

function audio.getSampleMicrophone(buffer)
  local sample
  local index
  local found_flag = false
  local sum = 0
  for i=0, #decoder_array-1 do
    sum = sum+sample_count[i]
    if buffer < sum then
      index = i
      sample = buffer-(sum-sample_count[i])
      found_flag = true
      break
    end
  end
  
  if not found_flag then return 0 end
  
  -- finds sample using decoders
  return decoder_array[index]:getSample(sample)
end

-- returns position in song
function audio.decoderTell(unit)
  if unit == 'samples' then
    return time_count*sample_rate
  else
    return time_count
  end
end

-- File Handling --
function recursiveEnumerate(folder)
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
      local recursive_table = recursiveEnumerate(file)
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

-- Song Handling --
-- only pass 0, 1, and -1 for now
function audio.changeSong(number)
  if microphone_active or not audio.musicExists() then return end

  if not loop_toggle then
    if shuffle_toggle then
      song_id = math.random(1, #music_list)
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

  song_name = music_list[song_id][2]

  -- setup decoder info
  decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
  sample_rate = decoder:getSampleRate()
  bit_depth = decoder:getBitDepth()
  channels = decoder:getChannelCount()
  seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

  -- start song queue
  end_of_song = false
  check_old = 0
  queue_size = 4+math.max(math.floor(2*spectrum.getSize()/(decoder_buffer/(bit_depth/8))), 1)
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  local check = current_song:getFreeBufferCount()
  time_count = 0
  gui.timestamp_end:setValue(audio.getDuration())
  local tmp = decoder:decode()
  for i=0, queue_size do
    decoder_array[i] = tmp
  end
  check = check-1
  while check ~= 0 do
    tmp = decoder:decode()
    if tmp ~= nil then
      current_song:queue(tmp)
      decoder_array[2*queue_size-check] = tmp
      check = check-1
    end
  end

  if is_paused then audio.pause() else audio.play() end
end

return audio
