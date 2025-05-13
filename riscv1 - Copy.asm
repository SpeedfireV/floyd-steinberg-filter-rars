# s0 - image_buffer_start
# s1 - output image buffer start
# s7 - image byte pointer
# s8 - first pixel pos
# s9 - image size width*height
# s10 - image width
# s11 - image height


	
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
    # Read width
    addi t2, s0, 18
    lhu t3, 0(t2)
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

    # Read height
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

    # Calculate padded row size in bytes: ((s10 + 3) / 4) * 4
    addi t3, s10, 3
    li t4, 4
    div t3, t3, t4
    mul s10, t3, t4 

    # Total image size
    mul s9, s10, s11     # s9 = total pixel data size (with padding)
    add s9 s9 s10
    add s9 s9 s10
    
	
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
	
	lbu t0, (s0)
	
	
	ble s7 s8 load_descriptor_byte
	bge s7 s9 end
	j dither_pixel
	
	
	
load_descriptor_byte:
	lb t6 (s0)
	sb t6 (s1)
	j pixel_iteration
	
	
dither_pixel:
	lbu t0 (s0) # LOAD OLD IMAGE PIXEL
	lbu t1 (s1) # LOAD NEW IMAGE PIXEL CURRENT VALUE
	li t2 128
	blt t0 t2 round_down

round_up:
	# CALCULATE QUANT ERROR
	mv s6 t0 
	li t3 255
	sub s6 s6 t3
	# SAVE NEW PIXEL
	sb t3 (s1)
	j propagate_right_pixel

round_down:
	# CALCULATE QUANT ERROR
	mv s6 t0
	li t3 0
	# SAVE NEW PIXEL
	sb t3 (s1)
	j propagate_right_pixel
	

propagate_right_pixel:
	li t0 7 # VALUE FOR MUL
	mv t1 s6 # QUANT MULTIPLICATION REGISTER
	mul t1 t1 t0 # MULTIPLY QUANT BY 7
	
	
	mv t2 s0 # LOAD PIXEL POS
	addi t2 t2 1 # CALCULATE RIGHT PIXEL POS
	lbu t3 (t2) # LOAD RIGHT PIXEL VALUE
	
	
	mv t4 t2 # COPY RIGHT PIXEL POS
	sub t4 t4 s8 # DECREASE BY FIRST PIXEL POS
	rem t4 t4 s10 # CALCULATE REST OF LINE
	beqz t4 propagate_left_bottom_pixel
	
	
	li t0 16
	
	mul t3 t3 t0 # MUL RIGHT PIXEL VALUE BY 16
	
	add t1 t1 t3 # SUM RIGHT PIXEL WITH QUANT
	
	srai t1 t1 4 # DIVIDE RESULT BY 16
	
	sb t1 (t2) # SAVE VALUE TO RIGHT PIXEL POS
	
	
	
propagate_left_bottom_pixel:
	li t0 3 # VALUE FOR MUL
	mv t1 s6 # QUANT MULTIPLICATION REGISTER
	mul t1 t1 t0 # MULTIPLY QUANT BY 3
	
	mv t2 s0 # LOAD PIXEL POS
	addi t2 t2 -1 # CALCULATE LEFT POS | - 1
	add t2 t2 s10 # CALCULATE BOTTOM POS | + WIDTH
	lbu t3 (t2) # LOAD RIGHT PIXEL VALUE
	
	li t0 16
	
	mul t3 t3 t0 # MUL PIXEL VALUE BY 16
	
	add t1 t1 t3 # SUM LEFT BOTTOM PIXEL WITH QUANT
	
	srai t1 t1 4 # DIVIDE RESULT BY 16
	
	sb t1 (t2) # SAVE VALUE TO LEFT BOTTOM PIXEL POS
	

propagate_bottom_pixel:
	li t0 5 # VALUE FOR MUL
	mv t1 s6 # QUANT MULTIPLICATION REGISTER
	mul t1 t1 t0 # MULTIPLY QUANT BY 5
	
	mv t2 s0 # LOAD PIXEL POS
	add t2 t2 s10 # CALCULATE BOTTOM POS | + WIDTH
	lbu t3 (t2) # LOAD BOTTOM PIXEL VALUE
	
	li t0 16
	
	mul t3 t3 t0 # MUL PIXEL VALUE BY 16
	
	add t1 t1 t3 # SUM RIGHT PIXEL WITH QUANT
	
	srai t1 t1 4 # DIVIDE RESULT BY 16
	
	sb t1 (t2) # SAVE VALUE TO LEFT BOTTOM PIXEL POS

propagate_bottom_right_pixel:
	li t0 1 # VALUE FOR MUL
	mv t1 s6 # QUANT MULTIPLICATION REGISTER
	mul t1 t1 t0 # MULTIPLY QUANT BY 1
	
	mv t2 s0 # LOAD PIXEL POS
	add t2 t2 s10 # CALCULATE BOTTOM POS | + WIDTH
	addi t2 t2 1 # CALCULATE RIGHT POS | + 1
	lbu t3 (t2) # LOAD BOTTOM RIGHT PIXEL VALUE
	
	li t0 16
	
	mul t3 t3 t0 # MUL PIXEL VALUE BY 16
	
	add t1 t1 t3 # SUM BOTTOOM RIGHT PIXEL WITH QUANT
	
	srai t1 t1 4 # DIVIDE RESULT BY 16
	
	sb t1 (t2) # SAVE VALUE TO LEFT BOTTOM PIXEL POS
	
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
	
