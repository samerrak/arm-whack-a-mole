.global _start
.equ TIMER_LOAD, 0xFFFEC600
.equ HEX_ADDR, 0xFF200020
.equ HEX_ADD, 0xFF200031
.equ SW_ADDR, 0xFF200040
.equ PUSH_ADDR, 0xff200050
load: .word 80000
control: .byte 1, 1, 0, 250 //EAI Prescale F
//Why did I chose 250 for prescale based on my calculations
//250 for prescale will result in 1E-4ms for each counter
//400 iterations

_start:
	
	BL reset 
		
	

end:
	B end
	
time_display:
	CMP A1, #0
	MOVEQ A1, #0b00111111
	BEQ set
	CMP A1, #1
	MOVEQ A1, #0b00000110
	BEQ set
	CMP A1, #2
	MOVEQ A1, #0b01011011
	BEQ set
	CMP A1, #3
	MOVEQ A1, #0b01001111
	BEQ set
	CMP A1, #4
	MOVEQ A1, #0b01100110
	BEQ set
	CMP A1, #5
	MOVEQ A1, #0b01101101
	BEQ set
	CMP A1, #6
	MOVEQ A1, #0b01111101
	BEQ set
	CMP A1, #7
	MOVEQ A1, #0b00000111
	BEQ set
	CMP A1, #8
	MOVEQ A1, #0b01111111
	BEQ set
	CMP A1, #9
	MOVEQ A1, #0b01101111
	BEQ set
	CMP A1, #10
	CMP V2, #0
	MOVLE A1, #0b00111111
	MOVGT A1, #0b01101111
		
set:	
	CMPLE A2, #0
	//ORREQ A1, A1, #0b10000000
    STRB A1, [A3], #-1         // update LED state with the contents of A1
	BX LR

reset:
	PUSH {V1-V8}
