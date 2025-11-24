# Variables
ASM = nasm
LD = ld
ASM_FLAGS = -f elf64 -g -F dwarf
LD_FLAGS = 

# Archivos
SRC_MAIN = 00_src/main.asm
OBJ_MAIN = 01_obj/main.o
BIN_MAIN = 02_bin/present

SRC_TEST = 00_src/test.asm
OBJ_TEST = 01_obj/test.o
BIN_TEST = 02_bin/test

# --- Reglas Principales ---

# Por defecto, compila el proyecto principal
all: $(BIN_MAIN)

# Regla para probar el entorno (Test)
test: $(BIN_TEST)
	@echo "--- Ejecutando Test de Entorno ---"
	@./$(BIN_TEST)

# Regla para correr el proyecto principal
run: $(BIN_MAIN)
	@echo "--- Ejecutando Proyecto PRESENT ---"
	@./$(BIN_MAIN)

# --- Compilación y Enlazado ---

# Main Project
$(BIN_MAIN): $(OBJ_MAIN)
	@mkdir -p 02_bin
	$(LD) $(LD_FLAGS) -o $(BIN_MAIN) $(OBJ_MAIN)

$(OBJ_MAIN): $(SRC_MAIN)
	@mkdir -p 01_obj
	$(ASM) $(ASM_FLAGS) $(SRC_MAIN) -o $(OBJ_MAIN)

# Test File
$(BIN_TEST): $(OBJ_TEST)
	@mkdir -p 02_bin
	$(LD) $(LD_FLAGS) -o $(BIN_TEST) $(OBJ_TEST)

$(OBJ_TEST): $(SRC_TEST)
	@mkdir -p 01_obj
	$(ASM) $(ASM_FLAGS) $(SRC_TEST) -o $(OBJ_TEST)

# Limpieza
clean:
	rm -rf 01_obj/*.o 02_bin/*