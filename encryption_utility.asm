# Who:  Jay Chen
# What: encryption_utility.asm
# Why:  CS2640 Project 4
# When: due 5/5
# How:  List the uses of registers (SEE SUBROUTINE HEADINGS FOR USE OF REGISTERS PER SUBROUTINE)

.data
    #file I/O constants
    .eqv            PASS_BUFFER_SZ                 257
    .eqv            PATH_BUFFER_SZ                 256
    .eqv            FILE_BUFFER_SZ                 1024
    .eqv            FILE_OPEN                      13
    .eqv            FILE_CLOSE                     16
    .eqv            FILE_READ                      14
    .eqv            FILE_WRITE                     15

    #buffers
    FILE_BUFFER:    .space                         FILE_BUFFER_SZ
    PASS_BUFFER:    .space                         PASS_BUFFER_SZ
    DST_PATH:       .space                         PATH_BUFFER_SZ
    SRC_PATH:       .space                         PATH_BUFFER_SZ

    #syscall constants
    .eqv	        NEW_LINE			           10  #line feed (newline)
    .eqv            ASTERISK                       42  
    .eqv	        PRINT_CHAR	                   11  #syscall code for printing char
    .eqv            PRINT_STRING                   4   #syscall code for printing string
    .eqv            READ_STRING                    8   #syscall code, a0 - buffer a1 - max size to read
    
    #receiver control
    .eqv	        CONSOLE_RCVR_CONTROL           0xffff0000
    .eqv        	CONSOLE_RCVR_READY_MASK        0x00000001
    .eqv	        CONSOLE_RCVR_DATA              0xffff0004

    #console prompts
    SRC_INPROMPT:   .asciiz                        "\nInput source file path (include .txt):\n(Note: chars beyond 255 bytes are ignored)\n-->"
    DST_INPROMPT:   .asciiz                        "\nInput destination file path (include .txt):\n(Note: chars beyond 255 bytes are ignored)\n-->"
    PASS_INPROMPT:  .asciiz                        "\nInput password:\n(Note: chars beyond 256 bytes are ignored)\n-->"
	PASS_OVER:      .asciiz                        "\nPassword input has reached 256 characters. Input ended.\n"
    FILE_ERROR:     .asciiz                        ": file caused file open error. program ended.\n"

.text
.globl main

main:  
    #program entry
    la $a0, SRC_PATH
    li $a1, PATH_BUFFER_SZ
    la $a2, SRC_INPROMPT
    jal get_string

    la $a0, DST_PATH
    li $a1, PATH_BUFFER_SZ
    la $a2, DST_INPROMPT
    jal get_string

    la $a0, PASS_BUFFER
    jal get_pass

    la $a0, SRC_PATH
    la $a1, DST_PATH
    la $a2, PASS_BUFFER
    jal encrypt_file

    b exit

end_main:

# GET_PASS: 
        # reads each byte entered from keyboard, stores as a passphrase
        # outputs asterisk to console for each char entered 
        # ends input automatically if passphrase entered reaches 256 chars
        # else ends input when user presses enter, stores null byte at end

#ARGS: $a0 - passphrase string buffer
#REGISTERS: 
    #v0 - syscall console printing
    #t0 - checks if console ready to read a character
    #t1 - stores newline to check if user has pressed enter
    #t2 - stores passphrase buffer idx, incremented with each input
    #t3 - maximum address of passphrase buffer idx, to check if user entered over allowed limit
#RETURNS: no return values, simply stores the passphrase in the argument buffer
get_pass:
    li $t1, NEW_LINE                            #ascii enter, signals to end input
	move $t2, $a0                               #save pass buffer to t2
    addi $t3, $a0, PATH_BUFFER_SZ               #make t3 last possible address for pass (reuse path size bc = 257-1)

    la $a0, PASS_INPROMPT                       #print prompt
    li $v0, PRINT_STRING
    syscall

    key_wait:                                   #wait 4 key press
    lw $t0, CONSOLE_RCVR_CONTROL
    andi $t0, $t0, CONSOLE_RCVR_READY_MASK      #isolate ready bit
    beqz $t0, key_wait

    lbu $a0, CONSOLE_RCVR_DATA                  #read 1 byte char fr keyboard
    beq	$a0, $t1, end_key_wait                  #check if keypress enter, then end
    
    beq $t2, $t3, passover                      #if passphrase at max # chars already, end input 

    sb $a0, ($t2)                               #store byte in next open space of PASS_BUFFER
    addi $t2, $t2, 1                            #increment counter to next avail space

    li $a0, ASTERISK                            #print asterisk
    li $v0, PRINT_CHAR
    syscall
    b key_wait

    passover:
    la $a0, PASS_OVER
    li $v0, PRINT_STRING
    syscall

    end_key_wait:
    li $t1, 0                                   #store null at end of passphrase
    sb $t1, ($t2)
    jr $ra
end_get_pass:

# GET_STRING
    #reads string for a filepath from user input, stores in the buffer argument
    #if the string exceeds the max buffer size the extra characters are ignored,  
    #and the fileopen will print an error and terminate program later
    #manually removes newline char and adds nullterminal when user input < max buffer size
#ARGS: $a0 - string buffer, $a1 - size of string buffer, $a2 - input prompt
#REGISTERS:
    #t0 - input buffer address
    #t1 - max end address of string buffer
    #t2 - stores byte to check for newline char
