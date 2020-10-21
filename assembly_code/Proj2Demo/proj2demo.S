/*
 *  main.S for microAptiv_UP MIPS core running on RVfpga
 *  FPGA target board
 *
 *  Copyright Srivatsa Yogendra, 2017
 *
 *  Created By:     Srivatsa Yogendra
 *  Ported By :     Thong Doan
 *  Last Modified:  03-Oct-2020 (SY)
 *
 *  Description:
 *  ============
 *  This program demonstrate the Rojobot world emulator.  It is modelled after
 *  the the simplebot implemented in the project 1 of the course. 
 * 
 *  The demo uses the 4 pushbuttons to control the Rojobot as follows:
 *  btn_left    - Left Motor forward
 *  btn_up      - Left Motor reverse
 *  btn_right   - Right Motor forward
 *  btn_down    - Right Motor reverse
 *  If neither of the two buttons that control each motor is pushed, then the motor is stopped. 
 *  If both of the two buttons that control each motor are pushed, the actions cancel each other
 *  leaving the motor stopped.
 * 
 *  The demo takes advantage of the wider display on the Nexys4 (8 digits vs. 4) to
 *  make the rojobot state easier for follow. The digits are mapped as follows:
 *  digit[7:5] - compass heading
 *  digit[4] - movement (Fwd, Rev, Stopped, turning)
 *  digits[2:1] - column position (X) in hex
 *  digits[1:0] - row position (Y) in hex
 * 
 *  Decimal points 5 and 4 are turned on to highlight the movement display.  Decimal point 0 toggles
 *  on and off every time the Rojobot updates its state
 * 
 *  The sensors are displayed on the LEDs.
 *
 *  The Bot Info port (PORT_BOTINFO) is a 32 bit port, which is supposed to pass the sensor, bot_info, LOCx_REG
 *  and LOCy_REG in the concatinated form as shown  BotInfo_IO = {LocX_reg,LocY_reg,Sensors_reg,BotInfo_reg}
 *  and should be driven in the same order.
 *  
 *  Also an acknowledgement bit has to be set and cleared for updating the handshaking flipflop
 * which synchronises between the 75Mhz Rojobot clock domain and the 50Mhz MIPSfpga clock domain.
 * 
 *  NOTE:  NOT ALL THE CODE IN THIS EXAMPLE IS USED.  THE EXAMPLE WAS CREATED TO GIVE YOU, THE
 *  STUDENT, AN EXAMPLE OF HOW TO CONTROL THE ROJOBOT AND NEXYS4 PERIPHERALS FROM AN EMBEDDED MIPS
 *  CPU. YOU MAY (OR NOT) FIND SOME OF THIS CODE APPLICABLE TO YOUR OTHER PROJECTS
 *
 *  Thong Notes:
 *  ============
 *  Followings are the (pseudo/macro) instructions I found, though work on MIPS, not work on RVfpga
 *      sb reg, VARIABLE
 *      sw reg, VARIABLE
 *  Registers v0, v1 does not exist in RISC-V
 *      
 */

# Masks for Pushbuttons
BTN_R_MASK              = 0x2
BTN_C_MASK              = 0x10
BTN_L_MASK              = 0x8
BTN_D_MASK              = 0x1
BTN_U_MASK              = 0x4
PUSHBUTTON_MASK         = 0x1F

# Values to display specific segments on the display
DISPLAY_SEGMENT_A       = 16
DISPLAY_SEGMENT_B       = 17
DISPLAY_SEGMENT_C       = 18
DISPLAY_SEGMENT_D       = 19
DISPLAY_SEGMENT_E       = 20
DISPLAY_SEGMENT_F       = 21
DISPLAY_SEGMENT_G       = 22
DISPLAY_SEGMENT_BLANK   = 28

# Button Masks to get specific commands
FORWARD                 = BTN_L_MASK | BTN_R_MASK
REVERSE                 = BTN_D_MASK | BTN_U_MASK
RIGHT_2X                = BTN_L_MASK | BTN_D_MASK
RIGHT_1X_L              = BTN_L_MASK
RIGHT_1X_R              = BTN_D_MASK
LEFT_2X                 = BTN_U_MASK | BTN_R_MASK
LEFT_1X_L               = BTN_U_MASK
LEFT_1X_R               = BTN_R_MASK
STOP                    = 0x00

# ======================
# === Port Addresses ===
# ======================

# Nexys 4 board base I/O interface ports compatible with the Nexyx4 I/O interface
# Port Addresses
PORT_LEDS           = 0x80001404        # (o) LEDs
PORT_SLSWTCH        = 0x80001400        # (i) slide switches
PORT_PBTNS          = 0x80001600        # (i) pushbuttons inputs
PORT_GPIO_EN        = 0x80001408        # (o) enable LEDs for output

# ========================================================================
# Change the following port address, as implemented by you in the hardware
# ========================================================================


