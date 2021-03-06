{{
  ┌───────────────────────────────────────────┐                                                                    │
  │     Author:  John B. Fisher               │
  │    Version:  1.0 (February 2007)          │
  │      Email:  johnbfisher@earthlink.net    │
  │  Copyright:  None                         │
  └───────────────────────────────────────────┘
  
Sony_IR_Decoder.spin.  Decodes five bits of signal from Sony IR Remote.
Display on either Debug terminal or on one seven segment display.

Based on ideas in "IR Remote for the BoeBot" by Andy Lindsay.

--------------------------------------------------------------------------------------
                                                             
Coding scheme for typical IR remote configured for Sony TV (at least mine,
a "3-in-One Remote" from Radio Shack):
                                                                  
                                                              routine increments 
 Remote   Bit:  0      1     2     3       4       Decimal   "message" variable to
 Button:  Value:1      2     4     8      16       Value:     replicate button:     
 ______       _______________________________      ______          ______
|       |    |     |      |     |     |      |    |      |        |      |      
|  1    |    |  0  |   0  |  0  |  0  |   0  |    |   0  |        |   1  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   2   |    |  1  |   0  |  0  |  0  |   0  |    |   1  |        |   2  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   3   |    |  0  |   1  |  0  |  0  |   0  |    |   2  |        |   3  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   4   |    |  1  |   1  |  0  |  0  |   0  |    |   3  |        |   4  |
 ______       ___   ____   ____  ____   ____       ______          ______ 
|       |    |     |      |     |     |      |    |      |        |      |
|   5   |    |  0  |   0  |  1  |  0  |   0  |    |   4  |        |   5  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   6   |    |  1  |   0  |  1  |  0  |   0  |    |   5  |        |   6  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   7   |    |  0  |   1  |  1  |  0  |   0  |    |   6  |        |   7  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   8   |    |  1  |   1  |  1  |  0  |   0  |    |   7  |        |   8  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   9   |    |  0  |   0  |  0  |  1  |   0  |    |   8  |        |   9  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|   0   |    |  1  |   0  |  0  |  1  |   0  |    |   9  |        |   0  | (special case)
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
| Chan +|    |  0  |   0  |  0  |  0  |   1  |    |  16  |        |  17  |
 ______       ___   ____   ____  ____   ____       ______          ______ 
|       |    |     |      |     |     |      |    |      |        |      |
| Chan -|    |  1  |   0  |  0  |  0  |   1  |    |  17  |        |  18  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
| Vol + |    |  0  |   1  |  0  |  0  |   1  |    |  18  |        |  19  |
  ______       ___   ____  ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
| Vol - |    |  1  |   1  |  0  |  0  |   1  |    |  19  |        |  20  |
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|  OK   |    |  0  |   0  |  1  |  0  |   1  |    |  20  |        |  21  |
 ______       ___   ____   ____  ____   ____       ______          ______
 ______       ___   ____   ____  ____   ____       ______          ______
|       |    |     |      |     |     |      |    |      |        |      |
|  Pwr  |    |  1  |   0  |  1  |  0  |   1  |    |  21  |        |  22  |
 _______      _______________________________      ______          ______
}} 


CON
     _clkmode = xtal1 + pll16x      
     _xinfreq = 5_000_000            
                                    
VAR
     Long stack1[50]                 ' Stack for 2nd BS2_Functions Cog 
     Word Pulse[5]                   ' Pulse width of each bit of message
     Word message                    ' Inteteger created from the five bits

OBJ
     BS2   : "BS2_Functions"         ' Create BS2 Object
     Seven : "SevenSegment"          ' Create Seven Segment Object

PUB Init | x
    BS2.start (31,30)                ' Initialize BS2 Object, Rx and Tx pins for DEBUG
    Seven.init                       ' Initialize seven segment display
    GetMessage

PUB GetMessage
    repeat
      
        Pulse[0] := (BS2.RCTIME(15, 0))/2         
        if (Pulse[0] > 975) and (Pulse[0] < 1425)

            Pulse[0] :=  BS2.PULSIN(15,0)
            Pulse[1] :=  BS2.PULSIN(15,0)
            Pulse[2] :=  BS2.PULSIN(15,0)
            Pulse[3] :=  BS2.PULSIN(15,0)
            Pulse[4] :=  BS2.PULSIN(15,0)

            if Pulse[0] < 400                        ' convert long and short pulses to
                message := 0                         ' bits in message variable.
            else
                message := 1
            if Pulse[1] > 400    
                message := message + 2
            if Pulse[2] > 400    
                message := message + 4
            if Pulse[3] > 400    
                message := message + 8
            if Pulse[4] > 400    
                message := message + 16

            message := message + 1                   ' make message = IR Remote numerical button
            if message == 10                         ' special case
                message := 0                   

            DisplayDebug 
            DisplaySevenSegment
    
PUB DisplaySevenSegment

    If (message > -1) and (message < 10)
        Seven.DisplayDigit(message)    
    if message == 17
        Seven.ChannelUp
    if message == 18
        Seven.ChannelDown
    If message == 19                      
        Seven.LoudnessUp
    If message == 20                     
        Seven.LoudnessDown                                        
    if message == 21
        Seven.AroundtheBlock   
    if message == 22
        Seven.Power

PUB DisplayDebug

    BS2.DEBUG_DEC(message)
    BS2.DEBUG_CHAR(13)
 