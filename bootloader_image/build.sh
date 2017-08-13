nasm -f bin -o bootloader.bin bootloader_image.asm
dd status=noxfer conv=notrunc if=bootloader.bin of=bootloader.flp
qemu-system-i386 -fda bootloader.flp
