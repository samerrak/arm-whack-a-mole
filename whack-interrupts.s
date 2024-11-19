.section .vectors, "ax"
B _start            // reset vector
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0             // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ     

.global _start
.equ TIMER_LOAD, 0xFFFEC600
.equ HEX_ADDR, 0xFF200020
.equ HEX_ADD, 0xFF200031
.equ SW_ADDR, 0xFF200040
.equ PUSH_ADDR, 0xff200050
.equ CONTROL, 0x0000fa07 //change here from polling I=1, A=1, E=1
load: .word 80000
PB_int_flag: .word 0x0
tim_int_flag: .word 0x0

	
_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV R1, #0b11010010      // interrupts masked, MODE = IRQ
    MSR CPSR_c, R1           // change to IRQ mode
    LDR SP, =0xFFFFFFFF - 3  // set IRQ stack to A9 on-chip memory
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV R1, #0b11010011      // interrupts masked, MODE = SVC
    MSR CPSR, R1             // change to supervisor mode
    LDR SP, =0x3FFFFFFF - 3  // set SVC stack to top of DDR3 memory
    BL  CONFIG_GIC           // configure the ARM GIC
    BL ARM_TIM_config_ATM
	BL enable_PB_INT_ASM
    // use ARM_TIM_config_ASM subroutine
    LDR R0, =0xFF200050      // pushbutton KEY base address
    MOV R1, #0xF             // set interrupt mask bits
    STR R1, [R0, #0x8]       // interrupt mask register (base + 8)
    // enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0
	
Initialize: 
	PUSH {V1-V3}
	LDR V1, =PB_int_flag
	LDR V1, [V1]
	CMP V1, #1
	POP {V1-V3}
	BNE Initialize
	
	BL HEX_config
	MOV V1, #9 //one second tracker
	MOV V2, #2 // 10 second tracker
	MOV V3, #0 // tenth second tracker
	MOV A3, #0
	
IDLE: 
	//MOV V3, #1
	CMP V1, #0
	ORR V4, V1, V2
	MOVEQ V1, #9 //reset one second tracker
	SUBEQ V2, V2, #1 //decrease 10 second counter
	
	CMP V4, #0
	MOVLE V1, #0 //base case
	LDR V5, =tim_int_flag
	LDR V6, [V5] //value stored at interrupt
	MOV V7, #0
	STR V7, [V5]
	ADD V3, V3, V6 // counts tenths of a second

	//V5 + V7 can be used
	CMP V3, #11 //check if 1 second has passed
	MOVGE V3, #1 //reinitialize
	SUBEQ V1, V1, #1 //decrement the second counter
	
	PUSH {A1, A2, A3, LR} //update hex
	CMP V2, #0
	MOVGT A1, V2 // if ten second not zero store one sec as first dig 
	MOVLE A1, V1
	MOV A2, #0
	LDR A3, =HEX_ADD
	BL time_display
	
	CMP V2, #0
	MOVGT A1, V1 //store second digit as one second if tenth is more than 0
	MOVLE A1, #10
	SUBLE A1, A1, V3 //else calculate the tenths
	ADD A2, A2, #1
	BL time_display
	POP {A1, A2, A3, LR}
	
	
  	
    PUSH {V1-V8}

push_button_mode:	
	LDR V1, =PB_int_flag
	LDR V2, [V1] //mode

	CMP V2, #2 //stop
	BEQ push_button_mode
	MOV V3, #0 // set PB int flag to 0
	STR V3, [V1] 
	CMP V2, #4
	POP {V1-V8}
	BEQ reset 
	B check_hex
	

reset:	
	//POP {V1-V8}
	B Initialize 
	
check_hex:
	PUSH {V1-V8} 
	LDR V1, =#0xFF200030
	LDRB V2, [V1] 
	LDRB V3, [V1,#1]
	
	
	CMP V2, #0b00111111
	CMPEQ V3, #0b00111111
	//POP {V1-V8}
	POPEQ {V1-V8}
	BNE continue
	PUSH {V1-V8}
	MOV V1, A3
	MOV V2, #0
	LDR V5, =#0xFF200020
	MOV V4, #0
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
	B Initialize
	

continue:
	POP {V1-V8}
	PUSH {A1-A2, V1-V8}
	LDR A1, =HEX_ADDR //hex adder address
    LDR V1, =SW_ADDR     // load the address of slider switch state
    LDR V1, [V1]
	AND V1, V1, #0x0000000F //mask all bits to isolate last 4 bits
	//here need to check if it hits it first
	
	CMP V3, #9
	POPLT {A1-A2, V1-V8}
	BLT IDLE
	
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
	
	
	
	
    B IDLE // This is where you write your main program task(s)
	

	

CONFIG_GIC:
    PUSH {LR}
    MOV R0, #73            // KEY port (Interrupt ID = 73)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT

	MOV R0, #29 			// TIN port (Interrupt ID = 29)
	MOV R1, #1
	BL CONFIG_INTERRUPT
/* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100    // base address of CPU Interface
/* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF        // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
/* Set the enable bit in the CPU Interface Control Register (ICCICR).
* This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
/* Set the enable bit in the Distributor Control Register (ICDDCR).
* This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}

CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
    LSR R4, R0, #3    // calculate reg_offset
    BIC R4, R4, #3    // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4    // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1        // enable
    LSL R2, R5, R2    // R2 = value
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
    LDR R3, [R4]      // read current register value
    ORR R3, R3, R2    // set the enable bit
    STR R3, [R4]      // store the new register value
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
    BIC R4, R0, #3    // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4    // R4 = word address of ICDIPTR
    AND R2, R0, #0x3  // N mod 4
    ADD R4, R2, R4    // R4 = byte address in ICDIPTR
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}
	
SERVICE_UND:
    B SERVICE_UND
/*--- Software interrupts ----------------------------------------*/
SERVICE_SVC:
    B SERVICE_SVC
/*--- Aborted data reads ------------------------------------------*/
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
/*--- Aborted instruction fetch -----------------------------------*/
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
/*--- IRQ ---------------------------------------------------------*/
SERVICE_IRQ:
    PUSH {R0-R7, LR}
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR

Pushbutton_check:
    CMP R5, #73
	BNE Timer_check
	BLEQ KEY_ISR
	B EXIT_IRQ
	
Timer_check:
	CMP R5, #29
	BLEQ ARM_TIM_ISR
UNEXPECTED:
    BNE UNEXPECTED      // if not recognized, stop here
EXIT_IRQ:
/* Write to the End of Interrupt Register (ICCEOIR) */
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
	SUBS PC, LR, #4
/*--- FIQ ---------------------------------------------------------*/
SERVICE_FIQ:
    B SERVICE_FIQ	


KEY_ISR:
    LDR R0, =0xFF200050    // base address of pushbutton KEY port
    LDR R1, [R0, #0xC]     // read edge capture register
    MOV R2, #0xF
    STR R2, [R0, #0xC]     // clear the interrupt
    LDR R0, =PB_int_flag    // base address of HEX display
CHECK_KEY0:
    MOV R3, #0x1
    ANDS R3, R3, R1        // check for KEY0
    BEQ CHECK_KEY1
    STR R3, [R0]           // store "0"
    B END_KEY_ISR
CHECK_KEY1:
    MOV R3, #0x2
    ANDS R3, R3, R1        // check for KEY1
    BEQ CHECK_KEY2
    STR R3, [R0]           // display "1"
    B END_KEY_ISR
CHECK_KEY2:
    MOV R3, #0x4
    ANDS R3, R3, R1        // check for KEY2
    BEQ IS_KEY3
    STR R3, [R0]           // display "2"
    B END_KEY_ISR
IS_KEY3:
    MOV R3, #0x8
    STR R3, [R0]           // display "3"
END_KEY_ISR:
    BX LR
	
ARM_TIM_ISR:
    LDR R0, =TIMER_LOAD   // base address of Timer
	MOV R1, #1
	STR R1, [R0, #12] // reset interrupt
	LDR R2, =tim_int_flag 
	STR R1, [R2] //return 1, since the IRQ is only raised when timer is done always 1
	
END_ARM_TIME_ISR:	
	BX LR




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
	
HEX_config:
	PUSH {V3-V4}
	LDR V4, =HEX_ADDR
	MOV V3, #0b00111111 //0
	STRB V3, [V4, #16]
	MOV V3, #0b01001111 //3
	STRB V3, [V4, #17]
	POP {V3-V4}

	
ARM_TIM_config_ATM:
	PUSH {A1, A2, V1}
	
	LDR R0, load //A1 load value 
	LDR R1, =CONTROL
	LDR V1, =TIMER_LOAD
	STR A1, [V1] //store the load value
	STR A2, [V1, #8] //control configuration
	
	POP {A1, A2, V1}
	BX LR
	 
enable_PB_INT_ASM:
	PUSH {V1-V3}
	LDR V1, =PUSH_ADDR
	LDR V2, [V1] //load the buttons that have been pressed
	LDR V3, [V1, #8] //load the interrupt register
	ORR V2, V2, V3 //to store in the interrupt register
	STR V2, [V1, #8]
	POP {V1-V3}

	BX LR
	
	
	
disable_PB_INT_ASM:
	PUSH {V1-V8}
	LDR V1, =PUSH_ADDR
	LDR V2, [V1, #12] // Interrupt register
	STR V2, [V1, #12]
	POP {V1-V8}
	
	BX LR