FXMasm
======

## Disassembler / assembler for Frantisek Fuka's (Fuxoft) AY chip music for ZX Spectrum 128 microcomputer.

In the 1980s, I composed and programmed many music tracks for 128k ZX Spectrum and its AY-3-8910 sound chip. I did this without any music software or MIDI keyboard, inputting the raw music data which was then interpreted using my custom playroutine. This was basically a miniature programming language that allowed for some tricky stuff (e.g. calls, loops, relative transposition of notes) to keep the music data extremely compact (often under 1 kilobyte).

Although many of these tracks are inspired by C64 music (especially by Rob Hubbard), there was no automatic conversion, I programmed everything "by ear" (and made mistakes doing so).

## The .fxmasm source files:

Here you can find the source code of most of my songs in the .fxmsrc format which very closely resembles the format I originally used to compose the music. The main difference is that this "update" uses human-readable opcodes (e.g. "JUMP", "CALL"). When I originally composed the music, I used hardcoded memorized byte-instructions, (e.g. 128 for JUMP, 129 for CALL).

The .fxmasm sources contain some trivia about specific songs. The [MUSIC_FORMAT.md](MUSIC_FORMAT.md) file contains the detailed explanation of the music format.

## Disassembler / assembler:

The `fxmasm.lua` LuaJIT script is able to compile and decompile these music files in the following manner:

`fxmasm.lua source.fxmasm dest.fxm` - Compiles the .fxmasm file into the dest.fxm binary file which can then be played on PC using e.g. the multiplatform [AY Emul music emulator](https://bulba.untergrund.net/emulator_e.htm) by Sergey Bulba.

`fxmasm.lua dest.fxm` or `fxmasm.lua dest.fxm 0` - Decompiles the dest.fxm binary file into the .fxmasm source file and outputs it to STDOUT. Works only with .fxmasm files (not with more complex .ay files). Notice that the decompiled file cannot be always reliably compiled back to the binary file and requiress some manual modifications first. Those are already applied in the included .fxmsrc files.

If the optional third parameter equals to `debug`, some debug info is output during the operation.
