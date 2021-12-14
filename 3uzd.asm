; Program: No. 3.1
; Task: Disassemble MOV, OUT, NOT, RCR, XLAT
; Made by: Kostas Ragauskas

JUMPS

.model small
.stack 100h

bufferLen = 3
sourceNameBuf = 14
outputNameBuf = 14
outputBufferLen = 100	;buffer for one line output
tempBufferLen = 5
hexBufferLen = 2

.data
	enterSymbol			db 0Dh, 0Ah

	introMSG			db 'The application disassembles .com files (or inputed bytes).', 0Dh, 0Ah, '/? - help', 0Dh, 0Ah, '$'
	helpMSG				db 'Help: all parameters should be .com files, separated by spaces. No parameters means input from the keyboard - input bytes in hexadecimal (minus sign to stop the input).', '$'

	errorCreatingMSG	db 0Dh, 0Ah, 'Failed to create the file: ', '$'
	errorOpeningMSG		db 0Dh, 0Ah, 'Failed to open the file: ', '$'
	errorReadingMSG		db 0Dh, 0Ah, 'Failed to read the file: ', '$'
	errorWritingMSG		db 0Dh, 0Ah, 'Failed to write to the file: ', '$'
	errorTooShortMSG	db 0Dh, 0Ah, 'One of the inputed parameters is too short (should be at least 5 symbols)', '$'

	successWritingMSG	db 0Dh, 0Ah, 'Successfully disassembled the file: ', '$'

	paramMSG			db 0Dh, 0Ah, 'Error reading the parameters.', '$'
	bufferMSG			db 0Dh, 0Ah, 'Error - the current buffer is too small (should be at least 1)', '$'

	successMSG			db 0Dh, 0Ah, 'The program finished tasks successfully.', '$'

	sourceF				db sourceNameBuf dup (0)
	outputF				db outputNameBuf dup (0)

	sourceBuffer		db (bufferLen) dup (?)
	outputBuffer		db (outputBufferLen + 1) dup (' ')

	tempBuffer			db (tempBufferLen + 1) dup ('0')
	tempLineBuffer		db (outputBufferLen + 1) dup (' ')
	tempSrBuffer		db (outputBufferLen + 1) dup (' ')
	hexBuffer			db (hexBufferLen + 1) dup ('$')
	offsetBuffer		db (tempBufferLen + 1) dup ('$')
	tempOffsetBuffer	db (tempBufferLen + 1) dup ('$')
	additionalBuffer	db (tempBufferLen + 1) dup ('$')
	
	comma			db ', ', '$' 
	h_letter		db 'h', '$'
	plus_sign		db ' + ', '$'
	one_symbol		db '1', '$'
	space_symbol	db ' ', '$'
	dollar_sign		db '', '$'

	hexTable		db '0123456789ABCDEF', 0
	defaultOutputFileName db 'rez.txt', '$'

	movWord			db 'MOV ', '$'
	rcrWord			db 'RCR ', '$'
	notWord			db 'NOT ', '$'
	outWord			db 'OUT ', '$'
	xlatWord		db 'XLAT', '$'
	undefinedWord	db 'UNDEFINED', '$'

	sourceFHandle		dw 99
	outputFHandle		dw 99	

	tempAL_index		dw 0
	tempAL				dw 0

	currentBufferRead	dw 0
	currentBufferLen	dw 0

	first_file_indicator	dw 0
	shortFileIndicator		dw 0	
	wrongFileIndicator		dw 0	
	wrong_value_indicator	dw 0

	offsetIndex			dw 0
	additionalIndex		dw 0
	
	readIndicator		dw 0
	bytesReadHex		dw 0
	byteIndex			dw 0

	unidentifiedIndex	dw 0
	identifiedIndex		dw 0

	movType1Index		dw 0
	movType2Index		dw 0
	movType3Index		dw 0
	movType4Index		dw 0
	movType5Index		dw 0

	rcrIndex			dw 0
	notIndex			dw 0
	outIndex			dw 0
	outPortIndex		dw 0
	
	port		dw 0

	val_prefix	dw 5
	val_d		dw 0
	val_v		dw 0
	val_w		dw 0
	val_mod		dw 0
	val_rm		dw 0
	val_reg		dw 0
	val_sr		dw 0

	val_byte_ptr db 'byte ptr ', '$'
	val_word_ptr db 'word ptr ', '$'

	reg_al		db 'al', '$'
	reg_cl		db 'cl', '$'
	reg_dl		db 'dl', '$'
	reg_bl		db 'bl', '$'

	reg_ah		db 'ah', '$'
	reg_ch		db 'ch', '$'
	reg_dh		db 'dh', '$'
	reg_bh		db 'bh', '$'

	reg_ax		db 'ax', '$'
	reg_cx		db 'cx', '$'
	reg_dx		db 'dx', '$'
	reg_bx		db 'bx', '$'

	reg_sp		db 'sp', '$'
	reg_bp		db 'bp', '$'
	reg_si		db 'si', '$'
	reg_di		db 'di', '$'

	sr_es		db 'es', '$'
	sr_cs		db 'cs', '$'
	sr_ss		db 'ss', '$'
	sr_ds		db 'ds', '$'

	addr_bxsi	db 'bx + si', '$'
	addr_bxdi	db 'bx + di', '$'
	addr_bpsi	db 'bp + si', '$'
	addr_bpdi	db 'bp + di', '$'

	srs			dw offset sr_es, offset sr_cs, offset sr_ss, offset sr_ds
	rm_mod11_w0	dw offset reg_al, offset reg_cl, offset reg_dl, offset reg_bl, offset reg_ah, offset reg_ch, offset reg_dh, offset reg_bh
	rm_mod11_w1	dw offset reg_ax, offset reg_cx, offset reg_dx, offset reg_bx, offset reg_sp, offset reg_bp, offset reg_si, offset reg_di
	rm_mod00	dw offset addr_bxsi, offset addr_bxdi, offset addr_bpsi, offset addr_bpdi, offset reg_si, offset reg_di, offset reg_bp, offset reg_bx

.code
 
start:
	MOV ax, @data                   ; standart procedure
	MOV es, ax						; es needed for stosb: Store AL at address ES:(E)DI
	MOV	si, 81h        				; program's parameters are written to es, starting with the 81h byte  

	CALL skip_spaces				; skip all spaces before the first parameter

	MOV	al, byte ptr ds:[si]		; read the first symbol of the first parameter
	CMP	al, 0Dh						; if no parameters found (carriage return), set handle to zero
	JNE continue

	PUSH ds si						; pushing the data segment and source index to the stack (so than we can read more parameters from console if needed)
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV sourceFHandle, 0			; setting the handle to zero (input bytes yourself)
	POP si ds

continue:
	MOV	ax, word ptr ds:[si]		; read the first word of the first parameter
	CMP ax, 3F2Fh        			; if "/?" was found (where 3F = '?'and 2F = '/') (switched places because of ah and al)
	JE help                 		; jump to help

	PUSH ds si						; pushing the data segment and source index to the stack (so than we can read more parameters from console if needed)
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	CALL clear_screen				; clearing the console window

	MOV ah, 09h						; print the intro message
	LEA dx, introMSG
	INT 21h

	MOV cx, bufferLen				; restrict user from using buffer, which is 0
	CMP cx, 0
	JE bufferError		

