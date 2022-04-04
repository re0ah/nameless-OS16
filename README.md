# nameless-OS16

## How build & start?
Load repository, download qemu, make, mkisofs and nasm, go to directory of project and input "sudo make run".
Sorry, build exist now only for linux.

## Philosophy
Write on assembly and feel pain.

## For what?
Killing time. Course work, thesis. Also, having site on django. And this site is my exam. Conveniently, right? https://github.com/re0ah/nameless_os_site

## TODO
- [x] Console
    - [x] Input
    - [x] Input reading
    - [x] Input between of words, deleting between the words
    - [x] Hardware scrolling
    - [x] VRAM free when has no place
    - [ ] History of input
- [ ] FAT12
    - [x] Reading files
    - [x] Creating files
    - [x] Renaming files
    - [x] Copy files
    - [x] Removing files
    - [ ] Writing files
    - [ ] Working that all with syscalls
- [ ] Keyboard
    - [x] Buffer, interruption
    - [x] OS scancodes
    - [x] LED, shift, caps
    - [ ] Spec scancodes (start with 0x80) not working on VirtualBox... WHY?!
- [x] CMOS. Reading time
- [x] Programs for OS: snake, date, dir, ls...
- [x] PIT. Timer
- [x] COM-port read/write.
- [x] System calls
- [x] Execute programs

## Author
Roman Evgenyevich. re0ah.