PORT_SEVENSEG_EN    = 0x80001038        # (o) 7 Segment enable
PORT_SEVENSEG_HGH   = 0x8000101c        # (o) 7 Segment Higher Display
PORT_SEVENSEG_LOW   = 0x8000103c        # (o) 7 Segment Lower Display
PORT_SEVENSEG_DP    = 0x80001018        # (o) 7 segment Decimal Point Display

PORT_BOTINFO        = 0x8000180c        # (i) Bot Info port
PORT_BOTCTRL        = 0x80001810        # (o) Bot Control port
PORT_BOTUPDT        = 0x80001814        # (i) Bot Update port (Poll)
PORT_INTACK         = 0x80001818        # (o) Bot Int Ack

# =====================================
# === Register bit mappings (masks) ===
# =====================================

#  bit masks for pushbuttons and switches for seven segment emulator
MSK_ALLBTNS     = 0x1F      # Buttons are in bits[5:0]
MSK_PBTNS       = 0x0F      # Mask for 4 buttons to display on LED
MSK_BTN_CENTER  = 0x10      # Pushbutton Center is bit 4
MSK_BTN_LEFT    = 0x08      # Pushbutton Left is bit 3
MSK_BTN_UP      = 0x04      # Pushbutton Up is bit 2
MSK_BTN_RIGHT   = 0x02      # Pushbutton Right is bit 25
MSK_BTN_DOWN    = 0x01      # Pushbutton Down is bit 0

MSK_SW7         = 0x80      # Slide switch 7 is bit 7
MSK_SW6         = 0x40      # Slide switch 6 is bit 6
MSK_SW5         = 0x20      # Slide switch 5 is bit 5
MSK_SW4         = 0x10      # Slide switch 4 is bit 4
MSK_SW3         = 0x08      # Slide switch 3 is bit 3
MSK_SW2         = 0x04      # Slide switch 2 is bit 2
MSK_SW1         = 0x02      # Slide switch 1 is bit 1
MSK_SW0         = 0x01      # Slide switch 0 is bit 0

MSK_SW15        = 0x80      # Slide switch 15 is bit 7
MSK_SW14        = 0x40      # Slide switch 14 is bit 6
MSK_SW13        = 0x20      # Slide switch 13 is bit 5
MSK_SW12        = 0x10      # Slide switch 12 is bit 4
MSK_SW11        = 0x08      # Slide switch 11 is bit 3
MSK_SW10        = 0x04      # Slide switch 10 is bit 2
MSK_SW09        = 0x02      # Slide switch 09 is bit 25
MSK_SW08        = 0x01      # Slide switch 08 is bit 0


# bit mask for LEDs
MSK_LEDS_LO = 0xFF      # Mask for rightmost 8 LEDs on the Nexy4
MSK_LEDS_HI = 0xFF      # Mask for the lefmost 8 LEDs on the Nexy4


# bit mask for display character codes and decimal points
MSK_CCODE       = 0x1F      # Character codes are in lower 5 bits
MSK_DECPTS      = 0x0F      # Decimal points 3 - 0 are in bits 3 to 0
MSK_DECPTS_HI   = 0xF0      # Decimal points 7-4 are in bits 3 to 0
MSK_HEXDIGIT    = 0x0F      # Hex digits only take 4 bits


# nibble masks
MSKLOWNIB   = 0x0F      # Mask out high nibble of byte
MSKHIGHNIB  = 0xF0      # Mask out low nibble of byte
INVLOWNIB   = 0x0F      # Invert low nibble of byte

# sensor info masks
MSKPROXL    = 0x10      # Mask out Proximity L sensor
MSKPROXR    = 0x08      # Mask out Proximity R sensor
MSKBLKL     = 0x07      # Mask out Black line sensor
MSKPROX     = 0x18      # Mask out all but proximity sensor bits
MSKMVMT_B   = 0x80      # Mask out all but Back movement bits
MSKMVMT_F   = 0x40      # Mask out all but Forward movement bits
MSKMVMT_R   = 0xE0      # Mask out all but Right movement bits
MSKMVMT_H   = 0x00      # Mask out all but Hold movement bits
MSKMVMT_L   = 0xC0      # Mask out all but Left movement bits

# Bot Information Masks
MSKLOCx     = 0xFF000000
MSKLOCy     = 0x00FF0000
MSKSENSOR   = 0x0000FF00
MSKBOTINFO  = 0x000000FF

# Bot Update Masks
MSKBOTUPDT  = 0x01


# =============================
# === Useful Data Constants ===
# =============================

#  Constants for True, False, Null and INT_ACK
FALSE   = 0x00
TRUE    = 0x01
NULL    = 0x00
INT_ACK = 0x01

# Character code table for special characters
# Decimal digits 0 to 15 display '0'to 'F'
CC_BASE     = 0x10      # Base value for special characters
CC_SEGBASE  = 0x10      # Base value for segment display special characters
                        #                abcdefg
