; Program: No. 2.16 
; Task: Parasykite programa, skaitancia pirmuoju parametru pateikiama faila ir sukeiciancia vietomis antruoju bei treciuoju parametrais nurodomas failo eilutes.
; Made by: Kostas Ragauskas

JUMPS

.model small
.stack 100h

bufferLen = 128
sourceNameBuf = 14
outputNameBuf = 15

;;;;;;swap last line with another - additional enter symbol in the end
;;;;;;what if all the lines in a file are empty?
	 
.data
	enterSymbol			db 0Dh, 0Ah

	introMSG			db 'The application swaps two strings in a file.', 0Dh, 0Ah, '/? - help', 0Dh, 0Ah, '$'
	helpMSG				db 'Help: first parameter - minus sign (optional, if you want to output results in the console), second - file name, third and fourth parameters - numbers of lines, which will be swapped in the file. (all parameters should be separated by a space)', '$'

	errorCreatingMSG	db 0Dh, 0Ah, 'Failed to create the file: ', '$'
	errorOpeningMSG		db 0Dh, 0Ah, 'Failed to open the file: ', '$'
	errorReadingMSG		db 0Dh, 0Ah, 'Failed to read the file: ', '$'
	errorWritingMSG		db 0Dh, 0Ah, 'Failed to write to the file: ', '$'

	errorNumberMSG		db 0Dh, 0Ah, 'Error the line numbers cannot be equal', '$'
	paramMSG			db 0Dh, 0Ah, 'Error reading the parameters.', '$'
	bufferMSG			db 0Dh, 0Ah, 'Error - the current buffer is too small (should be at least 1)', '$'
	lineNotFoundMSG		db 0Dh, 0Ah, 'Error - the given lines were not found.', '$'

	successMSG			db 0Dh, 0Ah, 'The program finished tasks successfully.', '$'

	sourceF				db sourceNameBuf dup ('$')
	outputF				db outputNameBuf dup ('$')

	sourceBufferFirst	db (bufferLen + 1) dup (?)
	sourceBufferSecond	db (bufferLen + 1) dup (?)
	tempLine			db (bufferLen + 1) dup (?)

	sourceFHandleFirst	dw 0
	sourceFHandleSecond	dw 0
	outputFHandle		dw 1					; placeholder

	lineErrorCounter	dw 0
	isWriting			dw 0
	areLinesCorrect		dw 0

	tempLineNum			dw 0					; the line numbers (temporary and inputed by user)
	firstLineNum		dw 0					
	secondLineNum		dw 0

	currentLineFirst	dw 0					; current line we are reading in the first or second file
	currentLineSecond	dw 0

	firstIndex			dw 0					; source indexes for the first and second files
	secondIndex			dw 0

	currentBufLenFirst	dw 0					; size of the current buffer (how much bytes did we read from the file)
	currentBufLenSecond	dw 0				

.code
 
start:
	MOV ax, @data                   ; standart procedure
	MOV es, ax						; es needed for stosb: Store AL at address ES:(E)DI
	MOV	si, 81h        				; program's parameters are written to es, starting with the 81h byte  

	CALL skip_spaces				; skip all spaces before the first parameter

	MOV	al, byte ptr ds:[si]		; read the first symbol of the first parameter
	CMP	al, 0Dh						; if no parameters found (carriage return), jump to help
	JE help

	MOV	ax, word ptr ds:[si]		; read the first word of the first parameter
	CMP ax, 3F2Fh        			; if "/?" was found (where 3F = '?'and 2F = '/') (switched places because of ah and al)
	JE help                 		; jump to help

	MOV	al, byte ptr ds:[si]		; read the first word of the first parameter
	CMP al, '-'       				; if minus sign is found - output results in the console
	JNE continue

	LEA di, outputF					; reading and writing the minus sign into our output file name
	CALL read_parameter	
	CMP	byte ptr es:[outputF], 0	; if the input is empty, jump to help
	JE help

	PUSH ds si						; pushing the data segment and source index to the stack (so than we can read more parameters from console if needed)
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	MOV outputFHandle, 0			; setting the handle to zero

	POP si ds