readFileName:
	CMP first_file_indicator, 0
	JE readFileName_continue

	LEA	dx, successWritingMSG
	MOV	ah, 09h
	INT	21h

	LEA	dx, sourceF
	MOV	ah, 09h
	INT	21h

readFileName_continue:
	MOV bytesReadHex, 0h

	CMP sourceFHandle, 0
	JE openOutputFile

	POP si ds

	MOV di, offset sourceF		; reading the source file name
	CALL read_parameter	

	CMP	wrongFileIndicator, 1	; if the input is wrong, read error
	JE readParameterError
	CMP	shortFileIndicator, 1	; if the input is too short, param error
	JE parameterTooShortError
	CMP	byte ptr es:[sourceF], 0	; if the input is empty, files have ended
	JE endProgram

	PUSH ds si
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV first_file_indicator, 1

	MOV si, offset sourceF			; setting the output file name, based on the source file.
	MOV di, offset outputF			
	CALL set_output_name

openSourceFile:
	MOV	dx, offset sourceF			; moving file name to dx
	MOV	ah, 3dh					 	; 3dh - open file command
	MOV	al, 0						; 0 - reading, 1 - writing, 2 - both
	INT	21h	
	JC sourceError					; carry flag is set on error (AX = error code). If so, jump to sourceError

	MOV sourceFHandle, ax			; saving the source file handle

openOutputFile:
	MOV	dx, offset outputF			; creating or clearing the output file

	CMP sourceFHandle, 0
	JNE continueOpenOutputFile

	MOV	dx, offset defaultOutputFileName

continueOpenOutputFile:
	MOV offsetIndex, offset offsetBuffer
	MOV additionalIndex, offset additionalBuffer

	MOV	ah, 3ch						; 3ch - create/clear file command				
	MOV	cx, 0						; no attributes
	INT	21h					
	JC outputCreateError			; carry flag is set on error (AX = error code). If so, jump to outputError
		
	MOV	ah, 3dh					 	; 3dh - open file command
	MOV	al, 1						; 0 - reading, 1 - writing, 2 - both
	INT	21h	
	JC outputOpenError				; carry flag is set on error (AX = error code). If so, jump to outputError

	MOV outputFHandle, ax			; saving the output file handle
	MOV byteIndex, 0				; setting important indexes to 0
	MOV readIndicator, 0
	MOV bytesReadHex, 0

	CMP sourceFHandle, 0
	JE readSourceFile

	ADD bytesReadHex, 100h			; if reading from file - add 100h

readSourceFile:
	MOV	bx, sourceFHandle			; move file handle to bx
	MOV	dx, offset sourceBuffer		; move file buffer to dx
	MOV	cx, bufferLen				; bytes to read (the length of our buffer)
	MOV	ah, 3fh         			; function 3fh - read from file
	INT	21h
	JC readError					; if carry flag is on - jump to readError

	MOV currentBufferRead, 0

	MOV cx, ax
	MOV currentBufferLen, cx
	CMP cx, 0						; bytes are placed inside ax, so if that is equal to 0 - read another file
	JNE preIterate

	MOV cx, sourceFHandle
	CMP cx, 0
	JE endProgram					;if stdin ended - end the program

	MOV	bx, outputFHandle			; if we were reading from files - close them
	CALL close_file

	MOV	bx, sourceFHandle
	CALL close_file

	JMP readFileName

preIterate:
	MOV si, offset sourceBuffer

	CMP	sourceFHandle, 0
	JNE	preIterateContinue

	CMP 	currentBufferLen, 3		;stdin end symbol - minus sign
	JNE 	preIterateContinue
	CMP 	byte ptr ds:[si], '-'
	JNE 	preIterateContinue
	CMP 	byte ptr ds:[si + 1], 13
	JNE 	preIterateContinue
	CMP 	byte ptr ds:[si + 2], 10
	JNE 	preIterateContinue

	JMP	endProgram

preIterateContinue:
	CMP readIndicator, 2			;if read indicator was 2 - skip line beginning
	JE iterate

	MOV di, offset outputBuffer

	PUSH si								;writing the begining of the line 
	MOV bx, bytesReadHex
	CALL dec_to_hex_str

	MOV si, offset tempBuffer
	CALL write_to_buffer
	POP si

	MOV al, ':'
	STOSB
	MOV al, ' '
	STOSB

iterate:
	MOV readIndicator, 0
	CALL read_byte

endReadByte:
	CMP readIndicator, 2						; the buffer ended
	JE readSourceFile

	CMP readIndicator, 0						; did not read for whatever reason
	JE iterate

	CALL analyze_byte

	CMP identifiedIndex, 1						; if command was identified - write it
	JE writeLine

	CMP unidentifiedIndex, 1
	JNE iterate

	CALL write_delim						; Otherwise, undefined - write the line as well

	PUSH si
	MOV si, offset undefinedWord
	CALL write_to_buffer
	POP si

writeLine:
	MOV ax, byteIndex						; adding enter and clearing the values for the next command
	ADD bytesReadHex, ax

	MOV ax, 0Dh
	STOSB
	MOV al, 0Ah
	STOSB

	SUB di, offset outputBuffer
	MOV dx, offset outputBuffer
	MOV cx, di
	MOV bx, outputFHandle
	MOV ah, 40h						
	INT	21h
	JC writeError	

	CALL clear_output_buffer
	CALL clear_hex_buffer
	CALL clear_offset_buffer
	CALL clear_additional_buffer

	CALL clear_val

	JMP preIterateContinue

endProgram:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, successMSG
	MOV	ah, 09h
	INT	21h

	MOV	bx, outputFHandle
	CALL close_file

	CMP	sourceFHandle, 0
	JE	ending

	MOV	bx, sourceFHandle
	CALL close_file

	JMP ending						; jump to the end of the program

;#################### Error messages ####################

sourceError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV	bx, sourceFHandle
	CALL close_file

	LEA	dx, errorOpeningMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	MOV	dx, offset sourceF
	INT	21h

	JMP errorEnding

outputOpenError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, errorOpeningMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	LEA	dx, outputF
	INT	21h

	JMP standartError

outputCreateError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax
	
	MOV	bx, sourceFHandle
	CALL close_file

	LEA	dx, errorCreatingMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	LEA	dx, outputF
	INT	21h

	JMP errorEnding

parameterTooShortError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, errorTooShortMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	JMP errorEnding

readParameterError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, errorReadingMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	LEA	dx, sourceF
	INT	21h

	JMP errorEnding

readError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, errorReadingMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	LEA	dx, sourceF
	INT	21h

	JMP standartError

bufferError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV ah, 09h						; printing the message
	LEA dx, bufferMSG
	INT 21h

	JMP errorEnding

writeError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	LEA	dx, errorWritingMSG			; printing the message
	MOV	ah, 09h
	INT	21h
	
	LEA	dx, outputF
	INT	21h

	JMP standartError

