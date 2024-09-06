﻿#Requires AutoHotkey v2.0

; これがないとタイピングが早すぎると途中で固まってしまう
SendMode "Event"
A_MaxHotkeysPerInterval := 200

; 共通設定
~LControl up::
{
    if (A_PriorKey = "LControl") {
        Send "{Escape}"
    }
}
~RShift up::{
    if (A_PriorKey = "RShift") {
        Send "!{Space}"
    }
}
~LShift up::{
    if (A_PriorKey = "LShift") {
        Send "!^+{Space}"
    }
}

LAlt::
{
    Send "{LAlt down}"
}
LAlt Up::
{
    if (A_PriorKey = "LAlt") {
        Send "{vkF2sc070}{vkF3sc029}"
    }
    Send "{LAlt Up}"
}

RAlt::
{
    Send "{RAlt down}"
}
RAlt Up::
{
    if (A_PriorKey = "RAlt") {
        Send "{vkF2sc070}"
    }
    Send "{RAlt Up}"
}
RWin Up::
{
    if (A_PriorKey = "RWin") {
        Send "^!{Space}"
    }
}

^#Up::
{
    Send "#{Up}"
}
^#Left::
{
    Send "#{Left}"
}
^#Right::
{
    Send "#{Right}"
}
^#Down::
{
    Send "#{Down}"
}
^#Enter::#Up


#HotIf (not WinActive("ahk_exe FlightSimulator.exe")) and (not WinActive("ahk_exe FactoryGame-Win64-Shipping.exe"))

q::'
+q::"
w::,
e::.
r::p
t::y
y::f
u::g
i::c
o::r
p::l
[::/
]::@
+]::+6
=::`
+=::+3


;a::a
s::o
d::e
f::u
g::i
h::d
j::h
k::t
l::n
`;::s
'::-

z::;
+z::
{
    Send ":"
}
x::q
c::j
v::k
b::x
n::b
;m::m
,::w
.::v
/::z

#HotIf not WinActive("ahk_exe WindowsTerminal.exe")
^a::Home
^e::End
#HotIf

^f::Right
^b::Left
^n::Down
^p::Up
^h::Backspace
^d::Delete
^m::Enter

^x::^x
^c::^c
^z::^z
^r::^r
^o::^o
^]::^]
!a::^a
!z::^z
!s::^s 
!c::^c
!v::^v
!w::^w
!q::!F4
!x::^x
!f::^f
!l::^l
!t::^t
!,::^,
!r::F5
!Enter::^Enter
!/::^/
!=::!=
!1::^1
!2::^2
!3::^3
!4::^4
!5::^5
!6::^6
!7::^7
!8::^8
!9::^9
!0::^0

1::!
2::[
3::+[
4::+9
5::=
6::+
7::)
8::+]
9::]
0::+8
-::+7

+1::1
+2::2
+3::3
+4::4
+5::5
+6::6
+7::7
+8::8
+9::9
+0::0
+-::+5
+`::+`
`::+4
`;::s

#HotIf WinActive("ahk_exe slack.exe")
!k::^t
!+h::^+h
#HotIf not WinActive("ahk_exe slack.exe")
!k::^k
^e::^e
#HotIf WinActive("ahk_exe WindowsTerminal.exe")
^k::^k
#HotIf not WinActive("ahk_exe WindowsTerminal.exe")
^k::
{
    Send "{Shift down}{End}{Shift up}{Delete}"
}
!p::^p
