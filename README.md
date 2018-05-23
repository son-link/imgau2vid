# ImgAu2Vid

Bash script to convert a image with a audio to video using FFMPEG

### Requisites
* FFMPEG compiled for support WebM (libvpx and libvorbis) and/or MP4 (libx264 and aac)
* Zenity for use the GUI if you use Gnome, Mate, LXDE, XFCE or other based GTK desktops
* Kdialog for use the GUI if you use KDE, LXQt or other based QT desktops

### Instalation:
Copy or move imgau2vid.sh to /usr/bin or another dir in your PATH. If you can launche the app GUI directly form your desktop menu copy one of the .desktop files to /usr/share/applications

A AUR package for Arch Linux and derivates is [avaliable here]()

### How to use the cli (terminal):

```sh
	imgau2vid -i path/to/image -a path/to/audio -o path/to/output-video
```

#### Other parameters

* -h: Show the help
* -k: Start Kdialog GUI
* -z: Start Zenity GUI
* -f webm|mp4: Set video format. By default is webm
* -r fhd|hd|sd: Set video resolution. By default is fhd (FullHD 1920x1080). hd is 1280x720 and sd is 854x480.

(c) 2018 Alfonso Saavedra "Son Link"
