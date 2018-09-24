Drop, a LÖVE visualizer and music player
==========

I've always loved music and visualizations, but mainstream visualizers are frequently so packed with features
that they feel cumbersome. They have some neat graphics, but aren't very good at reflecting the actual beat of
the music and so, I decided to create Drop; a simple, efficient music player/visualizer.    

![music visualization](https://i.imgur.com/LLsSyNt.png)    
To add music, either drag and drop your music on the window or make sure you run the visualizer at least once, exit, navigate to your system's appdata directory, open "LOVE/Drop/music", and place your music files/folders in there.

### Features:
  - drag and drop music files/folders onto window
  - scalable gui (can make Drop really small and put it in the corner of your screen)
  - realtime ffi-implemented rfft calculations (really fast and efficient waveform generation)
  - decoder/queueable audio support
  - ID3 metadata support (gets song name/artist when stored in mp3)
  - audio input support (with this you can visualize speaker and microphone audio!)
  - keyboard music controls and now graphical music controls (with color accents!)
  - scrub bar, timestamps, and draggable scrub head with an updating visualization
  - frame-by-frame visualization navigation
  - shuffle and loop functionality
  - volume and mute controls
  - fade-visual sync
  - configurable
  - quick start
  - fps capping
  - session persistence
  - spectrum/bar visualization
  - custom colors
  - doesn't run fft calculations when minimized or paused

### Controls:
  - Left Arrow: Previous Song
  - Right Arrow: Next Song
  - Up Arrow: Next Visualizer
  - Down Arrow: Previous Visualizer
  - Shift+Left: Skip Backwards 5s
  - Shift+Right: Skip Forward 5s
  - Shift+Up: Volume Up
  - Shift+Down: Volume Down
  - Space bar: Pause/Play
  - s and l: Shuffle and Loop
  - i: toggle fade
  - m: toggle mute
  - f: fullscreen mode
  - 1, 2, 3, and 4: change visualization type
  - Escape: exit fullscreen mode
  - Comma and Period: move frame-by-frame through the visualization

### Setup:
1. Download Drop with [this link](https://github.com/nabakin/drop/archive/master.zip)
2. Extract it and navigate to the drop-master folder

For Windows, navigate to "releases", "Windows", and then double click `start.bat` to start Drop.    
For Mac, navigate to "releases", "Mac", and then enter `bash start.sh` in Terminal to start Drop.

### Credit:
Drop uses the [drop-fft](https://github.com/nabakin/drop-fft) library which is a modified version of the [kissfft](https://sourceforge.net/projects/kissfft/) library.  All credit for the amazing fft implementation should go to its creator Mark Borgerding.