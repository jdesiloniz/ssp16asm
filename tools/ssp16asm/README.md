# ssp16asm

A quick and dirty assembler for the Samsung SSP16xx family of DSPs, notably known for its use (contained within the **SVP** chip - *Sega Virtua Processor*) in the Mega Drive/Genesis version of the game **Virtua Racing**.

## How to use

Assembling a source file is as easy as running:

```
ssp16asm source.sc target.o
```

If everything goes right, after executing the assembler and passing the input source file and the intended target file, you should have an assembled file in few seconds. Otherwise you'll see a list of (more or less informative) errors that can help you fix any issues.

### Optional useful parameters:

- `base_file`: Loads a binary to write the assembled code onto. Useful if the resulting code needs to be combined with code from a different architecture (i.e.: Motorola 68000 code).
- `fill`: Fills the resulting binary file with 0s until the specified maximum binary size (by default 4MB).
- `1meg`: Specifies a maximum binary file size of 1MB if `--fill` is in use.
- `2meg`: Specifies a maximum binary file size of 2MB if `--fill` is in use.
- `4meg`: Specifies a maximum binary file size of 4MB if `--fill` is in use (if not specified, this is the default maximum binary size). Note: the code is generated using 4MB as a base, and then truncated to the specified size.
- `hex`: Generates an alternative file containing the resulting code as a list of 16 bit hexadecimal values (to be used as source in HDL designs).

## Assembly style

This assembler follows most of the terminology used by the sample sources originally provided by Samsung on their website about this DSP family, even though it's incompatible with some other styles around (i.e.: with Virtua Racing's SVP disassemblies, especially regarding register names).

### Instruction set

All instructions are parsed regardless of letter case.

#### Control instructions

* `RET`.
* `BRA cond, address` (i.e.: `BRA always, 1200`).
* `CALL cond, address` (i.e.: `CALL z=0, 1200`).
* `MOD cond, operation` (i.e.: `MOD n=1, shr`).
* `MOD f, flag_operation` (i.e.: `MOD f, resop`).

Conditions include all flags (`l`, `n`, `z`, `ov`, `gpi0`, `gpi1`, `gpi2`, `gpi3`, `diof`) followed by an equal sign and its intended state, or the operand `always`. In the case of `MOD` instead of performing a jump to an address, if the provided condition is fulfilled a certain operation will be applied to the accumulator (`ror`, `rol`, `shr`, `shl`, `inc`, `dec`, `neg`, `abs`). Flag operations include: `resl`, `setl`, `resie`, `setie`, `resop`, `setop`, `res`, `set`.

#### Arithmetic instructions

Six arithmetic operations (`sub`,`cmp`, `add`, `and`, `or`, `eor`) can be applied to the accumulator in different fashions, depending on the operands after them. If a numeric value is used as part of the instruction, it's followed by a suffix `i` (i.e.: `subi`, `cmpi`...). Also, for those cases, the syntax can change when they are followed by bytes or words. i.e.:

* `OPi A, word` (i.e.: `ANDI A, 1138`).
* `OPi byte` (i.e.: `EORI FF`).
* `OP A, X` (i.e.: `CMP A, X`).

#### Load instructions

There's only one load opcode (`LD`). As with the arithmetic instructions, `LD` can also be used with numeric values. For load instructions only words are allowed:

* `LD A, 0009`.
* `LD A, 8080`.

Except when the other operand is a byte register:

* `LD R0, 0F`.

Loads can also use addresses in RAM banks A or B within the DSP, for those cases `A[addr]` or `B[addr]` syntax is used (`addr` being a 8-bit number). These addresses can be used as source or destination operand, as long as the other operand is always the **accumulator** register:

* `LD A[0x0A], A`
* `LD A, B[0xFF]`

#### DSP instructions

This family of DSPs provides multiple instructions for multiplication and addition/substraction operations, all using pointer registers as operands:

* `MLD (RX), (RY)` (i.e.: `MLD (R4+!), (R0+)`).
* `MPYA (RX), (RY)` (i.e.: `MPYA (R5), (R2+)`).
* `MPYS (RX), (RY)` (i.e.: `MPYS (R4!), (R0-)`).

Note that the pointer registers used as operands to define where in memory are the operands should always be in that order (RAM bank B/RAM bank A). Both operands can't be in the same RAM bank.