continue:
	LEA di, sourceF					; reading the source file name
	CALL read_parameter	
	CMP	byte ptr es:[sourceF], 0	; if the input is empty, jump to help
	JE help

	PUSH ds si						; pushing the data segment and source index to the stack (so than we can read more parameters from console if needed)
	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	CALL clear_screen				; clearing the console window

	MOV ah, 09h						; print the intro message
	LEA dx, introMSG
	INT 21h

	MOV cx, bufferLen				; restrict user from using buffer, which is zero
	CMP cx, 0
	JE bufferError

readParams:
	POP	si ds						; gaining back the source index and data segment (to read more parameters)

	CALL read_number				; reading the first number into bx
	MOV ax, bx						; putting that into ax

	CALL read_number				; reading second number into bx
	PUSH ax bx

	MOV	ax, @data					; standart procedure, again (since ax was in es)
	MOV	ds, ax

	POP bx ax						; gaining back the numbers we just read

	CMP	ax, 0						; if ax is empty, jump to param error
	JE paramError

	CMP	bx, 0						; if bx is empty, jump to param error
	JE paramError

	CMP ax, bx						; if both are equal - jump to number error
	JE numberError					
	JL setNumbers					; if ax is bigger than bx, exchange register values

	xchg ax, bx						

setNumbers:
	MOV firstLineNum, ax			; setting the line numbers
	MOV secondLineNum, bx

setOutputFileName:
	CMP outputFHandle, 0			; if handle is zero - do not set the output file's name
	JE openSourceFileFirst

	MOV si, offset sourceF			; setting the output file name, based on the source file.
	MOV di, offset outputF			
	CALL set_output_name

openSourceFileFirst:
	MOV	dx, offset sourceF			; moving file name to dx
	MOV	ah, 3dh					 	; 3dh - open file command
	MOV	al, 0						; 0 - reading, 1 - writing, 2 - both
	INT	21h	
	JC sourceErrorFirst				; carry flag is set on error (AX = error code). If so, jump to sourceError

	MOV sourceFHandleFirst, ax		; saving the source file handle

openSourceFileSecond:
	MOV	dx, offset sourceF			; moving file name to dx
	MOV	ah, 3dh					 	; 3dh - open file command
	MOV	al, 0						; 0 - reading, 1 - writing, 2 - both
	INT	21h	
	JC sourceErrorSecond			; carry flag is set on error (AX = error code). If so, jump to sourceError

	MOV sourceFHandleSecond, ax		; saving the source file handle

openOutputFile:
	CMP outputFHandle, 0
	JE setReadingValues

	MOV	dx, offset outputF			; creating or clearing the output file
	MOV	ah, 3ch						; 3ch - create/clear file command				
	MOV	cx, 0						; no attributes
	INT	21h					
	JC outputCreateError			; carry flag is set on error (AX = error code). If so, jump to outputError
		
	MOV	ah, 3dh					 	; 3dh - open file command
	MOV	al, 1						; 0 - reading, 1 - writing, 2 - both
	INT	21h	
	JC outputOpenError				; carry flag is set on error (AX = error code). If so, jump to outputError

	MOV outputFHandle, ax			; saving the output file handle

setReadingValues:
	MOV currentLineFirst, 1				; the line we will be reading from is 1 (not zero)
	MOV currentLineSecond, 1			; the line we will be reading from is 1 (not zero)

readFirstSourceFile:
	MOV	bx, sourceFHandleFirst		; move file handle to bx
	MOV	dx, offset sourceBufferFirst		; move file buffer to dx
	MOV	cx, bufferLen				; bytes to read (the length of our buffer)
	MOV	ah, 3fh         			; function 3fh - read from file
	INT	21h
	JC readError					; if carry flag is on - jump to readError

	MOV cx, ax
	CMP ax, 0						; bytes are placed inside ax, so if that is equal to 0 - end program
	JE endProgram

	MOV si, offset sourceBufferFirst	; move zero to the end of the buffer
	ADD si, cx
	MOV byte ptr ds:[si], 0
	SUB si, cx

	MOV currentBufLenFirst, cx		; move how many bytes we read to 'currentBufLen'
	MOV firstIndex, si

	JMP iterateLines

