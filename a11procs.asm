; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

section	.data

; -----
;  Define standard constants.

LF		equ	10			; line feed
NULL		equ	0			; end of string
SPACE		equ	0x20			; space

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	0			; Successful operation
NOSUCCESS	equ	1			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; system call code for read
SYS_write	equ	1			; system call code for write
SYS_open	equ	2			; system call code for file open
SYS_close	equ	3			; system call code for file close
SYS_fork	equ	57			; system call code for fork
SYS_exit	equ	60			; system call code for terminate
SYS_creat	equ	85			; system call code for file open/create
SYS_time	equ	201			; system call code for get time

O_CREAT		equ	0x40
O_TRUNC		equ	0x200
O_APPEND	equ	0x400

O_RDONLY	equ	000000q			; file permission - read only
O_WRONLY	equ	000001q			; file permission - write only
O_RDWR		equ	000002q			; file permission - read and write

S_IRUSR		equ	00400q
S_IWUSR		equ	00200q
S_IXUSR		equ	00100q

; -----
;  Define program specific constants.

GRAYSCALE	equ	0
BRIGHTEN	equ	1
DARKEN		equ	2

MIN_FILE_LEN	equ	5
BUFF_SIZE	equ	1000000			; buffer size

; -----
;  Local variables for getArguments() function.

eof		db	FALSE

usageMsg	db	"Usage: ./imageCvt <-gr|-br|-dk> <inputFile.bmp> "
		db	"<outputFile.bmp>", LF, NULL
errIncomplete	db	"Error, incomplete command line arguments.", LF, NULL
errExtra	db	"Error, too many command line arguments.", LF, NULL
errOption	db	"Error, invalid image processing option.", LF, NULL
errReadName	db	"Error, invalid source file name.  Must be '.bmp' file.", LF, NULL
errWriteName	db	"Error, invalid output file name.  Must be '.bmp' file.", LF, NULL
errReadFile	db	"Error, unable to open input file.", LF, NULL
errWriteFile	db	"Error, unable to open output file.", LF, NULL

; -----
;  Local variables for processHeaders() function.

HEADER_SIZE	equ	54

errReadHdr	db	"Error, unable to read header from source image file."
		db	LF, NULL
errFileType	db	"Error, invalid file signature.", LF, NULL
errDepth	db	"Error, unsupported color depth.  Must be 24-bit color."
		db	LF, NULL
errCompType	db	"Error, only non-compressed images are supported."
		db	LF, NULL
errSize		db	"Error, bitmap block size inconsistent.", LF, NULL
errWriteHdr	db	"Error, unable to write header to output image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for getRow() function.

buffMax		dq	BUFF_SIZE
curr		dq	BUFF_SIZE
wasEOF		db	FALSE
pixelCount	dq	0

errRead		db	"Error, reading from source image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for writeRow() function.

errWrite	db	"Error, writting to output image file.", LF,
		db	"Program terminated.", LF, NULL


; ------------------------------------------------------------------------
;  Unitialized data

section	.bss

localBuffer	resb	BUFF_SIZE
header		resb	HEADER_SIZE


; ############################################################################

section	.text

; ***************************************************************
;  Routine to get arguments.
;	Check image conversion options
;	Verify files by atemptting to open the files (to make
;	sure they are valid and available).

;  NOTE:
;	ENUM vaiables are 32-bits.

;  Command Line format:
;	./imageCvt <-gr|-br|-dk> <inputFileName> <outputFileName>

; -----
;  Arguments:
;	argc (value) - rdi
;	argv table (address) - rsi
;	image option variable, ENUM type, (address) - rdx
;	read file descriptor (address) - rcx
;	write file descriptor (address) - r8
;  Returns:
;	TRUE or FALSE


