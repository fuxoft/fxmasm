FXMasm
======

## Disassembler / assembler for Frantisek Fuka's (Fuxoft) AY chip music for ZX Spectrum 128 microcomputer.

In the 1980s, I (Frantisek Fuka) composed and programmed many music tracks for 128k ZX Spectrum and its AY-3-8910 sound chip. I did this without any music software or MIDI keyboard, inputting the raw music data into text file which was then compiled to binary file and interpreted using my custom playroutine. This was basically a miniature programming language that allowed for some tricky stuff (e.g. calls, loops, relative transposition of notes) to keep the music data extremely compact (often under 1 kilobyte).

Although many of these tracks are inspired by C64 music (especially by Rob Hubbard), there was no automatic conversion, I programmed everything "by ear" (and made mistakes doing so).

## The .fxmasm source files:

In the `songs/` subdirectory, you can find the source code of most of my songs in the .fxmsrc format which very closely resembles the format I originally used to compose the music. The main difference is that this "update" uses human-readable opcodes (e.g. "JUMP", "CALL"). When I originally composed the music, I used hardcoded memorized byte-instructions, (e.g. 128 for JUMP, 129 for CALL).

The .fxmasm sources contain some trivia about specific songs. The [MUSIC_FORMAT.md](MUSIC_FORMAT.md) file contains the detailed explanation of the music format. Note the important legacy bug with NOISE+ directive explained in that file.

## Disassembler / assembler:

The `fxmasm.lua` LuaJIT script can compile and decompile these music files in the following three ways:

`fxmasm.lua compile source.fxmasm dest.fxm` - Compiles the .fxmasm source file into the dest.fxm binary file which can then be played on PC using e.g. the multiplatform [AY Emul music emulator](https://bulba.untergrund.net/emulator_e.htm) by Sergey Bulba.

`fxmasm.lua compile_raw source.fxmasm dest.bin addr` - Compiles the .fxmasm source file into raw binary file dest.bin which should then be stored in the real ZX Spectrum (or emulator) memory at address `addr`. Specified address can be either hex (e.g. "0x8000") or decimal (e.g. "32768"). The dest.bin file then contains the three double-byte pointers to the datablocks of the three AY voices, followed immediately (i.e. from address `addr+6`) by the voice data itself. This format is basically equal to the FXM file format without the first 6 header bytes and can be used to add FXM format music to your own ZX Spectrum games. Note that this binary file does NOT include the actual Z80 playroutine. You must get it elsewhere.

`fxmasm.lua decompile dest.fxm` - Decompiles the dest.fxm binary file to .fxmasm source text format and outputs it to STDOUT. Works only with `.fxmasm` files (not with `.ay` or other ZX Spectrum music files). The decompiled file cannot be always reliably compiled back to the binary file and requiress some manual modifications first. Those modifications are already applied in the included .fxmsrc files. Also note that some original FXM files cannot be decompiled as they are (e.g. "Rendez-Vous 4") because they are strictly speaking INVALID and play on the real ZX Spectrum hardware only because of sheer luck. These are fixed in this archive.