readSecondSourceFile:
	MOV	bx, sourceFHandleSecond		; move file handle to bx
	MOV	dx, offset sourceBufferSecond		; move file buffer to dx
	MOV	cx, bufferLen				; bytes to read (the length of our buffer)
	MOV	ah, 3fh         			; function 3fh - read from file
	INT	21h
	JC readError					; if carry flag in on - jump to readError

	MOV cx, ax
	CMP ax, 0						; bytes are placed inside ax, so if that is equal to 0 - jump to finalize
	JE isLineError

	MOV si, offset sourceBufferSecond	; move zero to the end of the buffer
	ADD si, cx
	MOV byte ptr ds:[si], 0
	SUB si, cx

	MOV currentBufLenSecond, cx		; move how many bytes we read to 'currentBufLen'
	MOV secondIndex, si

	JMP iterateLines

isLineError:						; goes here if the last line does not have an enter symbol
	CMP lineErrorCounter, 1				
	JE lineNotFoundError

	CMP isWriting, 1				; if we are not writing - error
	JNE lineNotFoundError

	MOV dx, offset enterSymbol
	MOV cx, 2
	MOV bx, outputFHandle
	MOV ah, 40h						; INT 21h / AH= 40h - write to file
	INT 21h
	JC writeError					; CF set on error; AX = error code.

	ADD lineErrorCounter, 1
	ADD currentLineSecond, 1

;;;;;;;;;;;;;;;;;;;;;Reading and swapping the lines;;;;;;;;;;;;;;;;;;;;;

iterateLines:
	MOV cx, [currentLineFirst]		; move currently reading line number to cx

	CMP cx, [firstLineNum]			; compare it with the first and the second line numbers (and jump accordingly)
	JE readSecond

	CMP cx, [secondLineNum]
	JE readFirst

readWriteLine:
	MOV si, [firstIndex]

	MOV di, offset tempLine			; reading the line
	MOV cx, [currentLineFirst]
	MOV bx, 0
	CALL read_line

	MOV firstIndex, si

	PUSH cx

	MOV dx, offset tempLine
	MOV cx, bx
	MOV bx, outputFHandle
	MOV ah, 40h						; INT 21h / AH= 40h - write to file
	INT	21h
	JC writeError					; CF set on error; AX = error code.

	POP cx

	CMP cx, [currentLineFirst]		; did the line count change?
	JE readFirstSourceFile			; if not, continue reading (it means the buffer ended)
	
	MOV currentLineFirst, cx		; if line count changed - update the count and iterate through lines
	JMP iterateLines

readFirst:
	MOV cx, [firstLineNum]			; setting the temp line and first or second (for the readLines label)
	MOV tempLineNum, cx
	JMP readLines

readSecond:
	MOV cx, [secondLineNum]
	MOV tempLineNum, cx

readLines:
	MOV areLinesCorrect, 1			; found at least one line

	CMP secondIndex, 0				; if nothing read yet - go and read from the second file
	JE readSecondSourceFile
	
	MOV si, [secondIndex]

	MOV cx, [currentLineSecond]
	CMP cx, [tempLineNum]			; did we reach the line we are looking for?
	JE write						; if yes - write the line
	JA skipLine						; if we have already written the line, skip a line in the first file

	MOV	di, offset tempLine			; reading the line
	MOV cx, [currentLineSecond]
	MOV bx, 0
	CALL read_line

	MOV isWriting, 0
	MOV secondIndex, si

	CMP cx, [currentLineSecond]		; did the line count change?
	JE readSecondSourceFile			; if not, read again

	MOV currentLineSecond, cx		; if it did, update the count and repeat

	JMP readLines

