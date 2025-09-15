.equ PMC_BASE,  0xFFFFFC00  /* (PMC) Base Address */
.equ CKGR_MOR,	0x20        /* (CKGR) Main Oscillator Register */
.equ CKGR_PLLAR,0x28        /* (CKGR) PLL A Register */
.equ PMC_MCKR,  0x30        /* (PMC) Master Clock Register */
.equ PMC_SR,	  0x68        /* (PMC) Status Register */
.equ PIOC_BASE, 0xFFFFF800 /* Zacetni naslov registrov za PIOC */
.equ PIO_PER, 0x00 /* Odmiki... */
.equ PIO_OER, 0x10
.equ PIO_SODR, 0x30
.equ PIO_CODR, 0x34
.equ DBGU_BASE, 0xFFFFF200 /* Debug Unit Base Address */
.equ DBGU_CR, 0x00  /* DBGU Control Register */
.equ DBGU_MR, 0x04   /* DBGU Mode Register*/
.equ DBGU_IER, 0x08 /* DBGU Interrupt Enable Register*/
.equ DBGU_IDR, 0x0C /* DBGU Interrupt Disable Register */
.equ DBGU_IMR, 0x10 /* DBGU Interrupt Mask Register */
.equ DBGU_SR,  0x14 /* DBGU Status Register */
.equ DBGU_RHR, 0x18 /* DBGU Receive Holding Register */
.equ DBGU_THR, 0x1C /* DBGU Transmit Holding Register */
.equ DBGU_BRGR, 0x20 /* DBGU Baud Rate Generator Register */


.text
.code 32

.global _error
_error:
  b _error

.global	_start
_start:

/* select system mode 
  CPSR[4:0]	Mode
  --------------
   10000	  User
   10001	  FIQ
   10010	  IRQ
   10011	  SVC
   10111	  Abort
   11011	  Undef
   11111	  System   
*/

  mrs r0, cpsr
  bic r0, r0, #0x1F   /* clear mode flags */  
  orr r0, r0, #0xDF   /* set supervisor mode + DISABLE IRQ, FIQ*/
  msr cpsr, r0     
  
  /* init stack */
  ldr sp,_Lstack_end
                                   
  /* setup system clocks */
  ldr r1, =PMC_BASE

  ldr r0, = 0x0F01
  str r0, [r1,#CKGR_MOR]

osc_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x01
  beq osc_lp
  
  mov r0, #0x01
  str r0, [r1,#PMC_MCKR]

  ldr r0, =0x2000bf00 | ( 124 << 16) | 12  /* 18,432 MHz * 125 / 12 */
  str r0, [r1,#CKGR_PLLAR]

pll_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x02
  beq pll_lp

  /* MCK = PCK/4 */
  ldr r0, =0x0202
  str r0, [r1,#PMC_MCKR]

mck_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x08
  beq mck_lp

  /* Enable caches */
  mrc p15, 0, r0, c1, c0, 0 
  orr r0, r0, #(0x1 <<12) 
  orr r0, r0, #(0x1 <<2)
  mcr p15, 0, r0, c1, c0, 0 

.global _main
/* main program */
_main:

/* user code here */
bl INIT_IO
bl DEBUG_INIT
     
      adr r0,Testni
      bl SNDS_DEBUG

      ldr r0, =Received

      bl RCVS_DEBUG
      ldr r0, =Received 
      bl SNDS_DEBUG
      bl XWORD
    

     

/* end user code */

_wait_for_ever:
  b _wait_for_ever

DEBUG_INIT:
      stmfd r13!, {r0, r1, r14}
      ldr r0, =DBGU_BASE
@      mov r1, #26        @  BR=115200
      mov r1, #156        @  BR=19200
      str r1, [r0, #DBGU_BRGR]
      mov r1, #(1 << 11)
      str r1, [r0, #DBGU_MR]
      mov r1, #0b1010000
      str r1, [r0, #DBGU_CR]
      ldmfd r13!, {r0, r1, pc}

RCV_DEBUG:
      stmfd r13!, {r1, r14}
      ldr r1, =DBGU_BASE
RCVD_LP:
      ldr r0, [r1, #DBGU_SR]
      tst r0, #1
      beq RCVD_LP
      ldr r0, [r1, #DBGU_RHR]
      ldmfd r13!, {r1, pc}

SND_DEBUG:
      stmfd r13!, {r1, r2, r14}
      ldr r1, =DBGU_BASE
SNDD_LP:
      ldr r2, [r1, #DBGU_SR]
      tst r2, #(1 << 1)
      beq SNDD_LP
      str r0, [r1, #DBGU_THR]
      ldmfd r13!, {r1, r2, pc}

RCVS_DEBUG:
      stmfd r13!, {r1, r2, r14}
      mov r2, r0
RCVSD_LP:
      bl RCV_DEBUG
      strb r0, [r2], #1
      cmp r0, #13
      beq end
      bne RCVSD_LP
end:      mov r0, #0
      strb r0, [r2]
      ldmfd r13!, {r1, r2, pc}

SNDS_DEBUG:
      stmfd r13!, {r2, r14}
      mov r2, r0
SNDSD_LP:
      ldrb r0, [r2], #1
      cmp r0, #0
      beq SNDD_END
      bl SND_DEBUG
      b SNDSD_LP
SNDD_END:
      ldmfd r13!, {r2, pc}  

XWORD:
   stmfd r13!, {r1, r14}
   ldr r9, =Received
   mov r10, #0

zanka:   
   ldrb r1, [r9, r10]
   cmp r1, #13
   beq ending
   cmp r1, #32
   add r10, r10, #1
   beq delayer
nazaj:   beq zanka
   bl GETMCODE
   bl XMCODE
   b zanka

delayer:
   ldr r0,=1000
   bl DELAY
   b nazaj

ending:  
   ldmfd r13!, {r8, pc}
   
     
GETMCODE:
  stmfd r13!, {r1, r14}
  adr r4, ZNAKI
  sub r7, r1, #65
  
  mov r8, #6
  mul r3, r7, r8
  sub r7, r7, r7
  
other:
  ldrb r1, [r4, r3]
  add r3, r3, #1
  cmp r1, #0
  beq next
  adr r6, prom
  strb r1, [r6, r7]
  cmp r1, #0
  add r7, r7, #1
  bne other

next:
  mov r1, #0
  strb r1, [r6, r7]
  ldmfd r13!, {r1, pc}
  
  
  
    
XMCODE:
  stmfd r13!, {r1, r14}
  mov r3, #0
  adr r5, prom
  ldrb r1, [r5, r3]
  cmp r1, #0
  bne loop
  
loop: bl XMCHAR
  add r3, r3, #1
  ldrb r1, [r5, r3]
  cmp r1, #0
  bne loop
  ldr r0,=300
  bl DELAY
  ldmfd r13!, {r1, pc}  

XMCHAR:
  stmfd r13!, {r1, r14}
  cmp r1, #46
  beq dot
  
line: bl LED_ON
  ldr r0,=300
  bl DELAY
  bl LED_OFF
  ldr r0,=150
  bl DELAY
  ldmfd r13!, {r1, pc}
  
dot:  bl LED_ON
  ldr r0,=150
  bl DELAY
  bl LED_OFF
  ldr r0,=150
  bl DELAY
  ldmfd r13!, {r1, pc}
  
  
INIT_IO:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_PER]
  str r0, [r2, #PIO_OER]
  ldmfd r13!, {r0, r2, pc}

LED_ON:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_CODR]
  ldmfd r13!, {r0, r2, pc}

LED_OFF:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_SODR]
  ldmfd r13!, {r0, r2, pc}

DELAY:
  stmfd r13!, {r1, r14}

MSEC: ldr r1,=48000
ZAN: subs r1,r1,#1
      bne ZAN
     
      subs r0,r0,#1
      bne MSEC
     
  ldmfd r13!, {r1, pc}

/* constants */

.align

ZNAKI:    .ascii ".-" @ A 
.byte 0,0,0,0 

.ascii "-..."     @ B
.byte 0,0

.ascii "-·-·" @ C 
.byte 0,0 

.ascii "-.." @ D 
.byte 0,0,0 

.ascii "." @ E 
.byte 0,0,0,0,0 

.ascii "..-." @ F 
.byte 0,0 

.ascii "--." @ G 
.byte 0,0,0 

.ascii "...." @ H 
.byte 0,0 

.ascii ".." @ I 
.byte 0,0,0,0 

.ascii ".---" @ J 
.byte 0,0 

.ascii "-.-" @ K 
.byte 0,0,0 

.ascii ".-.." @ L 
.byte 0,0 

.ascii "--" @ M 
.byte 0,0,0,0 

.ascii "-." @ N 
.byte 0,0,0,0 

.ascii "---" @ O 
.byte 0,0,0 

.ascii ".--." @ P 
.byte 0,0 

.ascii "--.-" @ Q 
.byte 0,0 

.ascii ".-." @ R 
.byte 0,0,0 

.ascii "..." @ S 
.byte 0,0,0 

.ascii "-" @ T 
.byte 0,0,0,0,0 

.ascii "..-" @ U 
.byte 0,0,0 

.ascii "...-" @ V 
.byte 0,0 

.ascii ".--" @ W 
.byte 0,0,0 

.ascii "-..-" @ X 
.byte 0,0 

.ascii "-.--" @ Y 
.byte 0,0 

.ascii "--.." @ Z 
.byte 0,0

prom: .space 100


Testni:  .asciz "Write a word to get the morse code from the LED: \n"
Received: .asciz "                                                                  "

          .align


_Lstack_end:
  .long __STACK_END__

.end