CC_SEGA     = 0x10      # Segment A     [1000000]
CC_SEGB     = 0x11      # Segment B     [0100000]
CC_SEGC     = 0x12      # Segment C     [0010000]
CC_SEGD     = 0x13      # Segment D     [0001000]
CC_SEGE     = 0x14      # Segment E     [0000100]
CC_SEGF     = 0x15      # Segment F     [0000010]
CC_SEGG     = 0x16      # Segment G     [0000001]
CC_UCH      = 0x17      # Upper Case H
CC_UCL      = 0x18      # Upper Case L
CC_UCR      = 0x19      # Upper Case R
CC_LCL      = 0x1A      # Lower Case L
CC_LCR      = 0x1B      # Lower Case R
CC_SPACE    = 0x1C      # Space (blank)


# ======================
# === BotInfo values ===
# ======================
OR_N        = 0x00      # Orientation is North
OR_NE       = 0x01      # Orientation is Northeast
OR_E        = 0x02      # Orientation is East
OR_SE       = 0x03      # Orientation is Southeast
OR_S        = 0x04      # Orientation is South
OR_SW       = 0x05      # Orientation is Southwest
OR_W        = 0x06      # Orientation is West
OR_NW       = 0x07      # Orientation is Northwest

MV_STOP     = 0x00      # Movement is stopped
MV_FWD      = 0x04      # Movement is forward
MV_REV      = 0x08      # Movement is reverse
MV_SLT      = 0x0C      # Movement is slow left turn
MV_FLT      = 0x0D      # Movement is fast left turn
MV_SRT      = 0x0E      # Movement is slow right turn
MV_FRT      = 0x0F      # Movement is fast right turn
                        # Next 2 contants assume field is in low nibble
MSKMVMT     = 0x0F      # Mask out all but movement bits
MSKORIENT   = 0x07      # Mask out all but orientation bits
MSKBLKL     = 0x07      # Mask out all but line sensor bits
MSKMVMT_B   = 0x80      # Mask out all but Back movement bits
MSKMVMT_F   = 0x40      # Mask out all but Forward movement bits
MSKMVMT_R   = 0xE0      # Mask out all but right movement bits
MSKMVMT_H   = 0x00      # Mask out all but hold movement bits



# =================================
# === Scratch Pad RAM Variables ===
# =================================

# Pushbutton translation lookup table.  Converts pushbutton combos
# to Motor Control input register format [lmspd[2:0],lmdir,rmspd[2:0],rmdir]
SP_BTNBASE  = 0x00      # table is based at 0x00
                        #                               [b3,b2,b1,b0]=[lf,lr,rf,rr]
SP_LSRS     = 0x00      # left motor off, right motor off               [0000]
SP_LORR     = 0x02      # left motor off, right motor reverse           [0001]
SP_LSRF     = 0x03      # left motor off, right motor forward           [0010]
SP_LSRFR    = 0x00      # left motor off, right motor fwd & rev = off   [0011]
SP_LRRS     = 0x20      # left motor reverse, right motor off           [0100]
SP_LRRR     = 0x22      # left motor reverse, right motor reverse       [0101]
SP_LRRF     = 0x23      # left motor reverse, right motor forward       [0110]
SP_LRRFR    = 0x20      # left motor rev, right motor fwd & rev = off   [0111]
SP_LFRS     = 0x30      # left motor forward, right motor off           [1000]
SP_LFRR     = 0x32      # left motor forward, right motor reverse       [1001]
SP_LFRF     = 0x33      # left motor forward, right motor forward       [1010]
SP_LFRFR    = 0x30      # left motor fwd, right motor fwd & rev = off   [1011]
SP_LFRRS    = 0x00      # left motor fwd & rev = off, right motor off   [1100]
SP_LFRRR    = 0x02      # left motor fwd & rev = off, right motor rev   [1101]
SP_LFRRF    = 0x03      # left motor fwd & rev = off, right motor fwd   [1110]
SP_LFRRFR   = 0x00      # left  and right motor fwd & rev = off         [1111]


# Movement display lookup table.  Converts movement from BotInfo register to
# the character code to display.  Not very dense but we have the room in the SP RAM and
# it saves building a switch statement into the code.
SP_MVMTBASE = 0x10      # table is based at 0x10

SP_MVMT0    = 0x17      # Stopped - display upper case H
SP_MVMT1    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT2    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT3    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT4    = 0x0F      # Forward - display upper case F
SP_MVMT5    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT6    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT7    = 0x1C      # Reserved - display dot to indicate error
SP_MVMT8    = 0x0B      # Reverse (Backward) - display lower case B
SP_MVMT9    = 0x1C      # Reserved - display dot to indicate error
SP_MVMTA    = 0x1C      # Reserved - display dot to indicate error
SP_MVMTB    = 0x1C      # Reserved - display dot to indicate error
SP_MVMTC    = 0x18      # Slow left turn - display upper case L
SP_MVMTD    = 0x1A      # Fast left turn - display lower case L
SP_MVMTE    = 0x19      # Slow right turn - display upper case R
SP_MVMTF    = 0x1B      # Fast right turn - display lower case R


