''*******************************************************
''*  Waltr (Wireless, Apple II, Logo, Turtle, Robot)    *
''*  Author: Alex Lukacz                                *
''*  Version 1.0  16/12/2011                            *
''******************************************************* 
''

CON

  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000

  BUF_SIZE          = 8192           'Buffer size.
  BUF_ERR_NOSPACE   = 1              'No more buffer space.
  MODE_LOGO         = 1              'Logo mode.
  MODE_DIRECT       = 2              'Direct control mode.
  CR                = 13             'Carriage return.
'  PEN_PIN           = 2              'Pen servo.
'  PEN_POS_UP        = 1310           'Pen position up.
'  PEN_POS_DN        = 1460           'Pen position down.
'  RX_PIN            = 0              'Serial Comms Rx.
'  TX_PIN            = 1              'Serial Comms Tx.
  SPD_DEFAULT       = 3              'Default logo speed.
  SPD_FB            = 70             'Default direct speed (forward / back).
  SPD_LR            = 70             'Default direct speed (left / right).
'  USE_HEARTBEAT     = TRUE           'Generate a heartbeat signal.
  FORCE_7BIT_DATA   = FALSE          'Force incoming data to 7-bit.
                                     ' FLASE - FMSLog0, Apple Logo II
                                     ' TRUE  - Apple Logo, Terrapin V1.0, Joystick Exammple
  TERRAPIN_V1       = FALSE          'Terrapin Logo V1.0.          
  
OBJ

  sio   : "FullDuplexSerial_rr004"
'  sio2   : "FullDuplexSerial"        'Debugging
  s2    : "s2"
'  SERVO : "Servo32v7"

VAR
  long buf_head
  long buf_tail
  
  byte buf_error
  byte buffer[BUF_SIZE]

PUB start | mode, rx_byte, rx_byte_temp, command, prev_cmd, position, bypass, param1, speed, speed_fb, speed_lr, heartbeat
  
  'Start hardware driver cogs and low level routlines  
  s2.start 
  s2.start_motors
  s2.start_tones

  speed := SPD_DEFAULT             
  s2.set_speed(speed)

  speed_fb := SPD_FB                 'Direct mode - Speed forward and back
  speed_lr := SPD_LR                 'Direct mode - Speed left and right
  
