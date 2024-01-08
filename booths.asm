.data
multiplicand: .space 32
multiplier: .space 32
output: .space 64
line: .asciiz "----------\n"
multi_sign: .asciiz "X"
new_line: .asciiz "\n"
input_error: .asciiz "input error!"
overflow_error: .asciiz "overflow!"

.text

main:
	# Read Input String
	addi $v0, $zero, 8			# syscall for read-String
	add $a0, $zero, $sp			# stack as input buffer
	addi $a1, $zero, 255		# 255-bit string MAX (probably overkill)
	syscall
	jal convert_string_to_int
	add $s0, $zero, $a0

	addi $v0, $zero, 8
	add $a0, $zero, $sp
	addi $a1, $zero, 255
	syscall
	jal convert_string_to_int
	add $s1, $zero, $a0

	#Num 1 in $s0, num 2 in $s1

	# Print an extra space before num1
	addi $a0, $zero, 32
	addi $v0, $zero, 11
	syscall

	#Print Num1
	add $a0, $zero, $s0
	addi $a1, $zero, 0
	jal print_binary

	# prints multi_sign
    li $v0, 4 
    la $a0, multi_sign
    syscall

	#Print Num2
	add $a0, $zero, $s1
	addi $a1, $zero, 0
	jal print_binary

	# prints product line
    li $v0, 4 
    la $a0, line
    syscall

	# Jump to and perform booths alg
	jal booths_algorithm
	
	j exit_prgm

exit_prgm:
	addi $v0, $zero, 10
	syscall

# Put string into stack, result in $a0 
convert_string_to_int:
	addi $t1, $zero, 0
	addi $t2, $zero, 0
	addi $t4, $zero, 0 # if = 1 then negative

	lb $t2, 0($sp)
	addi $t3, $zero, 45
	beq $t2, $t3, csti_negative
csti_loop:
	lb $t2, 0($sp)
	
	# I want to check if it is zero, our string is null-terminating
	beq $t2, $zero, csti_done_print
	
	# compare to newline (Had this come up during testing)
	addi $t3, $zero, 10
	beq $t2, $t3, csti_done_print

	# compare to '-' sign because there should only be a '-' at the beginning
	addi $t3, $zero, 45
	beq $t2, $t3, csti_ndigit
	
	# Compare our value to known ascii digits
	addi $t3, $zero, 48	# == '0'
	bgt $t3, $t2, csti_ndigit
	
	addi $t3, $zero, 57	# == '9'
	bgt $t2, $t3, csti_ndigit
	
	#checks if mulitplicand and multiplier overflow
   # addu $t4, $t1, $t1 # unsigned integers have another bit place, which allows for testing
   # slt $t4, $t4, $t1 # branches if the sum of the multiplicand and multiplier is less than the multiplier
#	bne $t4, $zero, input_error


	# STEPS FOR ACTUAL CONVERSION:
	#	sub 48 (so '0' == 0)
	#	multiply result by 10 (1 --> 10, this means when we add 5 it becomes 15 instead of 6)
	#	add to the result (10 + 5 = 15)
	addi $t2, $t2, -48
	mul $t1, $t1, 10
	addu $t1, $t1, $t2

	# Check if MSB is 1 (overflow)
	srl $t2, $t1, 31
	bne $t2, $zero, csti_ndigit

	addi $sp, $sp, 1
	j csti_loop

csti_negative:
	addi $sp, $sp, 1
	addi $t4, $zero, 1

	j csti_loop
	
csti_ndigit:
	addi $v0, $zero, 4
	la $a0, input_error
	syscall
	j exit_prgm
	
csti_overflow:
	addi $v0, $zero, 4
	la $a0, overflow_error
	syscall
	j exit_prgm

csti_done_print:
	beq $t4, $zero, csti_done_skip_negative
	# Check if negative zero (means just a - sign was entered)
	beq $t1, $zero, csti_ndigit
	sub $t1, $zero, $t1