.globl _start
_start:

                // enable LEDs & SWs
                li  t0, PORT_GPIO_EN
                li  t1, 0x0000FFFF
                sw  t1, 0(t0)

                lui   x12, 0xbf80               # x12 = address of LEDs (0xbf800000)
                li  t3,     FALSE               # clear the semaphore
                jal LED_wrleds                  #
                nop
                # sb  t3,     SP_SEM              #
                la t2, SP_SEM
                sb t3, 0(t2)
                li  t3,     0xCB                # turn off decimal points 3-0.  Decimal point 0 (rightmost
                # sb  t3,     SP_OLDDP            # and save the value
                la t2, SP_OLDDP
                sb t3, 0(t2)
                jal init_btnluptbl              # initialize button to MotCtl lookup table
                nop
                jal init_mvmttbl                # initialize movement to character code lookup table
                nop
                jal SS_wrdpts                   # will be toggled in the interrupt handler
                nop
                li  t3, FALSE
                # sb t3, SP_RGTC0NT
                la t2, SP_RGTC0NT
                sb t3, 0(t2)


                # sw  t0, (SP_NSA_STATE)
                la t2, SP_NSA_STATE
                sw t0, 0(t2)

# ==================
# === Main  Loop ===
# ==================

main_L0:
                # determine robot mode by read switch [15]: OFF=MANUAL, ON=AUTO
                # lw      t0, (PORT_SLSWTCH)
                la t2, PORT_SLSWTCH
                lw t0, 0(t2)
                srl     t0, t0, 16              # shift right 16 bits, due to arrangement in RVfpga
                # and     t0, t0, 0x8000        # mask out all switches except [15]
                li t2, 0x8000
                and t0, t0, t2
                srl     t0, t0, 15            # move [15] to position 0
                # sb      t0, (SP_ROBOT_MODE)
                la t2, SP_ROBOT_MODE
                sb t0, 0(t2)
/*
                # polling for the robot interrupt
                li    x13, PORT_BOTUPDT         #   while(25) {  // main loop is an infinite loop
                lw    x21, 0(x13)               #   while (upd_sysreg == 0)  {}   // loop until isr updates rojobot registers
                beq   x21, zero, main_L0
                nop
*/
                li    x13, PORT_INTACK          #   Load the Acknowledgement port address
                li    x21, INT_ACK              #   Set the Acknowledgement bit
                sw    x21, 0(x13)               #   Write the Acknowledgement bit

main_L1:
                li    x13, PORT_BOTINFO         #   Load the BotInfo port address
                lw    x21, 0(x13)               #   Read the BotInfo Register

                and   x22, x21, MSKBOTINFO      #   Mask out the unwanted bits
                # sb    x22, BOTINF_REG           #   Update the BotInfo memory location
                la t2, BOTINF_REG
                sb x22, 0(t2)

                srl   x21, x21, 8               #   Move the original data to extract the Sensor info
                and   x22, x21, MSKBOTINFO      #   Mask out the unwanted bits
                # sb    x22, SENSOR_REG           #   Store the sensor information in the Sensor register memory location
                la t2, SENSOR_REG
                sb x22, 0(t2)

                srl   x21, x21, 8               #   Do the same for LOCy_REG
                and   x22, x21, MSKBOTINFO
                # sb    x22, LOCy_REG
                la t2, LOCy_REG
                sb x22, 0(t2)

                srl   x21, x21, 8               #   Do the same for LOCx_REG
                and   x22, x21, MSKBOTINFO
                # sb    x22, LOCx_REG
                la t2, LOCx_REG
                sb x22, 0(t2)

                jal next_loc                    #   Dig[3:2] = nex LocX# Dig[25:0] = next LocY
                nop
                jal next_mvmt                   #   Dig[4] = next movement
                nop
                jal next_hdg                    #   Dig[7:4] = next heading
                nop
                                                #   }
main_L2:        jal wr_alldigits                #   write all of the digits to the display
                nop
                lb  t3, SENSOR_REG              #   update LEDs with new sensor information
                jal LED_wrleds                  #
                nop

                li    x13, PORT_INTACK          #   Clear the Acknowledgement bit
                li    x21, FALSE
                sw    x21, 0(x13)

                beq   zero, zero,   next_step       #   tell rojobot what to do next
                nop
ret_next_step:

                beq zero,zero,  main_L0             #   } // end - main while loop
                nop




#**************************************************************************************
# Support functions
#**************************************************************************************

# ===============================================================================
# === wr_alldigits() - Writes all 8 display digits from the global locations  ===
# === Registers used x25,t3                                                   ===
# --- Scratchpad RAM locations used SP_DIG4, SP_DIG5, SP_DIG6, SP_DIG7        ===
# ===============================================================================

wr_alldigits:
                lw  x25, (SP_DIG0)              # Load the lower 7 segment displays
                li  t3, PORT_SEVENSEG_LOW
                sw  x25, 0(t3)                  # Write to the lower 7 segment displays
                lw  x25, (SP_DIG4)              # Load the higher 7 segment displays
                li  t3, PORT_SEVENSEG_HGH
                sw  x25, 0(t3)                  # Write to the higher 7 segment displays
                li  x25, 0x00                   # Enable all the display segments
                li  t3, PORT_SEVENSEG_EN
                sw  x25, 0(t3)
                jr  ra
                nop

