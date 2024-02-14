; Name:             music.asm
; Assemble:         tasm.exe music.asm
; Link:             tlink.exe music.obj
; Run in DOSBox:    music.exe song_name.txt


_code segment
assume  cs:_code, ds:_data, ss:_stack

start:  
    mov ax,_data
    mov ds,ax
    mov ax,_stack
    mov ss,ax

    clear_reg:  ; zerowanie rejestrow
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0 

;--------------------------------------------------------------------PARAMETRY Z KONSOLI-------------------------------------------------------------------------------------------;    
read_parametr:    ; odczytywanie parametrow z konsoli
    mov cl, es:[80h]        ; wczytanie rozmiaru parametru z command line (PSP address)
    cmp cl, 1               ; jesli nie podano zadnego parametru - blad
        jbe error_no_arg
    mov dx, 81h             ; adres parametru z command line (PSP address)
    mov bp, dx              ; adres parametru -> BP
    mov di, offset filename ; adres bufora z nazwa pliku
    inc bp                  ; pomijamy pierwszy znak (spacja)
    
arg_to_var:
    mov al, es:[bp]         ; wczytanie kolejenego znaku z parametru
    cmp al, 13              ; sprawdzenie czy koniec parametru (znak CRLF)
        je end_atv              ; jesli tak koczymy przepisywanie do zmiennej
    mov [di], al            ; zapisanie znaku do bufora filename
    inc di                  ; przesuniecie wskaznika bufora
    inc bp                  ; przesuniecie wskaznika parametru
    jmp arg_to_var          ; petla
    
end_atv:
    mov ax, _data
    mov es, ax
    call parse_filename   ; parsowanie nazwy pliku
    jmp open_file
    
error_no_arg:            ; ERROR - obsluga braku parametru
    lea dx, error_no_arg_msg
    call echo_string
    jmp end_program
    
parse_filename:         ; PODPROGRAM parsujacy nazwe pliku
    mov si, offset filename     ; wskaznik zrodlowy (string z nazwa pliku)
    mov di, si                  ; wskaznik docelowy (do docelowego stringa z nazwa pliku)
    cld                         ; ustawienie kierunku na rosnacy
parse_filename_find_end:
    lodsb                       ; zaladuj kolejny znak ze zrodla DS:SI (inkrementuje SI)
    cmp al, '$'                 ; sprawdz, czy zaladowany znak to $
        je parse_filename_end   ; jesli tak, zakoncz parsowanie
    stosb                       ; zapisz znak do docelowego stringa ES:DI (inkrementuje DI)
    jmp parse_filename_find_end ; powtarzaj az do znalezienia znaku konca

parse_filename_end:
    mov al, 0    ; zakoncz string w docelowym stringu
    mov [di], al
    ret
;--------------------------------------------------------------------OBSLUGA PLIKU-------------------------------------------------------------------------------------------;    
open_file: 
    mov ah, 3Dh         ; funkcja DOS do otwarcia pliku
    mov al, 0           ; tryb dostepu: odczyt
    lea dx, filename    ; nazwa pliku
    int 21h
        jc error_file   ; jesli CF jest ustawione, wystapil blad podczas otwierania pliku
    mov file_handle, ax ; jesli otwarcie sie powiodlo, ustaw uchwyt pliku

read_file:
    mov ah, 3Fh         ; funkcja DOS do odczytu zawartosci pliku
    lea dx, buffer      ; adres bufora gdzie bedzie przechowywana zawartosc pliku
    mov cx, 1024         ; liczba bajtow do odczytania
    mov bx, file_handle ; uchwyt do pliku
    int 21h
        jc error_file   ; jesli CF jest ustawione, wystapil blad podczas odczytywania zawartosci pliku     
    call set_EOF        ; ustaw znacznik konca pliku
    jmp close_file
    
set_EOF:
    mov si, offset buffer   ; wskaznik zrodlowy (string z nazwa pliku)
    mov di, si              ; wskaznik docelowy (do docelowego stringa z nazwa pliku)
    cld                     ; ustawienie kierunku na rosnacy

set_EOF_find_end:
    lodsb                   ; zaladuj kolejny znak ze zrodla DS:SI (inkrementuje SI)
    cmp al, '$'             ; sprawdz, czy zaladowany znak to $
        je set_EOF_end      ; jesli tak, zakoncz parsowanie
    cmp al, 0Dh             ; ASCII 13
        je set_EOF_end
    stosb                   ; zapisz znak do docelowego stringa ES:DI (inkrementuje DI)
    jmp set_EOF_find_end    ; powtarzaj az do znalezienia znaku konca
    
set_EOF_end:
    mov al, '$'         ; wstaw znacznik koncowy
    mov [di], al        ; zakoncz string w docelowym stringu
    ret     
    
close_file:
    mov ah, 3Eh         ; funkcja DOS do zamkniecia pliku
    mov bx, file_handle ; uchwyt do pliku
    int 21h
        jc error_file   ; jesli CF jest ustawione, wystapil blad podczas zamykania pliku
    jmp proc_data
    
error_file:         ; ERROR - blad zwiazany z plikiem
    lea dx, error_file_msg
    call echo_string
    jmp end_program
    
;-------------------------------------------------------------WALIDACJA I ZAPIS PARAMETROW DO ZMIENNYCH------------------------------------------------------------------------;    
proc_data:
    mov si, offset buffer    ; ustaw wskaznik zrodla na zmienna buffer
    mov di, offset song_name ; ustaw wskaznik docelowy na zmienna song_name

