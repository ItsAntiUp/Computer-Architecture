; Program: No. 1.19 
; Task: Parasykite programa, kuri perkoduoja ivesta ASCII simboliu eilute Cezario kodu (kiekvieno simbolis keiciamas abeceleje dviem paskesniu). Pvz.: jei eilute yra abc, turi atspausdinti cde.
; Made by: Kostas Ragauskas

.model small

bufferLen EQU 250
	 
Bseg SEGMENT

ORG 100h
ASSUME ds:Bseg, cs:Bseg, ss:Bseg
 
start:
	;MOV ax, @data                   ; standart procedure
	;MOV ds, ax        

	MOV ah, 09h						; intro message
	MOV dx, offset introMSG
	INT 21h

main:
	MOV ah, 09h						; input message
	MOV dx, offset inputMSG
	INT 21h

	MOV ah, 0Ah   					; line reading
	MOV dx, offset buffer                             
	INT 21h  

	XOR ch, ch						; clear ch, to avoid errors

	MOV cl, buffer[1]				; move buffer contents to cl     
	CMP cl, 0						; check if the whole buffer content is empty, if yes, jump to 'emptyError'  
	JE emptyError

	MOV ah, 09h						; result message
	MOV dx, offset resultMSG
	INT 21h   

	LEA si, buffer + 2				; assign buffer coordinates to si
	MOV ah, 02h						; preparing to print symbols one by one (just so we don't have to do this in the loop)

cypher:
	LODSB                        	; move part of the string (from si) and put to al             

	ADD al, 02h						; change every character's position by 2
	MOV dl, al						; print the character
	INT 21h  

	LOOP cypher						; return to 'cypher' loop
	JMP ending                      ; if ch = 0 , jump to 'ending'

emptyError:
	MOV ah, 09h						; empty error message
	MOV dx, offset emptyErrorMSG
	INT 21h

ending:
	MOV ax, 4c00h 					; ending program (error code 0)
	INT 21h                    

	introMSG		db 'Programa perkoduoja ivesta ASCII eilute Cezario kodu (per 2 pozicijas i prieki)', 0Dh, 0Ah, '$'
	inputMSG		db 'Iveskite simboliu eilute:', 0Dh, 0Ah,  "-> ", '$'
	emptyErrorMSG	db 'Turite ivesti bent viena simboli', 0Dh, 0Ah, '$'
	resultMSG    	db 0Dh, 0Ah,'Rezultatas:', 0Dh, 0Ah, '$'
	buffer			db bufferLen, ?, bufferLen dup (?)

Bseg ends
	 
end start