standartError:
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV	bx, sourceFHandle
	CALL close_file

	MOV	bx, outputFHandle
	MOV	dx, offset outputF		; clearing the output file
	MOV	ah, 3ch					; 3ch - create/clear file command				
	MOV	cx, 0					; no attributes
	INT	21h	
	
	MOV	bx, outputFHandle
	CALL close_file

errorEnding:
	MOV	ax, 4c01h					; (error code 1)
	INT	21h 

help:
	MOV	ax, @data					; standart procedure (in case ax is still inside es)
	MOV	ds, ax

	CALL clear_screen

	MOV ah, 09h						; help message
	LEA dx, helpMSG
	INT 21h

ending:
	MOV ax, 4c00h 					; ending program (exit code 0)
	INT 21h 
	 
;******************** Clear screen procedure ********************

clear_screen PROC near
	PUSH ax
	MOV ax, 03h
    INT 10h
	POP ax
    RET 

clear_screen ENDP

;******************** Close file procedure ********************

close_file PROC near
	MOV	ah, 3Eh						; 3Eh - close file command
	INT	21h 	
	RET

close_file ENDP

;******************** Skip spaces procedure ********************

skip_spaces PROC near
	PUSH ax

skip_spaces_loop:
	CMP byte ptr ds:[si], ' '		; comparing the current byte with an empty char
	JNE skip_spaces_end				; if it is not equal to the empty byte - jump to skip_spaces_end
	INC si
	JMP skip_spaces_loop

skip_spaces_end:
	POP ax
	RET
	
skip_spaces ENDP

;******************** Reading parameter procedure ********************

read_parameter PROC near
	PUSH ax bx

	MOV wrongFileIndicator, 0
	MOV shortFileIndicator, 0

	CALL skip_spaces				; skip spaces to the parameter
	MOV bx, 0

read_parameter_start:
	INC bx
	CMP bx, (sourceNameBuf - 1)
	JAE read_parameter_end

	CMP	byte ptr ds:[si], 0Dh		; comparing if the symbol is carriage return
	JE is_file_com					; if so, end the input
	CMP	byte ptr ds:[si], ' '		; if space is not detected
	JNE	read_parameter_next			; then move forward to the next character

is_file_com:
	CMP bx, 1
	JE parameters_ended

	CMP bx, 6				; checking if the file name is at least 5 symbols and whether or not it ends with 'com'
	JB parameter_too_short

	CMP	byte ptr ds:[si - 1], 'm'
	JNE	read_parameter_error
	CMP	byte ptr ds:[si - 2], 'o'
	JNE	read_parameter_error
	CMP	byte ptr ds:[si - 3], 'c'
	JNE	read_parameter_error

	JMP read_parameter_end

parameters_ended:
	MOV	al, 0			; write 0 to the end of al
	STOSB  
	POP	bx ax
	RET

read_parameter_end:   
	MOV	al, 0			; write 0 to the end of al
	STOSB  
	MOV	al, '$'			; write dollar to the end of al (for writing)
	STOSB                          
	POP	bx ax
	RET

read_parameter_next:
	LODSB				; load and store the symbol
	STOSB
	JMP read_parameter_start
	
read_parameter_error:
	MOV wrongFileIndicator, 1
	JMP read_parameter_end

parameter_too_short:
	MOV shortFileIndicator, 1
	JMP read_parameter_end

read_parameter ENDP

;******************** Setting the output file procedure ********************

set_output_name PROC near
	PUSH ax

	MOV al, '_'
	STOSB

loopSetOutputFile:
	LODSB					; rewrite the other symbols as they were
	STOSB

	CMP al, '.'
	JE writeTXT

	CMP al, 0				; comparing if the symbol is zero
	JE endSettingFile

	JMP loopSetOutputFile

endSettingFile:
	POP ax
	RET

writeTXT:
	MOV al, 't'				; adding '.txt' in the end
	STOSB
	MOV al, 'x'
	STOSB
	MOV al, 't'
	STOSB
	MOV al, '$'
	STOSB

	JMP endSettingFile

set_output_name ENDP

;******************** WriteToBuffer procedure ********************

write_to_buffer PROC near
	PUSH ax

loopWriteToBuffer:
	LODSB

	CMP al, '$'				; if dollar was found - end the writing
	JE endWriteToBuffer

	STOSB
	JMP loopWriteToBuffer

endWriteToBuffer:
	POP ax
	RET

write_to_buffer ENDP

;******************** WriteToMemory procedure ********************

write_to_memory PROC near
	PUSH ax
	CALL write_ptr

	MOV cx, val_sr
	PUSH cx

	CMP val_prefix, 5
	JE after_segment
	
	MOV cx, val_prefix
	MOV val_sr, cx
	CALL write_sr

	MOV al, ':'
	STOSB

after_segment:
	POP cx
	MOV val_sr, cx

	MOV al, '['
	STOSB

	CALL write_to_buffer

	MOV al, ']'
	STOSB

	POP ax
	RET

write_to_memory ENDP

;******************** stdin AH to hex AL procedure ********************

stdin_byte_AH_to_AL_hex PROC near
	MOV wrong_value_indicator, 0

	CMP ah, 'a'							;if lowercase letters detected - make them uppercase
	JB stdin_byte_AX_to_AL_convert
	CMP ah, 'f'
	JA stdin_byte_AX_to_AL_convert

	SUB ah, 32

stdin_byte_AX_to_AL_convert:
	CMP ah, '0'
	JB wrong_value
	CMP ah, 'F'
	JA wrong_value

check_if_wrong_number:
	CMP ah, '9'
	JA check_if_wrong_letter
	JMP convert_numbers

check_if_wrong_letter:
	CMP ah, 'A'
	JB wrong_value

convert_letters:
	SUB ah, 55
	JMP end_stdin_byte_AX_to_AL

convert_numbers:
	SUB ah, 48
	JMP end_stdin_byte_AX_to_AL

wrong_value:
	MOV wrong_value_indicator, 1
	
end_stdin_byte_AX_to_AL:
	RET

stdin_byte_AH_to_AL_hex ENDP

;******************** Decimal to hex String procedure ********************

dec_to_hex_str PROC near
	PUSH ax	si	;decimal bx to hex string tempBuffer

convert:
	MOV si, offset tempBuffer + tempBufferLen
	MOV byte ptr ds:[si], '$'

	MOV ax, bx
	MOV bx, 16

asc2:
	mov dx, 0
	div bx

	PUSH ax bx			;getting the correct symbol from hexTable
	MOV al, dl
	MOV bx, offset hexTable
	XLAT
	MOV dl, al
	POP bx ax

	dec si
	mov[si], dl

	cmp ax, 0
	jz endDecToHex
	jmp asc2

endDecToHex:
	POP si ax
	RET

dec_to_hex_str ENDP

;******************** Write delimiter procedure ********************

write_delim PROC near
	PUSH ax bx

	CMP val_prefix, 5
	JNE write_delim_continue
	DEC byteIndex
 