'  SERVO.Start
'  SERVO.Set(PEN_PIN, PEN_POS_UP)
   
  mode := MODE_LOGO
  buf_error := 0 
  command := 0
  position := 0
  bypass := FALSE
  prev_cmd := " "
  
  'Start the Serial Communication Object
  sio.start(s2#RX, s2#TX, 0, 9600)   'Onboard serial port
'  sio.start(RX_PIN, TX_PIN, 0, 9600) 'Bluetooth serial port
'  sio2.start(s2#RX, s2#TX, 0, 9600)  'Debugging
  sio.rxflush

  repeat
'    if USE_HEARTBEAT
'      heartbeat++
'      if heartbeat // 30000 == 0
'        sio.tx(".")
    case mode
      MODE_LOGO:
        if buf_error == 0
          repeat
            rx_byte_temp := sio.rxcheck
            if rx_byte_temp <> -1
              if FORCE_7BIT_DATA
                rx_byte_temp := rx_byte_temp & %01111111
'              if rx_byte_temp => 32 and rx_byte_temp =< 126 'Visible characters. 'Debugging  
'                sio2.tx(rx_byte_temp)                                            'Debugging
'              sio2.tx("[")                                                       'Debugging
'              sio2.dec(rx_byte_temp)                                             'Debugging
'              sio2.tx("]")                                                       'Debugging
              buf_error := bufadd(rx_byte_temp)
              if buf_error <> 0
                s2.beep
                s2.beep
                s2.beep
          until rx_byte_temp == -1        
        if bypass == FALSE
          rx_byte := bufcheck
        if rx_byte <> -1
          if position == 0
            case rx_byte
              "2", "f", "F", "b", "B", "l", "L", "r", "R", "p", "P", "v", "V":
                command := rx_byte
                position++
              "9":
                speed++
                s2.set_speed(speed)
              "8":
                speed--
                s2.set_speed(speed)
          else
            case command
              "2":
                if rx_byte == CR
                  sio.rxflush
                  buf_head := buf_tail
                  position := 0
                  mode := MODE_DIRECT
                  speed_fb := SPD_FB
                  speed_lr := SPD_LR
                  bypass := FALSE
              "f", "F":
                case position
                  1:
                    if TERRAPIN_V1
                      param1 := rx_byte - 1
                    else  
                      param1 := rx_byte
                    position++
                  2:
                    if FORCE_7BIT_DATA
                      param1 := (param1 * 128) + rx_byte
                    else 
                      param1 := (param1 * 256) + rx_byte
                    position++
                  other:
                    bypass := s2.moving
                    if rx_byte == CR and bypass == FALSE
                      s2.go_forward(param1)
                      position := 0
              "b", "B":
                case position
                  1:
                    if TERRAPIN_V1
                      param1 := rx_byte - 1
                    else  
                      param1 := rx_byte
                    position++
                  2:
                    if FORCE_7BIT_DATA
                      param1 := (param1 * 128) + rx_byte
                    else 
                      param1 := (param1 * 256) + rx_byte
                    position++
                  other:
                    bypass := s2.moving
                    if rx_byte == CR and bypass == FALSE
                      s2.go_back(param1)
                      position := 0
              "l", "L":
                case position
                  1:
                    if TERRAPIN_V1
                      param1 := rx_byte - 1
                    else  
                      param1 := rx_byte
                    position++
                  2:
                    if FORCE_7BIT_DATA
                      param1 := (param1 * 128) + rx_byte
                    else 
                      param1 := (param1 * 256) + rx_byte
                    position++
                  other:
                    bypass := s2.moving
                    if rx_byte == CR and bypass == FALSE
                      s2.turn_deg_now(param1)
                      position := 0
              "r", "R":
                case position
                  1:
                    if TERRAPIN_V1
                      param1 := rx_byte - 1
                    else  
                      param1 := rx_byte
                    position++
                  2:
                    if FORCE_7BIT_DATA
                      param1 := (param1 * 128) + rx_byte
                    else 
                      param1 := (param1 * 256) + rx_byte
                    position++
                  other:
                    bypass := s2.moving
                    if rx_byte == CR and bypass == FALSE
                      s2.turn_deg_now(-param1)
                      position := 0
              "p", "P":
                case rx_byte
                  "u", "U":
                    param1 := 1
                  "d", "D":
                    param1 := 2
                  CR:
                    bypass := s2.moving
                    if param1 == 1 and bypass == FALSE
'                      SERVO.Set(PEN_PIN, PEN_POS_UP)
                      position := 0
                    if param1 == 2 and bypass == FALSE
'                      SERVO.Set(PEN_PIN, PEN_POS_DN)
                      position := 0
              "v", "V":
                case position
                  1:
                    param1 := rx_byte
                    position++
                  other:
                    if rx_byte == CR
                      speed := param1
                      s2.set_speed(speed)
                      position := 0
         
      MODE_DIRECT:
        if bypass == FALSE
          rx_byte := sio.rxcheck
        else
          bypass := 0
        if rx_byte <> -1
          if FORCE_7BIT_DATA
            rx_byte := rx_byte & %01111111  
'          if rx_byte => 32 and rx_byte =< 126 'Visible characters. 'Debugging  
'            sio2.tx(rx_byte)                                       'Debugging
'          sio2.tx("[")                                             'Debugging
'          sio2.dec(rx_byte)                                        'Debugging
'          sio2.tx("]")                                             'Debugging
          if position == 0  
            case rx_byte    
              " ":
                s2.stop_now
                prev_cmd := rx_byte
              "1":
                sio.rxflush
                buf_head := buf_tail
                mode := MODE_LOGO
                speed := SPD_DEFAULT
                s2.set_speed(speed)
                position := 0
                bypass := FALSE
              "a", "A":
                s2.wheels_now(speed_fb, speed_fb, 0)
                prev_cmd := rx_byte
              "z", "Z":
                s2.wheels_now(-speed_fb, -speed_fb, 0)
                prev_cmd := rx_byte
              "d", "D":
                speed_fb++
                bypass := TRUE
                rx_byte := prev_cmd
              "c", "C":
                if speed_fb > 0
                  speed_fb--
                bypass := TRUE
                rx_byte := prev_cmd
              "f", "F":
                speed_lr++
                bypass := TRUE
                rx_byte := prev_cmd
              "v", "V":
                if speed_lr > 0
                  speed_lr--
                bypass := TRUE
                rx_byte := prev_cmd
'              "s", "S":
'                SERVO.Set(PEN_PIN, PEN_POS_UP)
'              "x", "X":
'                SERVO.Set(PEN_PIN, PEN_POS_DN)
              ",":
                s2.wheels_now(-speed_lr, speed_lr, 0)
                prev_cmd := rx_byte
              ".":
                s2.wheels_now(speed_lr, -speed_lr, 0)
                prev_cmd := rx_byte
              "g", "G":
                command := rx_byte
                position++
              "b", "B":
                command := rx_byte
                position++   
          else
            case command
              "g", "G":
                speed_fb := rx_byte
                position := 0
                bypass := TRUE
                rx_byte := prev_cmd
              "b", "B":
                speed_lr := rx_byte
                position := 0  
                bypass := TRUE
                rx_byte := prev_cmd

PUB bufcheck : return_byte

'' Check if byte exists (never waits)
'' returns -1 if no byte received, $00..$FF if byte
                                                                          
  return_byte--
  if buf_tail <> buf_head
    return_byte := buffer[buf_tail]
    buf_tail := (buf_tail + 1) & (BUF_SIZE - 1)

PUB bufadd(input_byte) : error | buf_pos

'' Add byte to buffer
'' returns -1 if byte not added ie no room in buffer, 0 if ok

  error--
  buf_pos := (buf_head + 1) & (BUF_SIZE - 1)
  if buf_pos <> buf_tail
    buffer[buf_head] := input_byte
    buf_head := buf_pos
    error := 0                