#RETURNS: no return values, stores the user input in argumet buffer
get_string:
    #src_filepath = getString(src_buffer)
    #dst_filepath = getString(dst_buffer)
    #getString uses syscall to read a string into a buffer from console.
    #this buffer should be able to contain at least 256 characters.
    #buffer must be null terminated.

    move $t0, $a0           #save input buffer to t0

    move $a0, $a2           #load and print prompt
    li $v0, PRINT_STRING
    syscall

    move $a0, $t0           #restore buffer to a0        
    li $v0, READ_STRING     #read input string, ignoring chars beyond max
    syscall
    
    move $t0, $a0           #copy string to t0
    addu $t1, $t0, $a1      #possible end address of string
    
    nullterminate:
        beq $t0, $t1, endnullterminate    
        lb $t2, ($t0)                    #get current byte of string
        addi $t0, $t0, 1                 #increment to next byte of string
        bne $t2, NEW_LINE, nullterminate #jump back to loop if not equal to newline
        foundnewline:
        addi $t0, $t0, -1                #decrement to next byte of string
        sb $0, ($t0)
    endnullterminate:
    
    jr $ra
end_get_string:


# ENCRYPT_FILE: 
        # subroutine opens source file in read mode, and destination file in write mode
        # XORs each byte of the buffer with a byte in the passphrase storing the resulting byte back to the buffer 
        # buffer is then written to the destination file 
        # used as an encryption method that allows files to be encrypted/decrypted using the same passphrase
#ARGS: $a0 - src path, $a1 - dst path, $a2 - pass buffer
#REGISTERS: 
    #s0 - srcfile read flag
    #s1 - dstfile, dstfile write flag
    #s2 - password buffer
    #t0 - checks if file open is valid, holds current byte of passphrase 
    #t1 - holds current byte of filebuffer
    #t2 - passphrase buffer idx, to save current index of passphrase to xor
    #t3 - FILEBUFFER offset, to mark idx of current byte in filebuffer to xor

#RETURNS: no return values, writes encrypted file to destination buffer (or creates new dest file if filename entered does not yet exist)
encrypt_file:
    move $s1, $a1 #save dst file to use arg register
    move $s2, $a2 #save password to use arg register
        
    filestuff:
        #open src file (already stored in $a0)
        li $a1, 0     #0 to read
        li $a2, 0
        li $v0, FILE_OPEN
        syscall
        #test the descriptor for fault
        move $s0, $v0 #save file descriptor READ
        slt $t0, $s0, $0
        bne $t0, $0, file_open_error

        #open dst file
        move $a0, $s1 #restore dst filepath
        li $a1, 1     #1 to write
        li $a2, 0
        li $v0, FILE_OPEN
        syscall

        #test the descriptor for fault
        move $s1, $v0 #save file descriptor write
        slt $t0, $s1, $0
        bne $t0, $0, file_open_error
    endfilestuff:

    move $t2, $s2   #passphrase placeholder start at beginning idx
    
    loopthru:
        #read buffer load of stuff
        li $v0, FILE_READ
        move $a0, $s0           #restore file desc READ
        la $a1, FILE_BUFFER
        li $a2, FILE_BUFFER_SZ
        syscall

        beq $v0, $0, closefile      #check if # of chars read = 0, if so close file
        
        li $t3, 0                   #FILEBUFFER offset
        
        xorpass:
        #loop thru the buffer byte by byte
        #xor each byte by byte of pass
        #increment pass placeholder
        
        #deprecated vvvv because faster to check if the number of characters read has been reached, not whole buffersize
        #beq $t3, FILE_BUFFER_SZ, endxorpass       #if reached end of max buffer size end inner loop

        beq $t3, $v0, endxorpass                   #if reached end of buffer characters read end inner loop
        
        lb $t1, FILE_BUFFER($t3)                   #get current byte from filebuffer
        
        passreset:
        lb $t0, ($t2)               #get current byte from passphrase
        bnez $t0, continue          #if pass not at null char, cont, else reset
        move $t2, $s2               #reset pass to front
        j passreset                 #get the passphrase char again now that its not null

        continue:
        xor $t1, $t0, $t1           #xor passphrase and filebuffer bytes
        sb $t1, FILE_BUFFER($t3)    #store xor'd value in the filebuffer at current idx
        addi $t2, $t2, 1            #increment password index
        addi $t3, $t3, 1            #increment filebuffer offset
        j xorpass
        endxorpass:

        #write buffer load of stuff
        move $a0, $s1           #restore file desc WRITE
        la $a1, FILE_BUFFER
        move $a2, $v0
        li $v0, FILE_WRITE
        syscall

        j loopthru
    endloopthru:    

    closefile:
        move $a0, $s0
        li $v0, FILE_CLOSE        #close file call
        syscall

        move $a0, $s1
        li $v0, FILE_CLOSE        #close file call
        syscall
    endclosefile:
    jr $ra
end_encrypt_file:

#FILE_OPEN_ERROR
    #small subroutine to print error code if invalid filename entered
#ARGS: $a0 - filepath tht caused error
#RETURNS: no return values, ends program on termination instead of returning to $ra
file_open_error:
    move $t0, $a0
    li $a0, NEW_LINE
    li $v0, PRINT_CHAR
    syscall
    li $v0, PRINT_CHAR
    syscall

    move $a0, $t0
    li $v0, PRINT_STRING #print name of file that caused error
    syscall

    la $a0, FILE_ERROR #print error message
    li $v0, PRINT_STRING
    syscall

    b exit              #end program because it cant run with invalid file input
end_file_open_error:

exit:
    li $v0, 10		        # terminate the program
    syscall