write_delim_continue:
	MOV bx, 2		;getting the actual byte count
	MOV ax, byteIndex
	MUL bx
	MOV bx, ax

	MOV ax, 15		;setting the di to be alligned
	SUB ax, bx
	ADD di, ax

	MOV al, ' '
	STOSB
	MOV al, '|'
	STOSB
	MOV al, ' '
	STOSB

	POP bx ax
	RET

write_delim ENDP

;******************** Read byte procedure ********************

read_byte PROC near
	XOR ax, ax

	CMP sourceFHandle, 0		;if handle = 0, read from stdin
	JNE read_byte_file
	CALL read_byte_stdin
	RET

read_byte_file:
	PUSH cx
	MOV cx, currentBufferRead
	CMP cx, currentBufferLen
	JAE endOfBuffer

	LODSB

read_byte_continue:
	CALL write_command_code
	ADD byteIndex, 1
	ADD currentBufferRead, 1
	MOV readIndicator, 1		; indicator, that at least one byte was read
	JMP endOfReadProc

endOfBuffer:
	MOV readIndicator, 2				;indicator that the buffer ended

endOfReadProc:
	POP cx
	RET

read_byte ENDP

;******************** Read byte from stdin procedure ********************

read_byte_stdin PROC near
read_byte_stdin_begin:
	CMP tempAL_index, 1
	JE read_byte_stdin_second

	MOV tempAL_index, 0

read_byte_stdin_first:
	MOV cx, currentBufferRead
	CMP cx, currentBufferLen
	JAE endOfBufferStdin

	LODSB
	ADD currentBufferRead, 1

	MOV ah, al
	CALL stdin_byte_AH_to_AL_hex

	CMP wrong_value_indicator, 1
	JE read_byte_stdin_begin

	XOR al, al
	MOV bx, 16
	MUL bx
	XOR bx, bx
	MOV bl, ah

	MOV tempAL, bx
	ADD tempAL_index, 1

read_byte_stdin_second:
	MOV cx, currentBufferRead
	CMP cx, currentBufferLen
	JAE endOfBufferStdin

	LODSB
	ADD currentBufferRead, 1

	MOV ah, al
	CALL stdin_byte_AH_to_AL_hex

	CMP wrong_value_indicator, 1
	JE read_byte_stdin_begin

	MOV bx, tempAL
	MOV bh, ah
	MOV ax, bx
	ADD al, ah
	XOR ah, ah

	CALL write_command_code

	ADD byteIndex, 1
	ADD tempAL_index, 1
	MOV readIndicator, 1		; indicator, that at least one byte was read

	JMP endOfReadStdinProc

endOfBufferStdin:
	MOV readIndicator, 2				;indicator that the buffer ended

endOfReadStdinProc:
	RET

read_byte_stdin ENDP

;******************** Analyze byte procedure ********************

analyze_byte PROC near	;byte should be in al
	MOV unidentifiedIndex, 0

	CMP byteIndex, 0
	JE endAnalyze

	CMP byteIndex, 1
	JE analyzePrefix
	CMP byteIndex, 2
	JE analyzeOpcode
	CMP byteIndex, 3
	JE analyzeSecondByte
	CMP byteIndex, 4
	JE analyzeThirdByte
	CMP byteIndex, 5
	JE analyzeFourthByte
	CMP byteIndex, 6
	JE analyzeFifthByte
	CMP byteIndex, 7
	JE analyzeSixthByte

	JMP unidentified

;;;******************Analyzing prefix******************;;;
analyzePrefix:
is_prefix_es:
	CMP al, 26h
	JNE is_prefix_cs
	MOV val_prefix, 0
	JMP endAnalyze

is_prefix_cs:
	CMP al, 2Eh
	JNE is_prefix_ss
	MOV val_prefix, 1
	JMP endAnalyze

is_prefix_ss:
	CMP al, 36h
	JNE is_prefix_ds
	MOV val_prefix, 2
	JMP endAnalyze

is_prefix_ds:				;unnecessary - it is always ignored
	CMP al, 3Eh
	JNE not_segment
	MOV val_prefix, 3
	JMP endAnalyze

not_segment:
	ADD byteIndex, 1
	JMP analyzeOpcode

;;;******************Analyzing opcode******************;;;

analyzeOpcode:	
	PUSH ax

    XOR al, 10001000b	;DONE if move type 1  - the result will be 0-3 (that is our d and w values)
    CMP al, 4
    JAE skip_mov_type_1
	MOV bl, al

	POP ax
	CALL set_val_w_last
	CALL set_val_d
    MOV MovType1Index, 1

	JMP endAnalyze

skip_mov_type_1:
	POP ax
	PUSH ax

    XOR al, 11000110b	;DONE if move type 2  - the result will be 0 or 1 (that is our w value)
    CMP al, 2
    JAE skip_mov_type_2
	MOV bl, al

	POP ax
	CALL set_val_w_last
    MOV MovType2Index, 1

	JMP endAnalyze

skip_mov_type_2:
	POP ax
	PUSH ax

    XOR al, 10110000b	;DONE if move type 3- the result will be 0-15 (that is our w and reg values)
    CMP al, 16
    JAE skip_mov_type_3
	MOV bl, al

	POP ax
	CALL set_val_w_first
	AND bl, 00000111b
	XOR bh, bh
	MOV val_reg, bx

	MOV MovType3Index, 1
	JMP endAnalyze

skip_mov_type_3:
	POP ax
	PUSH ax

    XOR al, 10100000b	;DONE if move type 4 (adrjb adrvb) - the result will be 0-3 (that is our v and w values)
    CMP al, 4
    JAE skip_mov_type_4
	MOV bl, al

	POP ax
	CALL set_val_v
	CALL set_val_w_last
	MOV MovType4Index, 1
	JMP endAnalyze

skip_mov_type_4:
	POP ax
	PUSH ax

    XOR al, 10001100b	;DONE if move type 5 - the result will be 0 or 1 (that is our d value)
    SHR al, 1
    CMP al, 2
    JAE skip_mov_type_5
	MOV bl, al

	POP ax
	CALL set_val_d
    MOV MovType5Index, 1
	JMP endAnalyze

skip_mov_type_5:		;DONE if out port - the result will be 0 or 1 (that is our w value)
	POP ax
	PUSH ax

    XOR al, 11100110b
    CMP al, 2
    JAE skip_out_port
	MOV bl, al

	POP ax
	CALL set_val_w_last
    MOV outPortIndex, 1

	JMP endAnalyze

skip_out_port:
	POP ax
	PUSH ax

    XOR al, 11101110b	;DONE if out - the result will be 0 or 1 (that is our w value)
    CMP al, 2
    JAE skip_out
	MOV bl, al

	POP ax
	CALL set_val_w_last
    CALL analyze_out

	JMP endAnalyze

skip_out:
	POP ax
	PUSH ax

    XOR al, 11110110b	;DONE if not - the result will be 0 or 1 (that is our w value)	
    CMP al, 2
    JAE skip_not
	MOV bl, al

	POP ax
	CALL set_val_w_last
	MOV notIndex, 1
	JMP endAnalyze

skip_not:
	POP ax
	PUSH ax

    XOR al, 11010000b	;DONE if rcr - the result will be 0-3 (that is our v and w values)	
    CMP al, 4
    JAE skip_rcr
	MOV bl, al

	POP ax
	CALL set_val_v
	CALL set_val_w_last
	MOV rcrIndex, 1
	JMP endAnalyze

