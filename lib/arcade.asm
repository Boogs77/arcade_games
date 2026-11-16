;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                              ;
;   ARCADE.ASM - credits, START and the 8-bit control panels   ;
;   of the Arcade6502 cabinet (vasm6502_oldstyle)              ;
;                                                              ;
;   The game defines, anywhere in its source:                  ;
;     ARC_VAR   24 bytes of free RAM (no zero page needed)     ;
;   and includes this file in its code:                        ;
;     include "../lib/arcade.asm"                              ;
;                                                              ;
;   ARC_INIT   A = most players of the game (1 or 2)           ;
;   ARC_JOY    A = player 1, X = player 2, 1 = pressed:        ;
;              bit 0 UP, 1 DOWN, 2 LEFT, 3 RIGHT, 4 BUTTON 1,  ;
;              5 BUTTON 2, 6 BUTTON 3, 7 START                 ;
;   ARC_START  A = players of the game that starts now (1-2),  ;
;              0 = nobody: call it at every frame of the title ;
;              (also kept in ARC_PLAYERS)                      ;
;   ARC_STATE  C = 1 when the texts below have changed since   ;
;              the last call (redraw them): ARC_MSG = pointer  ;
;              to the title line (20 characters + 0),          ;
;              ARC_CTXT = "CREDIT 0n" / "FREE PLAY" (9 + 0)    ;
;   ARC_DIRTY  the next ARC_STATE answers C = 1 (the page was  ;
;              drawn again)                                    ;
;   ARC_HOLD   the buttons held now are not new presses        ;
;   ARC_TSET   A/X = frames (lo/hi): starts the timer          ;
;   ARC_TICK   one frame of the timer: C = 1 when it is over   ;
;                                                              ;
;   Arcade BIOS with credits ($4C at $FD86): COIN gives a      ;
;   credit (max 9, counted by the BIOS); P1 START = 1 player,  ;
;   1 credit, P2 START = 2 players, 2 credits; FREE PLAY is    ;
;   chosen for each game in the system test of the BIOS.       ;
;   Arcade BIOS without credits: free play with START.         ;
;   Other machines (no $4C at $FD80): BUTTON 1 = 1 player,     ;
;   BUTTON 2 = 2 players, inputs masked to the 6 bits there.   ;
;                                                              ;
;   Created by Boogs77 - 2026                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ARC_JT_INPUTS  = $FD80       ; Arcade BIOS: A = P1, X = P2, Y = coins and switches
ARC_JT_CREDITS = $FD86       ; A = credits (0-9), C = 1 free play
ARC_JT_USE     = $FD89       ; A = credits to take (1-2): C = 0 taken / free play, C = 1 not enough
ARC_PORT_P1    = $D581       ; joystick VIA, port A (active low)
ARC_PORT_P2    = $D580       ; port B

ARC_B1         = %00010000
ARC_B2         = %00100000
ARC_B3         = %01000000
ARC_START_B    = %10000000

ARC_FLAGS = ARC_VAR          ; bit 7 credits in the BIOS, bit 6 arcade control panels
ARC_MASK  = ARC_VAR+1        ; $FF arcade, $3F elsewhere
ARC_MAXP  = ARC_VAR+2        ; most players of the game
ARC_PREV  = ARC_VAR+3        ; start buttons seen at the last ARC_START (bit 0 = 1 player, 1 = 2 players)
ARC_SHOWN = ARC_VAR+4        ; state of the texts the game shows ($FF = draw again)
ARC_TMP   = ARC_VAR+5
ARC_MSG   = ARC_VAR+6        ; 2 bytes: pointer to the title line
ARC_CTXT  = ARC_VAR+8        ; 10 bytes: "CREDIT 0n" or "FREE PLAY", 0
ARC_TIMER = ARC_VAR+18       ; 2 bytes: frames left (ARC_TSET / ARC_TICK)
ARC_PLAYERS = ARC_VAR+20     ; players of the last game started by ARC_START
                             ; ARC_VAR+21..+23: free for the game

ARC_INIT:
  STA ARC_MAXP
  STZ ARC_FLAGS
  LDA #$3F
  STA ARC_MASK
  LDA ARC_JT_INPUTS
  CMP #$4C
  BNE .ai_hold                 ; not the Arcade BIOS
  LDA #$FF
  STA ARC_MASK
  LDA #$40
  STA ARC_FLAGS
  LDA ARC_JT_CREDITS
  CMP #$4C
  BNE .ai_hold                 ; Arcade BIOS without credits
  LDA #$C0
  STA ARC_FLAGS
.ai_hold:
  JSR ARC_DIRTY
  ; fall into ARC_HOLD

ARC_HOLD:
  LDA #$03
  STA ARC_PREV
  RTS

ARC_DIRTY:
  LDA #$FF
  STA ARC_SHOWN
  RTS

ARC_TSET:
  STA ARC_TIMER
  STX ARC_TIMER+1
  RTS

ARC_TICK:
  LDA ARC_TIMER
  ORA ARC_TIMER+1
  BEQ .tk_end
  LDA ARC_TIMER
  BNE .tk_lo
  DEC ARC_TIMER+1
.tk_lo:
  DEC ARC_TIMER
  CLC
  RTS