read_song_name:     ; wczytaj nazwe piosenki (pierwsza sekcja)
    mov al, [si]        ; wczytaj znak ze wskaznika tekstu do AL
    cmp al, ':'         ; sprawdz, czy to koniec sekcji (znaleziono dwukropek)
        je read_params      ; jesli tak, przejdz do sekcji z parametrami
    inc si              ; przesun wskaznik zrodlowy
    stosb               ; zapisz znak do bufora `song_name` ES:DI (inkrementuje DI)
    jmp read_song_name    
    
read_params:
    inc si              ; przesun wskaznik zrodlowy
    mov al, [si]        ; wczytaj znak
    cmp al, 'd'         ; jesli `d` przejdz do odczytania parametru d
        je read_duration
    cmp al, 'o'         ; jesli `o` przejdz do odczytania parametru o
        je read_octave
    cmp al, 'b'         ; jesli `b` przejdz do odczytania parametru b
        je read_bpm_TMP
    
read_duration: ; -----------------------------PARAMETR D-------------------------------------------------;
    mov di, offset duration ; ustaw wskaznik docelowy na zmienna duration
    inc si                  ; przesun wskaznik tekstu do kolejnego znaku 
    mov al, [si]            ; wczytaj znak ze wskaznika tekstu do AL
    cmp al, '='             ; sprawdz czy po znaku `d` wystepuje znak `=`
        jne error_data_file_TMP ; jesli nie - blad

read_duration2:    
    inc si                          ; przesun wskaznik tekstu do kolejnego znaku 
    mov al, [si]                    ; wczytaj znak ze wskaznika tekstu do AL
    cmp al, '1'                     ; switch(al){ case 1: process, ..., default: error}
        je process_duration_1or16
    cmp al, '2'
        je process_duration
    cmp al, '4'
        je process_duration
    cmp al, '8'
        je process_duration
    cmp al, '3'
        je process_duration_32
    jmp error_data_file

read_duration_end:
    cmp al, ','         ; jesli po wartosci parametru wystepuje przecinek
        je read_params  ; to przejdz dalej
    jmp error_data_file ; jesli pojawia sie inne znaki - blad

error_data_file_TMP:    ; przejsciowa etykieta
    jmp error_data_file
read_params_TMP:        ; przejsciowa etykieta
    jmp read_params
read_bpm_TMP:           ; przejsciowa etykieta
    jmp read_bpm
    
process_duration:       ; walidacja parametru d 
    mov [di], al        ; zapisz wartosc parametru d do zmiennej duration
    inc si
    mov al, [si]        ; wczytaj kolejny znak
    jmp read_duration_end
    
process_duration_1or16:
    mov [di], al        ; zapisz wartosc parametru d do zmiennej duration
    inc si
    mov al, [si]        ; wczytaj kolejny znak
    cmp al, '6'
        je process_duration_16 ; jesli 6 - parametr d ma wartosc 16
    cmp al, ','         
        je read_params          ; jesli kolejny znak to przecinek przejdz dalej
        jmp error_data_file_TMP ; jesli znajduje sie inny znak - blad
    
process_duration_16:
    inc di                  ; cyfra 1 jest juz zapisana, przesuniemy wskaznik di i zapiszemy tam 6
    jmp process_duration
   
process_duration_32:
    mov bl, al      ; tymczasowe przechowanie znaku 3
    inc si
    mov al, [si]    ; wczytaj kolejny znak
    cmp al, '2'     ; jesli jest to znak 2 - parametr d ma wartosc 32
        jne error_data_file_TMP ; jesli inny znak - blad
    mov [di], bl    ; do zmiennej duration zapisujemy wartosc 32
    inc di
    mov [di], al
    inc si
    mov al, [si]
    jmp read_duration_end
    
read_octave:  ; -----------------------------PARAMETR O-------------------------------------------------; 
    mov di, offset octave   ; ustaw wskaznik docelowy na zmienna octave
    inc si
    mov al, [si]
    cmp al, '='                 ; sprawdz czy po znaku `o` wystepuje znak `=`
        jne error_data_file_TMP ; jesli nie - blad
    inc si
    mov al, [si]
    cmp al, '4'             ; parametr `o` moze przyjac wartosc 4, 5, 6 lub 7
        je process_octave
    cmp al, '5'
        je process_octave
    cmp al, '6'
        je process_octave
    cmp al, '7'
        je process_octave
    jmp error_data_file     ; jesli podany zostal inny - blad
    
process_octave:             ; zapisz parametr o  
    mov [di], al
    inc si
    mov al, [si]
    cmp al, ','             ; jesli po wartosci parametru wystepuje przecinek        
        je read_params_TMP  ; to przejdz dalej
    jmp error_data_file     ; jesli pojawia sie inne znaki - blad
        
read_bpm:  ; -----------------------------PARAMETR B-------------------------------------------------;              
    mov di, offset bpm  ; ustaw wskaznik docelowy na zmienna bpm
    inc si
    mov al, [si]
    cmp al, '='             ; sprawdz czy po znaku `b` wystepuje znak `=`
        jne error_data_file_TMP ; jesli nie - blad
    inc si
    mov al, [si]
    cmp al, '1'             ; dozwolone znaki to 0-9, z tym ze pierwsza cyfra nie moze byc rowna 0
    jb error_data_file_TMP  ; jesli pierwszy znak jest `mniejszy` (wg ASCII) niz pierszy dozwolony znak tj. 1 - blad
    jmp first_digit         ; obluga pierwszej cyfry
not_first_digit:
    cmp al, ':'             ; jesli znak to dwukropek przechdodzimy do kolejnej sekcji
        je read_notes
    cmp al, '0'             
    jb error_data_file_TMP  ; jesli znak jest `mniejszy` (wg ASCII) niz pierszy dozwolony znak tj. 0 - blad
