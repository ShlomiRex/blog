---
title: "How to create an operation system from scratch"
published: true
layout: post
---

I always wanted to understand how computers boot into the linux kernel.

In this post, I will summorize all of my knowledge that I collected. 

This post is targeted torward advanced users, those who studied computer science or has a background.

# Boot process

The first step is to understand how the computer reaches our kernel code from BIOS.

After POST occurs, which checks that the hardware works correctly, the BIOS starts the bootloader.

It looks for each bootable device (disk, floppy drive, cd rom). For each of the storage media is looks for sector 1 (first sector).

In sector 1 of the boot device, if the last 2 bytes are the magic bytes 0x55AA then the device can be booted.

This is caled Master Boot Record, thats how the BIOS knows if it should boot from that device.

Note: the BIOS looks for each device in predefined order in the BIOS menu (boot order).

The first 510 bytes of sector 1 are the assembly code. This assembly code will be interacting with BIOS interrupts.

## Run assembly code in first sector

```
ORG 0x7c00
BITS 16

start:
	mov ah, 0eh
	mov al, 'A'
	int 0x10
	jmp $

times 510-($ - $$) db 0
dw 0xAA55
```