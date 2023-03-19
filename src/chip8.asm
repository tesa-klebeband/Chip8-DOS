[BITS 16]
[ORG 0x100]

%define COLOR 0x9
mov bl, [0x80]
xor bh, bh
add bl, 0x81

mov [bx], byte 0

load_rom:
    mov ah, 0x1A
    mov dx, dta
    int 0x21

    mov ah, 0x4E
    mov cx, 0b100111
    mov dx, 0x82
    int 0x21
    jc rom_err

    cmp [dta + 0x1A], word 0
    je rom_err
    
    mov ax, 0x3D00
    mov dx, 0x82
    int 0x21

    mov bx, ax
    mov ah, 0x3F
    mov cx, [dta + 0x1A]
    mov dx, memory + 512
    int 0x21

    mov ah, 0x3E
    int 0x21

    mov [program_counter], word 0x200
    mov [stack_pointer], word 30
    mov [delay_timer], word 0

    mov ax, 0x13
    int 0x10

cycle:
    in al, 0x60
    cmp al, 1
    je exit

    mov ah, 0x86
    xor cx, cx
    mov dx, 500
    int 0x15

    cmp [delay_timer], word 0
    je .do_cycle

    dec word [delay_timer]

.do_cycle:
    call fetch
    call execute
    jmp cycle

fetch:
    mov si, [program_counter]
    add si, memory
    mov ax, [si]
    mov bl, ah
    mov bh, al
    mov ax, bx
    ret

execute:
    push word .return
    mov bx, ax
    
    cmp bx, 0x00E0
    je disp_clear
    cmp bx, 0x00EE
    je return
    
    and bx, 0xF000
    cmp bx, 0x1000
    je goto
    cmp bx, 0x2000
    je _call
    cmp bx, 0x3000
    je skipe
    cmp bx, 0x4000
    je skipue
    cmp bx, 0x5000
    je _skipe
    cmp bx, 0x6000
    je setx
    cmp bx, 0x7000
    je addx
    cmp bx, 0x9000
    je _skipue
    cmp bx, 0xA000
    je seti
    cmp bx, 0xB000
    je jmpi
    cmp bx, 0xC000
    je rand
    cmp bx, 0xD000
    je draw

    mov bx, ax
    and bx, 0xF00F
    cmp bx, 0x8000
    je _setx
    cmp bx, 0x8001
    je orx
    cmp bx, 0x8002
    je andx
    cmp bx, 0x8003
    je xorx
    cmp bx, 0x8004
    je _addx
    cmp bx, 0x8005
    je subx
    cmp bx, 0x8006
    je shrx
    cmp bx, 0x8007
    je _subx
    cmp bx, 0x800E
    je shlx

    mov bx, ax
    and bx, 0xF0FF
    cmp bx, 0xE09E
    je skipkey
    cmp bx, 0xE0A1
    je skipnkey
    cmp bx, 0xF007
    je getdelay
    cmp bx, 0xF00A
    je getkey
    cmp bx, 0xF015
    je setdelay
    cmp bx, 0xF018
    je setsound
    cmp bx, 0xF01E
    je addi
    
    cmp bx, 0xF033
    je stobcd
    cmp bx, 0xF055
    je regdump
    cmp bx, 0xF065
    je regload


.return:
    add [program_counter], word 2

    ret

disp_clear:
    push es
    push word 0xA000
    pop es
    xor al, al
    xor di, di
    mov cx, 64000
    rep stosb
    pop es

    ret

return:
    add [stack_pointer], word 2
    mov bx, [stack_pointer]
    mov dx, [bx + stack]
    mov [program_counter], dx
    ret

goto:
    mov bx, ax
    and bx, 0xFFF
    sub bx, 2
    mov [program_counter], bx
    ret

_call:
    mov bx, [stack_pointer]
    mov dx, [program_counter]
    mov [bx + stack], dx
    sub [stack_pointer], word 2

    mov bx, ax
    and bx, 0xFFF
    sub bx, 2
    mov [program_counter], bx
    ret
     
skipe:
    call load_dl
    
    mov bx, ax
    cmp dl, bl
    jne .done
    add [program_counter], word 2

.done:
    ret

skipue:
    call load_dl
    
    mov bx, ax
    cmp dl, bl
    je .done
    add [program_counter], word 2

.done:
    ret

_skipe:
    call load_dl
    call load_dh

    cmp dl, dh
    jne .done
    add [program_counter], word 2

.done:
    ret

setx:
    mov dx, ax

    call upper_reg_to_bx
    mov [bx], dl
    ret

addx:
    mov dx, ax

    call upper_reg_to_bx
    add [bx], dl
    ret