#*******
# Functions to convert pushbutton presses to Motor Control input
#*******

# ===============================================================================
# === init_btnluptbl() - initialize button translation lookup table in SP RAM ===
# === Registers affected: x25, t3                                             ===
# ===============================================================================
init_btnluptbl: la  t3,     (SP_BTNBAS1)        # t3 gets base of button translation lookup table
                li  t0,     SP_LSRS             # t0 gets values for 0x00
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LORR             # t0 gets values for 0x01
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LSRF             # t0 gets values for 0x02
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LSRFR            # t0 gets values for 0x03
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LRRS             # t0 gets values for 0x04
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LRRR             # t0 gets values for 0x05
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LRRF             # t0 gets values for 0x06
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LRRFR            # t0 gets values for 0x07
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRS             # t0 gets values for 0x08
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRR             # t0 gets values for 0x09
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRF             # t0 gets values for 0x0A
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRFR            # t0 gets values for 0x0B
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRRS            # t0 gets values for 0x0C
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRRR            # t0 gets values for 0x0D
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRRF            # t0 gets values for 0x0E
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_LFRRFR           # t0 gets values for 0x0F
                sb  t0,     0(t3)               # store the entry in the table
                jr  ra                         # done...at last
                nop


# =============================================================================
# === btn2mot() - Button to MotCtl conversion function                      ===
# === Registers affected: t3, t0                                            ===
# === x25 contains the button value to convert.                             ===
# === Result (Motor Control register value) is returned in t3               ===
# === x25 (Button value) is not changed                                     ===
# =============================================================================
btn2mot:        la  t0,     (SP_BTNBAS1)        # t0 gets base of button conversion table
                add t3,     a0, 0               # mask out upper nibble of buttons
                AND t3, t3, MSKLOWNIB           #
                add t0, t0, t3                  # t0 = Base + offset into table
                lb  t3,     0(t0)               # and fetch the entry
                jr  ra
                nop


# ===============================================================================
# === init_mvmttbl() - initialize movement translation lookup table in SP RAM ===
# === Registers affected: x25, t3                                              ===
# ===============================================================================
init_mvmttbl:   la  t3,     (SP_MVTBAS1)        # t3 gets base of movement translation lookup table
                li  t0,     SP_MVMT0            # t0 gets values for 0x00
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT1            # t0 gets values for 0x01
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT2            # t0 gets values for 0x02
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT3            # t0 gets values for 0x03
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT4            # t0 gets values for 0x04
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT5            # t0 gets values for 0x05
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT6            # t0 gets values for 0x06
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT7            # t0 gets values for 0x07
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT8            # t0 gets values for 0x08
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMT9            # t0 gets values for 0x09
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTA            # t0 gets values for 0x0A
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTB            # t0 gets values for 0x0B
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTC            # t0 gets values for 0x0C
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTD            # t0 gets values for 0x0D
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTE            # t0 gets values for 0x0E
                sb  t0,     0(t3)               # store the entry in the table
                add t3, t3, 1                   # increment the table index
                li  t0,     SP_MVMTF            # t0 gets values for 0x0F
                sb  t0,     0(t3)               # store the entry in the table
                jr  ra                         # done...at last
                nop


# =============================================================================
# === mvmt2cc() - movement to character code conversion function            ===
# === Registers affected: t3, t0                                            ===
# === x25 contains the movment value to convert.                            ===
# === Result (character code to display) is returned in t3                  ===
# === x25 (movement) is not changed                                         ===
# =============================================================================
mvmt2cc:        la  t0,     (SP_MVTBAS1)        # t0 gets base of movment conversion table
                add t3,     x25, 0              # mask out upper nibble of movment
                AND t3, t3, MSKLOWNIB           #
                ADD t0, t0, t3                  # t0 = Base + offset into table
                lb  t3,     0(t0)               # and fetch the entry
                beq zero, zero, back_mvmt2cc
                nop


##########################################
# Modify this function for Project 2 #####
##########################################

# ========================================================================
# === next_mvmt() - Calculate  digit for motion indicator              ===
# === Registers affected: x12, x25                                     ===
# === Uses BOTINF_REG (Bot Info register) to get movement.             ===
# ========================================================================
next_mvmt:      lb  x25,    (BOTINF_REG)        # x25[3:0] = BOTINF_REG[7:4]
                # sb  x25,    SP_OLDMVMT
                la t2, SP_OLDMVMT
                sb x25, 0(t2)
                srl     x25, x25, 4             #
                beq zero, zero, mvmt2cc             # translate movement to char code
                nop
back_mvmt2cc:
                # sb  t3,     SP_DIG4             # and move to digit 4.
                la t2, SP_DIG4
                sb t3, 0(t2)
                jr  ra                         # digit 4 is in the scratchpad RAM
                nop

