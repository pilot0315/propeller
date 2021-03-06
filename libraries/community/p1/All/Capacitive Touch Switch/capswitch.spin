{{

┌──────────────────────────────────────────┐
│ Capswitch V1.0                           │
│ Author: Ken Peterson                     │               
│ Copyright (c) 2008 Kenneth C Peterson    │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

This is a capacitive touch switch that can be used in place of a push button for some applications.

Prop    Vcc
────┐    
    │     1.0 MΩ
  Px├────┴─── to switch plate
    │
────┘

Theory of operation:

The Prop measures the RC time constant determined by the resistor and the capacitance on the plate.  When you bring your finger close
to the plate, the capacitance increases and therefore the RC time constant increases.

The sensitivity can be adjusted with the threshold value.  The avg value continually adjusts the system to the
average capacitance.  This automatically adjusts it for the surrounding conditions.  The added capacitance of a finger
near the plate produces a transient that can be detected.

The plate can be a wire or a piece of foil tape stuck to the back of a plastic or glass panel.  Try to keep the panel wall as thin as possible.

It should be noted that the system only detects transients. If you hold your finger in place, it may not continue to register a touch.
This should work for push-button type input.

Future work:  I'd like to make this work for several switches.  Right now each switch is expected to require one pin.

   
}}

CON

read_freq = 50                  ' samples per second

VAR
  long  reslt
  
PUB start(pin, a_ptr, c_ptr, threshold)
  reslt_ptr := @reslt
  avg_ptr := a_ptr
  cnt_ptr := c_ptr
  thres := threshold
  mask := |< pin
  reslt := 1
  delay_val := clkfreq/read_freq
  cognew(@entry, 0)
  repeat
  until reslt == 0              ' wait for avg to stabilize

PUB state
  return reslt <> 0
DAT

              ORG       0

entry         andn      outa,   mask            ' set pin low
              mov       delay_cnt, cnt          ' save counter for delay
              add       delay_cnt, delay_val
loop          mov       loopcnt, #8
              mov       diff,   #0
              
loop2         or        dira,   mask            ' set pin to output
              mov       cnt1,   cnt             ' get count              
              andn      dira,   mask            ' set pin to input
              waitpeq   mask,   mask            ' wait for pin to go high
              mov       cnt2,   cnt             ' get count
              sub       cnt2,   cnt1            ' cnt2 := cnt2 - cnt1
              add       diff,   cnt2            ' add to difference value (8x)
              djnz      loopcnt,#loop2
              
              shr       diff,   #3              ' diff = average of 8 readings
              mov       temp,   avg             ' temp := avg + thres - diff
              add       temp,   thres           '       "
              sub       temp,   diff  wc        '       "
              
        if_c  mov       temp,   #1              ' if temp < 0 (diff > avg + thres) temp := 1 (switch activated)
        if_nc mov       temp,   #0              ' if temp >= 0 (diff <= avg + thres) temp := 0 (switch not activated)
              wrlong    temp,   reslt_ptr       ' save result to hub RAM                   

              mov       temp,   avg wz          ' avg := (avg * 15 + diff) / 16 (calculate pseudo-average)..
        if_z  mov       temp,   diff            ' if avg = 0, start with avg := diff * 2
        if_z  shl       temp,   #1              '       "
              shl       temp,   #4              '       "
              sub       temp,   avg             '       "
              add       temp,   diff            '       "
              shr       temp,   #4              '       "
              mov       avg,    temp            '       "
              
              wrlong    avg,    avg_ptr         ' for debugging and threshold adjustment
              wrlong    diff,   cnt_ptr         ' for debugging and threshold adjustment
              
              waitcnt   delay_cnt, delay_val    ' read frequency delay
              jmp       #loop


cnt1          long      0                       ' initial counter value
cnt2          long      0                       ' final counter value
diff          long      0                       ' count difference
mask          long      0                       ' pin mask
reslt_ptr     long      0                       ' pointer to result in hub RAM
avg           long      0                       ' pseudo-average of last 8 readings
temp          long      0                       ' temporary variable
thres         long      0                       ' threshold to determine sensitivity (set in CON section)
delay_cnt     long      0                       ' keep track of counter value for delay
delay_val     long      0
avg_ptr       long      0
cnt_ptr       long      0
loopcnt       long      0

              FIT      

     {<end of object code>}
     
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}       