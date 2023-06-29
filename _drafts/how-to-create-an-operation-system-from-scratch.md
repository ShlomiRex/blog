---
title: "How to create an operation system from scratch"
published: true
layout: post
toc: true
---
I always wanted to understand how computers boot into the linux kernel.

In this post, I will summorize all of my knowledge that I collected. 

This post is targeted torward advanced users, those who studied computer science or has a background.

# Boot process

The first step is to understand how the computer reaches our kernel code from BIOS.

After POST occurs, which checks that the hardware works correctly, the BIOS starts the bootloader.

It looks for each bootable device (disk, floppy drive, cd rom). For each of the storage media is looks for sector 1 (first sector).

In sector 1 of the boot device, if the last 2 bytes are the magic bytes `0xAA55` then the device can be booted.

This is caled `Master Boot Record (MBR)`, thats how the BIOS knows if it should boot from that device. Today we use UEFI, but its not important, since MBR is simpler and I'll use it instead.

Note: the BIOS looks for each device in predefined order in the BIOS menu (boot order).

The first 510 bytes of sector 1 are the assembly code. This assembly code will be interacting with BIOS interrupts.

# Run assembly code in bootloader

Basic code that does nothing:

{% highlight nasm %}
ORG 0x7c00
BITS 16

jmp $

times 510-($ - $$) db 0
dw 0xAA55
{% endhighlight %}

The last 2 bytes are the magic `0x55AA` bytes

The first 510 bytes are the `jmp $` instruction which jumps to the same line as current instruction (infinite loop).

And the rest of the bytes are zeros (`jmp $` takes 3 bytes, so we are left with 510-3=507 bytes are zeros).

`BITS 16` means we are running in real-mode, and `ORG 0x7C00` is the offset from where we start.

Notice that we are working in little-endian (default for most CPU architectures to use little-endian), and so 0xAA55 appears as last bytes like so: `55 AA`.

Side note: big endian is used commonly in networking, I won't go into the reason, but its primaraly performance (little-endian) and readability (big-endian).

# Running the bootsector

To run the bootsector we can use `QEMU` which is an emulator that can run on any CPU architecture hosts that are different CPU architecture.

For example I can run x64 operation system in macOS M1 (which is arm64).

Here is screenshot showing running `QEMU` with the bootsector code below:

```
nasm bootsector.asm -f bin -o boot.img
qemu-system-x86_64 boot.img
```

![](/assets/2023-6/Screenshot 2023-06-29 211050.png)

## Print 'Hello World' in assembly

Code:

{% highlight nasm %}
[global Start]
[BITS 16]
[ORG 0x7C00]

section .text
Start:
    mov si, String                      ;Store string pointer to SI
    call PrintString                    ;Call print string procedure
    jmp $                               ;Infinite loop, hang it here.

PrintCharacter:                         ;Procedure to print character on screen
                                        ;Assume that ASCII value is in register AL
    mov ah, 0x0E                        ;Tell BIOS that we need to print one charater on screen.
    mov bh, 0x00                        ;Page no.
    mov bl, 0x07                        ;Text attribute 0x07 is lightgrey font on black background
    int 0x10                            ;Call video interrupt
    ret                                 ;Return to calling procedure
PrintString:                            ;Procedure to print string on screen
                                        ;Assume that string starting pointer is in register SI
    next_character:                     ;Lable to fetch next character from string
        mov al, [SI]                    ;Get a byte from string and store in AL register
        inc SI                          ;Increment SI pointer
        or AL, AL                       ;Check if value in AL is zero (end of string)
        jz exit_function                ;If end then return
        call PrintCharacter             ;Else print the character which is in AL register
        jmp next_character              ;Fetch next character from string
        exit_function:                  ;End label
        ret                             ;Return from procedure
String db 'Hello World', 0              ;HelloWorld string ending with 0

times 510 - ($ - $$) db 0               ;Fill the rest of sector with 0
dw 0xAA55                               ;Add boot signature at the end of bootloader
{% endhighlight %}