%import textio
%import strings
%import conv
%import floats
%encoding iso

; ------------------------------------------------------------------
;  picker : scrolling media / folder chooser for PLAYMOVIES
;
;  The folder listing is held in BANKED RAM, so the number of entries
;  is limited by free banks, not by main RAM.
;
;  Record layout  (128 bytes, 64 records per 8K bank)
;    +0  type      0=SPV  1=ZCM  2=WAV  3=DIR
;    +1  blocks    uword, as reported by the DOS listing (0 for DIR)
;    +3  baselen   length of the name without its 4-char extension
;                  (full length for folders)
;    +4  name      full file name, 0-terminated (max 96 chars)
;
;  Order: "..", then folders, then media files - each group in the
;  order DOS lists them.  ".." is shown whenever the current folder
;  is not the root: either the DOS listing contains a ".." entry
;  (every FAT32 sub-folder has one), or we entered the folder ourselves.
;  Slot 0 is always reserved for ".."; at the root the list simply
;  starts at slot 1 (ofs = 1), so nothing has to be moved.
;
;  Banks used: FIRST_BANK up to (main.VID_BANK1 - 1), skipping
;  VIDKIT.PalBank if it falls in that range.
;  On a 512K machine that is ~57 banks = ~3600 entries.
;  The list is rebuilt every time the picker opens or the folder
;  changes, so anything that later loads into these banks during
;  playback (tape sprites, ZCM data ...) does no harm.
; ------------------------------------------------------------------

