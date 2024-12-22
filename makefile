RAYLIB_VER = 5.5
RAYLIB_LIBRARY_SEARCH_PATH = /usr/local/lib/raylib-$(RAYLIB_VER)/lib
RAYLIB_LIB_NAME = raylib
C3_STD = --stdlib /usr/local/lib

OUTPUT_NAME = ./build/main

INCLUDES = \
	./src/enemy/*.c3  		\
	./src/bindings/*.c3	\
	./src/entity/*.c3		\
	./src/rendering/*.c3	\
	./src/utils/*.c3		\
	./src/world/*.c3
# FOLDERS = "src/bindings/*.c3 src/enemy/*.c3 src/entity/*.c3 src/rendering/*.c3 src/utils/*.c3 src/world/*.c3"

fast: src/main.c3
	c3c compile src/*.c3 $(INCLUDES) -O3 -l $(RAYLIB_LIB_NAME) -L $(RAYLIB_LIBRARY_SEARCH_PATH) $(C3_STD) -o $(OUTPUT_NAME) 

run: main
	./$(OUTPUT_NAME)

main: src/main.c3
	c3c compile src/*.c3 $(INCLUDES) -l $(RAYLIB_LIB_NAME) -L $(RAYLIB_LIBRARY_SEARCH_PATH) $(C3_STD) -o $(OUTPUT_NAME) 

clean:
	rm $(OUTPUT_NAME)
