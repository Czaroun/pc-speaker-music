# PC Speaker Music
#### A project implemented during IT studies. The project carried out in a class on low-level programming on a 16-bit microprocessor on the Intel 8086.


## General info
##### The task of the program was to play melodies using the system speaker. 
##### The melody is read from a text file where the melody information is stored in RTTTL format (handling of executable file parameters). 
##### While the melody is playing, it is possible to adjust the tempo, pause and end the melody (keyboard operation). 
##### Furthermore, when the melody is played, the color of the font in the console changes in tact with the sounds being played.
##### Example melodies are available in the "notes" directory

## Technologies
##### * Turbo Assembler 16-bit

## Setup:
##### To run the program you need to download an emulator of DOS environment - DOSBox. A properly configured emulator with debugger and Turo Assembler is available for download in this repository in the file 
##### **_DOSBox.zip_**
##### Unzip the archive and run **_dosbox-x.exe_**
##### Type the following commands in the emulator console:
```
tasm music.asm
tlink music.obj
music notes/song_name.txt
```
Where _sone_name_ is the name of the melody.