picker {
    const ubyte FIRST_BANK    = 1
    const uword REC_SIZE      = 128
    const ubyte RECS_PER_BANK = 64
    const ubyte NAME_MAX      = 96

    const ubyte R_TYPE    = 0
    const ubyte R_BLOCKS  = 1
    const ubyte R_BASELEN = 3
    const ubyte R_NAME    = 4

    const ubyte T_SPV  = 0
    const ubyte T_ZCM  = 1
    const ubyte T_WAV  = 2
    const ubyte T_DIR  = 3
    const ubyte T_NONE = $FF

    const ubyte RESULT_EXIT     = 0
    const ubyte RESULT_SELECTED = 1
    const ubyte RESULT_TYPENAME = 2     ; unused for now (typed entry disabled)

    ; ---- SCREEN MARGINS ------------------------------------------------
    ;  Change these four to pull the picker in from the screen edges
    ;  (composite / CRT overscan).  Every row and column below follows.
    ;  Current values = the VGA layout:
    ;    TOP    title row                    BOTTOM  last environment row
    ;    LEFT   left edge of the list box    RIGHT   scroll-marker column
    ;  Fixed-length lines to watch when narrowing: the key-help line
    ;  (~77 chars) and the environment lines (~70 chars) do not wrap -
    ;  shorten their text if RIGHT - LEFT drops below about 78.
    ; VGA Screen 1 parms
    ; const ubyte TOP    = 1
    ; const ubyte BOTTOM = 29
    ; const ubyte LEFT   = 1
    ; const ubyte RIGHT  = 78
    const ubyte TOP    = 3
    const ubyte BOTTOM = 28         ; was 30: row 30 is off an 80x30 screen
    const ubyte LEFT   = 4
    const ubyte RIGHT  = 75

    const ubyte WIDTH      = RIGHT - LEFT - 1   ; list row width (70)
    const ubyte COL        = LEFT + 1           ; text start column
    const ubyte NAME_WIDTH = WIDTH - 18         ; row = 1 + name + 8 blocks + 3 + 5 type + 1

    ;  TOP      title banner
    ;  TOP+2    column headings, with "File x of y" between Name and Blocks
    ;  TOP+3    rule
    ;  TOP+4..  file list (LIST_ROWS rows)
    ;           blank
    ;           key help             (KEYS_ROW)
    ;           blank
    ;  BOTTOM-1 / BOTTOM  version / environment info
    const ubyte TITLE_ROW  = TOP
    const ubyte HEAD_ROW   = TOP + 2
    const ubyte LIST_TOP   = TOP + 4
    const ubyte ENV_ROW    = BOTTOM - 1
    const ubyte KEYS_ROW   = ENV_ROW - 2
    const ubyte LIST_ROWS  = KEYS_ROW - LIST_TOP - 1

    ; "File x of y" sits on the heading line, centred between Name and Blocks.
    ; STATUS_W covers the longest text: "Reading folder... nnnn   " (25).
    const ubyte STATUS_ROW = HEAD_ROW
    const ubyte STATUS_W   = 25
    const ubyte STATUS_COL = (COL + 4 + COL + NAME_WIDTH + 2) / 2 - 9

    ; colours
    const ubyte C_BG     = 6
    const ubyte C_MOVIE  = 1
    const ubyte C_AUDIO  = 13
    const ubyte C_DIR    = 7        ; yellow folder names
    const ubyte C_SEL_FG = 6
    const ubyte C_SEL_BG = 1

    ; X16 key codes (local copies: "main._KEY_xx" will not parse in a when)
    ; verify PgUp/PgDn/End on your ROM
    const ubyte KEY_UP    = 145
    const ubyte KEY_DOWN  = 17
    const ubyte KEY_ENTER = 13
    const ubyte KEY_ESC   = 27
    const ubyte KEY_F2    = 137
    const ubyte KEY_HOME  = $13
    const ubyte KEY_END   = $04
    const ubyte KEY_PGUP  = $82
    const ubyte KEY_PGDN  = $02

    uword count                     ; entries shown
    uword ndirs                     ; folders shown (not counting "..")
    uword nfiles                    ; media files shown
    uword phys                      ; records written (includes reserved slot 0)
    ubyte ofs                       ; 0 = ".." shown, 1 = root (slot 0 hidden)
    bool  has_parent
    uword max_entries
    uword top
    uword sel
    ubyte skip_bank
    ubyte depth = 0                 ; folders entered below the start folder

    ubyte mbtn_prev                 ; mouse buttons on the previous poll
    uword mx_prev                   ; mouse position on the previous poll
    uword my_prev
    bool  mouse_moved               ; any mouse activity on the last poll

    ubyte cur_type
    uword cur_blocks
    ubyte cur_baselen
    str   namebuf = "?" * 100
    str   cmdbuf  = "?" * 104

; ---------------------------------------------------------- banked storage

    sub init_limits() {
        ubyte last = main.VID_BANK1 - 1        ; VIDKIT code lives from VID_BANK1 up
        ubyte nbanks = last - FIRST_BANK + 1
        skip_bank = VIDKIT.PalBank
        if skip_bank >= FIRST_BANK and skip_bank <= last { nbanks-- } else { skip_bank = 0 }
        max_entries = (nbanks as uword) * RECS_PER_BANK
    }

    sub rec_addr(uword idx) -> uword {
        ; idx = index as shown in the list
        return phys_addr(idx + ofs)
    }

    sub phys_addr(uword idx) -> uword {
        ; selects the RAM bank holding physical record idx and returns its
        ; address. Caller saves / restores the bank.
        ubyte bank = FIRST_BANK + lsb(idx >> 6)
        if skip_bank != 0 and bank >= skip_bank { bank++ }
        cx16.rambank(bank)
        return $A000 + (idx & 63) * REC_SIZE
    }

    sub add_entry(ubyte t, uword blocks, ubyte baselen) {
        ; stores namebuf as a new record
        if phys >= max_entries {
            return
        }
        ubyte ob = @(0)
        uword p = phys_addr(phys)
        @(p + R_TYPE) = t
        pokew(p + R_BLOCKS, blocks)
        @(p + R_BASELEN) = baselen
        void strings.copy(namebuf, p + R_NAME)
        cx16.rambank(ob)
        phys++
        count = phys
        if t == T_DIR { ndirs++ } else { nfiles++ }
        if (phys & 15) == 0 { show_progress() }
    }

    sub load_rec(uword idx) {
        ubyte ob = @(0)
        uword p = rec_addr(idx)
        cur_type    = @(p + R_TYPE)
        cur_blocks  = peekw(p + R_BLOCKS)
        cur_baselen = @(p + R_BASELEN)
        void strings.copy(p + R_NAME, namebuf)
        cx16.rambank(ob)
    }

    sub first_char(uword idx) -> ubyte {
        ubyte ob = @(0)
        ubyte c = @(rec_addr(idx) + R_NAME)
        cx16.rambank(ob)
        return up(c)
    }

; ---------------------------------------------------------- helpers

    sub up(ubyte c) -> ubyte {
        if c >= 'a' and c <= 'z' { return c - 32 }
        if c >= $C1 and c <= $DA { return c - $80 }     ; PETSCII shifted letters
        return c
    }

    sub is_alnum(ubyte c) -> bool {
        c = up(c)
        return (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')
    }

    sub is_parent_name() -> bool {
        return namebuf[0] == '.' and namebuf[1] == '.' and namebuf[2] == 0
    }

    sub is_hidden_name() -> bool {
        ; ".", ".." and macOS "._xxx" resource files
        if namebuf[0] != '.' { return false }
        if namebuf[1] == 0 or namebuf[1] == '_' { return true }
        return is_parent_name()
    }

    sub ext_type(ubyte n) -> ubyte {
        if n < 5 { return T_NONE }
        if namebuf[n-4] != '.' { return T_NONE }
        ubyte c1 = up(namebuf[n-3])
        ubyte c2 = up(namebuf[n-2])
        ubyte c3 = up(namebuf[n-1])
        if c1=='S' and c2=='P' and c3=='V' { return T_SPV }
        if c1=='Z' and c2=='C' and c3=='M' { return T_ZCM }
        if c1=='W' and c2=='A' and c3=='V' { return T_WAV }
        return T_NONE
    }

; ---------------------------------------------------------- folder read

    sub read_folder() -> bool {
        ; builds the list: "..", folders, then media files. Returns success.
        bool ok
        init_limits()
        ofs = 0
        phys = 0
        count = 0
        has_parent = depth > 0
        void strings.copy("..", namebuf)
        add_entry(T_DIR, 0, 2)                  ; reserved slot 0
        ndirs = 0                               ; ".." is not counted as a folder
        nfiles = 0
        ok = read_pass(true)
        if ok { ok = read_pass(false) }
        if has_parent { ofs = 0 } else { ofs = 1 }
        count = phys - ofs
        return ok
    }

    sub read_pass(bool want_dirs) -> bool {
        ; one pass over the "$" listing; keeps folders or media files
        ubyte ob = @(0)
        ubyte status
        ubyte lo
        ubyte hi
        ubyte ch
        ubyte n
        ubyte t
        ubyte quotes
        ubyte tn
        bool overflow
        bool isdir
        bool firstline = true
        ubyte[3] tbuf

        cbm.SETNAM(1, "$")
        cbm.SETLFS(11, main.drivenumber, 0)
        void cbm.OPEN()
        if_cs
            goto dir_error
        void cbm.CHKIN(11)
        repeat 4 { void cbm.CHRIN() }          ; load address + first line link
        status = cbm.READST()

        while status == 0 {
            lo = cbm.CHRIN()                    ; "line number" = block count
            hi = cbm.CHRIN()
            n = 0
            quotes = 0
            tn = 0
            overflow = false
            repeat {
                ch = cbm.CHRIN()
                if ch == 0 { break }
                if ch == 34 {
                    quotes++
                } else if quotes == 1 {         ; inside the quoted name
                    if n < NAME_MAX { namebuf[n] = ch  n++ } else { overflow = true }
                } else if quotes >= 2 and tn < 3 {
                    ch = up(ch)                 ; file type after the name: PRG / DIR ...
                    if ch >= 'A' and ch <= 'Z' { tbuf[tn] = ch  tn++ }
                }
            }
            namebuf[n] = 0
            void cbm.CHRIN()                    ; next line link
            void cbm.CHRIN()
            status = cbm.READST()

            if firstline {
                firstline = false               ; disk header line
            } else if is_parent_name() {
                has_parent = true               ; listing has "..": not the root
            } else if n > 0 and not overflow and not is_hidden_name() {   ; names over 96 chars are ignored
                isdir = tn == 3 and tbuf[0] == 'D' and tbuf[1] == 'I' and tbuf[2] == 'R'
                if isdir {
                    if want_dirs { add_entry(T_DIR, 0, n) }
                } else if not want_dirs {
                    t = ext_type(n)
                    if t != T_NONE { add_entry(t, mkword(hi, lo), n - 4) }
                }
            }
            void cbm.STOP()
            if_z
                break
        }

        cbm.CLRCHN()
        cbm.CLOSE(11)
        cx16.rambank(ob)
        if status != 0 and (status & $40) == 0 { return false }   ; bit 6 = EOF
        return true

dir_error:
        cbm.CLRCHN()
        cbm.CLOSE(11)
        cx16.rambank(ob)
        return false
    }

    sub change_dir() -> bool {
        ; sends CD:<namebuf> on the command channel. Returns success.
        ubyte c1
        ubyte c2
        void strings.copy("CD:", cmdbuf)
        void strings.append(cmdbuf, namebuf)
        cbm.SETNAM(strings.length(cmdbuf), cmdbuf)
        cbm.SETLFS(15, main.drivenumber, 15)
        void cbm.OPEN()
        void cbm.CHKIN(15)
        c1 = cbm.CHRIN()
        c2 = cbm.CHRIN()
        main.Flush15()                          ; rest of status, close 15, CLRCHN
        return c1 == '0' and c2 == '0'
    }

    sub show_progress() {
        txt.color2(15, C_BG)
        main.MyPlot(STATUS_ROW, STATUS_COL)
        txt.print("\x9BReading folder\x99... \x05")
        txt.print_uw(phys - 1)
        txt.print("   ")
    }

; ---------------------------------------------------------- drawing

    sub draw_frame() {
        txt.color2(1, C_BG)
        txt.clear_screen()
        main.MyPlot(TITLE_ROW, COL+7)
        txt.print("\x9C*\x9A*\x99* \x05X16 VIDKIT Movie & Audio Player ")
        txt.print(PENV.ISOASC_VERSTR)
        txt.print(" \x9E*\x81*\x1C*")

        main.MyPlot(HEAD_ROW, COL)  txt.print("\x9BName")
        main.MyPlot(HEAD_ROW, COL + NAME_WIDTH + 2) txt.print("Blocks")
        main.MyPlot(HEAD_ROW, COL + NAME_WIDTH + 11) txt.print("Type")
        txt.color2(15, C_BG)
        main.MyPlot(HEAD_ROW + 1, LEFT)
        repeat WIDTH { cbm.CHROUT(196) }

        main.MyPlot(KEYS_ROW, COL-1)
        txt.print("\x1E[\x05\x80\x18\x80\x19\x1E] \x9BMove  ")
        txt.print("\x1E[\x05PgUp\x99/\x05PgDn\x1E] \x9BPg  ")
        txt.print("\x1E[\x05Home\x99/\x05End\x1E]  ")
        txt.print("\x1E[\x05A-Z\x1E] \x9BJump ")
        txt.print("\x1E[\x05ENTER\x1E] \x9BOpen ")
        txt.print("\x1E[\x05ESC\x1E] \x9BExit")

        draw_env()
        txt.color2(1, C_BG)
    }

    sub draw_env() {
        ; row 28 : VIDKIT version (left)  +  file system (right)
        ; row 29 : processor, emulator/hardware, ROM
        txt.color2(1, C_BG)
        main.MyPlot(ENV_ROW, COL)
        txt.print("\x05VIDKIT Version\x1E: \x9E")
        txt.print_ub(main.VMajor)
        txt.print("\x1E.\x9E")
        txt.print_ub(main.VMinor)
        if main.VDevelopment { txt.print(" \x9C(\x9FDev Vers\x1C.\x9C)") } else { txt.print(" \x9C(\x99Release\x9C)") }


        main.MyPlot(ENV_ROW + 1, COL)
        txt.print(PENV.CPU)
        txt.print("  \x9BOn\x1E: \x05")
        if PENV.ON_EMU { txt.print("X16 Emulator") } else { txt.print("X16 Hardware") }
        txt.print("  \x9BROM\x1E: \x9Cr\x99")
        txt.print(conv.str_ub(ROM.VERSION))
        if ROM.IsPreRelease { txt.print("\x1E(\x9BPre-Release\x1E)") }
        txt.print("  ")
        if PENV.ON_EMU and PENV.IS_HOST { txt.print("\x1C(\x99HOST \x05File System\x1C)") }
        else { txt.print("\x1C(\x99Fat\x1E32 \x05File System\x1C)") }
    }

    sub print_right(uword value, ubyte width) {
        ; prints value right-aligned in width columns
        uword s = conv.str_uw(value)
        ubyte L = strings.length(s)
        if L < width { main.spc(width - L) }
        txt.print(s)
    }

    sub blank_row(ubyte row) {
        txt.color2(1, C_BG)
        main.MyPlot(row, LEFT)
        main.spc(WIDTH)
    }

    sub draw_row(uword idx, bool hilite) {
        ubyte row = LIST_TOP + lsb(idx - top)
        ubyte i = 0
        ubyte ch
        ubyte limit = NAME_WIDTH
        uword s

        load_rec(idx)
        if hilite {
            txt.color2(C_SEL_FG, C_SEL_BG)
        } else if cur_type == T_DIR {
            txt.color2(C_DIR, C_BG)
        } else if cur_type == T_SPV {
            txt.color2(C_MOVIE, C_BG)
        } else {
            txt.color2(C_AUDIO, C_BG)
        }

        main.MyPlot(row, LEFT)
        cbm.CHROUT(' ')
        if strings.length(namebuf) > NAME_WIDTH { limit = NAME_WIDTH - 1 }
        while i < limit {
            ch = namebuf[i]
            if ch == 0 { break }
            if ch < 32 or (ch >= 128 and ch < 160) { ch = '?' }    ; never emit control codes
            cbm.CHROUT(ch)
            i++
        }
        if limit < NAME_WIDTH { cbm.CHROUT(175)  i++ }               ; >> marks a cut-off name
        if i < NAME_WIDTH { main.spc(NAME_WIDTH - i) }

        if cur_type == T_DIR {
            main.spc(8)                                              ; no blocks for folders
        } else {
            print_right(cur_blocks, 8)
        }
        main.spc(3)
        when cur_type {
            T_SPV -> txt.print("Movie")
            T_ZCM -> txt.print("ZCM  ")
            T_WAV -> txt.print("WAV  ")
            else  -> {
                ; light red brackets, green DIR (plain on the highlight bar)
                if hilite { txt.print("<DIR>") } else { txt.print("\x96<\x1EDIR\x96>") }
            }
        }
        cbm.CHROUT(' ')
        txt.color2(1, C_BG)
    }

    sub draw_list() {
        ubyte r
        uword idx
        for r in 0 to LIST_ROWS-1 {
            idx = top + r
            if idx < count { draw_row(idx, idx == sel) } else { blank_row(LIST_TOP + r) }
        }
        txt.color2(7, C_BG)
        main.MyPlot(LIST_TOP, RIGHT)
        if top > 0 { txt.print("\x80\x18") } else { cbm.CHROUT(' ') }
        main.MyPlot(LIST_TOP + LIST_ROWS - 1, RIGHT)
        if top + LIST_ROWS < count { txt.print("\x80\x19") } else { cbm.CHROUT(' ') }
        txt.color2(1, C_BG)
    }

    sub draw_status() {
        txt.color2(15, C_BG)
        main.MyPlot(STATUS_ROW, STATUS_COL)
        main.spc(STATUS_W)            ; clear only the status field - the headings share this row
        ubyte pdir = 1 - ofs                    ; 1 when ".." is the first row

        ; media file total, lower right (row 28), right-aligned in 4 digits
        main.MyPlot(ENV_ROW, RIGHT - 17)
        txt.print("\x9BMedia Files\x1E: \x05")
        print_right(nfiles, 4)

        main.MyPlot(STATUS_ROW, STATUS_COL)
        if count == 0 {
            txt.print("\x96Empty folder")
        } else {
            if sel < pdir {
                txt.print("\x9BParent folder")
            } else {
                ; "Folder n of x" / "File n of y" - one shared print path
                uword n = sel - pdir + 1
                uword total = ndirs
                if n <= ndirs {
                    txt.print("\x9BFolder \x05")
                } else {
                    txt.print("\x9BFile \x05")
                    n -= ndirs
                    total = nfiles
                }
                txt.print_uw(n)
                txt.print(" \x9Bof \x05")
                txt.print_uw(total)
            }
        }
        txt.color2(1, C_BG)
    }

; ---------------------------------------------------------- navigation

    sub move_to(uword newsel) {
        if count == 0 { return }
        if newsel >= count { newsel = count - 1 }
        uword oldsel = sel
        uword oldtop = top
        sel = newsel
        if sel < top {
            top = sel
        } else if sel >= top + LIST_ROWS {
            top = sel - LIST_ROWS + 1
        }
        if top != oldtop {
            draw_list()
        } else if sel != oldsel {
            draw_row(oldsel, false)
            draw_row(sel, true)
        }
        draw_status()
    }

    sub jump_to(ubyte k) {
        ; next entry (wrapping) whose name starts with k
        k = up(k)
        uword idx = sel
        repeat count {
            idx++
            if idx >= count { idx = 0 }
            if first_char(idx) == k {
                move_to(idx)
                return
            }
        }
        main.Boing()
    }

    sub open_folder() {
        ; namebuf holds the folder name (from load_rec)
        bool going_up = is_parent_name()
        if not change_dir() {
            main.Boing()
            return
        }
        if going_up {
            if depth > 0 { depth-- }
        } else {
            depth++
        }
        sel = 0
        top = 0
        phys = 1
        show_progress()                         ; "Reading folder... 0"
        if not read_folder() { count = 0 }
        draw_list()
        draw_status()
    }

    sub page_up() {
        if sel > LIST_ROWS { move_to(sel - LIST_ROWS) } else { move_to(0) }
    }

    sub activate() -> bool {
        ; ENTER / click on the selected entry. True = media file chosen.
        if count == 0 { return false }
        load_rec(sel)
        if cur_type == T_DIR {
            open_folder()
            return false
        }
        apply_selection()
        return true
    }

; ---------------------------------------------------------- mouse

    sub mouse_on() {
        cx16.mouse_config(1, 80, 30)        ; mode 1 = 80x30 chars of 8x8 (640x240), in 8-pixel units
        mbtn_prev = $FF                     ; ignore a button already held down
    }

    sub mouse_off() {
        cx16.mouse_config(0, 0, 0)          ; pointer is sprite 0 - off before playback (0,0 = keep resolution)
    }

; ---------------------------------------------------------- screen blanker
;  Same timer as the info screen (main.SetScreenTimer / main.ScrTimer):
;  the display is switched off after a minute without key or mouse activity.

    sub wake() {
        cx16.VERA_DC_VIDEO = main.SAVE_DC_VIDEO
        main.SetScreenTimer()
    }

    sub check_blank() {
        float t = floats.time()
        if (t > main.ScrTimer) and (t < 16773000) { cx16.VERA_DC_VIDEO = 0 }
    }

    sub poll_mouse() -> bool {
        ; click row = select, click selected row = open, wheel = scroll,
        ; click the up/down markers = page.  True = media file chosen.
        ubyte btn
        byte wheel
        ubyte row
        ubyte pressed
        uword idx

        btn, wheel = cx16.mouse_get(lsb(&cx16.r0))
        ; pixels -> text row (8x8 cells); read r0/r1 before anything clobbers them
        row = lsb(cx16.r1 >> 3)
        mouse_moved = cx16.r0 != mx_prev or cx16.r1 != my_prev or btn != 0 or wheel != 0
        mx_prev = cx16.r0
        my_prev = cx16.r1

        ; one entry per wheel step; away from user (negative) = up the list
        if wheel < 0 {
            pressed = (0 - wheel) as ubyte  ; (pressed reused as the step count)
            if sel >= pressed { move_to(sel - pressed) } else { move_to(0) }
        } else if wheel > 0 {
            move_to(sel + (wheel as ubyte))
        }

        pressed = btn & ~mbtn_prev
        mbtn_prev = btn
        if (pressed & 1) == 0 { return false }
        if row < LIST_TOP or row >= LIST_TOP + LIST_ROWS { return false }

        idx = top + row - LIST_TOP
        if idx >= count { return false }
        if idx == sel { return activate() }
        move_to(idx)
        return false
    }

    sub apply_selection() {
        ; sets BASENAME and the file-found flags for the chosen entry
        load_rec(sel)
        void strings.copy(namebuf, main.BASENAME)
        main.BASENAME[cur_baselen] = 0
        void strings.copy(&namebuf + cur_baselen, main.FOUND_EXT)
        main.ISOUpper(main.FOUND_EXT)

        main.VID_FILE_FOUND = false
        VIDKIT.PCM_FILE_FOUND = false
        VIDKIT.IS_Z_FILE = false
        VIDKIT.IS_WAV_FILE = false
        VIDKIT.IS_PCM_ONLY = false

        if cur_type == T_SPV {
            void strings.copy(namebuf, main.VIDFILE)
            main.VID_FILE_FOUND = true
        } else {
            void strings.copy(namebuf, main.AUDFILE)
            VIDKIT.PCM_FILE_FOUND = true
            VIDKIT.IS_PCM_ONLY = true
            VIDKIT.IS_Z_FILE = (cur_type == T_ZCM)
            VIDKIT.IS_WAV_FILE = (cur_type == T_WAV)
        }
        main.SEND_BASENAME()
    }

    sub pick() -> ubyte {
        ; runs the chooser. Returns RESULT_SELECTED or RESULT_EXIT
        ubyte k
        ; keep sel/top from last time (same folder after F3), so the media
        ; file just played is highlighted again. Reset if the list shrank.
        if sel >= count {
            sel = 0
            top = 0
        }
        draw_list()
        draw_status()
        main.KEYFLUSH()
        mouse_on()
        main.SetScreenTimer()
        repeat {
            k = cbm.GETIN2()
            if k == 0 {
                if poll_mouse() {
                    wake()
                    mouse_off()
                    return RESULT_SELECTED
                }
                if mouse_moved { wake() } else { check_blank() }
                continue
            }
            wake()                          ; any key restores the display
            when k {
                KEY_UP          -> { if sel > 0 { move_to(sel - 1) } }
                KEY_DOWN        -> move_to(sel + 1)
                KEY_PGUP        -> page_up()
                KEY_PGDN        -> move_to(sel + LIST_ROWS)
                KEY_HOME        -> move_to(0)
                KEY_END         -> move_to(count - 1)
                KEY_ENTER       -> {
                    if activate() {
                        ; mouse_off()
                        return RESULT_SELECTED
                    }
                }
                KEY_ESC         -> {
                    mouse_off()
                    return RESULT_EXIT
                }
                ; KEY_F2        -> return RESULT_TYPENAME   ; typed-name entry disabled for now
                else -> {
                    if is_alnum(k) { jump_to(k) } else { main.Boing() }
                }
            }
        }
        return RESULT_EXIT
    }
}