_setx:
    call load_dh

    call upper_reg_to_bx
    mov [bx], dh
    ret

orx:
    call load_dh

    call upper_reg_to_bx
    or [bx], dh
    ret

andx:
    call load_dh

    call upper_reg_to_bx
    and [bx], dh
    ret

xorx:
    call load_dh

    call upper_reg_to_bx
    xor [bx], dh
    ret

_addx:
    call load_dh

    call upper_reg_to_bx
    add [bx], dh
    ret

subx:
    call load_dh

    call upper_reg_to_bx
    sub [bx], dh
    ret

shrx:
    call load_dl
    and dl, 1
    shr byte [bx], 1

    mov [registers + 0xF], dl
    ret

_subx:
    call load_dh

    call load_dl
    mov cl, dl
    shr dx, 8
    xor ch, ch
    sub dx, cx
    mov [bx], dl

    cmp dh, 0
    jne .no_borrow

    mov [registers + 0xF], byte 0
    jmp .done

.no_borrow:
    mov [registers + 0xF], byte 1

.done:
    ret

shlx:
    call load_dl
    shr dl, 7
    shl byte [bx], 1

    mov [registers + 0xF], dl
    ret

_skipue:
    call load_dl
    call load_dh

    cmp dl, dh
    je .done
    add [program_counter], word 2

.done:
    ret

seti:
    mov bx, ax
    and bx, 0xFFF
    mov [i_reg], bx
    ret

jmpi:
    mov bx, ax
    and bx, 0xFFF
    xor dh, dh
    mov dl, [registers]
    add bx, dx
    sub bx, 2
    mov [program_counter], bx
    ret

rand:
    ret

draw:
    mov [registers + 0xF], byte 0

    call load_dh

    call load_dl

    mov cx, ax
    and cx, 0xF

    mov bx, memory
    add bx, [i_reg]

.draw_loop:
    mov al, [bx]
    push dx
    push cx
    xor cl, cl

.bit_loop:
    shl ax, 1
    push ax
    and ah, 1
    cmp ah, 1
    pop ax
    je .bit_set

    jmp .next_bit

.bit_set:
    push ax
    call get_pixel
    cmp al, 0
    pop ax
    ja .flip_pixel

    push cx
    mov cl, COLOR
    call draw_pixel
    pop cx

    jmp .next_bit

.flip_pixel:
    push cx
    xor cx, cx
    call draw_pixel
    pop cx

    mov [registers + 0xF], byte 1

.next_bit:
    cmp cl, 7
    je .bit_loop_done
    inc cl
    inc dl
    jmp .bit_loop

.bit_loop_done:
    pop cx
    pop dx
    dec cx
    jcxz .done

    inc dh
    inc bx
    jmp .draw_loop

.done:
    ret

skipkey:
    call load_dl
    xor bh, bh
    mov bl, dl
    mov dl, [bx + keycodes]

    in al, 0x60

    cmp al, dl
    jne .done

    add [program_counter], word 2

.done:
    ret

skipnkey:
    call load_dl
    xor bh, bh
    mov bl, dl
    mov dl, [bx + keycodes]

    in al, 0x60

    cmp al, dl
    jne .skip
    jmp .done

.skip:
    add [program_counter], word 2
    jmp .done

.done:
    ret

getdelay:
    call load_dl
    mov dx, [delay_timer]
    shr dx, 3
    mov [bx], dl
    ret

getkey:
    call load_dl

.wait_key:
    in al, 0x60

    mov di, keycodes
    mov cx, 16
    repne scasb
    jne .wait_key

    dec di
    mov dx, di
    sub dx, keycodes
    mov [bx], dl
    ret
    
setdelay:
    call load_dl
    xor dh, dh
    shl dx, 3

    mov [delay_timer], dx
    ret

setsound:
    ret

addi:
    call load_dl
    xor dh, dh
    add [i_reg], dx
    ret

setsprite:
    call load_dl
    mov al, dl
    xor ah, ah
    mov cx, 5
    mul cx
    mov [i_reg], ax

    ret

stobcd:
    call load_dl
    mov al, dl
    xor ah, ah
    mov al, [bx]
    mov bx, [i_reg]
    mov cx, 100
    div cx
    mov [bx + memory], al
    mov ax, dx
    mov cx, 10
    div cx
    mov [bx + memory + 1], al
    mov ax, dx
    mov [bx + memory + 2], al
    
    ret    

regdump:
    mov cx, ax
    shr cx, 8
    and cx, 0xF
    inc cx
    mov si, registers
    mov di, memory
    add di, [i_reg]
    rep movsb

    ret