first_digit:
    cmp al, '9'             
        ja error_data_file_TMP  ; jesli znak jest `wiekszy` (wg ASCII) niz ostatni dozwolony znak tj. 9 - blad
    mov [di], al                ; zapisz cyfre do zmiennej bpm
    inc di
    inc si
    mov al, [si]
    jmp not_first_digit
    
  
read_notes:     ; zapis nut do zmiennej
    mov di, offset notes
read_notes2:    
    inc si
    mov al, [si]
    cmp al, '$'
        je convert_args
    stosb ; zapisz znak do zmiennej notes ES:DI (inkrementuje DI)
    jmp read_notes2

   
convert_args:
    mov si, offset bpm  ; ustaw wskaznik na poczatek ciagu znakow parametru b
    call parseArgsToNum ; konwersja string BPM -> int BPM
    mov [bpmNum], ax    ; zapisz przekonwertowanego wyniku do zmiennej
    call calcNoteLengths ; funkcja obliczacja czas trwania danego rodzaju nuty
    call echo_info
    jmp read_type_note

parseArgsToNum:
    ; funkcja konwersujaca wartosc parametru BPM (text -> hex)
    xor ax, ax         ; zeruj rejestr AX dla przechowywania konwertowanej liczby
    mov cx, 10         ; podstawa systemu
    parseLoop:
        mov bl, [si]     ; wczytaj znak
        cmp bl, '$'      ; sprawdz czy koniec ciagu
            je endParse  ; zakoncz, jesli koniec
        cmp bl, '0'
            jb invalidNumber ; zignoruj niepoprawne znaki
        cmp bl, '9'
            ja invalidNumber ; zignoruj niepoprawne znaki
        sub bl, '0'      ; konwersja cyfry ASCII na wartosc liczbowa
        mul cx           ; pomnoza obecna wartosc przez 10
        add ax, bx       ; dodaj obecna cyfre do wyniku
        inc si           ; przejdz do nastepnego znaku
        jmp parseLoop    ; powtorz dla kolejnych cyfr
    invalidNumber:
        xor ax, ax       ; zwroc 0 w przypadku bledu
        ret
    endParse:
        ret
        
;-------------------------------------------------------------MUZYKA----------------------------------------------------------------------------------------;  
;--------------------------------------------------------ODCZYT RODZAJU NUTY------------------------------------------------------------------------;   
read_type_note:
    mov si, offset notes ; odczytujemy rodzaj nuty dla danego dzwieku
next_sound:  
    mov al, [si]                    ; wczytujemy pierwszy znak
    ;call keyboard_interrupt
    ; sprawdzenie nut - okreslamy typ nuty
    cmp al, '1'
        jb error_type_TMP2              ; jesli mniejsze niz `1` - blad
    cmp al, '9'
        ja first_is_sound_TMP           ; jesli wiekszy niz `9` - byc moze mamy do czynienia od razu z dzwiekiem, ustawimy wtedy nute domyslna
    cmp al, '1'
        je type_whole_or_sixteen_TMP    ; cala nuta lub szesnastka
    cmp al, '2'
        je type_note_2                  ; pol nuta
    cmp al, '4'
        je type_note_4                  ; cwierc nuta
    cmp al, '8'
        je type_note_8                  ; osemka
    cmp al, '3'
        je type_thirty_two_note_TMP     ; byc moze 32
    jmp error_type_TMP                  ; else - blad


type_whole_or_sixteen_TMP:      ; przejsciowa etykieta
    jmp type_whole_or_sixteen
type_thirty_two_note_TMP:       ; przejsciowa etykieta
    jmp type_thirty_two_note
error_type_TMP2:                ; przejsciowa etykieta
    jmp error_type_TMP
first_is_sound_TMP:             ; przejsciowa etykieta
    jmp first_is_sound    

type_note_2:        ; typ nuty - pol nuta
    call type_note
    cmp bl, '.'         ; sprawdzenie czy nuta z kropka
        je type_note_2dot
    mov ax, [half_note]
    mov [buffer_type_note_time], ax
    jmp read_sound
 
type_note_2dot:    ; typ nuty - pol nuta z kropka
    mov ax, [half_note_dot]
    mov [buffer_type_note_time], ax 
    jmp read_sound

type_note_4:       ; typ nuty - cwierc nuta
    call type_note
    cmp bl, '.'         ; sprawdzenie czy nuta z kropka
        je type_note_4dot
    mov ax, [quarter_note]
    mov [buffer_type_note_time], ax
    jmp read_sound     

type_note_4dot:     ; typ nuty - cwierc nuta z kropka
    mov ax, [quarter_note_dot]
    mov [buffer_type_note_time], ax
    jmp read_sound 
     
type_note_8:        ; typ nuty - osemka
    call type_note
    cmp bl, '.'         ; sprawdzenie czy nuta z kropka
        je type_note_8dot
    mov ax, [eighth_note]
    mov [buffer_type_note_time], ax
    jmp read_sound     

type_note_8dot:     ; typ nuty - osemka z kropka
    mov ax, [eighth_note_dot]
    mov [buffer_type_note_time], ax
    jmp read_sound  

type_note_16:       ; typ nuty - szesnastka
    call type_note
    cmp bl, '.'         ; sprawdzenie czy nuta z kropka
        je type_note_16dot
        mov ax, [sixteenth_note]
    mov [buffer_type_note_time], ax
    jmp read_sound     

type_note_16dot:    ; typ nuty - szesnastka z kropka
    mov ax, [sixteenth_note_dot]
    mov [buffer_type_note_time], ax
    jmp read_sound

type_note_32:       ; typ nuty - trzydziestka-dwojka
    mov ax, [thirtysecond_note]
    mov [buffer_type_note_time], ax
    jmp read_sound     