write:
	MOV si, [secondIndex]

	MOV	di, offset tempLine			; reading the line
	MOV cx, [currentLineSecond]
	MOV bx, 0
	CALL read_line

	;CMP bx, 0							;*******Not necessary********
	;JE readSecondSourceFile			; if the line was empty, read again

	MOV secondIndex, si

	PUSH cx

	MOV dx, offset tempLine
	MOV cx, bx
	MOV bx, outputFHandle
	MOV ah, 40h						; INT 21h / AH= 40h - write to file
	INT	21h
	JC writeError					; CF set on error; AX = error code.

	POP cx

	MOV isWriting, 1

	CMP cx, [currentLineSecond]		; did the line count change?
	JE readSecondSourceFile			; if not - read again
				
	MOV currentLineSecond, cx

skipLine:
	MOV ah, 42h						; command lseek (Mandatory for it to be in the skipLine label)
	MOV al, 0						; pointer in the beginning
	MOV cx, 0						
	MOV dx, 0
	MOV bx, sourceFHandleSecond
	INT 21h 
	JC readError

	MOV si, [firstIndex]

	MOV	di, offset tempLine			; reading the line
	MOV cx, [currentLineFirst]
	MOV bx, 0
	CALL read_line

	MOV firstIndex, si

	CMP cx, [currentLineFirst]		; did the line count change?
	JE readFirstSourceFile			; if not, read again	
	
	MOV currentLineFirst, cx		; if it did, update current line number (first)
	MOV currentLineSecond, 1
	MOV secondIndex, 0

	JMP iterateLines
	
endProgram:
	CMP areLinesCorrect, 0
	JE lineNotFoundError

	LEA	dx, successMSG
	MOV	ah, 09h
	INT	21h

	MOV	bx, sourceFHandleFirst
	CALL close_file

	MOV	bx, sourceFHandleSecond
	CALL close_file

	MOV	bx, outputFHandle
	CALL close_file

	JMP ending						; jump to the end of the program

;#################### Error messages ####################
	
sourceErrorFirst:
	MOV	bx, sourceFHandleFirst
	JMP sourceError

sourceErrorSecond:
	MOV	bx, sourceFHandleSecond

sourceError:
	CALL close_file
	CALL clear_screen

	LEA	dx, errorOpeningMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	MOV	dx, offset sourceF
	INT	21h

	JMP errorEnding

outputOpenError:
	CALL clear_screen

	LEA	dx, errorOpeningMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	LEA	dx, outputF
	INT	21h

	JMP standartError

outputCreateError:
	CALL clear_screen
	
	MOV	bx, sourceFHandleFirst
	CALL close_file

	MOV	bx, sourceFHandleSecond
	CALL close_file

	LEA	dx, errorCreatingMSG			; printing the message and the file name
	MOV	ah, 09h
	INT	21h

	LEA	dx, outputF
	INT	21h

	JMP errorEnding

readError:
	CALL clear_screen

	LEA	dx, errorReadingMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	LEA	dx, sourceF
	INT	21h

	JMP standartError

paramError:
	CALL clear_screen

	MOV ah, 09h						; printing the message
	LEA dx, paramMSG
	INT 21h

	JMP errorEnding

bufferError:
	CALL clear_screen

	MOV ah, 09h						; printing the message
	LEA dx, bufferMSG
	INT 21h

	JMP errorEnding

writeError:
	CALL clear_screen

	LEA	dx, errorWritingMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	LEA	dx, outputF
	INT	21h

	JMP standartError

lineNotFoundError:
	CALL clear_screen

	MOV ah, 09h						; printing the message
	LEA dx, lineNotFoundMSG
	INT 21h

	JMP standartError

numberError:
	CALL clear_screen
	
	LEA	dx, errorNumberMSG			; printing the message
	MOV	ah, 09h
	INT	21h

	JMP errorEnding

