#!/usr/bin/python
# -*- coding: utf-8 -*-
from pathlib import Path

if __name__ == '__main__':
    buf = None
    with open("kernel.asm", "r") as fptr:
        buf = fptr.read()
        kernel_fsize = Path("kernel.bin").stat().st_size
        buf = buf.replace("0xFFFF ; SPECIAL_KEYWORD_PREPROCESSOR", f"{kernel_fsize}")
    with open("kernel.asm", "w") as fptr:
        fptr.write(buf)