;	YOUR CODE GOES HERE
global getArguments
getArguments:

	push rbp
	mov rbp, rsp
	push rbx
	push r11
	push r12
	push r13
	push r14
	push r15

	mov rax, 0
	mov rbx, 0	;counter for args
	mov r12, 0	;holds arguments
	mov r13, 0	
	mov r14, 0
	mov r15, 0

	;check if proper arg count
	cmp rdi, 1
	je improperArgCountNoInput

	cmp rdi, 4
	jg improperArgCountGreater
	jl improperArgCountLess

	;goes to 2nd argument
	inc rbx
	mov r12, qword[rsi + rbx * 8]	;move 2nd argument into a register

	;check 1st char, should be a '-'
	mov r14, 0
	mov al, byte[r12 + r14]
	mov r13b, '-'
	inc r14
	cmp al, r13b
	jne arg1CharError

	;check 2nd char, can be a 'g', 'b', or 'd'
	;check g
	mov al, byte[r12 + r14]	;2nd char
	mov r13b, 'g'
	inc r14
	cmp al, r13b
	je imageOptionCode1

	;check b
	mov r13b, 'b'
	cmp al, r13b
	je imageOptionCode1

	;check d
	mov r13b, 'd'
	cmp al, r13b
	je imageOptionCode2

	;if it wasnt any of these characters, its wrong.
	jmp arg1CharError

	;check 3rd char, can be 'r' or 'k'
	;check r
	imageOptionCode1:
	mov al, byte[r12 + r14]	;3rd char
	mov r13b, 'r'
	inc r14
	cmp al, r13b
	jne arg1CharError
	jmp checkTooManyChars

	;check k
	imageOptionCode2:
	mov al, byte[r12 + r14]	;3rd char
	mov r13b, 'k'
	inc r14
	cmp al, r13b
	jne arg1CharError
	jmp checkTooManyChars

	checkTooManyChars:
	;check for too many chars
	mov al, byte[r12 + r14] 
	cmp al, NULL
	jne arg1CharError
	;if all chars match, continue

	;go back to 2nd char
	dec r14
	dec r14
	mov al, byte[r12 + r14]	;get the 2nd char
	mov r13b, 'g'
	cmp al, r13b
	je setImageOptionCodeGR

	mov r13b, 'b'
	cmp al, r13b
	je setImageOptionCodeBR

	mov dword[rdx], DARKEN
	jmp imageCodeComplete

	setImageOptionCodeGR:
	mov dword[rdx], GRAYSCALE
	jmp imageCodeComplete

	setImageOptionCodeBR:
	mov dword[rdx], BRIGHTEN
	jmp imageCodeComplete

	imageCodeComplete:	;error checking is done and code is set, continue

	;goes to 3rd argument
	inc rbx
	mov r12, qword[rsi + rbx * 8]	;move 3rd argument into a register

	mov r13, 0	;gonna hold rdi for now
	mov r14, 0	;rsi for now

	push rsi
	push rcx

	mov rax, SYS_open
	mov rdi, r12
	mov rsi, O_RDONLY
	syscall

	;check if file 1 opened
	cmp rax, 0
	jge fileOneOpenSuccess

	;file 1 error, handle error
	
	push r13
	push r14

	mov r14, 0

	checkFileOneName:
	mov r13, 0
	mov r13b, byte[r12 + r14]
	inc r14
	cmp r13b, NULL
	jne checkFileOneName

	sub r14, 5
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, '.'
	jne fileOneImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'b'
	jne fileOneImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'm'
	jne fileOneImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'p'
	jne fileOneImproperName

	;if the file type is acceptable, then the file doesnt exist
	jmp fileOneNoSuchFile

	fileOneOpenSuccess:
	;file 1 successful, return file descriptor and check file 2
	pop rcx
	mov qword[rcx], rax

	;check output file
	;goes to 4th argument
	pop rsi
	inc rbx
	mov r12, qword[rsi + rbx * 8]	;move 4th argument into a register

	;file 2 check name
	push r13
	push r14

	mov r14, 0

	checkFileTwoName:
	mov r13, 0
	mov r13b, byte[r12 + r14]
	inc r14
	cmp r13b, NULL
	jne checkFileTwoName

	sub r14, 5
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, '.'
	jne fileTwoImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'b'
	jne fileTwoImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'm'
	jne fileTwoImproperName

	inc r14
	mov r13, 0
	mov r13b, byte[r12 + r14]
	cmp r13b, 'p'
	jne fileTwoImproperName

	pop r14
	pop r13

	mov rax, SYS_creat
	mov rdi, r12
	mov rsi, S_IRUSR | S_IWUSR
	syscall

	cmp rax, 0
	jb outputFileFail
	;if output file success 
	mov qword[r8], rax
	jmp endFunction

	;error outputting starts here
	improperArgCountNoInput:
	mov rdi, usageMsg
	call printString
	mov rax, FALSE
	jmp endFunction

	improperArgCountGreater:
	mov rdi, errExtra
	call printString
	mov rax, FALSE
	jmp endFunction

	improperArgCountLess:
	mov rdi, errIncomplete
	call printString
	mov rax, FALSE
	jmp endFunction

	arg1CharError:
	mov rdi, errOption
	call printString
	mov rax, FALSE
	jmp endFunction

	fileOneImproperName:
	pop r14
	pop r13
	mov rdi, errReadName
	call printString
	mov rax, FALSE
	jmp endFunction

	fileOneNoSuchFile:
	pop r14
	pop r13
	mov rdi, errReadFile
	call printString
	mov rax, FALSE
	jmp endFunction

	fileOneFileTypeError:
	mov rdi, errReadName
	call printString
	mov rax, FALSE
	jmp endFunction

	fileOneNoSuchProcess:
	mov rdi, errReadName
	call printString
	mov rax, FALSE
	jmp endFunction

	fileTwoImproperName:
	pop r14
	pop r13
	mov rdi, errWriteName
	call printString
	mov rax, FALSE
	jmp endFunction

	outputFileFail:
	mov rdi, errWriteFile
	call printString
	mov rax, FALSE
	jmp endFunction

	endFunction:

	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	mov rsp, rbp
	pop rbp	

	ret

