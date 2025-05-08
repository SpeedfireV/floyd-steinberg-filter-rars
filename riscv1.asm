# s0 - image_buffer_start
# s1 - output image buffer start
	
	.data
prompt: .asciz "Provide File Path\n"
open_error_message: .asciz "Error opening file!!!"

new_image_buffer: 
	.space 1000000

image_buffer:	
	.space 1000000

new_image_file: 
	.asciz "output.bmp"

input_file:	
	.space 1000
	.text
	.globl main

main:	
	# Ask for file path
	li a7, 4
	la a0, prompt
	ecall
	
	# Let user input file path
	li a7, 8
	la a0, input_file
	li a1 1000
	ecall
	
	
	# Get rid of \n at the end of input
	li t0, '\n'
	la t1, input_file
	lbu t2, (t1)
	beq t2, t0, find_new_line_loop_end
find_new_line_loop:
	addi t1, t1, 1
	lbu t2, (t1)
	bne t2, t0, find_new_line_loop
find_new_line_loop_end:
	li t0, 0
	sb t0, (t1)
	
	
	
	# Load image & save it's descriptor to memory
	li a7, 1024
	la a0, input_file
	li a1, 0
	ecall
	mv s6, a0 # Save descriptor in s6 register
	
	bltz a0, open_error
	
	
	# Read file into image_buffer
	la a1, image_buffer   # destination buffer
	li a2, 1000000        # max bytes to read
	li a7, 63             # syscall: read
	mv a0, s6             # file descriptor in a0
	ecall

	
	# Close original image
	li a7, 57
	mv a0, s6
	ecall
	
	# Load contents of bmp into s0
	la s0, image_buffer
	la s1, new_image_buffer
	
	# Load image's width & height to s10 (width) & s11 (height) registers	
	# s9 is the total size of image - width * height
	# TODO: Do zoptymalizowania - można wczytywać hword
get_width_and_height:
    addi t2, s0, 18
    lbu t3, 0(t2)
    lbu t4, 1(t2)
    lbu t5, 2(t2)
    lbu t6, 3(t2)
    slli t4, t4, 8
    slli t5, t5, 16
    slli t6, t6, 24
    or s10, t3, t4
    or s10, s10, t5
    or s10, s10, t6
    addi t2, s0, 22
    lbu t3, 0(t2)
    lbu t4, 1(t2)
    lbu t5, 2(t2)
    lbu t6, 3(t2)
    slli t4, t4, 8
    slli t5, t5, 16
    slli t6, t6, 24
    or s11, t3, t4
    or s11, s11, t5
    or s11, s11, t6
    mul s9 s10 s11
    
	
pre_iteration:
	# PC: Pointer at byte in original image
	li s7 -1
	# Load first pixel pos
	addi t2, s0, 10
	lbu t3, (t2)
	addi t2 t2 1
    	lbu t4, (t2)
    	addi t2 t2 1
    	lbu t5, (t2)
    	addi t2 t2 1
    	lbu t6, (t2)
    	slli t4, t4, 8
    	slli t5, t5, 16
    	slli t6, t6, 24
    	or s8, t3, t4
    	or s8, s8, t5
    	or s8, s8, t6
	
	addi s0 s0 -1
	addi s1 s1 -1
pixel_iteration:
	addi s7 s7 1
	# Move pointers
	addi s0 s0 1
	addi s1 s1 1
	
	lb t0, (s0)
	
	
	ble s7 s8 load_descriptor_byte
	j dither_pixel
	
	
	
load_descriptor_byte:
	lb t6 (s0)
	sb t6 (s1)
	j pixel_iteration
	
	
dither_pixel:
	lb t0 (s0)
	lb t1 (s1)
	add t0 t0 t1
	li t2 128
	ble t0 t2 round_down

		
round_up:
	li t0 255
	sb t0 (s1)
	j propagate_right_pixel 

round_down:
	li t0 0
	sb t0 (s1)

propagate_right_pixel:
	li t0 0
	sub t0 t0 s8
	add t0 t0 s7 # Current pos
	 
	
	
	mv t1 s10 # Width
	remu t2 t0 t1 # Remainder of current pos % width
	beqz t2 propagate_left_bottom_pixel
	sub t2 s9 s7 # size - pos pointer
	beqz t2 end # end if it's last element
	# TODO: Implement
	mv t0 s1 # Load address of new image buffer
	addi t0 t0 1
	lb t1 (t0) # Load current state of that byte
	addi t1 t1 112 # Add 7/16 (112) to current state
	sb t1 (t0) # Save to memory
	
propagate_left_bottom_pixel:
	li t0 0
	sub t0 t0 s8 # Load first pixel pos
	add t0 t0 s7 # Load pos pointer
	addi t0 t0 -1 # Left
	add t0 t0 s10 # Bottom
	bgt t0 s9 pixel_iteration
	mv t1 s1 # Load memory address
	addi t1 t1 -1 # Left
	add t1 t1 s10 # Bottom
	lb t2 (t1) # Load from memory
	addi t2 t2 48 # Add 3/16 
	sb t2 (t1)

propagate_bottom_pixel:
	li t0 0
	sub t0 t0 s8 # Load first pixel pos
	add t0 t0 s7 # Load pos pointer
	add t0 t0 s10 # Bottom
	bgt t0 s9 pixel_iteration
	mv t1 s1 # Load memory address
	add t1 t1 s10 # Bottom
	lb t2 (t1) # Load from memory
	addi t2 t2 80 # Add 5/16 
	sb t2 (t1)

propagate_bottom_right_pixel:
	li t0 0
	sub t0 t0 s8 # Load first pixel pos
	add t0 t0 s7 # Load pos pointer
	addi t0 t0 1 # Right 
	add t0 t0 s10 # Bottom
	bgt t0 s9 pixel_iteration
	mv t1 s1 # Load memory address
	addi t1 t1 1 # Right
	add t1 t1 s10 # Bottom
	lb t2 (t1) # Load from memory
	addi t2 t2 16 # Add 5/16 
	sb t2 (t1)
	
	j pixel_iteration


end:
	# Open new image file
	li a7 1024
	la a0 new_image_file
	li a1 1
	ecall
	mv s6 a0
	
	# Number of bytes to write to file
	li t0 0
	add t0 t0 s8
	add t0 t0 s9
	
	li a7, 64               # syscall: write
	mv a0, s6              # file descriptor
	la a1, new_image_buffer     # buffer address
	mv a2, t0               # number of bytes to write
	ecall
	
	# Close file
	li a7, 57
	mv a0, s6
	ecall

	

	
	li a0, 0      # return code 0 (success)
	li a7, 93     # syscall: exit
	ecall
	
	
open_error:
    la a0, open_error_message # Define this in your .data section
    li a7, 4                # syscall: print string
    ecall
    li a0, 10               # Error exit code
    li a7, 93               # syscall: exit
    ecall
	
