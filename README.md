Drop, a LÖVE visualizer and music player
==========

I've always loved music and visualizations have always interested me, but the mainstream visualizers were
always too chock-full of features and pretty graphics that weren't good at representing the actual beat of
the music.  It was as if they were made to just look pretty with little relevance to the actual beat of the song.
To me they felt like a gimic.  Something that you use once or twice, say "Oh cool!" and then never use again.
I believe visualizers have a lot of potential integrated into music players and so, I decided to
create Drop; a simple, efficient music player/visualizer.

![music visualization](http://i.imgur.com/kPV5umV.png)

### Features:
  - handles multiple songs
  - scrub bar and music controls
  - spectrum visualization
  - realtime fft calculations
  - multiple colors (temporarily disabled)
  - fade-visual sync (temporarily disabled)
  - disables visualization when in the background (behind windows (Mac only) or minimized)

### Controls:
  - Left Arrow: Previous Song
  - Right Arrow: Next Song
  - Space bar: Pause/Play
  - r, g, and b: change visualization type (colors disabled atm)
  - f: Fullscreen
  - Escape: Quit

### TODO:
  - add playlists
  - add a better font
  - add more visualizations (folder for custom visualizations?)
  - add fade bloom (maybe)
  - add fade transition softening
  - add drag and drop for music files (love.filedropped/love.directorydropped/love.system.openURL)
  - add song selection without changing songs
  - add a settings panel with includes
    - quality settings: 256, 512, 1024, 2048, auto (remember quality factors:
  	  size/4, division function, waveform/10 division in draw and dtscounter
	  and fade, and scaling i)
	  - maybe auto scale sample size option depending on song for maximum quality
	- file visualization saving option: off, automatic, manual (greatly improves performance at the cost of disk space)
	- tick distance slider (inside settings menu for default vis)
	- screen ratio setting: 16/10, 16/9, 4/3
	- fade options: toggle, turn off bloom, intensity slider (right side for louder songs, left for softer), auto
	- more color options
  - move music folder to appdata
  - optimize icon
  - read and evaluate how https://github.com/Sulunia/love2d-fftvis and https://github.com/opatut/VisuaLove handle ffts
  - fix fade average to scale with different qualities
  - fix scaling differences between Mac and Windows
  - Researched/unfinished:
    - potential fft overlap NOTE: turns out the benefits from fixing the overlap were not great enough for the extra processing power and memory requirements necessary.  Actually ended up making things a lot worse.  The implementation consisted of calculating the fft in real-time separate from love.update, storing it in memory once some compression/optimization was preformed, obtaining it when the sample time appeared for love.draw, then removing it from memory once used.
    - when behind windows disable visualizer calcs NOTE: can't do this atm (10.2) bc love uses SDL which has issues implementing this.  Currently implemented, but likely error-prone need to test further on other computers
