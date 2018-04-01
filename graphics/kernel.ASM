include "macro.inc"
        org     100h

InitOS:
        mov     al,20h
        mov     ah,25h
        mov     dx,ProgTerm
        int     21h

        mov     ah,00h
        mov     al,3
        int     10h
        mov     ah,01h
        mov     ch,20h
        mov     cl,20h
        int     10h
        mov     ax,1003h
        mov     bx,0
        int     10h
        mov     ah,0Fh
        int     10h

        ;background
        mov     dx,0h
        mov     bl,09Fh
        mov     cx,2000
        mov     si,1
        call    DrawRect
        mov     dx,0101h
        call    MoveCursor
        mov     dx,title
        mov     ah,09h
        int     21h

        ;rectangle
        mov     dl,0
        mov     dh,2
        mov     bl,stdColor
        mov     cx,80
        mov     si,25
        call    DrawRect
        mov     cx,5
        mov     dh,5
        mov     dl,35

        ;read root dir
        call    ReadRootDir
        mov     dh,5
        mov     dl,35

.Loop:
        call    MoveCursor
        mov     di,readLine
        push    cx
        mov     cx,11

        mov     al,[si + 11]
        test    al,18h
        jnz     @f
        mov     al,[si]
        cmp     al,0E5h
        je      @f
        cmp     al,0
        je      .ExitLoop
        push    si
        rep
        movsb
        pop     si
        pop     cx
        push    dx
        mov     dx,readLine
        mov     ah,09h
        int     21h
        pop     dx
        add     dh,2
@@:
        add     si,32

        loop    .Loop
.ExitLoop:

        mov     dh,5
        mov     dl,35
        call    MoveCursor
        mov     si,readLine
@@:
        mov     cx,11
        mov     bl,selColor
        call    SelectLine
        mov     ah,00h
        int     16h
        mov     bl,stdColor
        call    SelectLine

        cmp     ah,50h
        je      .Down
        cmp     ah,48h
        je      .Up
        cmp     ah,3Bh
        je      .About
        cmp     ah,01h
        je      Exit
        cmp     ah,1Ch
        je      Open
        jmp     @b

.Down:

        push    dx
        add     dh,2
        call    IsEmptyLine
        pop     dx
        cmp     ax,0
        je      .BotBorder
        add     dh,2

        call    MoveCursor
.BotBorder:

        jmp     @b
.Up:
        push    dx
        sub     dh,2
        call    IsEmptyLine
        pop     dx
        cmp     ax,0
        je      .TopBorder
        sub     dh,2
        call    MoveCursor
.TopBorder:
        jmp     @b

.About:
        mov     dx,0h
        mov     bl,09Fh
        mov     cx,2000
        mov     si,1
        call    DrawRect
        mov     dx,0101h
        call    MoveCursor
        mov     dx,text
        mov     ah,09h
        int     21h
L:
        mov     ah,10h
        int     16h
        cmp     al,27
        jne     L
        jmp     InitOS

Open:
        mov     cx,11
        mov     si,readLine
        call    ReadText
        mov     di,buffer
        call    GetFile
        mov     si,readLine
        mov     ah,09h
        mov     dx,readLine
        int     21h
        clr     dx
        call    MoveCursor
        mov     ah,00h
        mov     al,3h
        int     10h
        mov     ax,1000h
        init    ax,ds,es,gs,fs,ss
        mov     sp,0FFFEh
        push    0
        mov     ax,20CDh
        mov     [es:0],ax

        jmp     1000h:100h

Exit:
        mov     ax,5307h
        mov     bx,1
        mov     cx,3
        int     15h




;---------------------------------------------------------
; GetFile
;
; reads root directory into buffer
; Params:  DI <- root directory; SI <- file name
; Returns: (none)
;---------------------------------------------------------
GetFile:
        mov     cx,224         ; entries count
.Loop:
        mov     ax,11
        xchg    cx,ax
        mov     si,readLine
        mov     bx,di
        rep
        cmpsb
        mov     di,bx

        je      .LoadFAT
        xchg    cx,ax
        add     di,32
        loop    .Loop
        jmp     .Error
.LoadFAT:
        mov     dx,[es:di + 26]
        mov     [currClus],dx

        mov     cx,18
        mov     ax,1
        push    50h
        pop     es
        mov     bx,buffer


        int     80h

        mov     ax,1010h
        mov     es,ax

        mov     bx,00h


.LoadFile:
        mov     ax,[currClus]
        mov     bx,[currAddr]
        ; calculate LBA
        add     ax,31
        mov     cx,1


        int     80h

        mov     ax,[currClus]
        mov     cx,ax
        mov     dx,ax
        shr     dx,1
        add     cx,dx

        mov     bx,buffer

        add     bx,cx
        mov     dx,word [ds:bx]
        test    ax,1
        jnz     .Odd
.Even:
        and     dx,0111111111111b

        jmp     .Done
.Odd:
        shr     dx,4
.Done:
        mov     [currClus],dx
        cmp     dx,0FF8h
        jae     .Exit
        add     word [currAddr],512
        jmp     .LoadFile

.Error:
        mov     ah,09h
        mov     dx,errMes
        int     21h
.Exit:

        ret



;---------------------------------------------------------
; ReadRootDir
;
; reads root directory into buffer
; Params:  (none)
; Returns: (none)
;---------------------------------------------------------
ReadRootDir:

        mov     bx,buffer

        int     81h
        clr     ax                    ; Reset floppy
        mov     dl,0
        stc
        int     13h
        mov     cx,dx
        mov     si,buffer

        ret

