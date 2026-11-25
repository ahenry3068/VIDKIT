%encoding iso
%import textio
%import strings
%zeropage basicsafe

licenses {
 str TITLE = "\x00"+"?"*70

sub set_title(str NewTitle) { strings.copy(NewTitle, TITLE) }


sub show_MIT(str COPYDATE, str AUTHOR) {
    cx16.set_screen_mode(1)
    txt.cp437()
    txt.color2(1,6)
    txt.clear_screen()
    txt.print("\x0D\x0D\x0D")
    if strings.length(licenses.TITLE) > 0 { txt.print(licenses.TITLE) }
    txt.print("\x0D\x0D\x0D")
    txt.print("\x05 Copyright \x99") txt.print(COPYDATE) txt.print("\x1E, \x05") txt.print(AUTHOR) txt.print("\x0D\x0D\x9B")
    txt.print(" Permission is hereby granted, \x99free of charge\x1E,\x9B to any person obtaining a copy\x0D")
    txt.print(" of this software and associated documentation files \x96(\x05the Software\x96)\x1E,\x9B to deal\x0D")
    txt.print(" in the Software without restriction, including without limitation the\x0D")
    txt.print(" the rights to use, copy, modify, merge, publish, distribute, sublicense,\x0D")
    txt.print(" and/or sell copies of the Software, and to permit persons to whom the\x0D")
    txt.print(" software is furnished to do so.\x0D\x0D\x05")
    txt.print(" THE SOFTWARE IS PROVIDED  AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS\x0D")
    txt.print(" OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\x0D")
    txt.print(" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \x0D")
    txt.print(" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\x0D")
    txt.print(" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\x0D")
    txt.print(" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS\x0D")
    txt.print(" IN THE SOFTWARE.\x0D\x0D")
}

}
