        format binary as 'img'

BootSector:
.BS_jmpBoot:
                jmp     CodeStart
                db      3 - $ dup(90h)
.BS_OEMName     db      "MSWIN4.1"
.BPB_BytsPerSec dw      512
.BPB_SecPerClus db      1
.BPB_RsvdSecCnt dw      1
.BPB_NumFATs    db      2
.BPB_RootEntCnt dw      224
.BPB_TotSec16   dw      2880
.BPB_Media      db      0F0h
.BPB_FATSz16    dw      9
.BPB_SecPerTrk  dw      18
.BPB_NumHeads   dw      2
.BPB_HiddSec    dd      0
.BPB_TotSec32   dd      0
.BS_DrvNum      db      0
.BS_Reserved1   db      0
.BS_BootSig     db      29h
.BS_VolID       dd      %t
.BS_VolLab      db      "NikitOS    "
.BS_FilSysType  db      "FAT12   "




include "macro.inc"
;---------------------------------------------------------
; ReadSectors (int 80h)
;
; Reads sectors into ES:BX
; Params:  AX <- starting sector; ES:BX <- read buffer; CX <- sectors count
; Returns: ES:BX -> sectors list in memory
;---------------------------------------------------------
ReadSectors:

        push    ds
        push    07C0h
        pop     ds
.Main:
        mov     di,05h
.SecLoop:
        push    ax,bx,cx

        call    LBAToCHS
        mov     ah,02h
        mov     al,1
        mov     ch,[absTrack]
        mov     cl,[absSector]
        mov     dh,[absHead]
        mov     dl,[BootSector.BS_DrvNum]
        int     13h
        jnc     .Success
        clr     ax
        int     13h
        dec     di
        pop     cx,bx,ax

        jnz     .SecLoop
        int     18h
.Success:

        pop     cx,bx,ax

        add     bx,[BootSector.BPB_BytsPerSec]
        inc     ax
        loop    .Main
        pop     ds
        iret

;---------------------------------------------------------
; CHSToLBA
;
; Convert CHS to LBA
; Params:  AX <- current cluster
; Returns: AX -> LBA address
;---------------------------------------------------------
CHSToLBA:
        sub     ax,2
        clr     cx
        mov     cl,[BootSector.BPB_SecPerClus]
        mul     cx
        add     ax,[dataSector]
        ret

;---------------------------------------------------------
; LBAToCHS
;
; Convert LBA to CHS
; Params:  AX <- LBA address
; Returns: (none)
;---------------------------------------------------------
LBAToCHS:
        clr     dx
        div     [BootSector.BPB_SecPerTrk]
        inc     dl
        mov     [absSector],dl
        clr     dx
        div     [BootSector.BPB_NumHeads]
        mov     [absHead],dl
        mov     [absTrack],al
        ret

;---------------------------------------------------------
; LoadDirRoot
;
; Convert LBA to CHS
; Params:  AX <- LBA address
; Returns: (none)
;---------------------------------------------------------
LoadDirRoot:
        push    ds
        push    07C0h
        pop     ds
        clr     cx
        clr     dx
        mov     ax,32
        mul     [BootSector.BPB_RootEntCnt]
        div     [BootSector.BPB_BytsPerSec]
        xchg    ax,cx ;14

        mov     al,[BootSector.BPB_NumFATs]
        mul     [BootSector.BPB_FATSz16]
        add     ax,[BootSector.BPB_RsvdSecCnt]
        mov     [dataSector],ax
        add     [dataSector],cx


        int     80h
        pop     ds
        iret
;========================================

CodeStart:
        cli
        mov     ax,7C0h

        mov     ds,ax
        mov     es,ax
        mov     fs,ax
        mov     gs,ax

        add     ax,544
        mov     ss,ax
        mov     sp,0FFFFh
        sti
        mov     al,21h
        mov     ah,25h
        mov     dx,ISR_21h
        pushf

        push    cs
        call    ISR_21h
        mov     al,80h
        mov     ah,25h
        mov     dx,ReadSectors
        int     21h
        mov     al,81h
        mov     ah,25h
        mov     dx,LoadDirRoot
        int     21h

        mov     bx,0200h
        int     81h


        mov     cx,[BootSector.BPB_RootEntCnt]
        mov     di,0200h

.Loop:
        push    cx
        mov     cx,11
        mov     si,fileName
        push    di
        rep
        cmpsb
        pop     di
        je      LoadFAT
        pop     cx
        add     di,32
        loop    .Loop
        jmp     Error

LoadFAT:


;26 (1A) - point to first cluster
        mov     dx,[di + 26]
        mov     [clus],dx

        clr     ax
        mov     al,[BootSector.BPB_NumFATs]
        mul     [BootSector.BPB_FATSz16]
        mov     cx,ax

        mov     ax,[BootSector.BPB_RsvdSecCnt]

        mov     bx,0200h

        int     80h


        ;segment
        mov     ax,60h
        mov     es,ax
        ;offset
        mov     bx,0000h
        push    bx

LoadFile:
        mov     ax,[clus] ; first cluster
        pop     bx
        call    CHSToLBA
        clr     cx
        mov     cl,[BootSector.BPB_SecPerClus]

        int     80h
        push    bx

        mov     ax,[clus]
        mov     dx,ax
        mov     cx,ax
        shr     dx,1
        add     cx,dx
        mov     bx,0200h
        add     bx,cx
        mov     dx,[bx]
        test    ax,1
        jnz     .OddClus
.EvenClus:
        and     dx,0111111111111b
        jmp     .Done
.OddClus:
        shr     dx,4
.Done:
        mov     [clus],dx
        cmp     dx,0FF8h
        jb      LoadFile

Done:

        mov     ax,50h
        mov     ds,ax
        mov     fs,ax
        mov     es,ax
        mov     gs,ax
        mov     ss,ax
        mov     sp,0FFFEh
        push    00h

        jmp     50h:0100h


Error:

        mov     ah,00h
        int     16h
        int     19h

include "isr_21h.asm"

;========================================

absSector               db      00h
absHead                 db      00h
absTrack                db      00h

dataSector              dw      00h
clus                    dw      00h
fileName                db      "KERNEL  COM"

TIMES   510 - ($ - $$)  db      0
                        db      055h, 0AAh


FAT1:
                db      $F0, $FF, $FF
                db      $03, $40, $00
                db      $05, $F0, $FF

                db      9 * 512 - ($ - FAT1) dup($00)

FAT2:
                repeat 9 * 512
                  load a byte from FAT1 + % - 1
                  db a
                end repeat

RootDir:


                db 224 * 32 - ($ - RootDir) dup($00)

SecBoot:

                db 2880 * 512 - $ dup($00)