.tk_end:
  SEC
  RTS

ARC_JOY:
  LDA ARC_PORT_P2
  EOR #$FF
  AND ARC_MASK
  TAX
  LDA ARC_PORT_P1
  EOR #$FF
  AND ARC_MASK
  RTS

; A = credits, C = 1 free play (always free play without the credits of the BIOS)
ARC_CREDITS:
  BIT ARC_FLAGS
  BPL .ac_free
  JMP ARC_JT_CREDITS
.ac_free:
  LDA #$00
  SEC
  RTS

ARC_START:
  JSR ARC_JOY                  ; A = P1, X = P2
  BIT ARC_FLAGS
  BVC .as_mini
  ASL A                        ; C = P1 START
  LDA #$00
  ROL A                        ; bit 0 = P1 START
  CPX #$80
  BCC .as_cur                  ; P2 START not pressed
  ORA #$02
  BRA .as_cur
.as_mini:                      ; BUTTON 1 = 1 player, BUTTON 2 = 2 players (either joystick)
  STX ARC_TMP
  ORA ARC_TMP
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
.as_cur:
  TAX                          ; X = held now
  LDA ARC_PREV
  EOR #$FF
  STX ARC_PREV
  AND ARC_PREV                 ; A = new presses
  BEQ .as_none
  LSR A
  LDA #$01                     ; bit 0: one player
  BCS .as_use
  LDA ARC_MAXP                 ; bit 1: two players (one if the game has one)
.as_use:
  STA ARC_TMP
  BIT ARC_FLAGS
  BPL .as_ok                   ; no credits: free play
  JSR ARC_JT_USE
  BCS .as_none                 ; not enough credits
.as_ok:
  JSR ARC_DIRTY
  LDA ARC_TMP
  STA ARC_PLAYERS
  RTS
.as_none:
  LDA #$00
  RTS

ARC_STATE:
  BIT ARC_FLAGS
  BVS .st_arc
  LDA #$00                     ; state 0: buttons, 1-player game
  LDX ARC_MAXP
  CPX #$02
  BCC .st_key
  LDA #$10                     ; state 1: buttons, 2-player game
  BRA .st_key
.st_arc:
  JSR ARC_CREDITS
  BCC .st_coin
  LDA #$20                     ; state 2: free play
  BRA .st_key
.st_coin:
  CMP #10
  BCC .st_c9
  LDA #9
.st_c9:
  LDX #$30                     ; state 3: no credits
  CMP #$00
  BEQ .st_or
  LDX #$40                     ; state 4: one credit
  CMP #$02
  BCC .st_or
  LDX #$50                     ; state 5: two or more
.st_or:
  STX ARC_TMP
  ORA ARC_TMP
.st_key:                       ; A = state << 4 | credits
  CMP ARC_SHOWN
  BNE .st_new
  CLC
  RTS
.st_new:
  STA ARC_SHOWN
  LSR A
  LSR A
  LSR A
  LSR A
  TAX                          ; X = state
  LDA ARC_MSGS_LO,X
  STA ARC_MSG
  LDA ARC_MSGS_HI,X
  STA ARC_MSG+1
  LDA ARC_MAXP                 ; 1-player game: "PRESS START" instead of 1P / 2P
  CMP #$02
  BCS .st_msg
  CPX #$02
  BCC .st_msg
  CPX #$03
  BEQ .st_msg
  LDA #<ARC_M_ST
  STA ARC_MSG
  LDA #>ARC_M_ST
  STA ARC_MSG+1
.st_msg:
  LDA ARC_CTXT_OF,X            ; the credit line: blank, FREE PLAY or CREDIT 0n
  TAY
  PHX
  LDX #$00
.st_ct:
  LDA ARC_CTXTS,Y
  STA ARC_CTXT,X
  INY
  INX
  CPX #$09
  BNE .st_ct
  STZ ARC_CTXT+9
  PLX
  CPX #$03
  BCC .st_end
  LDA ARC_SHOWN
  AND #$0F
  ORA #$30
  STA ARC_CTXT+8               ; the digit of "CREDIT 0n"
.st_end:
  SEC
  RTS

; title lines (20 characters) and credit lines of the states 0-5
ARC_MSGS_LO: .byte <ARC_M_B1,<ARC_M_B12,<ARC_M_12,<ARC_M_COIN,<ARC_M_1,<ARC_M_12
ARC_MSGS_HI: .byte >ARC_M_B1,>ARC_M_B12,>ARC_M_12,>ARC_M_COIN,>ARC_M_1,>ARC_M_12
ARC_CTXT_OF: .byte 0,0,18,9,9,9
ARC_M_B1:   .byte "   PRESS BUTTON 1   ",0
ARC_M_B12:  .byte " B1 = 1P    B2 = 2P ",0
ARC_M_12:   .byte "PRESS 1P OR 2P START",0
ARC_M_COIN: .byte "    INSERT  COIN    ",0
ARC_M_1:    .byte "   PRESS 1P START   ",0
ARC_M_ST:   .byte "    PRESS  START    ",0
ARC_CTXTS:  .byte "         "           ; 0: blank
            .byte "CREDIT 0 "           ; 9: the digit goes at +8
            .byte "FREE PLAY"           ; 18