### Registers

This family of DSP comes with two main types of registers: general and pointer registers. Among the general kind, there are eight _external_ registers:

* General registers: `-`, `X`, `Y`, `A`, `ST`, `STACK`, `PC`, `P`.
* External registers: `ext0`, `ext1`, `ext2`, `ext3`, `ext4`, `ext5`, `ext6`, `ext7`.
* Pointer registers: `R0`, `R1`, `R2`, `R3`, `R4`, `R5`, `R6`, `R7`.

Those can be referred to directly (by just specifying the name of the register), with a first level of indirection expressed with a single set of parenthesis and a second level being express as a double set of parenthesis.

Indirections can also modify the value of the register itself by incrementing (`+`), modulo-incrementing (`+!`), modulo-decreasing it (`-!`) in registers `R0`, `R1`, `R2`, `R4`, `R5` and `R6`. Two of the pointer registers (`R3` and `R7`) have a different indirection mode: they always contain the value 0, but can be directly addressed by using these four modifiers: `|00`, `|01`, `|10`, `|11` - that is: to access first, second, third or fourth position within each memory bank (they're meant to be used as a software stack).

* `LD R0, X`
* `LD (R0!+), Y`.
* `LD A, ((R2))`.
* `LD B, (R7|01)`.

### Operands

All numeric values are expressed as hexadecimal numbers. Typical syntaxis to stress this (i.e: `0x` prefix and `h` suffix) will be ignored. The size of the number will be implied by its size:

* Bytes are expressed by any number of 1 or 2 figures (i.e: `0` or `FF`).
* Words are expressed by any number of 3 or 4 figures (i.e.: `0000`, `100`, `FFFF`).

Not all operations are compatible with bytes or words, so please take this into account. 

### Assembler directives

A few of the typical assembler directives have been implemented:

* `ORG`: sets the current address to assemble to.
* `DW`: writes a word in the assembled file. Supports multiple words with a single macro.
* `EQU`: ties a word-sized constant value to a label (i.e.: `constant_label: EQU 00FF`).
* `EQUB`: ties a byte-sized constant value to a label (i.e.: `constant_label: EQU FF`).

### Labels

A label is expressed by a string followed by a colon sign (i.e.: `label_name:`). Then they can be addressed to in the code by prefixing them with an `@` sign (i.e.: `@label_name`).  These can serve two purposes:

* Pointers to different parts of the assembled file (i.e.: markers to tables in the source). These pointers are stored in the *symbol table*.
* Constants built with the `EQU`/`EQUB` directives. These will be stored in their *constants tables* and substituted by word/byte values during assembly.

## Compatibility

This assembler was originally built with the intention of being used to test an FPGA-based implementation of the SSP1601 DSP found inside the Mega Drive/Genesis version of Virtua Racing. As it was built quickly to perform simple tests, expect its use to be a little bit quirky. Now that the door has opened to proper development using the actual SVP chip, expect improvements in the future. 

There's also quite a lack of proper information on this family of DSPs (with the exception of all the reverse engineering done to Virtua Racing during the past decade), so there may be compatibility issues between different versions of the core. If you have further information about the different models, please feel free to let me know so we can have the most complete assembler possible for this family of devices :).

## Code style

This was my first real project built in Rust (during my spare time in the span of a week, after learning the language during another week), so I'm pretty sure that saying there's room for improvement here is an understatement :). Please feel free to send suggestions, or even better... pull requests! :D

## TODO

* More intensive testing.
* DUP assembler macro.
* Includes somewhere down the line...?
* Meaningful errors including code lines, etc.

## Acknowledgement

To all the people responsible for sheding light on the mysteries surrounding the first home console version of Virtua Racing and the reverse engineering of the SSP1601 DSP (i.e.: *notaz*, *Tasco Deluxe*, *Pierpaolo Prazzoli*, *Grazvydas Ignotas* and many others), thanks a lot for your awesome knowledge and commitment!

## License

This code is MIT-licensed. Also take into account the following conditions of use:

* Please use this code for good. Also for fun. But good fun, not evil fun.
* If you build something really cool (moderately cool also works) please drop me a comment at `taiyou[at]gmail.com`.
* You're not forced, but if you use this code I'd appreciate if you could acknowledge me :).