skip_rcr:
	POP ax
	PUSH ax

    XOR al, 11010111b	;DONE if xlat - the result will be zero
    CMP al, 1
    JAE skip_xlat
	POP ax
    CALL analyze_xlat
	JMP endAnalyze

skip_xlat:
	POP ax				;instruction undefined
	JMP unidentified
    
;;;******************Analyzing second byte******************;;;

analyzeSecondByte:
	CMP movType5Index, 1
	JE analyzeSecondByteMovType5
	CMP movType4Index, 1
	JE analyzeSecondByteMovType4
	CMP movType3Index, 1
	JE analyzeSecondByteMovType3
	CMP movType2Index, 1
	JE analyzeSecondByteMovType2
	CMP movType1Index, 1
	JE analyzeSecondByteMovType1
	CMP outPortIndex, 1
	JE analyzeSecondByteOutPort
	CMP notIndex, 1
	JE analyzeSecondByteNot
	CMP rcrIndex, 1
	JE analyzeSecondByteRcr

	JMP unidentified

analyzeSecondByteMovType1:
	CALL get_rm_mod
	CALL get_reg

is_movType1_mod_3:
	CMP val_mod, 3
	JNE is_movType1_mod_0
	CALL analyze_movType1
	JMP endAnalyze

is_movType1_mod_0:
	CMP val_mod, 0
	JNE needs_offset

	CMP val_rm, 6			;direct address
	JE needs_offset

	CALL analyze_movType1
	JMP endAnalyze

analyzeSecondByteMovType2:
	PUSH ax
    AND al, 00111000b	;the result should be 0 (decimal)
	MOV bl, al
	POP ax
    CMP bl, 0
    JNE unidentified

	CALL get_rm_mod
	JMP endAnalyze

analyzeSecondByteMovType3:
	CALL add_to_offset_buffer
	CMP val_w, 0
	JNE is_mov_type3_w1
	CALL analyze_movType3

is_mov_type3_w1:
	JMP endAnalyze

analyzeSecondByteMovType4:
	CALL add_to_offset_buffer
	JMP endAnalyze

analyzeSecondByteMovType5:
	PUSH ax
    AND al, 00100000b	;the result should be 0 (decimal)
	MOV bl, al
	POP ax
    CMP bl, 0
    JNE unidentified

	CALL get_rm_mod
	CALL get_sr

is_movType5_mod_3:
	CMP val_mod, 3
	JNE is_movType5_mod_0
	CALL analyze_movType5
	JMP endAnalyze

is_movType5_mod_0:
	CMP val_mod, 0
	JNE needs_offset

	CMP val_rm, 6
	JE needs_offset

	CALL analyze_movType5
	JMP endAnalyze	

analyzeSecondByteOutPort:
	CALL analyze_out_port
	JMP endAnalyze

analyzeSecondByteNot:
	PUSH ax
    AND al, 00111000b	;the result should be 16 (decimal)
	MOV bl, al
	POP ax
    CMP bl, 16
    JNE unidentified

	CALL get_rm_mod

is_not_mod_3:
	CMP val_mod, 3
	JNE is_not_mod_0
	CALL analyze_not
	JMP endAnalyze

is_not_mod_0:
	CMP val_mod, 0
	JNE needs_offset

	CMP val_rm, 6
	JE needs_offset

	CALL analyze_not
	JMP endAnalyze

needs_offset:
	JMP endAnalyze

analyzeSecondByteRcr:
	PUSH ax
    AND al, 00111000b	;the result should be 24 (decimal)
	MOV bl, al
	POP ax
    CMP bl, 24
    JNE unidentified

	CALL get_rm_mod

is_rcr_mod_3:
	CMP val_mod, 3
	JNE is_rcr_mod_0
	CALL analyze_rcr
	JMP endAnalyze

is_rcr_mod_0:
	CMP val_mod, 0
	JNE needs_offset

	CMP val_rm, 6
	JE needs_offset

	CALL analyze_rcr
	JMP endAnalyze
	
;;;******************Analyzing third byte******************;;;

analyzeThirdByte:
	CMP movType5Index, 1
	JE analyzeThirdByteMovType5
	CMP movType4Index, 1
	JE analyzeThirdByteMovType4
	CMP movType3Index, 1
	JE analyzeThirdByteMovType3
	CMP movType2Index, 1
	JE analyzeThirdByteMovType2
	CMP movType1Index, 1
	JE analyzeThirdByteMovType1
	CMP notIndex, 1
	JE analyzeThirdByteNot
	CMP rcrIndex, 1
	JE analyzeThirdByteRcr

	JMP unidentified

analyzeThirdByteMovType1:
	CALL add_to_offset_buffer

	CMP val_mod, 0
	JNE analyzeThirdByteMovType1_continue
	CMP val_rm, 6
	JE endAnalyze

analyzeThirdByteMovType1_continue:
	CMP val_mod, 1
	JNE endAnalyze
	CALL analyze_movType1
	JMP endAnalyze

analyzeThirdByteMovType2:
	CMP val_mod, 3			;mod = 3, no offset
	JNE is_movType2_mod_0

	CALL add_to_offset_buffer	;add bojb to offset

	CMP val_w, 1				; is bovb needed?
	JNE is_movType2_w0_third
	JMP endAnalyze

is_movType2_w0_third:
	CMP val_mod, 0
	JNE movType2_mod_10_third

	CMP val_rm, 6
	JNE movType2_mod_10_third
	JMP endAnalyze

movType2_mod_10_third:	
	CALL analyze_movType2		; if not - analyze
	JMP endAnalyze

is_movType2_mod_0:			;mod = 0, no offset
	CMP val_mod, 0
	JNE movType2_mod_10_third_

	CMP val_rm, 6
	JE movType2_mod_10_third_

	CALL add_to_offset_buffer	;add bojb to offset

	CMP val_w, 1			; is bovb needed?
	JNE is_movType2_w0_third_
	JMP endAnalyze

is_movType2_w0_third_:
	CALL analyze_movType2	; if not - analyze
	JMP endAnalyze

movType2_mod_10_third_:			; if offset was found, add to additional buffer
	CALL add_to_additional_buffer
	JMP endAnalyze

analyzeThirdByteMovType3:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_movType3
	JMP endAnalyze

analyzeThirdByteMovType4:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_movType4
	JMP endAnalyze

analyzeThirdByteMovType5:
	CALL add_to_offset_buffer

	CMP val_mod, 0
	JNE analyzeThirdByteMovType5_continue
	CMP val_rm, 6
	JE endAnalyze

analyzeThirdByteMovType5_continue:
	CMP val_mod, 1
	JNE endAnalyze
	CALL analyze_movType5
	JMP endAnalyze

analyzeThirdByteRcr:
	CALL add_to_offset_buffer

	CMP val_mod, 0
	JNE analyzeThirdByteRcr_continue
	CMP val_rm, 6
	JE endAnalyze

analyzeThirdByteRcr_continue:
	CMP val_mod, 1
	JNE endAnalyze	
	CALL analyze_rcr
	JMP endAnalyze

