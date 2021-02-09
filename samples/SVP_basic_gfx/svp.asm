;****************************************************************************************
; SVP ACCESS CODE
;****************************************************************************************
; This part of the source offer the main routines we use to
; submit the drawing command to the SVP, as well as preparing
; data so that the generated tiles can be displayed correctly.
;****************************************************************************************

;****************************************************************************************
; External registers
;****************************************************************************************
; The DSP contained inside the SVP chip has 7 external registers that can
; be used as a normal register in SVP code, but they're external (duh) to
; the DSP and can be accessed by the Mega Drive/Genesis side. We'll use the
; following ones:
;
; - XST: Mega Drive/Genesis can submit words (16 bytes) to the SVP side.
;        Both sides can write/read from this register (unconfirmed yet: maybe 
;        the 68000 side can't read what the SVP side writes).
;        Useful to activate the SVP to perform certain operations.
;
; - XST_State: This register allows both sides to check if the other part has
;              read/written from XST. It contains two main bits:
;              ???? ???? ???? ??10
;              
;              0: active if DSP has written data. And cleared when M68000 reads from it.
;              1: active if M68000 has written data. Cleared if DSP reads from it.
;
; The Mega Drive/Genesis side can access these through memory mappings.
;****************************************************************************************

regXST          equ 0x00A15000
regXSTState     equ 0x00A15004
regXSTState_L   equ 0x00A15005

;*****************************************
; Sources/destinations of generated tiles
;*****************************************
dramTilesOrigin         equ 0x00302000
dramTilesSize           equ 0x1000
vramTilesDestination    equ 0x0A00

;********************************************************************************
; Setting up tilemap for SVP-generated tiles
;********************************************************************************
; SVP-generated tiles will be transferred to VRAM, but for them to be displayed
; they need to line up with the indices of the following tilemap. It allows them
; to be shown and to behave as a small 8x8-tile sized framebuffer.
;********************************************************************************
PrepareTilemapForSVP:
    ; This routine writes in VRAM a tilemap that allows SVP data to be displayed
    ; as a 8 x 8 tileset in the center of the screen.
    ;
    ; d0 = offset for tile data
    ; a0 = where to write in VRAM

    clr.l d1        ; d1 will contain Y counter
    move.w a0, d4   ; d4 to iterate over the different VRAM addresses

    ; Put the framebuffer a bit more centered before writing to screen
    add.w #0x220, d4

@loop_y:
    clr.l d2        ; d2 will contain X counter
    cmp.w #8, d1    ; are we done?
	beq @end
    bne @loop_x
@update_row:
    add.w #1, d1
    add.w #0x70, d4   ; next row
    
    bra @loop_y
@loop_x:
    cmp.w #8, d2    ; are we done with this row?
    beq @update_row

    ; Perform VDP write
    move.l d4, d5
    SetVramAddrReg d4, vdp_cmd_vram_write
    move.l d5, d4
    move.w d0, vdp_data

    add.w #1, d2
    add.l #2, a0                    ; update VRAM address
    add.w #1, d0                    ; update next tile number
    add.l #2, d4                    ; update next tile address
    
    bra @loop_x

@end:
    rts

;********************************************************************************
; Request tile data to the SVP
;********************************************************************************
; This small routine just sends to the XST register the current color index we 
; want for our next set of tiles to be generated by the SVP. The SVP should be
; waiting for this write (by checking on the XST_State register) to start the
; tile generation process.
;********************************************************************************
AskSVPForTileData:
    ; d0 (byte - actually nibble): color to be used for the tiles (0-F)

    and.l #0xF, d0
    move.w d0, regXST

@AskSVPEnd
    rts