standartError:
	MOV	bx, sourceFHandleFirst
	CALL close_file

	MOV	bx, sourceFHandleSecond
	CALL close_file

	MOV	bx, outputFHandle

	CMP bx, 0
	JE errorEnding

	CALL close_file

	MOV	dx, offset outputF		; clearing the output file
	MOV	ah, 3ch				; 3ch - create/clear file command				
	MOV	cx, 0				; no attributes
	INT	21h	
	
	MOV	bx, outputFHandle
	CALL close_file

errorEnding:
	MOV	ax, 4c01h					; (error code 1)
	INT	21h 

help:
	MOV	ax, @data					; standart procedure (in case ax is still inside es)
	MOV	ds, ax

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

skip_spaces_loop:
	CMP byte ptr ds:[si], ' '		; comparing the current byte with an empty char
	JNE skip_spaces_end				; if it is not equal to the empty byte - jump to skip_spaces_end
	INC si
	JMP skip_spaces_loop

skip_spaces_end:
	RET
	
skip_spaces ENDP

;******************** Reading parameter procedure ********************

read_parameter PROC near
	PUSH ax bx
	CALL skip_spaces				; skip spaces to the parameter
	MOV bx, 1

read_parameter_start:
	INC bx
	CMP bx, sourceNameBuf
	JE read_parameter_end

	CMP	byte ptr ds:[si], 0Dh		; comparing if the symbol is carriage return
	JE read_parameter_end			; if so, end the input
	CMP	byte ptr ds:[si], ' '		; if space is not detected
	JNE	read_parameter_next			; then move forward to the next character

read_parameter_end:
	MOV	al, 0						; write 0 to the end of al
	STOSB                           ; store al at address ES:DI, di = di + 1 (incremented)
	POP	bx ax
	RET

read_parameter_next:
	LODSB							; load and store the symbol
	STOSB
	JMP read_parameter_start

read_parameter ENDP

;******************** Reading number procedure ********************

read_number PROC near
	PUSH ax
	MOV bx, 0						; bx - the result. bp - the base, by which we will multiply each digit.
	MOV bp, 10
	CALL skip_spaces

read_number_start:
	CMP	byte ptr ds:[si], 0Dh		; comparing if the symbol is carriage return
	JE read_number_end				; if so, end the input
	CMP	byte ptr ds:[si], ' '		; if space is not detected
	JNE	read_number_next			; then move forward to the next character

read_number_end:
	POP	ax
	RET

read_number_next:
	LODSB							; load the next symbol to al (si = si + 1)

	CMP bx, 0						; if bx 0 (nothing yet) - then just add the read digit
	JNE read_number_multiply

read_number_add:
	XOR ah, ah						; clearing ah and converting al to a digit. Then adding whole ax to bx
	SUB al, 48
	ADD bx, ax

	JMP read_number_start

read_number_multiply:
	MOV cl, al						; saving the symbol in al to cl
	MOV ax, bx						; saving the current digit to ax
	MUL bp							; multiplying ax by bp (by 10).
	MOV bx, ax						; moving the ax (result) back to bx
	MOV al, cl						; moving cl back to al

	JMP read_number_add

read_number ENDP

;******************** Setting the output file procedure ********************

set_output_name PROC near
	PUSH ax

	MOV al, '_'
	STOSB

loopSetOutputFile:
	LODSB						; rewrite the other symbols as they were
	STOSB

	CMP al, 0				; comparing if the symbol is zero
	JE endSettingFile

	JMP loopSetOutputFile

endSettingFile:
	POP ax
	RET

set_output_name ENDP

;******************** Reading selected line procedure ********************

read_line PROC near
	PUSH ax

;;;;;bx - bytes read, cx - line count

getLines:	
	CMP byte ptr ds:[si], 0
	JE endBuffer
			
	LODSB
	STOSB

	INC bx						; increase bx by one	

	CMP al, 0Ah
	JNE getLines	
										
endLine:
	INC cx	

endBuffer:
	POP ax
	RET
	
read_line ENDP

end start