analyzeThirdByteNot:
	CALL add_to_offset_buffer

	CMP val_mod, 0
	JNE analyzeThirdByteNot_continue
	CMP val_rm, 6
	JNE endAnalyze

analyzeThirdByteNot_continue:
	CMP val_mod, 1
	JNE endAnalyze	
	CALL analyze_not
	JMP endAnalyze

;;;******************Analyzing fourth byte******************;;;

analyzeFourthByte:
	CMP movType5Index, 1
	JE analyzeFourthByteMovType5
	CMP movType2Index, 1
	JE analyzeFourthByteMovType2
	CMP movType1Index, 1
	JE analyzeFourthByteMovType1
	CMP notIndex, 1
	JE analyzeFourthByteNot
	CMP rcrIndex, 1
	JE analyzeFourthByteRcr

	JMP unidentified

analyzeFourthByteMovType1:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_movType1
	JMP endAnalyze

analyzeFourthByteMovType2:
	CMP val_mod, 3				;no offset
	JNE is_movType2_mod_00
	CALL save_offset_first_byte	;it means reading the last byte and analyzing
	CALL add_to_offset_buffer
	CALL analyze_movType2
	JMP endAnalyze

is_movType2_mod_00:
	CMP val_mod, 0			;no offset
	JNE is_movType2_mod_0_fourth

	CMP val_rm, 6
	JE is_movType2_mod_0_fourth

	CALL save_offset_first_byte	;it means reading the last byte and analyzing
	CALL add_to_offset_buffer
	CALL analyze_movType2
	JMP endAnalyze

is_movType2_mod_0_fourth:		;offset was present
	CMP val_mod, 1			; if mod = 1, offset is 1 byte
	JNE is_movType2_mod_02

	CALL add_to_offset_buffer	;adding bojb

	CMP val_w, 1			; is bovb needed?
	JNE is_movType2_w0_fourth
	JMP endAnalyze

is_movType2_w0_fourth:
	CALL analyze_movType2	; if not - analyze
	JMP endAnalyze

is_movType2_mod_02:			; if mod = 2, offset is 2 bytes
	CALL save_additional_first_byte
	CALL add_to_additional_buffer
	JMP endAnalyze

analyzeFourthByteMovType5:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_movType5
	JMP endAnalyze

analyzeFourthByteNot:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_not
	JMP endAnalyze

analyzeFourthByteRcr:
	CALL save_offset_first_byte
	CALL add_to_offset_buffer
	CALL analyze_rcr
	JMP endAnalyze

;;;******************Analyzing fifth byte******************;;;

analyzeFifthByte:
	CMP movType2Index, 1
	JE analyzeFifthByteMovType2

analyzeFifthByteMovType2:
	CMP val_mod, 2			;if mod = 2, 
	JNE bojb_type2
	CALL add_to_offset_buffer	;adding bojb

	CMP val_w, 1			; is bovb needed?
	JNE is_movType2_w0_fifth
	JMP endAnalyze

is_movType2_w0_fifth:
	CALL analyze_movType2	; if not - analyze
	JMP endAnalyze

bojb_type2:
	CALL save_offset_first_byte		;adding bovb
	CALL add_to_offset_buffer
	CALL analyze_movType2
	JMP endAnalyze

;;;******************Analyzing sixth byte******************;;;

analyzeSixthByte:
	CMP movType2Index, 1
	JE analyzeSixthByteMovType2

analyzeSixthByteMovType2:
	CALL save_offset_first_byte		;adding bovb
	CALL add_to_offset_buffer
	CALL analyze_movType2
	JMP endAnalyze

unidentified:
	MOV unidentifiedIndex, 1
	JMP endAnalyze

endAnalyze:
	RET

analyze_byte ENDP

;******************** get from table procedure ********************

get_from_table PROC near
	PUSH cx
	MOV cx, 2
	MUL cx
	ADD bx, ax
	MOV si, [bx]
	POP cx
	RET
get_from_table ENDP

;******************** get rm_mod procedure ********************

get_rm_mod PROC near

	;Getting rm
	PUSH ax
	AND al, 00000111b
	XOR bh, bh
	MOV bl, al
	POP ax
	MOV val_rm, bx

	;Getting mod
	PUSH ax
	AND al, 11000000b
	XOR bh, bh
	MOV bl, al
	SHR bl, 6
	POP ax
	MOV val_mod, bx

	RET

get_rm_mod ENDP

;******************** get reg procedure ********************

get_reg PROC near
	PUSH ax
	AND al, 00111000b
	XOR bh, bh
	MOV bl, al
	SHR bl, 3
	POP ax
	MOV val_reg, bx

	RET

get_reg ENDP

;******************** get sr procedure ********************

get_sr PROC near
	PUSH ax
	AND al, 00011000b
	XOR bh, bh
	MOV bl, al
	SHR bl, 3
	POP ax
	MOV val_sr, bx

	RET

get_sr ENDP

;******************** write 1cl procedure ********************

write_1cl PROC near
	PUSH si
	MOV si, offset comma
	CALL write_to_buffer

	CMP val_v, 0
	JNE is_cl
	MOV si, offset one_symbol
	JMP end_write_1cl

is_cl:
	MOV si, offset reg_cl

end_write_1cl:
	CALL write_to_buffer
	POP si
	RET
write_1cl ENDP

;******************** write rm procedure ********************

write_rm PROC near
	PUSH bx

is_rm_mod_3:
	CMP val_mod, 3
	JNE is_rm_mod_012
	MOV bx, offset rm_mod11_w0

	CMP val_w, 1
	JE set_val_w_1

	JMP write_rm_to_buffer

is_rm_mod_012:
	MOV bx, offset rm_mod00
	JMP write_rm_to_buffer

set_val_w_1:
	MOV bx, offset rm_mod11_w1

write_rm_to_buffer:
	PUSH si ax
	MOV ax, val_rm
	CALL get_from_table
	POP ax

	CMP val_rm, 6
	JNE write_rm_to_buffer_continue
	CMP val_mod, 0
	JNE write_rm_to_buffer_continue

direct_address:
	PUSH di
	MOV si, offset h_letter
	MOV di, offsetIndex
	CALL write_to_buffer
	POP di

	MOV si, offset offsetBuffer

write_rm_to_buffer_continue:
	PUSH di
	MOV di, offset tempLineBuffer
	CALL write_to_buffer

	CMP val_mod, 1
	JE add_offset
	CMP val_mod, 2
	JE add_offset
	JMP write_command

add_offset:
	MOV si, offset plus_sign
	CALL write_to_buffer

	MOV si, offset additionalBuffer
	CALL write_to_buffer

	MOV si, offset h_letter
	CALL write_to_buffer

write_command:
	PUSH ax
	MOV al, dollar_sign
	STOSB
	POP ax di si

	PUSH si
	MOV si, offset tempLineBuffer

	CMP val_mod, 3
	JNE writeToMemory
	CALL write_to_buffer
	JMP end_set_rm

writeToMemory:
	CALL write_to_memory
	JMP end_set_rm

end_set_rm:
	POP si bx
	RET

