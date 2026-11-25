# ADDENDUM #3 (Aspect Ratio Handling)

For many Movie formats the X16 Movie Maker drops scales down the number of scanlines in the stored bitmap to save bandwidth on playback. For this reason the encoded resolution does not exactly match the correct source Aspect ratio of the Video. The player use’s Hardware scaling to achieve the correct playback aspect ratio.

On encode the Movie Maker stores this information in the Shint field of the SPV Header. There are currently 5 used values: four fixed ratios and “A”, which carries the exact aspect ratio !

The Shint field is 1 byte long and is interpreted as a character value rather than a number by the player ! This also makes it easier for a person to tell what the Video will be by examining the header with a hex editor/viewer.

CURRENTLY USED VALUES

“N” – Normal The encoded video should be displayed with a 4:3 (Standard TV) aspect ratio.

“T” - Tall The encoded video should be displayed with a 9:16 (Cell phone) aspect ratio. Normally used for Sprite encoded vids only !

“K” - Ktall This value was chosen kind of randomly. It is a variant of 9:16 playback ratio for Bitmap based Videos. If marked with this Shint then the Frame Image is 270 pixels wide centered in a 320 wide frame since bitmap frames on the X16 must be either 320 or 640 in width. On playback an HSCALE value of 128 for full 640 width is used on the X16, but the bitmap screen is set to 320 wide and the image centered with HSTART & HSTOP. Vertically the image will be scaled to full screen Height !

The Movie Maker can also pad 9:16 input videos with black borders. But these are actually 4:3 videos for display and will be marked with an N value for Shint

“W” – Wide The encoded video should be displayed with a 16:9 (Standard MODERN TV) aspect ration. This is actually the most common ratio today for downloaded videos !

“A” – Aspect The exact display aspect ratio (width / height) is stored as a 5 byte Commodore (CBM) float in header EXTRA bytes 1-5 (counting from 0), see below.

This scheme does not account for every possible aspect Ratio. If a crop option is not chosen for a source Video with an Aspect Ratio greater than 1.9 then you will be prompted to Crop it to 16:9 prior to conversion. (POSSIBLE FUTURE FEATURE: incorporate an S value for Shint for SuperWide)

These values are always respected by the Video player programs EXCEPT the scripting language.

For SPRITE BASED VIDEOS ONLY the scripting language can turn off the scaling factors and the Script Author should program the desired SCALE & STOP values in the script itself !

BITMAPPED BASED FRAMES are less flexible. The VERA only accepts 320 or 640 as the width of a bitmap layer ! The scripting language will always set the correct Bitmap hwidth for display !

The Movie Maker may also CROP a 16:9 or higher wide screen ratio to a 4:3 ratio prior to conversion.

It uses ffmpeg to do the cropping ! After any cropping or padding to 4:3 then a Video has full 4:3 frames and will be marked with an N. The active part of the video just has black borders added ! Cropping may be desirable, but Padding a 16:9 video should usually be avoided as it waste’s Video bandwidth on just shoving a bunch of 0 bytes during playback !

HINT “A” – EXACT ASPECT (Movie Maker 2.0 / VIDKIT 2.0)

The Movie Maker has a checkbox “Keep original aspect” (default ON), next to “Mark as TALL video”. It is shown for bitmap, sector and desktop types and hidden for sprite, VGA and Amiga types, which keep the older behavior.

The effective aspect a is the source aspect, or 4:3 when crop options 1, 2 or 4 are used, or 16:9 when crop option 3 is used. The Shint is then chosen as follows:

1.28 to 1.40 -\> “N” 1.70 to 1.90 -\> “W” 0.5 to 0.6 -\> “K” (bitmap) / “T” (sprite) anything else -\> “A”

For “A” the aspect is stored as a 5 byte CBM float in header EXTRA bytes 1 to 5 (counting from 0; bytes 2 to 6 counting from 1). EXTRA byte 0 keeps its old meaning (“X”, “J”, “W”, 0 or the Amiga audio period) and EXTRA byte 6 is the palette tag. The value is only valid when Shint is “A”. Valid values are about 0.3 to 6. In the prog8 header definition the float is aliased as &float AspectF = \$51A.

X16 BITMAP VIDEOS WITH ASPECT BELOW 1 are never marked “A”. They are K videos: when the source is outside 0.5 to 0.6 the Movie Maker pads it to 9:16 with ffmpeg (black borders), and the frame is 270 wide centered in a 320 wide frame as described above.

Desktop only videos (MJPG and other desktop types) are always marked “A” when the box is checked. They have no X16 window.

PLAYBACK ON THE X16 (VIDKIT 2.0). When Shint is “A” and the video is not a sprite video, VIDKIT sets HAS_ASPECT (\$049D) and computes the display window from the float:

aspect \>= 4/3 : 640 columns wide by floor(640 / aspect) lines, rounded to even (2 line units) aspect \< 4/3 : 480 lines tall by floor(480 \* aspect) columns, rounded to a multiple of 8

The window is centered. HSCALE and VSCALE are floor(frame size \* 128 / window size), capped at 128. Scales are floored so a picture is never smaller than its window: at most a few edge lines or columns can be cut, never garbage margins.

The Movie Maker refuses frames that do not fit the window (a 640 wide bitmap with a window narrower than 640, or more frame lines than window lines). Standard bitmap sizes are lowered with a note; sector and custom sizes get an error. Warnings (not errors) are shown when edge lines or columns are cut by the integer scale or the window cannot be exactly centered. VIDKIT does not range check the float, so a corrupt “A” header (zero or garbage aspect) could divide by zero.

PLAYBACK ON THE DESKTOP. The desktop player and the SPV-HANDLES / VID-HANDLES libraries return the stored aspect from SPVASPECT# / VIDASPECT# (falling back to FrameW / FrameH when the value is missing or outside 0.3 to 6). SPVHDRASPECT# returns the decoded header aspect, or 0 when there is no valid “A”. The player shows it as “Display aspect” in the video info.

OLDER PLAYERS that do not know “A” should treat it as “N”. The scripting language rules above are unchanged.
