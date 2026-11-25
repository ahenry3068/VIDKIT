# ADDENDUM #2

Frame playback rate on SPV videos is actually controlled by the VERA PCM playback rate.

The VERA audio FIFO is partially pre-filled just prior to playback initiation.

For each Video exactly the same amount of Audio is read in for each Video frame, this chunk of PCM data I refer to as the Audio frame. The next Video frame is only processed when the VERA AFLOW condition is asserted (FIFO buffer 25% or less full). The Audio frame is processed first, then the video frame. Thus the Video frame rate is directly coupled to the PCM playback rate. This also ensures A/V sync is maintained.

Since the VERA PCM rate precision is from 0 to 48828.15 hz in 128 discrete steps of 381.4699 hz this does not allow exact precision on the frame rate. But allows something close enough to the sampled frame rate to be acceptable from the end user stand point. Most person’s cannot tell if a Music is being undersampled by 152.4 hz (that number chosen at random, to make the point.) Nor is it apparent if a video encoded at 14.7 frames per second is being played at 14.62 frames per second.

Audio frame size should always be at least 512 bytes and can be no more than 3072 bytes. For SPI direct videos this MUST be a multiple of 512 bytes. For Standard videos it can be any size in this range but must be an even number for Stereo or 16 bit PCM and divisible by 4 for Stereo 16 bit PCM. This feature is experimental and audio stability is bad with 16 bit PCM, especially if Stereo !!.

The Audio frame is determined in two different ways.

1.  In an SPV with embedded/interleaved audio the PCM format & sample rate and audio frame size is calculated when the video is encoded. The exact value is stored in the header. In these videos the FPS byte & FPS extended formats are only informational.

2.  For an SPV with a separate Audio track the track may be changed out after encoding. The Audio Frame Size is calculated at play time and determined by the formula.

    ```
    AudioFrameSize = AUDIO-FILE-SIZE/VIDEO-NUMBER-OF-FRAMES
    ```

    This number will be rounded as necessary to meet any divisibility requirement (2, 4 or 512). Audio file format is RAW signed PCM without a header and the extension .SVA just to signify that it belongs to a particular .SPV. Because the frame size may be rounded it could cause A/V sync to drift if the file parameters have not been correctly figured. (this should NOT be a problem for tracks created in the X16 Movie Maker, but can be if you decide to change tracks)

3.  Since there is no header on the SVA file the proper PCM sample rate and format is calculated based on the Movies Frames Per Second value. This will be as close as possible given the 381.47 hz Step precision of the VERA PCM decoder. On older videos this FPS value is a whole number, the FPS byte value. This is STILL SUPPORTED. On newer videos there is an extension to allow this to be a fixed point number with a precision of 100th’s of an FPS. It is stored in a 16 bit fixed point format in the header (see spec table). Since this calculation result is always rounded to a whole unsigned byte Value designating the VERA rate steps the FPS will almost never be dead on. But the precision is sufficient for acceptable playback quality.

4.  This is the formula used to determine VERA Rate. Calculations are done in floating point and not rounded to the VERA Byte rate until the final step. (AudioFrameSize however is a 16 bit integer value !)

```
;(FPS can either be whole or also have a decimal component)
Audio-SampleRate = AudioFrameSize * FPS
if PCM_IS_STEREO then Audio-SampleRate = Audio-SampleRate/2
if PCM_IS_16BIT then Audio-SampleRate = Audio-SampleRate/2
VERA-RATEBYTE = _floor((Audio-SampleRate / 48828.15) * 128)
```

## AMIGA VIDEOS (VTYPE 199)

Amiga videos do not use the VERA rate byte. The audio is 8 bit signed mono PCM with embedded audio frames, played at a rate set by an Amiga Paula period, and 16 bit or stereo audio is not available. The period is stored as a 16 bit little endian value in header EXTRA bytes 0-1.

```
Audio-SampleRate = Clock / Period
```

The Clock is 3579545.45 hz for NTSC and 3546894.6 hz for PAL. The header screen hint is “P” for PAL and “N” for NTSC. The smallest legal period is 124. The Movie Maker offers a fixed list of rates (about 8000, 11025, 16000, 22050, 24000 and 28000 hz), converts each to the nearest period, and sets the audio frame size to round(rate / FPS) rounded down to an even number. A player that finds a period below 124 (or missing) falls back to Audio Frame Size * FPS.

## MS-DOS VIDEOS (VTYPE 86 and 88)

The MS-DOS (VGA and Mode X) video types carry UNSIGNED 8 bit PCM audio, as a PC sound card expects. All other video types use SIGNED 8 bit PCM (or signed 16 bit where the extended audio formats are used). A player must convert the samples by subtracting 128 if it needs signed data. Stereo is not available for these types.