write_rm ENDP

;******************** write reg procedure ********************

write_reg PROC near
	PUSH bx

	MOV bx, offset rm_mod11_w0
	CMP val_w, 1
	JE write_reg_val_w_1

	JMP write_reg_continue

write_reg_val_w_1:
	MOV bx, offset rm_mod11_w1

write_reg_continue:
	PUSH si ax
	MOV ax, val_reg
	CALL get_from_table
	POP ax

	PUSH di
	MOV di, offset tempLineBuffer
	CALL write_to_buffer

write_reg_command:
	PUSH ax
	MOV al, dollar_sign
	STOSB
	POP ax di si

	PUSH si
	MOV si, offset tempLineBuffer

	CALL write_to_buffer
	JMP end_write_reg

end_write_reg:
	POP si bx
	RET

write_reg ENDP

;******************** write sr procedure ********************

write_sr PROC near
	PUSH bx
	MOV bx, offset srs

write_sr_continue:
	PUSH si ax
	MOV ax, val_sr
	CALL get_from_table
	POP ax

	PUSH di
	MOV di, offset tempSrBuffer
	CALL write_to_buffer

write_sr_command:
	PUSH ax
	MOV al, dollar_sign
	STOSB
	POP ax di si

	PUSH si
	MOV si, offset tempSrBuffer

	CALL write_to_buffer
	JMP end_write_sr

end_write_sr:
	POP si bx
	RET

write_sr ENDP

;******************** set val_w first procedure ********************

set_val_w_first PROC near
	PUSH ax
	AND al, 00001000b
	SHR al, 3

	CMP al, 0
	JNE set_val_w1
	MOV val_w, 0
	JMP set_val_w_end

set_val_w1:
	MOV val_w, 1

set_val_w_end:
	POP ax 
	RET

set_val_w_first ENDP

;******************** set val_w last procedure ********************

set_val_w_last PROC near
	PUSH ax
	AND al, 00000001b

	CMP al, 0
	JNE set_val_w1_last
	MOV val_w, 0
	JMP set_val_w_last_end

set_val_w1_last:
	MOV val_w, 1

set_val_w_last_end:
	POP ax 
	RET

set_val_w_last ENDP

;******************** set val_v procedure ********************

set_val_v PROC near
	PUSH ax
	AND al, 00000010b
	SHR al, 1

	CMP al, 0
	JNE set_val_v1
	MOV val_v, 0
	JMP set_val_v_end

set_val_v1:
	MOV val_v, 1

set_val_v_end:
	POP ax 
	RET

set_val_v ENDP

;******************** set val_d procedure ********************

set_val_d PROC near
	PUSH ax
	AND al, 00000010b
	SHR al, 1

	CMP al, 0
	JNE set_val_d1
	MOV val_d, 0
	JMP set_val_d_end

set_val_d1:
	MOV val_d, 1

set_val_d_end:
	POP ax 
	RET

set_val_d ENDP

;******************** Get accumulator procedure ********************

get_accumulator PROC near
	CMP val_w, 0
	JNE accumulator_ax
	MOV si, offset reg_al
	JMP end_get_accumulator

accumulator_ax:
	MOV si, offset reg_ax

end_get_accumulator:
	RET

get_accumulator ENDP

;******************** Write 'byte ptr' or 'word ptr' procedure ********************

write_ptr PROC near
	PUSH si
	CMP val_w, 0
	JNE is_mem_val_w_1
	MOV si, offset val_byte_ptr
	CALL write_to_buffer
	JMP end_write_ptr

is_mem_val_w_1:
	MOV si, offset val_word_ptr
	CALL write_to_buffer

end_write_ptr:
	POP si
	RET

write_ptr ENDP

;******************** Analyze MOV type 5 procedure ********************

analyze_movType5 PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset movWord
	CALL write_to_buffer

	PUSH di
	MOV si, offset offsetBuffer
	MOV di, offset additionalBuffer
	CALL write_to_buffer
	POP di

	MOV val_w, 1	;always in word registers

	CMP val_d, 0
	JNE write_sr_first

	CALL write_rm

	MOV si, offset comma
	CALL write_to_buffer

	CALL write_sr
	POP si
	RET

write_sr_first:
	CALL write_sr

	MOV si, offset comma
	CALL write_to_buffer

	CALL write_rm

	POP si
	RET
analyze_movType5 ENDP

;******************** Analyze MOV type 4 procedure ********************

analyze_movType4 PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset movWord
	CALL write_to_buffer

	CMP val_v, 0
	JNE write_memory_first

	CALL get_accumulator
	CALL write_to_buffer

	MOV si, offset comma
	CALL write_to_buffer

	PUSH di
	MOV si, offset h_letter
	MOV di, offsetIndex
	CALL write_to_buffer
	POP di

	MOV si, offset offsetBuffer
	CALL write_to_memory

	POP si
	RET

write_memory_first:
	PUSH di
	MOV si, offset h_letter
	MOV di, offsetIndex
	CALL write_to_buffer
	POP di

	MOV si, offset offsetBuffer
	CALL write_to_memory

	MOV si, offset comma
	CALL write_to_buffer

	CALL get_accumulator
	CALL write_to_buffer
	POP si
	RET
analyze_movType4 ENDP

;******************** Analyze MOV type 3 procedure ********************

analyze_movType3 PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset movWord
	CALL write_to_buffer

	CALL write_reg

	MOV si, offset comma
	CALL write_to_buffer

	MOV si, offset offsetBuffer
	CALL write_to_buffer

	MOV si, offset h_letter
	CALL write_to_buffer

	POP si
	RET
analyze_movType3 ENDP

;******************** Analyze MOV type 2 procedure ********************

analyze_movType2 PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset movWord
	CALL write_to_buffer

	CALL write_rm

	MOV si, offset comma
	CALL write_to_buffer

	MOV si, offset offsetBuffer
	CALL write_to_buffer

	MOV si, offset h_letter
	CALL write_to_buffer

	POP si
	RET
analyze_movType2 ENDP

;******************** Analyze MOV type 1 procedure ********************

analyze_movType1 PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset movWord
	CALL write_to_buffer

	PUSH di
	MOV si, offset offsetBuffer
	MOV di, offset additionalBuffer
	CALL write_to_buffer
	POP di

	CMP val_d, 0
	JNE write_reg_first

	CALL write_rm

	MOV si, offset comma
	CALL write_to_buffer

	CALL write_reg
	POP si
	RET

write_reg_first:
	CALL write_reg

	MOV si, offset comma
	CALL write_to_buffer

	CALL write_rm

	POP si
	RET
analyze_movType1 ENDP

;******************** Analyze xlat procedure ********************

analyze_xlat PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset xlatWord
	CALL write_to_buffer
	POP si
	RET

analyze_xlat ENDP

;******************** Analyze out procedure ********************

analyze_out PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si

	MOV si, offset outWord
	CALL write_to_buffer

	MOV si, offset reg_dx
	CALL write_to_buffer

	MOV si, offset comma
	CALL write_to_buffer

	CMP val_w, 0
	JNE analyze_out_ax
	MOV si, offset reg_al
	JMP end_analyze_out

