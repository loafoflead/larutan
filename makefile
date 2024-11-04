RAYLIB_LIBRARY_SEARCH_PATH = ./raylib-5.0/lib
RAYLIB_LIB_NAME = raylib
C3_STD = --stdlib /usr/local/lib

OUTPUT_NAME = main

fast: src/main.c3
	c3c compile src/*.c3 -O3 -l $(RAYLIB_LIB_NAME) -L $(RAYLIB_LIBRARY_SEARCH_PATH) $(C3_STD) -o $(OUTPUT_NAME) 

run: main
	./$(OUTPUT_NAME)

main: src/main.c3
	c3c compile src/*.c3 -l $(RAYLIB_LIB_NAME) -L $(RAYLIB_LIBRARY_SEARCH_PATH) $(C3_STD) -o $(OUTPUT_NAME) 

clean:
	rm $(OUTPUT_NAME)
