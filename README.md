Drop, a LÖVE visualizer and music player
==========

I've always loved music and visualizations, but mainstream visualizers are frequently so packed with features
that they feel cumbersome. They have some neat graphics, but aren't very good at reflecting the actual beat of
the music. I think visualizers have a lot of potential integrated into music players and so, I decided to
create Drop; a simple, efficient music player/visualizer.

![music visualization](https://i.imgur.com/ZRqD1YO.png)

To add music, either drag and drop your music folder(s) on the window or make sure you run the visualizer at least once, exit, navigate to your system's appdata directory, open "LOVE/Drop/music", and place your music files/folders there.

### Features:
  - drag and drop
  - scrub bar and music controls
  - spectrum visualization
  - realtime fft calculations
  - multiple colors
  - fade-visual sync (currently disabled)
  - \[Mac only, see [this](https://github.com/nabakin/drop#researchedunfinished-features)\] disables fft generation when in the background (behind windows or minimized)
  - delay correction
  - bulk sampling
  - fully-scalable

### Controls:
  - Left Arrow: Previous Song
  - Right Arrow: Next Song
  - Space bar: Pause/Play
  - Click the scrub bar to change time
  - Drag the scrub head to change time
  - r, g, and b: change visualization color
  - f: Fullscreen mode
  - 1, 2, 3, and 4: change visualization type
  - Escape: Quit
  - Comma and Period: move frame by frame through the visualization (broken by [decoder](https://github.com/nabakin/drop/commit/93eec1a518581f7ae7c63f26dc09aa4c6a54455d) implementation)

### Setup:
1. Download Drop with [this link](https://github.com/nabakin/drop/archive/master.zip)
2. Extract it and navigate to the drop-master folder

For Windows, navigate to "releases", "Windows", and then double click "start.bat" to run Drop.    
For Mac, navigate to "releases", "Mac", and then run `bash start.sh` from Terminal

### Researched/unfinished features:
  - potential fft overlap NOTE: turns out the benefits from fixing the overlap were not great enough for the extra processing power and memory requirements necessary.  Actually ended up making things a lot worse.  The implementation consisted of calculating the fft in real-time separate from love.update, storing it in memory once some compression/optimization was preformed, obtaining it when the sample time appeared for love.draw, then removing it from memory once used.
  - when behind windows disable visualizer calcs NOTE: can't do this atm (0.11.0) bc love uses SDL which has issues implementing this.  Currently implemented, but likely error-prone need to test further on other computers
  - fix background detection on windows: can't because Love uses SDL to handle these things and it's bugged