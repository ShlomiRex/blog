---
title: "How to create an operation system from scratch"
published: true
layout: post
toc: true
---
I always wanted to understand how computers boot into the linux kernel.

In this post, I will summorize all of my knowledge that I collected. 

This post is targeted torward advanced users, those who studied computer science or has a background. And also people who researched about OS development. Here it is summorized easily.

Before we start, let me list the most useful resources for OS development:

- [OSDev.org wikipedia](https://wiki.osdev.org/Expanded_Main_Page)
- [Writing a Simple Operating System — from Scratch by Nick Blundell](https://www.cs.bham.ac.uk/~exr/lectures/opsys/10_11/lectures/os-dev.pdf)
- [BIOS Interrupts and Functions](https://ostad.nit.ac.ir/payaidea/ospic/file1615.pdf)

## Boot process

The first step is to understand how the computer reaches our kernel code from BIOS.

After POST occurs, which checks that the hardware works correctly, the BIOS starts the bootloader.

It looks for each bootable device (disk, floppy drive, cd rom). For each of the storage media is looks for sector 1 (first sector).

In sector 1 of the boot device, if the last 2 bytes are the magic bytes `0xAA55` then the device can be booted.

This is caled `Master Boot Record (MBR)`, thats how the BIOS knows if it should boot from that device. Today we use UEFI, but its not important, since MBR is simpler and I'll use it instead.

Note: the BIOS looks for each device in predefined order in the BIOS menu (boot order).

The first 510 bytes of sector 1 are the assembly code. This assembly code will be interacting with BIOS interrupts.

![](/assets/2023-6/Screenshot 2023-06-29 214257.png)

## Run assembly code in bootloader

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

`BITS 16` means we are running in real-mode, and `ORG 0x7C00` is the offset from where we start. The BIOS always loads our bootsector onto address 0x7C00. The BIOS did hardware initialization and other checks, those required some memory. So to avoid our code to override the BIOS memory, it puts our code in predefined memory area 0x7C00 (in RAM).

We are working in `16-bits` which means we can only use addresses up to 2 bytes long.

Notice that we are working in little-endian (default for most CPU architectures to use little-endian), and so 0xAA55 appears as last bytes like so: `55 AA`.

Side note: big endian is used commonly in networking, I won't go into the reason, but its primaraly performance (little-endian) and readability (big-endian).

## Running the bootsector

To run the bootsector we can use `QEMU` which is an emulator that can run on any CPU architecture hosts that are different CPU architecture.

For example I can run x64 operation system in macOS M1 (which is arm64).

Here is screenshot showing running `QEMU` with the bootsector code below:

```
nasm bootsector.asm -f bin -o boot.img
qemu-system-x86_64 boot.img
```

![](/assets/2023-6/Screenshot 2023-06-29 211050.png)

### Print 'Hello World' in assembly

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

Here is the hexdump of the program:

![](/assets/2023-6/Screenshot 2023-06-29 212153.png)

We can see 'Hello World' appears in the dump, aswell as the last 2 magic bytes.

We can continue to play with assembly and do whatever we want in assembly, but we want to load the kernel.

## Understand CPU addressing

In 16-bit real-mode the CPU has 3 registers that are used for addressing:

1. `CS` - Code Segment
2. `DS` - Data Segment
3. `SS` - Stack Segment

You should read on the internet about them. Understand segments.

In a nutshell the addressing mode is called `segment:offset`:

We can access up to 1MB of effective address using segments. An effective address is computed by combining the base address from the segment register and the offset value. When we run `mov ax, [0xffff]` the CPU will take the value of `DS` and multiply it by 16 and add it to the address. So if `DS` is `0x1000`, then the address will be `0x1000*16 + 0xffff`.

Notice: `0xffff*16 + 0xffff = 0x10FFEF = 1,114,095` which is a little mode than 20 bits (`2^10=1,048,576`).

## Understand Disk I/O - CHS - Cylinder, Head, Sector

When we talk about hard drives, to get desired memory block we need to know where to read from or write to. 

This is where the CHS comes from. It specifies the cylinder, head and sector of the hard drive. Basically it is a 3D coordinate system.

![](/assets/2023-6/1024px-Hard_drive_geometry_-_English_-_2019-05-30.svg.png)

In a nutshell, cylinder is what physical platter we read from (in blue), head (or track) is the radius of the platter (in yellow), and sector is the angle of the platter (in red).

## Read from disk

Now we want to read different sectors of our code. Since 512 bytes isn't enough, we will make a bootable image of 2 sectors (1024 bytes).

The first sector will be regular bootsector code, and the second sector will be filled with 0xFF bytes. The first sector will read 16 bytes of the second sector and print it to the screen.

## Understand the stack: SP, BP, SS

The stack is used for when we push or pop values. It grows from high address to low address. It grows downwards.

When we push a value, the stack pointer `SP` is decremented by the amount of bytes of the value.

When we pop a value, the stack pointer `SP` is incremented by the amount of bytes of the value, and the value is stored inside a register.

The `SP` points to the top element of the stack (last element pushed).

Now we have 2 more registers to talk about:

1. `BP` - Base Pointer
2. `SS` - Stack Segment

The `BP` register is like the stack frame. It points to the start (base) of the current stack frame. Stack frame is a block of memory when usually when we call a function. The stack frame is used to store local variables, and other data in the current local scope.

So the `BP` points to the current stack frame. It is used to debug the current stack frame for each stack frame, so its used extensively in debugging.

We can calculate how much bytes a function used the stack by subtracting `BP` from `SP`.

Lastly, the `SS` register is the stack segment. It is used to tell the CPU where the stack is located in memory (beginning of the entire stack, where it begins). It is used with the `SP` register to calculate the effective address of the stack. It is used in combination with `SP` to reach high effective address, more than a single register can hold (more than 2 bytes).

For example of `SS = 0xAAAA` and `SP = 0x0001`, then the effective address of the top of stack is `0xAAAA*16 + 0x0001 = 0xAAAA0 + 0x0001 = 0xAAAA1`.

Here is an image describing the stack:

![](/assets/2023-6/Screenshot 2023-06-30 180924.png)

This is my code. It first prints the value of `SP` register (`0x6F00`)

Then it pushes `AX` onto stack, which should decrement `SP` by 2, and we get `0x6EFE`;

Then it pops back `AX` from the stack, which should increment `SP` by 2, and we get `0x6F00` again.


## Initializing the stack

We need to initialize the stack, so when we use it, it wont override other memory. Remember: the stack grows downwards.

Since our code starts at `0x7C00`, then if we initialize the stack pointer to `0x7C01`, after one byte push the stack pointer will override `0x7C01`, which is our code. We don't want that.

So we need to initialize the stack pointer to a higher address, or lower address. If we do it higher than `0x7C00` we still have to worry about the stack growing downwards. But if we initialize it to a lower address (lower than `0x7C00`), then it can't override our code. We 
