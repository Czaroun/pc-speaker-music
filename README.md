# PC Speaker Music
This project was implemented during IT studies as part of a low-level programming class on a 16-bit microprocessor, specifically the Intel 8086

## General info
The program's task was to play melodies using the system speaker. Melodies were read from a text file stored in RTTTL format (handling of executable file parameters). While playing the melody, users could adjust the tempo, pause, and end the melody using 
keyboard commands. Additionally, the font color in the console changed in time with the sounds being played. Example melodies are available in the `notes` directory.

## Technologies
- Turbo Assembler 16-bit

## Setup:
To run the program, you need to download this repository and a DOS environment emulator - DOSBox. A properly configured emulator with debugger and Turbo Assembler is available for download in this repository in the file **_DOSBox.zip_**.
1. Unzip the archive.
2. Move the `music.asm` to the `VHDD` folder.
3. Run **_dosbox-x.exe_**
4. Type the following commands in the emulator console:
```DOSBox CLI
tasm music.asm
tlink music.obj
music notes/song_name.txt
```
Where _sone_name_ is the name of the melody.
