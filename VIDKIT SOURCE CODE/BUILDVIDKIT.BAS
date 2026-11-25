$Console:Only
Dim Shared PROG8JAR$
Dim Shared KillCmd$
Dim Shared CopyCmd$
Dim Shared Slash$

$If WINDOWS Then
    KillCmd$ = "DEL "
    CopyCmd$ = "COPY "
    Slash$ = "\"
$Else
    KillCmd$ = "rm "
    CopyCmd$ = "cp "
    Slash$ = "/"
$End If

ChDir _StartDir$


If _CommandCount = 1 And UCase$(Command$(1)) = "CLEAN" Then
    CLEANDIR
    System
End If


PROG8JAR$ = Get_Prog8_Jar
If Not _FileExists(PROG8JAR$) Then
    Print
    Print "prog8 JAR not found !"
    Print "Can't continue !"
    Print
    End
End If

MakeTrampolineObject
PROG8 "VIDKIT-B1.p8"
PROG8 "VIDKIT-B2.p8"
PROG8 "VIDKIT-B3.p8"
MAKEVIDKITENGINE
MAKESPIKITENGINE
MAKE_VIDKIT_LIBRARY
System


Sub MakeTrampolineObject ()
    Dim codebyte As _Unsigned _Byte
    Dim I As Integer
    CheckKILL "a.out"
    CheckKILL "tramp.o"
    Print "Assembling trampoline.s"
    Shell "64tass tramp.s"
    If Not _FileExists("a.out") Then
        Print "Error assembling Trampoline object !"
        Print
        End
    End If
    Open "a.out" For Binary As #1
    Open "tramp.o" For Binary As #2

    For I = 1 To 2
        Get #1, , codebyte
    Next

    Do While Loc(1) < LOF(1) ' not EOF(1): in binary mode it only turns true after a read past the end, which wrote one extra 00 byte
        Get #1, , codebyte
        Put #2, , codebyte
    Loop
    Close 1
    Close 2
End Sub


Function Get_Prog8_Jar$ ()
    Dim JName$
    If _FileExists("P8JARPATH") Then
        Open "P8JARPATH" For Input As #1
        Input #1, JName$
        Close #1
    End If
    If CheckJar(JName$) Then
        Get_Prog8_Jar = JName$
        Exit Function
    Else
        JName$ = _OpenFileDialog$("FINDING PROG8 JAR FILE", "", "*.JAR|*.jar", "jar Files", _FALSE)
        If _FileExists(JName$) Then
            CheckKILL ("P8JARPATH")
            Open "P8JARPATH" For Output As #1
            Print #1, JName$
            Close #1
        End If
    End If
    Get_Prog8_Jar = JName$
End Function

Function CheckJar% (jarname$)
    CheckJar% = _FileExists(jarname$) _AndAlso (LCase$(Right$(jarname$, 4)) = ".jar")
End Function

Sub MAKEVIDKITENGINE
    Dim POPDIR$
    Dim CMD$
    POPDIR$ = _CWD$
    ChDir "VIDKIT-ENGINE"
    Shell "make"
    CMD$ = CopyCmd$ + "VIDKIT.ENGINE " + ".." + Slash$
    Print
    Print CMD$
    Print
    Shell CMD$
    Print
    ChDir POPDIR$
End Sub

Sub MAKESPIKITENGINE
    Dim POPDIR$
    Dim CMD$
    POPDIR$ = _CWD$
    ChDir "SPIVID-ENGINE"
    Shell "make"
    CMD$ = CopyCmd$ + "SPIVID.ENGINE " + ".." + Slash$
    Print
    Print CMD$
    Print
    Shell CMD$
    Print
    ChDir POPDIR$
End Sub


Sub CLEANDIR
    CLEANENGINES
    CheckKILL "a.out"
    CheckKILL "tramp.o"
    CheckKILL "VIDKIT-B1.bin"
    CheckKILL "VIDKIT-B2.bin"
    CheckKILL "VIDKIT-B3.bin"
    CheckKILL "VIDKIT.ENGINE"
    CheckKILL "SPIVID.ENGINE"
    CheckKILL "BUILDVIDKIT.license.txt"
    Shell KillCmd$ + " *.asm"
    Shell KillCmd$ + " *.vice-mon-list"
End Sub

Sub CLEANENGINES
    Dim popdir$
    popdir$ = _CWD$
    ChDir "SPIVID-ENGINE"
    CheckKILL "SPIVID.ENGINE"
    ChDir "src"
    CheckKILL "main.o"
    ChDir popdir$
    ChDir "VIDKIT-ENGINE"
    CheckKILL "VIDKIT.ENGINE"
    ChDir "src"
    CheckKILL "main.o"
    ChDir popdir$
End Sub


Sub PROG8 (SRCFILE$)
    Dim cmd$
    cmd$ = "java -jar " + PROG8JAR$ + " -target cx16 " + SRCFILE$
    Print cmd$
    Print
    Shell cmd$
    Print
End Sub