;---------------------------------------------------------
; IsEmptyLine
;
; Checks that line is empty or not
; Params:  DL <- x; DH <- y
; Returns: AX -> bool result
;---------------------------------------------------------
IsEmptyLine:
        push    cx,si
        mov     cx,1
        call    ReadText
        mov     ah,[si]
        cmp     ah,' '
        jne     @f
        mov     ax,0
@@:
        pop     si,cx
        ret
;---------------------------------------------------------
; SelectLine
;
; Highlights line
; Params:  DL <- x; DH <- y; BL <- color; CX <- characters count; SI <- string variable
; Returns: (none)
;---------------------------------------------------------
SelectLine:
        pusha
        call    ReadText
        call    MoveCursor
        push    si
        mov     si,1
        call    DrawRect
        pop     si
        mov     dx,si
        mov     ah,09h
        int     21h
        popa
        ret

;---------------------------------------------------------
; ReadText
;
; Reads ASCII characters to SI
; Params:  DL <- x; DH <- y; CX <- count; SI <- string variable
; Returns: SI -> read text
;---------------------------------------------------------
ReadText:
        pusha
@@:
        cmp     cx,0
        mov     ah,08h
        mov     bh,0
        je      @f
        call    MoveCursor
        int     10h
        mov     [si],al
        inc     si
        inc     dl
        dec     cx
        jmp     @b
@@:
        popa
        ret

;---------------------------------------------------------
; DrawRect
;
; Draws rectangle at text mode
; Params:  BL <- color; DL <- x; DH <- y; CX <- width; SI <- height
; Returns: (none)
;---------------------------------------------------------
DrawRect:
        pusha

@@:
        mov     ah,09h
        mov     al,' '
        mov     bh,0
        cmp     si,0
        je      @f
        call    MoveCursor

        int     10h
        inc     dh
        dec     si
        jmp     @b
@@:
        popa
        ret

;---------------------------------------------------------
; MoveCursor
;
; Moves cursor position
; Params:   DL <- x; DH <- y
; Returns:  (none)
;---------------------------------------------------------
MoveCursor:
        pusha
        mov     ah,02h
        mov     bh,0
        int     10h
        popa
        ret

;---------------------------------------------------------
; ProgTerm (int 20h)
;
; Terminates program *.com
; Params:   (none)
; Returns:  (none)
;---------------------------------------------------------
ProgTerm:
        mov     ax,50h
        init    ax,ds,ss,es,gs,fs
        push    50h
        push    100h
        retf


title           db "NikitOS v0.1$"
dsSeg           dw ?

text            db "Simple DOS-like operating system based on FAT12 file system.", 13, 10, "(C)akaDova, 2018$$"

stdColor        = 079h
selColor        = 0F5h

readLine        db 12 dup ("$")
currClus        rw 1
currAddr        dw 0
errMes          db "error$"
; this ASCII arts for future works)
homer           db 13,10,\
"          _ _,---._",13,10,\
"       ,-','       `-.___",13,10,\
"      /-;'               `._",13,10,\
"     /\/          ._   _,'o \",13,10,\
"    ( /\       _,--'\,',''`. )",13,10,\
"     |\      ,'o     \'    //\",13,10,\
"     |      \        /   ,--'''`-.",13,10,\
"     :       \_    _/ ,-'         `-._",13,10,\
"      \        `--'  /                )",13,10,\
"       `.  \`._    ,'     ________,','",13,10,\
"         .--`     ,'  ,--` __\___,;'",13,10,\
"          \`.,-- ,' ,`_)--'  /`.,'",13,10,\
"           \( ;  | | )      (`-/",13,10,\
"             `--'| |)       |-/",13,10,\
"               | | |        | |",13,10,\
"               | | |,.,-.   | |_",13,10,\
"               | `./ /   )---`  )",13,10,\
"              _|  /    ,',   ,-'",13,10,\
"     -hrr-   ,'|_(    /-<._,' |--,",13,10,\
"             |    `--'---.     \/ \",13,10,\
"             |          / \    /\  \",13,10,\
"           ,-^---._     |  \  /  \  \",13,10,\
"        ,-'        \----'   \/    \--`.",13,10,\
"       /            \              \   \",13,10,"$"


tree            db 13,10,\
"           *             ,",13,10,\
"                       _/^\_",13,10,\
"                      <     >",13,10,\
"     *                 /.-.\         *",13,10,\
"              *        `/&\`                   *",13,10,\
"                      ,@.*;@,",13,10,\
"                     /_o.I %_\    *",13,10,\
"        *           (`'--:o(_@;",13,10,\
"                   /`;--.,__ `')             *",13,10,\
"                  ;@`o % O,*`'`&\",13,10,\
"            *    (`'--)_@ ;o %'()\      *",13,10,\
"                 /`;--._`''--._O'@;",13,10,\
"                /&*,()~o`;-.,_ `""`)",13,10,\
"     *          /`,@ ;+& () o*`;-';\",13,10,\
"               (`""--.,_0 +% @' &()\",13,10,\
"               /-.,_    ``''--....-'`)  *",13,10,\
"          *    /@%;o`:;'--,.__   __.'\",13,10,\
'              ;*,&(); @ % &^;~`"`o;@();         *',13,10,\
'              /(); o^~; & ().o@*&`;&%O\',13,10,\
'        jgs   `"="==""==,,,.,="=="==="`',13,10,\
"           __.----.(\-''#####---...___...-----._",13,10,\
'         `         \)_`"""""`',13,10,\
"                 .--' ')",13,10,\
"               o(  )_-\",13,10,\
'                 `"""` `',13,10,"$"

buffer: