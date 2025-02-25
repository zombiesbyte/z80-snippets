ENTRY_POINT EQU $8000                   ; start of the empty memory
ORG ENTRY_POINT                         ; start
call $0DAF                              ; cls

                                        ; prints the program title
ld b, 2
ld c, 9
call set_cursor
ld bc, program_title
call print_string
                                        ; prints the progam version
ld b, 20
ld c, 9
call set_cursor
ld bc, program_version
call print_string
                                        ; setup the screen for key table
ld b, 5
ld c, 3
call set_cursor
ld bc, key_table_header
call print_string

main_loop:

    ld bc, $FBFE                ; check letter R
    in a, (c)                   ; for key press
    and %00001000
    call z, game_options_redefine_keys

    call get_key_states
    call get_kempston_states

    call print_key_state_bitmask
    call print_all_key_states_row
    call reset_key_states               ; if nz then no key has been pressed
    jp main_loop                        ; loop

get_key_states:
    ld bc, (key_map)                    ; load the port address for the keyboard row into BC
    in a, (c)                           ; read the keyboard state into the accumulator
    ld hl, key_map + 2                  ; because we can't just load directly into AND we borrow the hl reg
    and (hl)                            ; mask out the key we are interested in (e.g. Q key)
    CALL z, up_key_pressed              ; check if the key is pressed

    ld bc, (key_map + 4)                ; e.g. A key
    in a, (c)
    ld hl, key_map + 6
    and (hl)
    CALL z, dn_key_pressed

    ld bc, (key_map + 8)                ; e.g. O key
    in a, (c)
    ld hl, key_map + 10
    and (hl)
    CALL z, lt_key_pressed

    ld bc, (key_map + 12)               ; e.g. P key
    in a, (c)
    ld hl, key_map + 14
    and (hl)
    call z, rt_key_pressed

    ld bc, (key_map + 16)               ; e.g. Space key
    in a, (c)
    ld hl, key_map + 18
    and (hl)
    call z, fi_key_pressed

    ld bc, (key_map + 28)               ; e.g. X key
    in a, (c)
    ld hl, key_map + 30
    and (hl)
    jr z, ex_key_pressed
    ret

get_kempston_states:
    in a, ($1F)
    ;cp %00001000
    bit 3, a
    call nz, up_key_pressed

    in a, ($1F)
    ;cp %00000100
    bit 2, a
    call nz, dn_key_pressed

    in a, ($1F)
    ;cp %00000010
    bit 1, a
    call nz, lt_key_pressed

    in a, ($1F)
    ;cp %00000001
    bit 0, a
    call nz, rt_key_pressed

    in a, ($1F)
    bit 4, a
    call nz, fi_key_pressed
    ret

ex_key_pressed:
    ld a, (key_map + 32)
    set 0, a
    ld (key_map + 32), a
    ld b, 9
    ld c, 13
    call set_cursor
    ld bc, key_exit_msg
    call print_string
    call print_key_state_bitmask
    call print_all_key_states_row
    jp return

reset_key_states:
                                        ; maybe not the best approach if we were ever looking for key up events
                                        ; but right now I don't think we need to account for that
    ld a, %00000000
    ld (key_map + 32), a
    xor a
    inc a
    ret

up_key_pressed:
    ld a, (key_map + 32)
    set 7, a
    res 6, a
    ld (key_map + 32), a
    ret

dn_key_pressed:
    ld a, (key_map + 32)
    set 6, a
    res 7, a
    ld (key_map + 32), a
    ret

lt_key_pressed:
    ld a, (key_map + 32)
    set 5, a
    res 4, a
    ld (key_map + 32), a
    ret

rt_key_pressed:
    ld a, (key_map + 32)
    set 4, a
    res 5, a
    ld (key_map + 32), a
    ret

fi_key_pressed:
    ld a, (key_map + 32)
    set 3, a
    ld (key_map + 32), a
    ret

print_string:
    ld a, (bc)
    cp 0
    jr z, return
    rst $10
    inc bc
    jr print_string

set_cursor:
    ld a, $16                           ; at control character
    rst $10
    ld a, b                             ; Y 0-20 (not 0-23)
    rst $10
    ld a, c                             ; X (0-31)
    rst $10
    ret

return:
    ret

print_key_state_bitmask:
    ld a, (key_map + 32)
    ld hl, key_states_str
    ld b, 8

print_key_state_bitmask_next_char:
    rlca
    ld (hl), '0'
    jr nc, print_key_state_bitmask_next_bit
    ld (hl), '1'

print_key_state_bitmask_next_bit:
    inc hl
    djnz print_key_state_bitmask_next_char

    ld b, 12
    ld c, 11
    call set_cursor

    ld bc, key_states_str
    call print_string
    ret

print_all_key_states_row:
                                        ; we should now loop through each bit of our byte key tracker
    ld a, (key_map + 32)                ; load our byte key tracker into record a ready for rlca
    ld b, 8                             ; set the loop count to 8, we'll use this for calculating screen x placement
    jp print_all_key_states_row_begin   ; jump past the first z flag check otherwise loop wont start (need to understand this a bit more)
print_all_key_states_row_loop:
    jr z, print_all_key_states_row_end
print_all_key_states_row_begin:
    rrca
    push bc
    push af
    jr nc, print_all_key_states_row_down

print_all_key_states_row_up             ; we should assume key up state first
    ld a, b
    add a, a
    add a, b                            ; time the value in b by 3
    ld b, a
    inc b                               ; we need to add 1 for alignment

    ld c, b                             ; set X
    ld b, 6                             ; set Y
    call set_cursor
    ld bc, key_active_msg
    call print_string
    pop af
    pop bc
    dec b
    jr print_all_key_states_row_loop
print_all_key_states_row_down
    ld a, b
    add a, a
    add a, b                            ; time the value in b by 3
    ld b, a
    inc b                               ; we need to add 1 for alignment

    ld c, b                             ; set X
    ld b, 6                             ; set Y
    call set_cursor
    ld bc, key_inactive_msg             ; we set the msg ready
    call print_string
    pop af
    pop bc
    dec b
    jr print_all_key_states_row_loop
print_all_key_states_row_end:
    ret

game_options_redefine_keys:
    ld c, 9                             ; set X
    ld b, 7                             ; set Y
    call set_cursor
    ld bc, msg_redefine_keys             ; we set the msg ready
    call print_string
game_options_redefine_up:
    call delay_half_second
    ld c, 12                             ; set X
    ld b, 8                             ; set Y
    call set_cursor
    ld bc, msg_redefine_up             ; we set the msg ready
    call print_string
    ld hl, key_map
    call game_options_key_redefine_groups
game_options_redefine_down:
    call delay_half_second
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 12                             ; set X
    ld b, 8                             ; set Y
    call set_cursor
    ld bc, msg_redefine_down            ; we set the msg ready
    call print_string
    ld hl, key_map + 4
    call game_options_key_redefine_groups
game_options_redefine_left:
    call delay_half_second
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 12                             ; set X
    ld b, 8                             ; set Y
    call set_cursor
    ld bc, msg_redefine_left            ; we set the msg ready
    call print_string
    ld hl, key_map + 8
    call game_options_key_redefine_groups
game_options_redefine_right:
    call delay_half_second
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 12                             ; set X
    ld b, 8                             ; set Y
    call set_cursor
    ld bc, msg_redefine_right            ; we set the msg ready
    call print_string
    ld hl, key_map + 12
    call game_options_key_redefine_groups
game_options_redefine_fire:
    call delay_half_second
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 12                             ; set X
    ld b, 8                             ; set Y
    call set_cursor
    ld bc, msg_redefine_fire            ; we set the msg ready
    call print_string
    ld hl, key_map + 16
    call game_options_key_redefine_groups

    call delay_half_second
    ld c, 9                         ; set X
    ld b, 7                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ld c, 12                         ; set X
    ld b, 8                         ; set Y
    call set_cursor
    ld bc, msg_key_set_mask            ; we set the msg ready
    call print_string
    ret

game_options_key_redefine_groups:
    ld bc, $FBFE                ; q,w,e,r,t
    call game_options_key_redefine_listen
    ld bc, $FDFE                ; a,s,d,f,g
    call game_options_key_redefine_listen
    ld bc, $FEFE                ; shift,z,x,c,v
    call game_options_key_redefine_listen
    ld bc, $F7FE                ; 1,2,3,4,5
    call game_options_key_redefine_listen
    ld bc, $EFFE                ; 0,9,8,7,6
    call game_options_key_redefine_listen
    ld bc, $DFFE                ; p,o,i,u,y
    call game_options_key_redefine_listen
    ld bc, $BFFE                ; ret,l,k,j,h
    call game_options_key_redefine_listen
    ld bc, $7FFE                ; space,sym shift/ctrl,m,n,b
    call game_options_key_redefine_listen
    jr game_options_key_redefine_groups
game_options_key_redefine_listen
    in a, (c)                   ; for key press
    ;cpl                         ; complements %10111111 to $01000000
    ;cp 63                       ; 64 = %01000000
                                ; if any other bits (key mask) active then the value will be higher
    call pe, game_options_key_redefine_set_key ;this detects when a key is pressed but I think i need to save the keypress before returning to game_options_redefine_keys or similar
    ret

game_options_key_redefine_set_key:
    ; break and return? skip this ret by removing it from stack and use next return?
    ld (hl), c                      ; key address
    inc hl
    ld (hl), b                      ; key address
    inc hl
    cpl
    ld (hl), a                      ; save the key bit mask
    ld c, 9                         ; set X
    ld b, 9                         ; set Y
    call set_cursor
    ld bc, msg_key_set              ; we set the msg ready
    call print_string
    ;dec d

    pop hl
    pop hl                          ; skip last 2 returns and return to previous one
    ret

delay_half_second:
    ld bc, 1         ; outer loop count bc *.5 seconds
delay_outer_loop:
    ld de, 0xFFFF         ; inner loop count
delay_inner_loop:
    dec de                ; decrement de
    ld a, d               ; set flags based on de
    or e                  ; set flags based on de
    jr nz, delay_inner_loop     ; sontinue inner loop until de is 0
    dec bc                ; decrement bc
    ld a, b               ; set flags based on bc
    or c                  ; set flags based on bc
    jr nz, delay_outer_loop     ; continue outer loop until bc is 0
    ret

data:
    program_title db 'Input Monitor', 13, 0
    program_version db 'Version 0.5', 13, 0
    key_active_msg db '++', 13, 0
    key_inactive_msg db '--', 13, 0
    key_exit_msg db 'Exit', 13, 0
    key_table_header db '|UP|DN|LT|RT|FR|--|--|EX|', 13, 0
    key_states_str db '00000000', 13, 0 ; string of key states

    msg_redefine_keys db 'Redefine keys', 13, 0
    msg_redefine_up db 'Up?   ', 13, 0
    msg_redefine_down db 'Down? ', 13, 0
    msg_redefine_left db 'Left? ', 13, 0
    msg_redefine_right db 'Right?', 13, 0
    msg_redefine_fire db 'Fire? ', 13, 0
    msg_key_set db 'Keyset', 13, 0
    msg_key_set_mask db '             ', 13, 0

key_map EQU $F000;
ORG $F000
    ; row address, bitmap mask
    DB $FE, $FB, %00000001, %00000000   ; up key, default q
    DB $FE, $FD, %00000001, %00000000   ; down key, default a
    DB $FE, $DF, %00000010, %00000000   ; left key, default o
    DB $FE, $DF, %00000001, %00000000   ; right key, default p
    DB $FE, $7F, %00000001, %00000000   ; fire key, default space
    DB $00, $00, %00000000, %00000000   ; unused key
    DB $00, $00, %00000000, %00000000   ; unused key
    DB $FE, $FE, %00000100, %00000000   ; exit key, default x
    DB %00000000                        ; key states

END ENTRY_POINT                         ; end of file marker