type_note_1:        ; typ nuty - cala nuta
    dec si
    call type_note
    cmp bl, '.'         ; sprawdzenie czy nuta z kropka
        je type_note_1dot
    mov ax, [whole_note]
    mov [buffer_type_note_time], ax
    jmp read_sound 
    
type_note_1dot:     ; typ nuty - cala nuta z kropka
    mov ax, [whole_note_dot]
    mov [buffer_type_note_time], ax
    jmp read_sound
    
type_note:
    push si
    call found_dot ; sprawdz czy nuta z kropka
    pop si
    ret
     
read_sound_TMP:    ; przejsciowa etykieta
    jmp read_sound
play_TMP:          ; przejsciowa etykieta
    jmp play
     
type_whole_or_sixteen: ; okreslamy czy mamy do czynienia z cala nuta czy szesnastka
    inc si
    mov al, [si]        
    cmp al, '6'         ; jesli kolejnym znakiem po `1` jest `6` - mamy do czynienia z szesnastka
        je type_note_16
    cmp al, 'a'
        jb error_type_TMP
    cmp al, 'p'
        je type_note_1
    cmp al, 'h'
        ja error_type_TMP
    jmp type_note_1

type_note_2_TMP:    ; przejsciowa etykieta
    jmp type_note_2
type_note_4_TMP:    ; przejsciowa etykieta
    jmp type_note_4
type_note_8_TMP:    ; przejsciowa etykieta
    jmp type_note_8
error_type_TMP:     ; przejsciowa etykieta
    jmp error_type
    
        
type_thirty_two_note: ; sprawdzenie czy mamy do czynienia z trzydziestka-dwojka
    mov bl, al      ; tymczasowe przechowanie znaku 3
    inc si
    mov al, [si]    ; wczytaj kolejny znak
    cmp al, '2'     ; jesli jest to znak 2 - jest to nuta trzydziestka-dwojka
    jne error_type_TMP ; jesli nie - blad
    jmp type_note_32
    
    found_dot:  ; podprogram szukajacy w zapisie znaku kropki
    inc si
    mov al, [si]
    cmp al, '.'
        je note_with_dot ; jesli znaleziono znak kropki - nuta z kropka
    cmp al, ','
        je end_found_dot ; jesli znaleziono znak przecinka - koniec zapisu nuty
    cmp al, '$'
        je end_found_dot ; jesli znaleziono znak dolara - koniec zapisu nuty
    jmp found_dot
note_with_dot:
    mov bl, '.'
end_found_dot:
    ret
    
first_is_sound:  ; pierwsza informacja nie jest nuta - sprawdzimy czy jest to dzwiek
    cmp al, 'a'
        jb error_type_TMP   ; jesli znak jest mniejszy od `a` - blad
    cmp al, 'p'
        je default_type     ; jesli znak jest rowny p - znak poprawny
    cmp al, 'h'
        ja error_type_TMP   ;jesli znak jest wiekszy od `h` - blad

default_type:  ; pierwszy znak to dzwiek - nuta przyjmuje wartosc domyslna
    dec si
    mov al, [duration]
    cmp al, '2'     ; switch (duration){ case 2: ... }
        je type_note_2_TMP
    cmp al, '4'
        je type_note_4_TMP
    cmp al, '8'
        je type_note_8_TMP
    cmp al, '3'
        je default_type_32
    cmp al, '1'
        je default_type_1or16
    default_type_32:
        stosb               ; zapisz znak do docelowego stringa ES:DI (inkrementuje DI)
        mov al, [duration+1]
        jmp type_note_32
    default_type_1or16:
        mov al, [duration+1]
        cmp al, '6'
            je default_type_16
        jmp type_note_1
    default_type_16:
        jmp type_note_16
            
;-------------------------------------------------------------ODCZYT DZWIEKU-----------------------------------------------------------------------------; 
read_sound:
    inc si
    mov al, [si]
    cmp al, 'a'
        jb error_type_TMP   ; jesli znak jest mniejszy od `a` - blad
    cmp al, 'p'
        je sound_correct     ; jesli znak jest rowny p - dzwiek poprawny
    cmp al, 'h'
        ja error_type_TMP   ;jesli znak jest wiekszy od `h` - blad
sound_correct:
    mov di, offset buffer_sound
    mov [di], al
    ;; sprawdzenie czy dzwiek zwiekszony o pol tonu - C#, D#, F#, G#, A#
    cmp al, 'c'
        je check_semitone
    cmp al, 'd'
        je check_semitone   
    cmp al, 'f'
        je check_semitone
    cmp al, 'g'
        je check_semitone
    cmp al, 'a'
        je check_semitone
    jmp read_octave_of_sound
        
check_semitone:
    inc si
    inc di
    mov al, [si]                ; pobieramy nastepny znak po znaku dzwieku
    cmp al, '#'                 ; jesli po znaku dzwieku pojawi sie znak # - dzwiek zwiekszony o pol tonu
        je sound_inc_semitone
        jne sound_not_inc_semitone
sound_inc_semitone:
    mov [di], al                ; zapisujemy do `buffer_sound` znak #
    jmp read_octave_of_sound
sound_not_inc_semitone:
    mov al, 0                   
    mov [di], al                ; zapisujemy do `buffer_sound` pusty znak - czyszczenie po poprzednich dzwiekach
    dec si
    jmp read_octave_of_sound

;-------------------------------------------------------------ODCZYT OKTAWY DZWIEKU-----------------------------------------------------------------------------;    
read_octave_of_sound:
    mov di, offset buffer_octave