analyze_out_ax:
	MOV si, offset reg_ax

end_analyze_out:
	CALL write_to_buffer
	POP si
	RET

analyze_out ENDP

;******************** Analyze out port procedure ********************

analyze_out_port PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset outWord
	CALL write_to_buffer
	POP si
	
write_port:
	CALL write_command_code

	PUSH si
	MOV si, offset h_letter
	CALL write_to_buffer

	MOV si, offset comma
	CALL write_to_buffer
	POP si

analyze_out_port_write:
	PUSH si
	CMP val_w, 0
	JNE analyze_out_port_ax
	MOV si, offset reg_al
	JMP end_analyze_out_port

analyze_out_port_ax:
	MOV si, offset reg_ax

end_analyze_out_port:
	CALL write_to_buffer
	POP si
	RET

analyze_out_port ENDP

;******************** Analyze rcr procedure ********************

analyze_rcr PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset rcrWord
	CALL write_to_buffer

	PUSH di
	MOV si, offset offsetBuffer
	MOV di, offset additionalBuffer
	CALL write_to_buffer
	POP di si

	CALL write_rm
	CALL write_1cl

	RET

analyze_rcr ENDP

;******************** Analyze not procedure ********************

analyze_not PROC near
	MOV identifiedIndex, 1
	CALL write_delim

	PUSH si
	MOV si, offset notWord
	CALL write_to_buffer

	PUSH di
	MOV si, offset offsetBuffer
	MOV di, offset additionalBuffer
	CALL write_to_buffer
	POP di si

	CALL write_rm
	RET

analyze_not ENDP

;******************** Write command code procedure ********************

write_command_code PROC near
	PUSH si
	XOR ah, ah
	CALL hex_to_char
	MOV si, offset hexBuffer
	CALL write_to_buffer
	CALL clear_hex_buffer
	POP si
	RET

write_command_code ENDP

;******************** hex to char procedure ********************

hex_to_char PROC near
    PUSH ax bx di

	MOV bx, offset hexTable

	MOV ah, al
    SHR ah, 4
    AND al, 0Fh
    XLAT                  
    XCHG ah, al
    XLAT

	MOV di, offset hexBuffer
	STOSB
	MOV al, ah
	STOSB

    POP di bx ax
    ret

hex_to_char ENDP

;******************** Add to offset buffer procedure ********************

add_to_offset_buffer PROC near
	PUSH si di bx

	MOV di, offsetIndex
	SUB di, offset offsetBuffer
	MOV bx, di

	CMP bx, 2
	JAE needs_swapping
	JMP continue_add_to_offset_buffer

needs_swapping:
	MOV offsetIndex, offset offsetBuffer
	
continue_add_to_offset_buffer:
	XOR ah, ah
	CALL hex_to_char
	MOV si, offset hexBuffer
	MOV di, offsetIndex
	CALL write_to_buffer
	MOV offsetIndex, di
	CALL clear_hex_buffer

	CMP bx, 2
	JB end_add_to_offset_buffer

	MOV si, offset tempOffsetBuffer
	CALL write_to_buffer

	ADD offsetIndex, 2

end_add_to_offset_buffer:
	POP bx di si
	RET
add_to_offset_buffer ENDP

;******************** Add to additional buffer procedure ********************

add_to_additional_buffer PROC near
	PUSH si di bx

	MOV di, additionalIndex
	SUB di, offset additionalBuffer
	MOV bx, di

	CMP bx, 2
	JAE needs_additional_swapping
	JMP continue_add_to_additional_buffer

needs_additional_swapping:
	MOV additionalIndex, offset additionalBuffer
	
continue_add_to_additional_buffer:
	XOR ah, ah
	CALL hex_to_char
	MOV di, additionalIndex
	MOV si, offset hexBuffer
	MOV di, offset additionalBuffer
	CALL write_to_buffer
	MOV additionalIndex, di
	CALL clear_hex_buffer

	CMP bx, 2
	JB end_add_to_additional_buffer

	MOV si, offset tempOffsetBuffer
	CALL write_to_buffer

	ADD additionalIndex, 2

end_add_to_additional_buffer:
	POP bx di si
	RET
add_to_additional_buffer ENDP

;******************** Save offset first byte procedure ********************

save_offset_first_byte PROC near
	PUSH si di

	MOV si, offset offsetBuffer
	MOV di, offset tempOffsetBuffer
	CALL write_to_buffer

	POP di si
	RET
save_offset_first_byte ENDP

;******************** Save additional first byte procedure ********************

save_additional_first_byte PROC near
	PUSH si di

	MOV si, offset additionalBuffer
	MOV di, offset tempOffsetBuffer
	CALL write_to_buffer

	POP di si
	RET
save_additional_first_byte ENDP

;******************** Clear output buffer procedure ********************

clear_output_buffer PROC near
	PUSH cx ax di

	MOV cx, outputBufferLen + 1
	MOV di, offset outputBuffer

clear_line_loop:
	XOR ah, ah
	MOV al, ' '
	STOSB
	LOOP clear_line_loop

	POP di ax cx 
	RET

clear_output_buffer ENDP

;******************** Clear hex buffer procedure ********************

clear_hex_buffer PROC near
	PUSH cx ax di

	MOV cx, hexBufferLen + 1
	MOV di, offset hexBuffer

clear_line2_loop:
	XOR ah, ah
	MOV al, '$'
	STOSB
	LOOP clear_line2_loop

	POP di ax cx
	RET

clear_hex_buffer ENDP

;******************** Clear offset buffer procedure ********************

clear_offset_buffer PROC near
	PUSH cx ax di

	MOV cx, tempBufferLen + 1
	MOV di, offset offsetBuffer

clear_line3_loop:
	XOR ah, ah
	MOV al, '$'
	STOSB
	LOOP clear_line3_loop

	POP di ax cx
	RET

clear_offset_buffer ENDP

;******************** Clear additional buffer procedure ********************

clear_additional_buffer PROC near
	PUSH cx ax di

	MOV cx, tempBufferLen + 1
	MOV di, offset additionalBuffer

clear_line4_loop:
	XOR ah, ah
	MOV al, '$'
	STOSB
	LOOP clear_line4_loop

	POP di ax cx
	RET

clear_additional_buffer ENDP

;******************** Clear values procedure ********************

clear_val PROC near
	MOV unidentifiedIndex, 0
	MOV identifiedIndex, 0

	MOV byteIndex, 0

	MOV movType1Index, 0
	MOV movType2Index, 0
	MOV movType3Index, 0
	MOV movType4Index, 0
	MOV movType5Index, 0

	MOV rcrIndex, 0
	MOV notIndex, 0
	MOV outIndex, 0
	MOV outPortIndex, 0

	MOV port, 0

	MOV offsetIndex, offset offsetBuffer
	MOV additionalIndex, offset additionalBuffer

	MOV val_prefix, 5
	MOV val_d, 0
	MOV val_w, 0
	MOV val_v, 0
	MOV val_mod, 0
	MOV val_rm, 0
	MOV val_reg, 0
	MOV val_sr, 0

	RET

ENDP clear_val

end start