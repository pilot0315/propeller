{{

┌──────────────────────────────────────────┐
│ DayOfTheWeek v1.0                        │
│ Author: Andrew Silverman                 |
│ Copyright (c) 2010 Andrew Silverman      │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

}}

PUB DOTW (Year, Month, Day) | c, y, y2, m, ly
{{ This function determines the Day of the Week, given a 4-digit modern year, month, and day. Accounts for leap years and
century-years where no leap year takes place.  Algorithm was taken from the wikipedia article at 
"http://en.wikipedia.org/wiki/Calculating_the_day_of_the_week".

Input:  Year in 4 digit format, Month from 1-12, Day from 1-31.

Returns an int between 0:6 for Sunday:Saturday. Valid for Gregorian Calendar dates.  Keep in mind that various countries
adopted the Gregorian calendar on widely differing dates.  Great Britain and its colonies adopted it during 1752.
}}

y2 := Year // 100                                                    'y2 is the last two digits of the year (e.g. "10" in 2010)
ly := (Year // 4 == 0 and y2 <> 0) or (y2 == 0 and Year // 400 == 0) 'Applies leap year rules, accounting for 100's (not a LY) and 400's (are a LY.)
c := 2 * (3- ((Year/100) // 4))
y := y2 + (y2 / 4)
case Month
  1:
     if ly ' Leap year
       m := 6
     else
       m := 0
  2:
     if ly
       m := 2
     else
       m := 3
  3, 11:
    m := 3
  4, 7:
    m := 6
  5:
    m := 1
  6:
    m := 4
  8:
    m := 2
  9, 12:
    m := 5
  10:
    m := 0

return (c+y+m+day) // 7

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