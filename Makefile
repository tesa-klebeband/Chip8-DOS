ASM = nasm -f bin

all: prep chip8.com

prep:
	mkdir -p build

chip8.com: src/chip8.asm
	$(ASM) $^ -o build/$@