# Makefile contributed by jtsiomb

src = lights.asm

.PHONY: all
all: lights.img

lights.img: $(src)
	nasm -f bin -l lights.lst -o $@ $(src)

.PHONY: clean
clean:
	$(RM) lights.img

.PHONY: runqemu
runqemu: lights.img
	qemu-system-i386 -fda lights.img