# ==============================================================================
# === next_hdg() - Calculate  digits for heading (compass setting)           ===
# === Registers affected: x11, x14, x13, x25, t3, x5, x6, x7          ===
# === Uses BOTINF_REG (Bot Info register) to get orientation.  Calculates    ===
# === digits with a case statement based on orientation.                     ===
# ==============================================================================
next_hdg:       lb  x25,    (BOTINF_REG)        # x25[2:0] = BOTINF_REG[2:0] = orientation
                and x25,    x25,    MSKORIENT   #
                # sb  x25,    SP_OLDHDG
                la t3, SP_OLDHDG
                sb x25, 0(t3)
                                                # switch(orientation)  {
nh_caseORN:     
                # bne x25,    OR_N, nh_caseORNE   #   case(OR_N):
                la t3, OR_N
                bne x25, t3, nh_caseORNE
                nop                             #
                li  x5,     00                  #       Dig[2:0] = 000
                li  x6,     00                  #
                li  x7,     00                  #
                beq zero,zero,  nh_endcase          #       break
                nop
                                                #
nh_caseORNE:    
                # bne x25,    OR_NE, nh_caseORE   #   case (OR_NE):
                la t3, OR_NE
                bne x25, t3, nh_caseORE
                nop                             #
                li  x5,     00                  #       Dig[2:0] = 045
                li  x6,     04                  #
                li  x7,     05                  #
                beq zero,zero,  nh_endcase          #       break
                nop

nh_caseORE:     
                # bne x25,    OR_E, nh_caseORSE   #   case (OR_E):
                la t3, OR_E
                bne x25, t3, nh_caseORSE
                nop                             #
                li  x5,     0x00                #       Dig[2:0] = 090
                li  x6,     0x09                #
                li  x7,     0x00                #
                beq zero,zero,  nh_endcase          #       break
                nop

nh_caseORSE:    
                # bne x25,    OR_SE, nh_caseORS   #   case (OR_SE):
                la t3, OR_SE
                bne x25, t3, nh_caseORS
                nop                             #
                li  x5,     0x01                #       Dig[2:0] = 135
                li  x6,     0x03                #
                li  x7,     0x05                #
                beq zero,zero,  nh_endcase          #       break
                nop

nh_caseORS:     
                # bne x25,    OR_S, nh_caseORSW   #   case (OR_S):
                la t3, OR_S
                bne x25, t3, nh_caseORSW
                nop                             #
                li  x5,     0x01                #       Dig[2:0] = 180
                li  x6,     0x08                #
                li  x7,     00                  #
                beq zero,zero,  nh_endcase          #       break
                nop

nh_caseORSW:    
                # bne x25,    OR_SW, nh_caseORW   #   case (OR_SW):
                la t3, OR_SW
                bne x25, t3, nh_caseORW
                nop                             #
                li  x5,     02                  #       Dig[2:0] = 225
                li  x6,     02                  #
                li  x7,     05                  #
                beq zero,zero,  nh_endcase          #       break
                nop

nh_caseORW:     
                # bne x25,    OR_W, nh_caseORNW   #   case (OR_W):
                la t3, OR_W
                bne x25, t3, nh_caseORNW
                nop                             #
                li  x5,     02                  #       Dig[2:0] = 270
                li  x6,     07                  #
                li  x7,     00                  #
                beq zero,zero,  nh_endcase          #       break
                nop

                                                #   case (OR_NW):  // only remaining case
nh_caseORNW:    li  x5,     03                  #       Dig[2:0] = 315
                li  x6,     01                  #
                li  x7,     05                  #
                                                # } // end of switch statement
nh_endcase:     
                # sb  x5,     SP_DIG7             # update the heading display digits
                la t3, SP_DIG7
                sb x5, 0(t3)
                # sb  x6,     SP_DIG6             # these are stored in the Scratchpad RAM
                la t3, SP_DIG6
                sb x6, 0(t3)
                # sb  x7,     SP_DIG5             #
                la t3, SP_DIG5
                sb x7, 0(t3)
                jr  ra
                nop


# ==============================================================================
# === next_loc() - Calculate digits for Rojobot location                     ===
# === Registers affected: x12, x11, x14, x13, x25                            ===
# === Uses LocX and LocY to get location.                                    ===
# ==============================================================================
next_loc:       lb      x25,    (LOCx_REG)              # Dig[3:2] gets X-coordinate
                add     x11,    x25, 0                  # Digit 2 gets lower nibble
                and     x11,    x11,   MSK_HEXDIGIT     #
                srl     x25,    x25, 4                  #
                add     x12,    x25, 0                  #

                lb      x25,    (LOCy_REG)              # Dig[1:0] gets Y-coordinate
                add     x13,    x25, 0                  # Digit 0 gets lower nibble
                and     x13,    x13,   MSK_HEXDIGIT     #
                srl     x25,    x25, 4                  #
                add     x14,    x25, 0                  #
                # sb      x11,    SP_DIG2
                la t2, SP_DIG2
                sb x11, 0(t2)
                # sb      x12,    SP_DIG3
                la t2, SP_DIG3
                sb x12, 0(t2)
                # sb      x13,    SP_DIG0
                la t2, SP_DIG0
                sb x13, 0(t2)
                # sb      x14,    SP_DIG1
                la t2, SP_DIG1
                sb x14, 0(t2)
                jr  ra
                nop