Sub MAKE_VIDKIT_LIBRARY ()
    Dim PROCEED As Integer

    PROCEED = _FileExists("VIDKIT-B1.bin")

    If PROCEED Then
        Print "FOUND: VIDKIT-B1.bin"
    Else
        Print "MISSING: VIDKIT-B1.bin"
        Print
        System
    End If

    PROCEED = _FileExists("VIDKIT-B2.bin")

    If PROCEED Then
        Print "FOUND: VIDKIT-B2.bin"
    Else
        Print "MISSING: VIDKIT-B2.bin"
        Print
        System
    End If

    PROCEED = _FileExists("VIDKIT-B3.bin")

    If PROCEED Then
        Print "FOUND: VIDKIT-B3.bin"
    Else
        Print "MISSING: VIDKIT-B3.bin"
        Print
        System
    End If

    PROCEED = _FileExists("VIDKIT.ENGINE")

    If PROCEED Then
        Print "FOUND: VIDKIT.ENGINE"
    Else
        Print "MISSING: VIDKIT.ENGINE"
        Print
        System
    End If

    PROCEED = _FileExists("SPIVID.ENGINE")

    If PROCEED Then
        Print "FOUND: SPIVID.ENGINE"
    Else
        Print "MISSING: SPIVID.ENGINE"
        Print
        System
    End If

    ReDim CODEBUFFER(0 To 1) As _Unsigned _Byte
    ReDim PADBUFFER(0 To 1) As _Unsigned _Byte
    Dim CODETOP As Long
    Dim PADTOP As Long
    Dim CURSIZE As Long

    Print
    Print "CREATING:  VIDKIT-A000.BIN"
    CheckKILL ("VIDKIT-A000.BIN")
    Open "VIDKIT-A000.BIN" For Binary As 1

    Open "VIDKIT-B1.bin" For Binary As 2

    CODETOP = LOF(2) - 1
    PADTOP = (8192 - LOF(2)) - 1
    Print "COPYING: VIDKIT-B1.bin,  Size:"; LOF(2)
    Print "PAD BYTES: "; PADTOP + 1, "TOTAL BYTES: "; LOF(2) + PADTOP + 1
    Print
    ReDim CODEBUFFER(0 To CODETOP) As _Unsigned _Byte
    ReDim PADBUFFER(0 To PADTOP) As _Unsigned _Byte

    Get #2, , CODEBUFFER()
    Put #1, , CODEBUFFER()
    Put #1, , PADBUFFER()
    Close 2

    Open "VIDKIT.ENGINE" For Binary As 2
    CODETOP = LOF(2) - 1
    PADTOP = (2560 - LOF(2)) - 1
    Print "COPYING: VIDKIT.ENGINE, Size:"; LOF(2)
    Print "PAD BYTES: "; PADTOP + 1, "TOTAL BYTES: "; LOF(2) + PADTOP + 1
    Print
    ReDim CODEBUFFER(0 To CODETOP) As _Unsigned _Byte
    ReDim PADBUFFER(0 To PADTOP) As _Unsigned _Byte
    Get #2, , CODEBUFFER()
    Put #1, , CODEBUFFER()
    Put #1, , PADBUFFER()
    Close 2

    Open "VIDKIT-B2.bin" For Binary As 2
    CODETOP = LOF(2) - 1
    PADTOP = (5632 - LOF(2)) - 1
    Print "COPYING: VIDKIT-B2.bin, Size:"; LOF(2)
    Print "PAD BYTES: "; PADTOP + 1, "TOTAL BYTES: "; LOF(2) + PADTOP + 1
    ReDim CODEBUFFER(0 To CODETOP) As _Unsigned _Byte
    ReDim PADBUFFER(0 To PADTOP) As _Unsigned _Byte
    Get #2, , CODEBUFFER()
    Put #1, , CODEBUFFER()
    Put #1, , PADBUFFER()
    Close 2
    Print

    Open "SPIVID.ENGINE" For Binary As 2
    CODETOP = LOF(2) - 1
    PADTOP = (5120 - LOF(2)) - 1
    Print "COPYING: SPIVID.ENGINE,  Size:"; LOF(2)
    Print "PAD BYTES: "; PADTOP + 1, "TOTAL BYTES: "; LOF(2) + PADTOP + 1
    ReDim CODEBUFFER(0 To CODETOP) As _Unsigned _Byte
    ReDim PADBUFFER(0 To PADTOP) As _Unsigned _Byte
    Get #2, , CODEBUFFER()
    Put #1, , CODEBUFFER()
    Put #1, , PADBUFFER()
    Close 2
    Print

    Open "VIDKIT-B3.bin" For Binary As 2
    CODETOP = LOF(2) - 1
    ReDim CODEBUFFER(0 To CODETOP) As _Unsigned _Byte
    Print "COPYING: VIDKIT-B3.bin,  Size:"; LOF(2)
    Get #2, , CODEBUFFER()
    Put #1, , CODEBUFFER()
    Close #1
    Print
    Print " VIDKIT-A000.BIN  SIZE: "; (8192 * 2) + 5120 + LOF(2)

    Close 1
    Close 2
End Sub

Sub CheckKILL (afile$)
    If _FileExists(afile$) Then
        Print "Removing -->  "; afile$
        Kill afile$
    End If
End Sub

