; ***************************************************************
;  Read and verify header information
;	status = processHeaders(readFileDesc, writeFileDesc,
;				fileSize, picWidth, picHeight)

; -----
;  2 -> BM				(+0)
;  4 file size				(+2)
;  4 skip				(+6)
;  4 header size			(+10)
;  4 skip				(+14)
;  4 width				(+18)
;  4 height				(+22)
;  2 skip				(+26)
;  2 depth (16/24/32)			(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data		(+34)
;  skip remaing header entries

; -----
;   Arguments:
;	read file descriptor (value)	- rdi
;	write file descriptor (value)	- rsi
;	file size (address)				- rdx
;	image width (address)			- rcx
;	image height (address)			- r8

;  Returns:
;	file size (via reference)
;	image width (via reference)
;	image height (via reference)
;	TRUE or FALSE


;	YOUR CODE GOES HERE
global processHeaders 
processHeaders:

	push rbx
	push r12
	push r13
	push r14
	push r15
	push rsi
	push r8
	push rcx
	push rdx

	mov rbx, 0
	mov r12, 0
	mov r13, 0
	mov r14, 0
	mov r15, 0

	mov rax, SYS_read
	mov rsi, header
	mov rdx, HEADER_SIZE
	syscall

	cmp rax, 0
	jl headerReadFail

	;check to make sure the first two bytes are B and M
	mov r12b, byte[header]
	cmp r12b, 'B'
	jne fileSignatureInvalid
	mov r12b, byte[header + 1]
	cmp r12b, 'M'
	jne fileSignatureInvalid

	;if first 2 bytes are BM, then store file size
	pop rdx
	mov r12d, dword[header + 2]
	mov dword[rdx], r12d	;stores file size here

	;store width
	mov r12, 0
	pop rcx
	mov r12d, dword[header + 18]
	mov dword[rcx], r12d

	;store height
	mov r12, 0
	pop r8
	mov r12d, dword[header + 22]
	mov dword[r8], r12d 

	;check depth
	mov r12, 0
	mov r12w, word[header + 28]
	cmp r12, 24
	jne colorDepthInvalid
	
	;check compression code
	mov r12, 0
	mov r12d, dword[header + 30]
	cmp r12, 0
	jne compressionCodeInvalid

	;check for bitmap block size consistency
	;file size = size of image in bytes + header size
	mov r12, 0
	mov r12d, dword[header + 2]	;file size
	mov r13, 0
	mov r13d, dword[header + 34] ;size of image in bytes
	add r13d, HEADER_SIZE
	cmp r12d, r13d
	jne bitmapSizeInvalid

	;if all pass for input file, write header to output file
	mov rax, SYS_write
	pop rsi
	mov rdi, rsi
	mov rsi, header
	mov rdx, HEADER_SIZE
	syscall

	cmp rax, 0
	jl headerWriteFail
	mov rax, TRUE
	jmp endProcessHeaders

	;error outputting
	headerReadFail:
	mov rdi, errReadHdr
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	fileSignatureInvalid:
	pop rdx
	pop rcx 
	pop r8
	pop rsi
	mov rdi, errFileType
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	colorDepthInvalid:
	pop rsi
	mov rdi, errDepth
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	compressionCodeInvalid:
	pop rsi
	mov rdi, errCompType
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	bitmapSizeInvalid:
	pop rsi
	mov rdi, errSize
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	headerWriteFail:
	mov rdi, errWriteFile
	call printString
	mov rax, FALSE
	jmp endProcessHeaders

	endProcessHeaders:

	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx

	ret

; ***************************************************************
;  Return a row from read buffer
;	This routine performs all buffer management

; ----
;  HLL Call:
;	status = getRow(readFileDesc, picWidth, rowBuffer);

;   Arguments:
;	read file descriptor (value)	- rdi
;	image width (value)				- rsi
;	row buffer (address)			- rdx
;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been returned
;	and returns FALSE only if there is an
;	error on read (which would not normally occur)
;	or the end of file.

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.


;	YOUR CODE GOES HERE
global getRow
getRow:

	;  Local variables for getRow() function.
	;
	;buffMax	dq	BUFF_SIZE
	;curr		dq	BUFF_SIZE
	;wasEOF		db	FALSE
	;pixelCount	dq	0
	;
	;errRead		db	"Error, reading from source image file.", LF,
	;		db	"Program terminated.", LF, NULL
	
	push rbp 
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15 ; curr

mov r12, rdi ; read file
mov r13, rsi ; image width
mov r14, rdx ; row buffer address


mov rax, rsi ; set rax to width
mov r10, 3
mul r10
mov qword[pixelCount], rax ; picwidth * 3

mov r8, 0 ; index

getNextByte:

	mov r15, qword[curr]
	cmp r15, BUFF_SIZE
	jb skipRead
	
	cmp byte[wasEOF], TRUE
	je doneRow
	
	jmp fileRead
	

; ---- syscall to grab a buffer of input file and read into provided localBuffer array

fileRead:

	mov rdi, r12
	mov rsi, localBuffer
	mov rdx, BUFF_SIZE
	mov rax, SYS_read
	syscall
	
	cmp byte[wasEOF], TRUE
	je skipRead
	
	cmp rax, 0 
	je setFalse
	
	cmp rax, 0
	jl errorOnRead
	
	cmp rax, BUFF_SIZE
	jl finalRead
	
	mov qword[curr], 0
	
	
skipRead:	
	
	mov r15, qword[curr]
	mov al, byte[localBuffer + r15] ; chr =   buffer[currIdx]
	inc qword[curr] ; currIdx++
	
	mov byte[r14 + r8], al ; rowBuffer[i] = chr
	inc r8 ; i++
	
	cmp r8, qword[pixelCount]
	jb getNextByte
	
	cmp byte[wasEOF], TRUE
	je setFalse
	jmp doneRow


; ---- copy a line from the buffer, known from image width into row buffer byte by byte


; From that large buffer, the getRow() function would return one row (width *3 bytes). The next call the
; getRow() function would return the next row. As such, the getRow() function must keep track of where
; it is in the buffer. When the buffer is depleted, the readRow() function must re-fill the buffer by
; reading BUFF_SIZE bytes from the file. Only after the last row has been returned, should the
; getRow() function return a FALSE status.


; ---- eof checks
	finalRead:  
		mov byte[wasEOF], TRUE
		mov qword[curr], 0
		mov rdi, r12
		mov rsi, localBuffer
		mov rdx, rax
		mov rax, SYS_read
		syscall
		jmp skipRead
		
	doneRow:
		mov rax, TRUE
		jmp done3
		
;	if(eof)
;		set buffmax to the curr indx - to grab the remaining amount of characters


; ---- check if done

errorOnRead: 
	mov rdi, errRead
	call printString
	mov rax, FALSE
	jmp done3
	
setFalse: 
	mov rax, FALSE
    
done3:  
	  pop r15
	  pop r14
	  pop r13
	  pop r12
	  pop rbx
	  mov rsp, rbp
	  pop rbp
  
  ret

; ***************************************************************
;  Write image row to output file.
;	Writes exactly (width*3) bytes to file.
;	No requirement to buffer here.

; -----
;  HLL Call:
;	status = writeRow(writeFileDesc, pciWidth, rowBuffer);

;  Arguments are:
;	write file descriptor (value)	- rdi
;	image width (value)				- rsi
;	row buffer (address)			- rdx

;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been written
;	and returns FALSE only if there is an
;	error on write (which would not normally occur).


;	YOUR CODE GOES HERE
global writeRow
writeRow:

	push r12

	mov r12, 3
	mov rax, rsi
	push rdx
	mul r12
	pop rdx
	mov r12, rax

	;Function writeRow() should write one row of pixels to the output file.
	;startWriteRow:
	mov rax, SYS_write
	mov rsi, rdx
	mov rdx, r12
	syscall

	cmp rax, 0
	jl writeRowFail
	;If successful, return TRUE.
	mov rax, TRUE
	jmp endWriteRow

	;If there is a write error, dispaly error message and return FALSE.
	writeRowFail:
	mov rdi, errWrite
	call printString
	mov rax, FALSE
	jmp endWriteRow

	endWriteRow:

	pop r12

	ret

; ***************************************************************
;  Convert pixels to grayscale.

; -----
;  HLL Call:
;	status = imageCvtToBW(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)	- rsi
;  Returns:
;	updated row buffer (via reference)


;	YOUR CODE GOES HERE
global imageCvtToBW
imageCvtToBW:

;newRed = newGreen = newBlue = (oldRed + oldGreen + oldBlue )/3

	push rbx
	push r12
	push r13
	push r14
	push r15

	mov rbx, 0
	mov r12, 0
	mov r13, 0
	mov r14, 0
	mov r15, 3
	;mov r15b, 3

	mov rax, rdi
	mul r15
	mov r12, rax

	startGrayscaleConvert:
	;old r + g + b
	movzx rax, byte[rsi + rbx + 0]
	movzx r14, byte[rsi + rbx + 1]
	add rax, r14
	movzx r14, byte[rsi + rbx + 2]
	add rax, r14

	;div 3
	cqo
	div r15

	mov byte[rsi + rbx + 0], al
	mov byte[rsi + rbx + 1], al
	mov byte[rsi + rbx + 2], al

	add rbx, 3

	cmp rbx, r12
	jl startGrayscaleConvert

	;if complete, return true
	mov rax, TRUE

	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx

	ret

; ***************************************************************
;  Update pixels to increase brightness

; -----
;  HLL Call:
;	status = imageBrighten(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)


;	YOUR CODE GOES HERE
global imageBrighten
imageBrighten:

push rbx
push r12
push r13
push r14

mov rbx, 0	
mov r12, 0
mov r12, 2
mov r13, 3
mov r14, 0
mov r14b, 255

mov rax, rdi
mul r13
mov r13, rax

;newBrightenedColorValue = oldColorValue/2 + oldColorValue
startBrightenConvert:
mov rax, 0
movzx rax, byte[rsi + rbx]
cqo
div r12
movzx r14, byte[rsi + rbx]
add rax, r14

cmp rax, 255
jbe colorInBounds
;cmp al, 0
;jae colorInBounds
mov rax, 0
mov al, 255
colorInBounds:

mov byte[rsi + rbx], al
inc rbx
cmp rbx, r13
jl startBrightenConvert
mov rax, TRUE

pop r14
pop r13
pop r12
pop rbx

	ret

; ***************************************************************
;  Update pixels to darken (decrease brightness)

; -----
;  HLL Call:
;	status = imageDarken(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)


;	YOUR CODE GOES HERE
global imageDarken
imageDarken:

push rbx
push r12
push r13

mov rbx, 0	
mov r12, 0
mov r12b, 2
mov r13, 3

mov rax, rdi
mul r13
mov r13, rax

;newDarkenedValue = oldColorValue/2
startDarkenConvert:
mov rax, 0
mov al, byte[rsi + rbx]

div r12b
mov byte[rsi + rbx], al
inc rbx
cmp rbx, r13
jl startDarkenConvert
mov rax, TRUE

pop r13
pop r12
pop rbx

	ret

; ******************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.

;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	- address, string
;  Returns:
;	nothing

global	printString
printString:
	push	rbx

; -----
;  Count characters in string.

	mov	rbx, rdi			; str addr
	mov	rdx, 0
strCountLoop:
	cmp	byte [rbx], NULL
	je	strCountDone
	inc	rbx
	inc	rdx
	jmp	strCountLoop
strCountDone:

	cmp	rdx, 0
	je	prtDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write			; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
						; EDX=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

prtDone:
	pop	rbx
	ret

; ******************************************************************