##########################################
# Modify this function for Project 2 #####
##########################################

# ==============================================================================
# === next_step() - Tells rojobot what to do next                            ===
# === Registers affected: x25, t3                                            ===
# === This version reads the pushbuttons, calculates the new Motor Control   ===
# === register value and then writes MotCtl so Rojobot knows what to do      ===
# ==============================================================================
next_step:

                # determine MANUAL or AUTO mode
                lb      t0, (SP_ROBOT_MODE)
                beq     t0, zero, next_step_manual
############################################################################################################## 
next_step_auto: ### It is just given for your reference.
##
##
##       You need to add your code over here to make the icon move automatically. That is to make icon
##		 follow black line when you  turn on the SW[15].	
##
##
##                
#########################################################################################################

next_step_manual:
                lb      x25,(SENSOR_REG)
                lb      t3, (SENSOR_REG)
                lb      t0, (SENSOR_REG)
                AND     x25,    x25,MSKPROXL
                AND     t3, t3,MSKPROXR
                AND     t0, t0,MSKBLKL

                jal     DEB_rdbtns                  # Read the pushbuttons. buttons returned in a0
                nop
                jal     btn2mot                     # and calculate new MotCtl - returned in t3
                nop
                li      x25,    PORT_BOTCTRL
                sw      t3,     0(x25)              # tell Rojobot what to do
                beq     zero, zero, ret_next_step
                nop

#*************************
# Nexyx5 I/O Functions
#*************************

#---------------------
# check_off_black_line() - Check if the robot is off black line
#
# Return: a0 = 1 (off black line) / 0 (on black line)
#
# Registers affected: a0
#---------------------
check_off_black_line:
                # lb      v0, (SENSOR_REG)           # read sensor contents
                la t2, SENSOR_REG
                lb a0, 0(t2)
                # and     v0, v0, 0x1                 # mask out all bits except [0]
                and a0, a0, 0x1
                jr      ra
                nop

#---------------------
# reorder_btns() - Rearrange read bits of the push buttons
#
# Original order is stored in x25
# Reorder from xxxU-DLCR --> xxxC-LURD
#
# Registers affected: x25, x21, a1
#---------------------
reorder_btns:
                add     x25, zero, zero             # init x25 to zero

                # set D to bit[0]
                srl     x21, a1, 3              # move D to bit 0 by shift right 3 positions
                and     x21, x21, 0x00000001    # mask out the unused bits
                and     x25, x25, 0xFFFFFFFE    # clear the target bit
                or      x25, x25, x21           # assign bit[0] from x21 to x25, w/o changing the other bits

                # set R to bit[1]
                sll     x21, a1, 1              # move R to bit 1 by shift left 1 position
                and     x21, x21, 0x00000002    # mask out the unused bits
                and     x25, x25, 0xFFFFFFFD    # clear the target bit
                or      x25, x25, x21           # assign bit[1] from x21 to x25, w/o changing the other bits

                # set U to bit[2]
                srl     x21, a1, 2              # move U to bit 2 by shift right 2 positions
                and     x21, x21, 0x00000004    # mask out the unused bits
                and     x25, x25, 0xFFFFFFFB    # clear the target bit
                or      x25, x25, x21           # assign bit[2] from x21 to x25, w/o changing the other bits

                # set L to bit[3]
                sll     x21, a1, 1              # move L to bit 3 by shift left 1 position
                and     x21, x21, 0x00000008    # mask out the unused bits
                and     x25, x25, 0xFFFFFFF7    # clear the target bit
                or      x25, x25, x21           # assign bit[3] from x21 to x25, w/o changing the other bits

                # set C to bit [4]..., but we don't need it after all, so skip!

                # assign result to a1 and return
                add     a1, x25, zero
                jr      ra
                nop

#---------------------
# DEB_rdbtns() - Reads the debounced pushbuttons
#
# Returns the 5 pushbuttons. The buttons are returned as follows
# (assuming the inputs to the I/O interface matches this order)
# example:
#    bit  7    6      5        4        3        2         1         0
#         r    r      r    btn_cntr  btn_left  btn_up  btn_right  btn_down
#
# where r = reserved. A value of 1 indicates that the button is pressed.
# A 0 indicates that the button is not pressed.
#
# Registers used x25
#---------------------
DEB_rdbtns:     li      x25,        PORT_PBTNS          # read the buttons
                lw      a1,     0(x25)

                # reorder the button positions, according to the Nexys4 DDR
                /*
                addi    sp, sp, -4                # push ra to stack
                sw      ra, 0(sp)
                */
                move    t1, ra
                jal     reorder_btns                # call function
                nop
                move    ra, t1
                /*
                lw      ra, 0(sp)                 # pop ra from stack
                addi    sp, sp, 4
                */
                and     a0, a1, MSK_ALLBTNS         # mask out unused bits
                jr  ra                             # and return
                nop