r:
	LDR A1, =TIMER_LOAD
	LDR A2, =PUSH_ADDR
	LDR A4, =#0x0000fa03
	MOV A3, #0
	MOV V1, #1
	STR V1, [A1, #12]
	LDR V2, =HEX_ADDR
	MOV V3, #0b00111111 //0
	STRB V3, [V2, #16]
	MOV V3, #0b01001111 //3
	STRB V3, [V2, #17]
	POP {v1-V8}

	

setup: 
	PUSH {V1-V8}
	LDR V1, load
	STR V1, [A1] //store load value, V1 now at control register
	
	LDR V2, =PUSH_ADDR 
	MOV V4, #1

	
start_sb4:
	LDR V1, [V2, #12]
	TST V4, V1
	BEQ start_sb4

clear: //V4 stores the operation 
	LDR V3, [V2, #12]
	STR V3, [V2, #12] //reset 
	POP {V1-V8}
	

	
timer:
	PUSH {V1-V8}
	PUSH {A4}
	//MOV V4, #1
	MOV V3, #9
	MOV V5, #2
	LDR A4, =#0x0000fa03
	STR A4, [A1, #8] //enables it 
	POP {A4}


one_second:	//poll for one second from 10 - 30 done
	//CMP V5, #1
	//CMPEQ V3, #0
	//BEQ tenth_s
	MOV V4, #1
	CMP V3, #0
	ORR V8, V3, V5
	MOVEQ V3, #9
	SUBEQ V5, V5, #1

	CMP V8, #0
	MOVLE V3, #0

	LDR V1, [A1, #12] // loads interrupt value
	TST V1, V4
	BEQ one_second // polls for interrupt
	ADD V2, V2, #1 // counts tenths of a second
	STR V1, [A1, #12] //writing #1 to interrupt
	CMP V2, #11 //tenth second counter = 1s change here to 11
	MOVGE V2, #1
	//BNE one_second
	SUBEQ V3, V3, #1 // decrement second counter
	PUSH {A1, A2, A3, LR}
	LDR A3, =HEX_ADD
	CMP V5, #0
	MOV A2, #0
	MOVGT A1, V5 //store first dig
	MOVLE A1, V3 
	BL time_display
	ADD A2, A2, #1
	CMP V5, #0
	MOVGT A1, V3 //store second dig
	//MOVLE A1, V2
	MOVLE A1, #10
	SUBLE A1, A1, V2
	BL time_display
	POP {A1, A2, A3, LR}
	
	//CMP V2, #1
	//MOVGE V2, #0
	//B one_second
	
	
check_hex:
	PUSH {V1-V8} 
	LDR V1, =#0xFF200030
	LDRB V2, [V1] 
	LDRB V3, [V1,#1]
	
	
	CMP V2, #0b00111111
	CMPEQ V3, #0b00111111
	//AND V1, V2, V3
	//MOV V4, #0
	

	POP {V1-V8}
	POPEQ {V1-V8}
	BNE check_c
	PUSH {V1-V8}
	MOV V1, A3
	MOV V2, #0
	LDR V5, =#0xFF200020
	STREQ V4, [V5]
	
division:
	CMP V1, #10
	BLT store
	ADD V2, V2, #1
	SUB V1, V1, #10
	B division
	
store: 
	PUSH {A1, A3, LR}
	LDR A3, =HEX_ADD
	MOV A1, V2
	BL time_display
	MOV A1, V1
	BL time_display
	
	POP {A1, A3, LR}
	
	
	POP {V1-V8}
	
	PUSH {V4}

reset_wait:
	LDR V4, [A2, #12] // get edgecapture
	CMP V4, #8 // if reset, restart the whole thing
	POPEQ {V4}
	BEQ reset
	STR V4, [A2, #12] 
	B reset_wait
	
	
check_c:	
	PUSH {V1-V8} //moved here now
check:
	LDR V4, [A2, #12] // get edgecapture
	CMP V4, #2 //this will cause it to stop by entering an endless while
	BEQ check
	CMP V4, #4 // if reset, restart the whole thing
	LDR V6, [A2, #12] // clear edgecapture
	STR V6, [A2, #12] 
	POP {V1-V8}
	POPEQ {V1-V8}
	BEQ reset


	
switch_check:
	PUSH {A1-A2, V1-V8}
	LDR A1, =HEX_ADDR //hex adder address
    LDR V1, =SW_ADDR     // load the address of slider switch state
    LDR V1, [V1]
	AND V1, V1, #0x0000000F //mask all bits to isolate last 4 bits
	//here need to check if it hits it first
	
check_hit:
	PUSH {V1-V8}
	SUB V2, A4, A1 //get which hex o stored in
	
	//MOV V8, A3
	
	CMP V2, #0
	ADDNE PC, PC, #4 //helps with randomization
	CMP V1, #1
	ADDEQ A3, A3, #1
	
	CMP V2, #1
	ADDNE PC, PC, #4
	CMP V1, #2
	ADDEQ A3, A3, #1
	
	CMP V2, #2
	ADDNE PC, PC, #4
	CMP V1, #4
	ADDEQ A3, A3, #1
	
	CMP V2, #3
	ADDNE PC, PC, #4
	CMP V1, #8
	ADDEQ A3, A3, #1
		
	//CMP V8, A3
	BEQ clear_hx
	

	
clear_hx:
	MOV V5, #0
	LDR V6, =HEX_ADDR //hex adder address
	STR V5, [V6]
	POP {V1-V8}

randomizer:
	LDR V2, =#0xFFFEC600
	MOV V3, #0b00111111
	//randomize hex display
	PUSH {V3 - V8}
	
	
	CMP V1, #0
	MOVEQ V5, #2
	MOVEQ V6, #1
	MOVEQ V7, #0
	MOVEQ V8, #3
	LDREQ V2, [V2, #4] //current count, TIMER_LOADER //change was A1
	BEQ random_f	

	CMP V1, #1
	MOVEQ V5, #3
	MOVEQ V6, #1
	MOVEQ V7, #2
	MOVEQ V8, #1
	LDREQ V2, [V2, #4] //current count, TIMER_LOADER //change was A1
	BEQ random_f	

	CMP V1, #2
	MOVEQ V5, #0
	MOVEQ V6, #2
	MOVEQ V7, #0
	MOVEQ V8, #3
	LDREQ V2, [V2, #4] //current count, TIMER_LOADER //change was A1
	BEQ random_f	

	CMP V1, #4
	MOVEQ V5, #1
	MOVEQ V6, #3
	MOVEQ V7, #0
	MOVEQ V8, #3
	LDREQ V2, [V2, #4] //current count, TIMER_LOADER //change was A1
	BEQ random_f	

	CMP V1, #8
	MOVEQ V5, #0
	MOVEQ V6, #1
	MOVEQ V7, #2
	MOVEQ V8, #1
	LDREQ V2, [V2, #4] //current count, TIMER_LOADER //change was A1
	BEQ random_f	

	
random_f:	
	AND V2, V2, #0x7 //this is masking that last three bits
	LDR A1, =HEX_ADDR //hex adder address
	
	CMP V2, #0 // to increase randomization isntead of just defaulting to hex 4 if its greater than 3
	ADDEQ A1, A1, V5 //0

	CMP V2, #4
	ADDEQ A1, A1, V5 //0
	BEQ store_r
	
	CMP V2, #1
	ADDEQ A1, A1, V6

	CMP V2, #5
	ADDEQ A1, A1, V6
	BEQ store_r
	
	CMP V2, #2
	ADDEQ A1, A1, V7

	CMP V2, #7
	ADDEQ A1, A1, V7
	BEQ store_r
	
	CMP V2, #3
	ADDEQ A1, A1, V8

	CMP V2, #6
	ADDEQ A1, A1, V8
	BEQ store_r
	
	
	

	
store_r:
	POP {V3 - V8}
	STRB V3, [A1]

	MOV A4, A1
	POP {A1-A2, V1-V8}
	
	B one_second