
	;; Simple boot sector code, which loads image of Bertrand Russell on 
	;; the sectors 2-4 of the boot disk.
	;; 
	;; Written by Ville Räisänen vsr@vsr.name
	;; 
	;; BIOS loads the boot sector with the following code to the address
	;; 0x7c00. We need indicate this location to the NASM so that the
	;; memory addresses in instructions are appropriate.
	
[org 0x7c00]
	
	BITS 16 		; We work in 16-bit real mode.

	;; Memory organization after boot:
	;; 0x00000 - 0x003FF Real Mode Interrupt Vector Table
	;; 0x00400 - 0x004FF BIOS Data Area
	;; 0x00500 - 0x07BFF Free
	;; 0x07C00 - 0x07CFF Boot Sector
	;; 0x07E00 - 0x7FFFF Free
	;; 0x80000 - 0x9FBFF Free, if exists
	;; 0x9FC00 - 0x9FFFF Extended BIOS Data Area
	;; 0xA0000 - 0xFFFFF Video Memory and ROM Area

	;; We will set Stack to grow down from 0x80000. Before copying each
	;; part of the image to the video memory, the data is read to
	;; 0x09000-0x0D9FF.
start:
	mov byte [BOOT_DRIVE],       dl   ; The boot drive is given by the BIOS.
	mov word [VIDEO_TARGET],     0xa000
	mov word [IMAGE_INPUT_ADDR], 0x0920
	mov byte [INDEX_CYLINDER],   0
	mov byte [NUM_CYLINDERS],    3

	mov bp, 8000h			; Set Stack Segment at 0x80000.
	mov sp, bp
	
	mov ah, 0			; Set Video Mode
	mov al, 0x13			; MCGA (320x200x256)
	int 10h

	call set_palette
repeat_read:	
	mov ah, 2     			; Read Sectors From Drive
	mov al, 37			; Sectors To Read Count
	mov bx, 9000h			; ES:BX Buffer Address Pointer
	mov ch, [INDEX_CYLINDER]	; Cylinder
	mov cl, 1			; Sector
	mov dh, 0			; Head
	mov dl, [BOOT_DRIVE]		; Drive

	int 13h	
	jc disk_error			; Carry flag is set in case of error.

        mov bx, [VIDEO_TARGET]
	mov cx, [IMAGE_INPUT_ADDR]	; First sector is the boot sector.
	call repeat_pixel

	;;  (37 - 1) sectors * 512 bytes/sector = 18432 bytes = 1152 * 16 bytes
	add word [VIDEO_TARGET], 1152 	; Increase the target video address. 

	inc byte [INDEX_CYLINDER] 	; Jump back if last cylinder to be 
	mov ah, [NUM_CYLINDERS]		; read is not reached.
	cmp byte [INDEX_CYLINDER], ah
	jne repeat_read
	
	jmp finish
	
repeat_pixel:
	mov ds, cx
	mov WORD ax, [ds:di]
	mov ds, bx
	mov WORD [ds:di], ax
	inc di
	cmp di, 18944
	je finish_draw
	jmp repeat_pixel
finish_draw:
	mov cx, 0
	mov ds, cx
	ret

	;; Generate a grayscale palette by dividing the color index by 4
	;; for the RGB values.
set_palette:
	mov bx, 0 ; color
repeat_palette:

	mov dx, 0		; We wish to avoid an exception.
	mov ax, bx
	mov cx, 4
	div cx

        mov dh, al       	; Red Value   (0-63)
        mov ch, al 	 	; Green Value (0-63)
        mov cl, al	 	; Blue Value  (0-63)

	mov ax, 1010h 	 	; Set One DAC Color Register.
        int 10h

	inc bx
	cmp bx, 255
	jne repeat_palette

	ret
       
finish:		
	jmp $			; Endless loops.

disk_error:
	mov ah, 0		; Set Video Mode
	mov al, 0x3		; VGA Text Mode (80x25x16)
	int 10h

	mov ax, 0		; The output string is read from DS:SI.
	mov ds, ax		; Thus, we need to set DS to 0.
	mov si, DISK_ERROR_MSG
	call print_string
	jmp $


	;; Print a character string starting at DS:SI.
print_string:
	mov ah, 0eh		; Teletype Output
.repeat:
	lodsb			; Load byte to AL from DS:SI and increment SI.
	cmp al, 0		; Jump to .done if character is equal to 0.
	je .done
	int 10h
	jmp .repeat
.done:
	ret

	
INDEX_CYLINDER   db 0
NUM_CYLINDERS    db 0	
VIDEO_TARGET     dw 0	
BOOT_DRIVE       db 0
IMAGE_INPUT_ADDR dw 0	
DISK_ERROR_MSG   db "Disk Read Error!", 0
times 510-($-$$) db 0
dw 0xaa55


%include "img.asm"