#---------------------
# LED_wrleds() - Write the low order 8 LEDs
#
# Writes the pattern in t3 to the rightmost 8 LEDs on the Nexyx5
#
# Registers used x25, t3
#---------------------
LED_wrleds:     
                add     x25,    t3, 0               # Copy LEDs to x25 to preserve them
                and     x25, x25,   MSK_LEDS_LO     # mask out unused bits
                li      t3, PORT_LEDS
                sw      x25,    0(t3)               # and write pattern to the LEDs
                jr ra                               # and return
                nop



#---------------------
# SS_wrdpts() - Write the decimal points for digit 3 to 0 to the display
#
# Writes the decimal points specified in t3 to the display.
# The decimal point register is formatted as follows:
#    bit   7  6  5  4   3    2     25     0
#          r  r  r  r  dp3  dp2   dp1   dp0
#
# where r = reserved, dp7 (leftmost), dp3, dp2, dp1 dp0 (rightmost) = 25
# lights the decimal point. A 0 in the position turns off the decimal point
#
# Registers used x25,t3
#---------------------
SS_wrdpts:      lb      x25,    SP_OLDDP                # Copy the decimal points to x25 to leave t3 unchanged
                li      t3,     PORT_SEVENSEG_DP
                sw      x25,        0(t3)   # write the decimal points to the display
                jr    ra
                nop

# Different variables for lookup table, BotInfo register, LOCx_REG, LOCy_REG, Old_Heading register,
# 7 segment displays, and other variables required. All are byte wides except SP_TEMP which is word
# wide.
.section .data
.align 2    # Put next label on a word boundary

# 7 segment display variables
SP_DIG0:    .byte   0
SP_DIG1:    .byte   0
SP_DIG2:    .byte   0
SP_DIG3:    .byte   0
SP_DIG4:    .byte   0
SP_DIG5:    .byte   0
SP_DIG6:    .byte   0
SP_DIG7:    .byte   0

#Location x variable
LOCx_REG:   .byte   0
#Location y variable
LOCy_REG:   .byte   0
#Bot sensors variable
SENSOR_REG: .byte   0
#Botinfo variable
BOTINF_REG: .byte   0

# Intermediate variables can be used for implementing the algorithm
SP_SEM:     .byte   0
SP_OLDMVMT: .byte   0
SP_OLDHDG:  .byte   0
SP_OLDDP:   .byte   0
SP_OLDHDG1: .byte   0
SP_RGTCNT:  .byte   0
SP_LEFTFL:  .byte   0
SP_OLDX:    .byte   0
SP_OLDY:    .byte   0

# Buttons lookup table
SP_BTNBAS1: .byte   0
SP_BTNBAS2: .byte   0
SP_BTNBAS3: .byte   0
SP_BTNBAS4: .byte   0
SP_BTNBAS5: .byte   0
SP_BTNBAS6: .byte   0
SP_BTNBAS7: .byte   0
SP_BTNBAS8: .byte   0
SP_BTNBAS9: .byte   0
SP_BTNBAS10:.byte   0
SP_BTNBAS11:.byte   0
SP_BTNBAS12:.byte   0
SP_BTNBAS13:.byte   0
SP_BTNBAS14:.byte   0
SP_BTNBAS15:.byte   0
SP_BTNBAS16:.byte   0

# Movement lookup table
SP_MVTBAS1: .byte   0
SP_MVTBAS2: .byte   0
SP_MVTBAS3: .byte   0
SP_MVTBAS4: .byte   0
SP_MVTBAS5: .byte   0
SP_MVTBAS6: .byte   0
SP_MVTBAS7: .byte   0
SP_MVTBAS8: .byte   0
SP_MVTBAS9: .byte   0
SP_MVTBAS10:.byte   0
SP_MVTBAS11:.byte   0
SP_MVTBAS12:.byte   0
SP_MVTBAS13:.byte   0
SP_MVTBAS14:.byte   0
SP_MVTBAS15:.byte   0
SP_MVTBAS16:.byte   0
SP_RGTC0NT: .byte   0
SP_TEMP:    .word   0x00


###### Delete this also 
# ====================================================================================================
# Variables for running the algorithm
# ====================================================================================================

# Robot mode: 0=manual, 1=auto
SP_ROBOT_MODE: .byte 0

# Temp word
SP_TEMP_1: .word 0

# Current state of the robot
SP_NSA_STATE: .word 0

# Hold the starting direction & the opposite of it, before trying any other directions
SP_NSA_START_DIRECTION: .word 0
SP_NSA_OPPOSITE_DIRECTION: .word 0

# Hold the current trial direction
SP_NSA_TRIAL_DIRECTION: .word 0

# Hold current position, before doing a navigating session
SP_NSA_LOC_X: .word 0
SP_NSA_LOC_Y: .word 0
