CC=gcc

pulse: main.c
	mkdir -p build/
	$(CC) main.c -o build/main