csti_done_skip_negative:
	add $a0, $zero, $t1	# I want to return the value in the arguments registers
	jr $ra

# void print_binary($a0 = toPrint, $a1 = newlineCharacter? (0=Newline,1=NoNewLine)) 
print_binary:
	addi $t1, $zero, 33
	addi $t4, $zero, 0 
	add $t2, $zero, $a0
	# assume thing in $a0 (move it to $t2)
pb_loop:
	# Subtract and check counter
	addi $t1, $t1, -1
	beq $t1, $zero, pb_done

	# Test MSB = 1
	srl $t4, $t2, 31
	andi $t0, $t4, 1
	beq $t0, $zero, pb_zero
	j pb_one
pb_zero:
	# Shift values
	# Print '1'
	sll $t2, $t2, 1
	addi $a0, $zero, 0x30
	addi $v0, $zero, 11
	syscall
	j pb_loop
pb_one:
	# Shift values
	# Print '0'
	sll $t2, $t2, 1
	addi $a0, $zero, 0x31
	addi $v0, $zero, 11
	syscall
	j pb_loop
pb_done:
	addi $a0, $zero, 1
	beq $a1, $a0, pb_done2
	# Print newline 
	li $v0, 11
	li $a0, 10
	syscall
pb_done2:
	jr $ra

booths_algorithm:
	#AQ Right-Shift
	addi $s2, $zero, 32 #counter
	addi $t4, $t4, 0	# For shifting math
	add $t5, $zero, $s0 #loads the multiplicand
	add $t6, $zero, $s1 #loads the multiplier
	add $t7, $zero, $s1 #this will initialize the Q-register with the multiplier value
	add $t8, $zero, $zero #this will initialize Q(-1) register
	add $t9, $zero, $zero #this will initialize A register

booths_algorithm_loop:
	beq $s2, $zero, booths_algorithm_done # this will check if the 32 iterations are done
	
	#checks Q(0) and Q(-1)
	andi $t4, $t7, 1 
	bne $t4, $t8, booth_add_or_subtract
	
booth_return:
	#Shift all by one bit (A , Q, and Q(-1))
	andi $t8, $t7, 1 # andi q_-1, q_0, 1

	srl $t7, $t7, 1 # shifts (Q)						# 

	# Extract the LSB of A and make it the MSB of Q
	sll $t4, $t9, 31  # Shift A right by 31 bits to extract the LSB
	or $t7, $t4, $t7 

	sra $t9, $t9, 1 # shifts (A) 

	#prints space before number
	addi $a0, $zero, 32
	addi $v0, $zero, 11
	syscall

	#prints current iteration 64 bit number
	add $a0, $zero, $t9 #A /// We get an overflow error here sometimes
	addi $a1, $zero, 1
	jal print_binary

	add $a0, $zero, $t7 #Q
	addi $a1, $zero, 0
	jal print_binary

	#decrements and loops
	addi $s2, $s2, -1
	j booths_algorithm_loop

booth_add_or_subtract:
	# If Q(-1) = 0 subtract, otherwise add
	beq $t8, $zero, booth_sub # This adds positive or negative multiplicand to the A field( A is in $t9 register)
	add $t9, $t9, $t5 # A = A + M
	j booth_return
booth_sub:
	sub $t9, $t9, $t5 # A = A - M
	j booth_return
	
booths_algorithm_done:
	#result is printed in binary (64-bit)
	addi $a0, $zero, 64

	# prints product line
    li $v0, 4 
    la $a0, line
    syscall

	# prints output 
	
	#prints space before number
	addi $a0, $zero, 32
	addi $v0, $zero, 11
	syscall

	#prints current iteration 64 bit number
	add $a0, $zero, $t9 #A /// We get an overflow error here sometimes
	addi $a1, $zero, 1
	jal print_binary

	add $a0, $zero, $t7 #Q
	addi $a1, $zero, 0
	jal print_binary

	# exits
	jal exit_prgm

error:

	# prints input error message
	li $v0, 4 
    la $a0, input_error
    syscall

	jal exit_prgm