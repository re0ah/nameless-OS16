#!/usr/bin/python
# -*- coding: utf-8 -*-
from pathlib import Path

if __name__ == '__main__':
    buf = ""
    with open("kernel.asm", "r") as fptr:
        for line in fptr:
            if line.startswith("KERNEL_SIZE equ"):
                line = "KERNEL_SIZE equ 0xFFFF ; SPECIAL_KEYWORD_PREPROCESSOR\n"
            buf += line
    with open("kernel.asm", "w") as fptr:
       fptr.write(buf)

