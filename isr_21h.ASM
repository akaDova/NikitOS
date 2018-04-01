        ;include "macro.inc"



ISR_21h:
        push    ds

        cmp     ah,9h
        je      ToFunc_9
        cmp     ah,25h
        je      ToFunc_25

ToFunc_9:
        call    Func_9
        jmp     ISR_Exit

ToFunc_25:
        call    Func_25
        jmp     ISR_Exit

Func_25:
        clr     ah
        mov     bx,ax
        shl     bx,2
        clr     ax
        mov     fs,ax
        mov     ax,ds
        cli
        xchg    word [fs:bx],dx
        xchg    word [fs:bx + 2],ax
        ret


Func_9:
        pusha
        mov     si,dx
.Loop:
        lodsb
        cmp     al,"$"
        je      .Exit
        mov     ah,0Eh
        int     10h
        jmp     .Loop
.Exit:
        popa
        ret
ISR_Exit:

        pop     ds
        iret
