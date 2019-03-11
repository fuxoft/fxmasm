Fuxoft song source file format
==============================

## Basics

Fuxoft songs are written using a text editor in the .fxmsrc file and then compiled using `fxmasm.lua` into .fxm binary file.

The format of .fxmsrc file is as follows:

Lines beginning with `--` are comments.

If a line begins with an identifier that ends with `:`, this identifier is a label which can be referenced elsewhere in the file. For example:

`melody9: 40,10 JUMP melody9`

At the label `melody9`, the song plays note 40 for 10 interrupts and then jumps back to `melody9`.

All labels are compiled into 2 byte addresses (LSB, MSB).

The music consists of exactly three voices, each of which is executed in its own "thred" and is independent of the other two voices. These three voices have entry points that correspond to labels `voice1`, `voice2` and `voice3`. These names are hardcoded.

All time intervals are specified in interrupts, where one interrupt is equal to 1/50 of one second.

## Notes

Notes are specified by byte pairs in the format `n,l`, where `n` is a note and `l` is its length (in interrupts). Notes are numbered by semitones (similar to MIDI notes). Note 40 is C and note 0 is silence. For example:

`40,25 42,25, 44,25 45,25 47,25 49,25 51,25 52,25 0,50`

This plays the C major scale with each note having the length of 0.5 seconds (25 interrupts), followed by one second of silence.

Note that the "pairing" of the notes using commas is purely cosmetic. The following line has the exactly same effect as the example above and translates to exactly same 18 bytes of data:

`40 25,42 25 44 25 45 25 47 25 49 25 51 25,52 25,0 50`

Each voice data ends either with JUMP back to the beginning of that voice's data. There is no "end of song" marker. If you want the song to end, you have to create an infinite silent loop at the end of each voice's data. Note that sound values (eg transpose, envelope, noise type) are NOT reset when jumping back to the beginning of the voice.

Before playing any notes, both envelope and vibrato for that voice *must* be specified (see ENV and VIB directives below).

## Voice directives

Apart from notes (explained above), each of the three voices consists of directives explained below:

### JUMP label

Immediately transfers the execution to `label`.

### CALL label

Calls the subroutine at `label`. Calls can be nested.

### RET

Returns from subroutine.

### LOOP uint

Starts a loop that repeats `uint` times, where `uint` is unsigned integer. Loops can be nested.

### NEXT

Ends the innermost loop.

### TR int

Sets the transpose value for the current voice to `int` (signed integer). For each subsequent non-zero note in the current voice, this value is added to the note number. At the start of the song, the transpose value is 0.

### TR+ int

Adds the signed integer `int` to the current transpose value for the current voice. This can be used for some very nifty tricks, for example:

`LOOP 3 40,50 TR+ 4 NEXT`

Provided that transpose is 0, this plays the notes 40, 44 and 48 (C, E, G#), each for 1 second. After that, the transpose value remains set at 12.

### NOISE uint

Sets the noise type to `uint`. Acceptable values are 0 to 31. Note that the noise type is shared by all three voice (this is AY hardware feature, unfortunately).

### NOISE+ int

Adds the `int` signed integer to the noise type value and then ANDs the result with 31. Used to slide the noise type gradually. For example:

NOISE 0 LOOP 5 30,1 NOISE+ -20 NEXT

This produces 5 notes, each of them 1 interrupt long, with noise values 30, 10, 22, 2 and 14 respectively. This can be used for some nifty percussion sounds, especially in conjuction with the LEG+ directive.

> Note that some of the earlier songs had an error in the playroutine that resulted in ANDing the sum with 15 instead of 31. When playing those old sounds in the current AY player, the noise might sound "wrong".

### TYPE uint

Sets the sound type for corresponding voice to `uint`. Valid `uint` values are:

* 8 - Tone (default)
* 1 - Noise
* 0 - Tone and noise
* 9 - Silence (of limited practical use)

You should not use any other value than 0, 1, 8 or 9.

### EXTERNAL_CALL label

Immediately calls native Z80 machine code subroutine at `label`. Used only in Indiana Jones 3 music.

### ENV label

Sets the envelope data for the current voice (explained below).

### VIB label

Sets the vibrato data for the current voice (explained below).

> Both ENV and VIB must be explicitly specified before playing a note in any voice. There are no "default" ENV and VIB values!

> ENV and VIB definitions are completely independent of each other and can be shared between multiple voices without problems.

### LEG+

Sets the legato mode on. The following note will be played as normal but all notes afterwards will not reset the ENV pointer (while the VIB pointer is reset as normal).

### LEG-

Sets the legato mode off (default).

## ENV data format:

The ENV directive defines the volume envelope of the "instrument". It consists of byte pairs in the format `v,l` where `v` is the volume (0 to 15) and `l` is length (in interrupts) for holding this value.

The only directive allowe in ENV data is `JUMP label`.

Entering a single byte with the value `v` of 50 to 65 has the same effect as entering the byte pair `v-50,1`.

Example:

```
envelope5: 15,5 14,3 63 62 61
hold10: 10,99 JUMP hold10
```

This envelope holds volume 15 for 5 interrupts, volume 14 for 3 interrupts, volume 13 for 1 interrupt, volume 12 for 1 interrupt, volume 11, for 1 interrupt and then hold volume 10 forever (until the note end).

This is exactly equivalent to the following "long form" data:

```
envelope5: 15,5 14,3 13,1 12,1 11,1
hold10: 10,99 JUMP hold10
```

> Important note: The very first data in the envelope definition **must be** in the long form (full pair). E.g. `15,1` is correct first pair, `65` is not allowed here and produces unexpected results.

## VIB data format

The VIB directive specifies the vibrato, i.e. how the note height changes after each interrupt. The VIB data is a sequence of signed bytes that are added to the note frequency after each interrupt. Example:

`vibrato3: 1 -1 0 -2 2 JUMP vibrato3`

Let's say the note with frequency 500 is played with this VIB definition. The frequencies of this note then are as follows (after each interrupt): 500, 501, 500, 500, 498, 500 and then they repeat from 501 onwards infinitely.

Note that the "frequency" value is not actually frequency but period. Consequently, **positive** VIB values **lower** the note frequency and vice versa. For example, the following VIB definition produces a sharp infinite **downward** frequency glide:

`freqdown: 25 JUMP freqdown`

> Note that the note frequencies increase logarithmically. That means that the same vibrato definitions are much more pronounced with higher notes than with lower notes.

Apart from the `JUMP` directive, the following directives are available in the VIB data:

### XOR

XORs the sound type value of the current channel (see the TYPE directive above) with the number 9. That means it changes between 0 and 9 or between 1 and 8. Useful mainly for percussion sounds.

### TONE

Changes the current VIB mode to semitone mode. In this mode, the vibrato bytes are not added to note frequency but to the note number. This is used mainly for producing those sweet 8-bit pseudo chords like this:

`majorchord: TONE 4 3 -7 JUMP majorchord`

This VIB definition, when used to play e.g. note 40 (C), produces the notes 40, 44 and 47 in rapid succession, which is the C major chord (C, E, G).

In TONE mode, positive values increase the note and negative values decrease the note number (i.e. the opposite of FREQ mode).

### FREQ

Changes the current VIB mode from TONE back to the default behavior.

> Note: In the `TONE` mode, each frequency played corresponds to "pure" semitone, regardless of what previous `FREQ` glides happened with the current note. The combinations of `TONE` and `FREQ` in a single VIB definition can be used for some very advanced tricks.