regload:
    mov cx, ax
    shr cx, 8
    and cx, 0xF
    inc cx
    mov di, registers
    mov si, memory
    add si, [i_reg]
    rep movsb

    ret

draw_pixel:
    push es
    push ax
    push bx
    push dx
    push word 0xA000
    pop es

    push cx

    mov ax, dx
    push dx
    xor ah, ah
    mov cx, 5
    mul cx
    mov bx, ax
    pop dx
    mov ax, dx
    shr ax, 8
    mov cx, 1600
    mul cx
    add bx, ax

    pop cx

    mov [es:bx], cl
    mov [es:bx + 1], cl
    mov [es:bx + 2], cl
    mov [es:bx + 3], cl
    mov [es:bx + 4], cl
    mov [es:bx + 320], cl
    mov [es:bx + 321], cl
    mov [es:bx + 322], cl
    mov [es:bx + 323], cl
    mov [es:bx + 324], cl
    mov [es:bx + 640], cl
    mov [es:bx + 641], cl
    mov [es:bx + 642], cl
    mov [es:bx + 643], cl
    mov [es:bx + 644], cl
    mov [es:bx + 960], cl
    mov [es:bx + 961], cl
    mov [es:bx + 962], cl
    mov [es:bx + 963], cl
    mov [es:bx + 964], cl
    mov [es:bx + 1280], cl
    mov [es:bx + 1281], cl
    mov [es:bx + 1282], cl
    mov [es:bx + 1283], cl
    mov [es:bx + 1284], cl
    
    pop dx
    pop bx
    pop ax
    pop es
    
    ret

get_pixel:
    push es
    push bx
    push cx
    push dx
    push word 0xA000
    pop es

    mov ax, dx
    push dx
    xor ah, ah
    mov cx, 5
    mul cx
    mov bx, ax
    pop dx
    mov ax, dx
    shr ax, 8
    mov cx, 1600
    mul cx
    add bx, ax

    mov al, [es:bx]
    xor ah, ah
    
    pop dx
    pop cx
    pop bx
    pop es

    ret

load_dl:
    mov bx, ax
    shr bx, 8
    and bx, 0xF
    add bx, registers
    mov dl, [bx]
    ret

load_dh:
    mov bx, ax
    shr bx, 4
    and bx, 0xF
    add bx, registers
    mov dh, [bx]
    ret

upper_reg_to_bx:
    mov bx, ax
    shr bx, 8
    and bx, 0xF
    add bx, registers
    ret

exit:
    mov ax, 0x2
    int 0x10
    mov ax, 0x4C00
    int 0x21

rom_err:
    mov ah, 0x9
    mov dx, usage_msg
    int 0x21

    mov ax, 0x4C01
    int 0x21

dta: resb 0x2B
usage_msg: db "Usage: chip8.com [ROM_FILE]", 0xA, 0xD, '$'

delay_timer:
    dw 0

registers:
    resb 16             ; 16 Registers

i_reg:
    dw 0

program_counter:
    dw 0

stack_pointer:
    dw 0

stack:
    resb 32             ; 16 levels of nesting

keycodes:
    db 0x2D
    db 0x2
    db 0x3
    db 0x4
    db 0x10
    db 0x11
    db 0x12
    db 0x1E
    db 0x1F
    db 0x20
    db 0x15
    db 0x2E
    db 0x5
    db 0x13
    db 0x21
    db 0x2F

memory:
    db 0xF0, 0x90, 0x90, 0x90, 0xF0
    db 0x20, 0x60, 0x20, 0x20, 0x70
    db 0xF0, 0x10, 0xF0, 0x80, 0xF0
    db 0xF0, 0x10, 0xF0, 0x10, 0xF0
    db 0x90, 0x90, 0xF0, 0x10, 0x10
    db 0xF0, 0x80, 0xF0, 0x10, 0xF0
    db 0xF0, 0x80, 0xF0, 0x90, 0xF0
    db 0xF0, 0x10, 0x20, 0x40, 0x40
    db 0xF0, 0x90, 0xF0, 0x90, 0xF0
    db 0xF0, 0x90, 0xF0, 0x10, 0xF0
    db 0xF0, 0x90, 0xF0, 0x90, 0x90
    db 0xE0, 0x90, 0xE0, 0x90, 0xE0
    db 0xF0, 0x80, 0x80, 0x80, 0xF0
    db 0xE0, 0x90, 0x90, 0x90, 0xE0
    db 0xF0, 0x80, 0xF0, 0x80, 0xF0
    db 0xF0, 0x80, 0xF0, 0x80, 0x80