skip_to_comma:      ; oktawa potencjalnie znajduje sie na ostatnim miejscu dzwieku, na lewo od przecinka
    inc si
    mov al, [si]
    cmp al, '$'
        je last_sound_octave ; jesli napotkany zostanie znak $ lub 0 - ostatni dzwiek
    cmp al, 0
        je last_sound_octave
    cmp al, ','
        jne skip_to_comma
last_sound_octave:
    dec si          ; pobierz znak przed znakiem , (lub znakiem $ / 0)
    mov al, [si]
    cmp al, '4'    ; jesli znajduje sie tam znak 4, 5, 6, 7 - jest to wartosc oktawy w ktorej ma zostac zagrany dzwiek
        je set_octave
    cmp al, '5'
        je set_octave
    cmp al, '6'
        je set_octave
    cmp al, '7'
        je set_octave
    cmp al, '.'     ; jesli znajduje sie tam znak dzwieku, poltonu (#) lub nuty zwiekszone (.) - nie ma informacji o oktawie, przyjmujemy oktawe domyslna
        je set_default_octave
    cmp al, '#'
        je set_default_octave
    cmp al, 'p'
        je set_default_octave
    cmp al, 'c'
        je set_default_octave
    cmp al, 'd'
        je set_default_octave
    cmp al, 'e'
        je set_default_octave
    cmp al, 'f'
        je set_default_octave  
    cmp al, 'g'
        je set_default_octave
    cmp al, 'a'
        je set_default_octave  
    cmp al, 'b'
        je set_default_octave
set_octave:         ; ustaw podana oktawe
    mov [di], al
    jmp play
set_default_octave: ; ustaw domyslna oktawe
    mov al, [octave]
    mov [di], al
    jmp play
;-------------------------------------------------------------ZAGRANIE DZWIEKU----------------------------------------------------------------------------;
play:
    call keyboard_interrupt
    mov al, [buffer_sound] ; pobierz z bufora informacje o dzwieku
    cmp al, 'c'
        je playC
    cmp al, 'd'
        je playD
    cmp al, 'e'
        je playE
    cmp al, 'f'
        je playF_TMP
    cmp al, 'g'
        je playG_TMP
    cmp al, 'a'
        je playA_TMP
    cmp al, 'b'
        je playB_TMP
    cmp al, 'p'
        je playPause_TMP
    play2:    
        call playNote ; przejdz do zagrania dzwieku
    jmp end_note

playF_TMP:      ; przejsciowa etykieta
    jmp playF
playG_TMP:      ; przejsciowa etykieta
    jmp playG
playA_TMP:      ; przejsciowa etykieta
    jmp playA
playB_TMP:      ; przejsciowa etykieta
    jmp playB
playPause_TMP:  ; przejsciowa etykieta
    jmp playPause
    
playC:
    mov al, [buffer_sound+1]    ; pobierz z bufora nastepny znak
    cmp al, '#'                 ; jesli jest to znak # - dzwiek zwiekszony o poltonu
        je playCis
    mov color, 0001b            ; blue
    call change_color
    mov dx, c
    call calc_freq              ; oblicz czestotliwosc dla dzwieku w zadanej oktawie
    jmp play2

playCis:
    mov color, 1001b            ; light blue
    call change_color
    mov dx, cis
    call calc_freq
    jmp play2
    
playD:
    mov al, [buffer_sound+1]
    cmp al, '#'
        je playDis
    mov color, 0010b            ; green
    call change_color
    mov dx, d
    call calc_freq
    jmp play2

playDis:
    mov color, 1010b            ; light green
    call change_color
    mov dx, dis
    call calc_freq
    jmp play2
    
playE:
    mov color, 0110b            ; brown
    call change_color
    mov dx, e
    call calc_freq
    jmp play2
    
playF:
    mov al, [buffer_sound+1]
    cmp al, '#'
        je playFis
    mov color, 0100b            ; red
    call change_color
    mov dx, f
    call calc_freq
    jmp play2

playFis:
    mov color, 1100b            ; light red
    call change_color
    mov dx, fis
    call calc_freq
    jmp play2
    
playG:
    mov al, [buffer_sound+1]
    cmp al, '#'
        je playGis
    mov color, 0101b            ; magenta
    call change_color
    mov dx, g
    call calc_freq
    jmp play2

playGis:
    mov color, 1101b            ; light
    call change_color
    mov dx, gis
    call calc_freq
    jmp play2
    
playA:
    mov al, [buffer_sound+1]
    cmp al, '#'
        je playAis
    mov color, 0011b            ; cyan
    call change_color
    mov dx, a
    call calc_freq
    jmp play2

playAis:
    mov color, 1011b            ; light cyan
    call change_color
    mov dx, ais
    call calc_freq
    jmp play2
    
playB:
    mov color, 1110b            ; yellow
    call change_color
    mov dx, b
    call calc_freq
    jmp play2
    
playPause:
    mov color, 1111b            ; white
    call change_color
    mov ax, 0               ; wyzerowanie czestliwosci dzwieku
    mov buffer_freq, ax
    call set_duration       ; `graj` pauze
    jmp end_note            ; przejdz do kolejnej nuty

calc_freq:         ; podprogram obliczajacy wartosc czestotliwosci dzwieku w danej oktawie
    mov bl, [buffer_octave]
    sub bl, '0'         ; od wartosci oktawy odejmujemy wartosc ascii 0 - uzyskujemy jej wartosc w hexie
    mov cl, 7           ; liczba oktaw
    sub cl, bl          ; od ogolnej liczby oktaw odejmujemy wartosc konkretnej oktawy - wynik to liczba o ile nalezy przesunac czestotliwosc dzwieku aby dojsc do zadanej oktawy
    shl dx, cl          ; czestotliwosc dziweku =  dzwiek * 2 ^ przesuniecie
    mov buffer_freq, dx ; zapisujemy wynik w zmiennej `buffer_freq`
    mov ax, buffer_freq
    ret
 
error_type:     ; ERROR - bledna wartosc rodzaju nuty
    lea dx, error_type_msg
    call echo_string
    jmp end_program

;-------------------------------------------------------------OPERACJE NA GLOSNIKU----------------------------------------------------------------------------;
playNote:
    mov dx, ax      ; zapis czestotliwosci nuty w DX
    mov al, dh      
    out 43h, al     ; wybor rejestru timera 2 (generowanie dzwieku)
    
    ; ustaw rejestr timera sprzetowego (port 42h) dla nuty
    mov al, dl
    out 42h, al     ; wyslij mlodszy bajt czestotliwosci do portu 42h
    mov al, dh
    out 42h, al     ; wyslij starszy bajt czestotliwosci do portu 42h 
    
speaker_on:          ; wlacz glosnik, ustawiajac bit 0 i 1 na porcie 61h
    in al, 61h       ; wczytaj aktualna wartosc portu 61h do AL
    or al, 00000011b ; ustaw bity glosnika: bit 0 - wlaczenie bramki do glosnika, bit 1 - wlaczenie mozliwosci wysylania danych do glosnika
    out 61h, al      ; wyslij AL do portu 61h
    
set_duration:   ; ustawienie czasu trwania dzwieku
    mov ax, [buffer_type_note_time] ; do AX ladujemy czas trwania dzwieku
    mov bx, 1000                    ; przeksztalcamy czas na milisekundy
    mul bx
    
    ; korzystamy z przerwania 15 funkcji 86 - BIOS wait function
    ; program bedzie czekal interwal czasowy CX:DX podany w milisekundach 
    mov cx, dx          ; czesc mlodsza wyniku mnozenia przenosimy do CX
    mov dx, ax          ; czesc starsza wyniku mnozenia przenosimy do DX
    mov ah, 86h
    int 15h
    cmp [buffer_sound], 0 ; jesli `gralismy` pauze - koniec podprogramu
        je wait_pause_end ; jesli nie - wylacz glosnik
        
speaker_off: ; wylacz glosnik, zerujac bity 0 i 1 na porcie 61h
    
    in al, 61h          ; wczytaj aktualna wartosc portu 61h do AL
    and al, 11111100b   ; ustaw bity glosnika na 0
    out 61h, al         ; wyslij AL do portu 61h
wait_pause_end:
    ret

;-------------------------------------------------------------PRZEJSCIE DO KOLEJNEGO DZWIEKU LUB KONIEC PROGRAMU-------------------------------------------------------------------------;    
end_note:  ; koniec nuty
    inc si
    mov al, [si]
    cmp al, '$'      ; jesli napotkano znak $ - koniec piosnenki
        je end_music
        cmp al, ','  ; jesli napotkano znak , - przejdz do nastepnego dzwieku
        jne end_note
    inc si
    jmp next_sound

end_music:      ; koniec piosenki
    jmp end_program ; zakoncz program


;-------------------------------------------------------------ZMIANA KOLORU------------------------------------------------------------------------; 
change_color: ; podprogram zmieniajacy kolor tekstu
;ret
    mov di, 1       ; ustawienie indeksu na 1, poczatkowa pozycja wideo (pierwsza kolumna pierwszego wiersza)
    mov ax, 0B800h  ; segment pamieci wideo (ekran konsoli tekstowej)
    push es
    mov es, ax      ; przeniesienie adresu segmentu do rejestru ES
    mov cx, 2000    ; ilosc znakow (dwa bajty na kazdy znak - kolor i kod znaku) w 25 wierszach i 80 kolumnach
fill_loop:
    mov al, color   ; ladowanie wartosic koloru do AL
    mov es:[di], al ; zapis koloru do pamieci wideo na adresie w ES:DI
    add di, 2       ; przesuniecie wskaznika na kolejny znak (dwa bajty na znak)
    cmp di, 4000    ; sprawdzenie czy doszlismy do konca ekranu (4000 to 2000 znakow * 2 bajty/znak)
        jge end_fill  
    jmp fill_loop
end_fill:
    pop es
    ret

;-------------------------------------------------------------ZMIANA TEMPA-----------------------------------------------------------------------; 
keyboard_interrupt:
    xor ax, ax
    mov ah, 1               ; przerwanie 16h funkcja 1 - sprawdzenie bufora klawiatury czy nacisnieto jakis klawisz
    int 16h                 ; AL = znak ASCII, jesli nie nacisnieto zadnego klawisza ZF = 1
        jz keyboard_interrupt_end
    cmp al, '+'             ; jesli nacisnieto klaiwsz `+` - zwieksz bpm
        je increase_tempo
    cmp al, '-'             ; jesli nacisnieto klaiwsz `-` - zmniejsz bpm
        je decrease_tempo
    cmp al, 'q'             ; jesli nacisnieto klawisz `q` - zakoncz natychmiast granie piosenki
        je end_music
    cmp al, 'p'
        je pause_music
    keyboard_interrupt_end:
    mov ax, 0C00h           ; przerwanie 21h funkcja 0Ch - czyszczenie bufora klawiatury
    int 21h
    ret
    
increase_tempo:
    add bpmNum, 5           ; zwieksz tempo o 5
    call info_bpm           ; funkcja wyswietlajaca tekst o nowym tempie
    call calcNoteLengths    ; oblicz na nowo dlugosc trwania nut
    jmp keyboard_interrupt_end

decrease_tempo:
    sub bpmNum, 5           ; zmniejsz tempo o 5
    call info_bpm           ; funkcja wyswietlajaca tekst o nowym tempie
    call calcNoteLengths    ; oblicz na nowo dlugosc trwania nut
    jmp keyboard_interrupt_end

pause_music:
    mov ah, 0Ch
    int 21h     ; wyczyszc bufora klawiatury
pause_loop:
    mov ah, 1
    int 16h
    cmp al, 'p' ; czekaj az do ponownego wcisniecia klawisza `p`
        jne pause_loop
    jmp keyboard_interrupt_end
    
    
calcNoteLengths:  ; podprogram obliczajacy czas trwania nuty
    ; cwierc nuta
    xor dx, dx
    mov ax, 60000           ; liczba milisekund w minucie - dzielna
    mov cx, [bpmNum]        ; wartosc bpm - dzielnik
    idiv cx                 ; (DX AX) / CX = AX r DX
    mov [quarter_note], ax  ; zapisanie wyniku do zmiennej
    
    ; pol nuta = cwiercnuta * 2
    mov ax, 2
    imul [quarter_note]
    mov [half_note], ax
    
    ; cala nuta = cwiercnuta * 4
    mov ax, 4
    imul [quarter_note]
    mov [whole_note], ax
    
    ; osemka = cwiercnuta / 2
    xor dx, dx
    mov ax, [quarter_note]
    mov bx, 2
    idiv bx
    mov [eighth_note], ax
    
    ; szesnastka = cwiercnuta / 4
    xor dx, dx
    mov ax, [quarter_note]
    mov bx, 4
    idiv bx
    mov [sixteenth_note], ax
    
    ; trzydziestka-dwojka = cwiercnuta / 8
    xor dx, dx
    mov ax, [quarter_note]
    mov bx, 8
    idiv bx
    mov [thirtysecond_note], ax
    
    ; cala nuta z kropka = cala nuta + pol nuta
    mov ax, [whole_note]
    add ax, [half_note]
    mov [whole_note_dot], ax
    
    ; pol nuta z kropka = pol nuta + cwierc nuta
    mov ax, [half_note]
    add ax, [quarter_note]
    mov [half_note_dot], ax
    
    ; cwierc nuta z kropka = cwierc nuta + osemka
    mov ax, [quarter_note]
    add ax, [eighth_note]
    mov [quarter_note_dot], ax
    
    ; osemka z kropka = osemka + szesnastka
    mov ax, [eighth_note]
    add ax, [sixteenth_note]
    mov [eighth_note_dot], ax
    
    ; szesnastka z kropka = szesnastka + trzydziestka-dwojka
    mov ax, [sixteenth_note]
    add ax, [thirtysecond_note]
    mov [sixteenth_note_dot], ax
    ret   

info_bpm:
    xor cx, cx          ; czyszczenie CX - bedzie on przechowywal dlugosc wyniku
    xor bx, bx          ; czyszczenie BX - indeks do przechowywania wyniku
    mov ax, [bpmNum]    ; ladujemy do AX wartosc HEX nowego BPM
convert_loop:
    xor dx, dx          ; czyszczenie DX przed dzieleniem
    mov bx, 10          ; dzielnik
    div bx              ; podziel AX przez BX
    add dl, '0'         ; konwertuj reszte z dzielenia na znak ASCII
    push dx             ; wynik przenies na stos
    inc cx              ; zwieksz licznik dlugosci wyniku
    test ax, ax         ; sprawdz czy AX jest zerem
    jnz convert_loop    ; jesli nie - kontynuuj konwersje
    mov di, offset bpm  ; zaladuj adres teksu bpm
save_bpm:
    pop ax              ; sciagnij ze stosu kolejne wartosci ascii nowego bpm
    stosb               ; i zapisz w stringu bpm
    loop save_bpm
    mov al, '$'         ; na koncu wstaw znak $
    mov [di], al
echo_info_bpm:
    mov ax, 0900h       ; wypisz informacje o nowym tempie
    lea dx, text_bpm
    int 21h
    lea dx, bpm
    int 21h
    lea dx, new_line
    int 21h
    ret
    
echo_string: ; podprogram wyswietlajacy tekst na konsole
    mov ax, 0900h   ; przerwanie 21h funkcja DOS 9h do wyswietlania stringa z DX
    int 21h
    ret

echo_info:  ; podprogram wyswietlajacy informacje o utworze i klawiszach funkcyjnych w programie
    mov ax, 0900h
    lea dx, text_quit
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_pause
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_inc_bpm
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_dec_bpm
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_songname
    int 21h
    lea dx, song_name
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_octave
    int 21h
    lea dx, octave
    int 21h
    lea dx, new_line
    int 21h
    lea dx, text_bpm
    int 21h
    lea dx, bpm
    int 21h
    lea dx, new_line
    int 21h
    ret

error_data_file: ; ERROR - blad skladniowy w pliku
    lea dx, error_data_file_msg
    call echo_string
    jmp end_program

end_program:       
    mov ah, 4Ch     ; funkcja `Exit` DOSu
    mov al, 0
    int 21h
    
_code ends

_data segment
    filename            db 15 dup('$') ; zmienna do parametrow konsoli
    
    ; komunikaty o bledach
    error_no_arg_msg    db 'Nie podano parametru$', 0 
    error_file_msg      db 'Blad pliku$', 0
    error_data_file_msg db 'Blad skladniowy w pliku$', 0
    error_type_msg      db 'Bledna nuta$', 0
    
    ; teksty na konsoli
    text_quit           db 'Wcisnij ', 5Bh, 'q', 5Dh, ' aby zakonczyc granie$', 0
    text_pause          db 'Wcisnij ', 5Bh, 'p', 5Dh, ' aby zapauzowac/odpazuowac utwor$', 0
    text_inc_bpm        db 'Wcisnij ', 5Bh, '+', 5Dh, ' aby zwiekszyc tempo$', 0
    text_dec_bpm        db 'Wcisnij ', 5Bh, '-', 5Dh, ' aby zmniejszyc tempo$', 0
    text_songname       db 'Nazwa utworu   : $', 0
    text_octave         db 'Domyslna oktawa: $', 0
    text_bpm            db 'Tempo          : $', 0
    new_line            db 0Dh, 0Ah, '$', 0
    
    ; zmienna zwiazane z zawartoscia pliku
    file_handle         dw ?
    buffer              dw 1024 dup('$') ; zmienna przechowujaca zawartosc pliku
    song_name           db 32 dup('$')  ; zmienna przechowujaca nazwe utworu
    duration            db 3 dup('$')   ; zmienna przechowujaca wartosc parametru d
    octave              db 2 dup ('$')  ; zmienna przechowujaca wartosc parametru o
    bpm                 db 4 dup ('$')  ; zmienna przechowujaca wartosc parametru b
    octaveNum           dw ?
    bpmNum              dw ?
 
    notes               dw 1024 dup('$') ; zmienna przechowujaca nuty
    buffer_type_note    db 3 dup('$')   ; pomocniczna zmienna przechowujaca informacje o rodzaju nuty w postaci stringa
    buffer_sound        db 2 dup('$')   ; pomocniczna zmienna przechowujaca informacje o danym dzwieku w postaci stringa
    buffer_octave       db 1            ; pomocniczna zmienna przechowujaca informacje o oktawie w postaci stringa
    buffer_type_note_time dw ?
    color               db ?
    
    ; zmienne od czestotliwosic dzwiekow (7 oktawa)
    c                   dw 570  ; 2093.0000 hz
    cis                 dw 538  ; 2217.4600 hz
    d                   dw 508  ; 2349.3200 hz
    dis                 dw 479  ; 2489.0200 hz
    e                   dw 452  ; 2637.0200 hz
    f                   dw 427  ; 2793.8300 hz
    fis                 dw 403  ; 2959.9600 hz
    g                   dw 380  ; 3135.9600 hz
    gis                 dw 359  ; 3322.4400 hz
    a                   dw 339  ; 3520.0000 hz
    ais                 dw 320  ; 3729.3100 hz
    b                   dw 302  ; 3951.0700 hz
    buffer_freq         dw ?

    
    ;c4   = 4561        ;  261.6260 hz
    ;cis4 = 4305        ;  277.1830 hz
    ;d4   = 4063        ;  293.6650 hz
    ;dis4 = 3835        ;  311.1270 hz
    ;e4   = 3620        ;  329.6280 hz
    ;f4   = 3417        ;  349.2280 hz
    ;fis4 = 3225        ;  369.9940 hz
    ;g4   = 3044        ;  391.9950 hz
    ;gis4 = 2873        ;  415.3050 hz
    ;a4   = 2712        ;  440.0000 hz
    ;ais4 = 2560        ;  466.1640 hz
    ;b4   = 2416        ;  493.8830 hz
    ;c5   = 2280        ;  523.2510 hz
    ;cis5 = 2152        ;  554.3650 hz
    ;d5   = 2032        ;  587.3300 hz
    ;dis5 = 1918        ;  622.2540 hz
    ;e5   = 1810        ;  659.2550 hz
    ;f5   = 1708        ;  698.4560 hz
    ;fis5 = 1612        ;  739.9890 hz
    ;g5   = 1522        ;  783.9910 hz
    ;gis5 = 1437        ;  830.6090 hz
    ;a5   = 1356        ;  880.0000 hz
    ;ais5 = 1280        ;  932.3280 hz
    ;b5   = 1208        ;  987.7670 hz
    ;c6   = 1140        ; 1046.5000 hz
    ;cis6 = 1076        ; 1108.7300 hz
    ;d6   = 1016        ; 1174.6600 hz
    ;dis6 = 959        ; 1244.5100 hz
    ;e6   = 905        ; 1318.5100 hz
    ;f6   = 854        ; 1396.9100 hz
    ;fis6 = 806        ; 1479.9800 hz
    ;g6   = 761        ; 1567.9800 hz
    ;gis6 = 718        ; 1661.2200 hz
    ;a6   = 678        ; 1760.0000 hz
    ;ais6 = 640        ; 1864.6600 hz
    ;b6   = 604        ; 1975.5300 hz
    ;c7   = 570        ; 2093.0000 hz
    ;cis7 = 538        ; 2217.4600 hz
    ;d7   = 508        ; 2349.3200 hz
    ;dis7 = 479        ; 2489.0200 hz
    ;e7   = 452        ; 2637.0200 hz
    ;f7   = 427        ; 2793.8300 hz
    ;fis7 = 403        ; 2959.9600 hz
    ;g7   = 380        ; 3135.9600 hz
    ;gis7 = 359        ; 3322.4400 hz
    ;a7   = 339        ; 3520.0000 hz
    ;ais7 = 320        ; 3729.3100 hz
    ;b7   = 302        ; 3951.0700 hz
    
    ; zmienne od dlugosci nut
    whole_note          dw ?
    half_note           dw ?
    quarter_note        dw ?
    eighth_note         dw ?
    sixteenth_note      dw ?
    thirtysecond_note   dw ?
    whole_note_dot      dw ?
    half_note_dot       dw ?
    quarter_note_dot    dw ?
    eighth_note_dot     dw ?
    sixteenth_note_dot  dw ?
    pause               dw 30
    
_data ends

_stack segment stack
    dw  100h dup(?)
_stack ends

end start