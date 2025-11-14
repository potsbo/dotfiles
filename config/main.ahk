#Requires AutoHotkey v2.0

; これがないとタイピングが早すぎると途中で固まってしまう
SendMode "Event"
A_MaxHotkeysPerInterval := 100

; 物理的にはスペースキーの左, Mac の標準では Left Command
LControl::
{
    Send "{LControl down}"
}
LControl Up::
{
    if (A_PriorKey = "LControl") {
        Send "{vkF2sc070}{vkF3sc029}"
    }
    Send "{LControl Up}"
}

; 物理的にはスペースキーの右, Mac の標準では Right Command
RControl::
{
    Send "{RControl down}"
}
RControl Up::
{
    if (A_PriorKey = "RControl") {
        Send "{vkF2sc070}"
    }
    Send "{RControl Up}"
}
; ─────────────────────────────
; Ctrl / Alt / Win が押されていない時だけ Dvorak を有効化
; ─────────────────────────────
#HotIf !GetKeyState("Ctrl", "P")      ; 左右どちらの Ctrl でも
    && !GetKeyState("Alt", "P")       ; 左右どちらの Alt でも
    && !GetKeyState("LWin", "P")
    && !GetKeyState("RWin", "P")

; Dvorak
; row 1
`::+4
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
=::`

+`::+`
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

; row 2
q::'
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
+=::+3

; row 3
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

; row 4
z::;
x::q
c::j
v::k
b::x
n::b
;m::m
,::w
.::v
/::z

#HotIf

;; emac keybinding
!a::Home
!e::End
!f::Right
!b::Left
!n::Down
!p::Up
!h::Backspace
!d::Delete
!m::Enter
#HotIf not WinActive("ahk_exe WindowsTerminal.exe") and not WinActive("ahk_exe Cursor.exe") and not WinActive("ahk_exe Code.exe")
!k::
{
    Send "{Shift down}{End}{Shift up}{Delete}"
}
#HotIf 

; mac のエミュレーション
^q::!F4         ; ⌘Q
<^Tab::AltTab   ; ⌘Tab
!Tab::^Tab      ; Control+Tab
!+^4::PrintScreen


; Utility
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
