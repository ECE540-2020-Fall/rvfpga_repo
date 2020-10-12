
.globl _start
_start:

configureHW:
	call ra, uartInit

	li   x29, 0x100000

sayHello:
	la a0, welcome
	call uartSendString

    and x1, zero, zero           # Wait some time before the next iteration
    time1:
        addi x1, x1, 1
        bne  x29, x1, time1

	j sayHello



# Register addresses for Uart Peripheral 
# -----------------------------------------------------------------------------------------------------------
#define CONSOLE_ADDR 0x80001008
#define HALT_ADDR    0x80001009
#define UART_BASE    0x80002000

#define REG_BRDL (4*0x00) /* Baud rate divisor (LSB)        */
#define REG_IER (4*0x01)  /* Interrupt enable reg.          */
#define REG_FCR (4*0x02)  /* FIFO control reg.              */
#define REG_LCR (4*0x03)  /* Line control reg.              */
#define REG_LSR (4*0x05)  /* Line status reg.               */
#define LCR_CS8 0x03   /* 8 bits data size */
#define LCR_1_STB 0x00 /* 1 stop bit */
#define LCR_PDIS 0x00  /* parity disable */

#define LSR_THRE 0x20
#define FCR_FIFO 0x01    /* enable XMIT and RCVR FIFO */
#define FCR_RCVRCLR 0x02 /* clear RCVR FIFO */
#define FCR_XMITCLR 0x04 /* clear XMIT FIFO */
#define FCR_MODE0 0x00 /* set receiver in mode 0 */
#define FCR_MODE1 0x08 /* set receiver in mode 1 */
#define FCR_FIFO_8 0x80  /* 8 bytes in RCVR FIFO */




# Function: Initialize UART peripheral
# call:  by call ra, uartInit
# inputs: None
# outputs: None
# destroys: t0, t1
# -----------------------------------------------------------------------------------------------------------
uartInit:
	li	t0, UART_BASE

	/* Set DLAB bit in LCR */
	li	t1, 0x80
	sb	t1, REG_LCR(t0)

	/* Set divisor regs */
	li	t1, 27
	sb	t1, REG_BRDL(t0)

	/* 8 data bits, 1 stop bit, no parity, clear DLAB */
	li	t1, LCR_CS8 | LCR_1_STB | LCR_PDIS
	sb	t1, REG_LCR(t0)

	li	t1, FCR_FIFO | FCR_MODE0 | FCR_FIFO_8 | FCR_RCVRCLR | FCR_XMITCLR
	sb	t1, REG_FCR(t0)

	/* disable interrupts  */
	sb	zero, REG_IER(t0)

	ret 



# Function: Send byte through UART
# call:  by call ra, uartSendByte
# inputs: a0, byte to be sent
# outputs: None
# destroys: t0, t1
# -----------------------------------------------------------------------------------------------------------
uartSendByte:
	li t1, UART_BASE

	/* Check for space in UART FIFO */
	lb	t0, REG_LSR(t1)
	andi	t0, t0, LSR_THRE
	beqz	t0, uartSendByte
	sb	a0, 0(t1)
	
	ret



# Function: Send string through UART (terminated by \0)
# call:  by call ra, uartSendString
# uses: uartSendByte
# inputs: a0, address of first character of string to be sent
# outputs: None
# destroys: t0, t1, t2
# -----------------------------------------------------------------------------------------------------------
uartSendString:
	li t1, UART_BASE
	add t2,zero,ra # save caller address
	add a1,zero,a0 # use a1 as index
	/* Load first byte */
	lb a0, 0(a1)
internalNextChar:
	call ra, uartSendByte
	addi a1, a1, 1
	lb a0, 0(a1)
	bne a0, zero, internalNextChar

	add ra,zero,t2 # restore caller address
	ret



.section .data

welcome:
.string "\nHELLO WORLD !!!\n"

.end