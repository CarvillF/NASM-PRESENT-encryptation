# NASM-PRESENT-encryptation
Implementation of PRESENT in NASM code (x86-64 in WSL)

## How to setup - Guía de Inicio: Proyecto PRESENT (Assembler x86-64 en WSL)

Esta guía detalla paso a paso cómo configurar el entorno de desarrollo en Windows utilizando **WSL (Windows Subsystem for Linux)**. 

## 1. Instalar WSL y Ubuntu
Si aún no has activado WSL en tu Windows:

1.  Abre **PowerShell** como Administrador.
2.  Ejecuta el siguiente comando:
    ```powershell
    wsl --install
    ```
3.  Al iniciar, se abrirá una ventana de terminal automáticamente instalando Ubuntu.
4.  Te pedirá crear un **nombre de usuario** y una **contraseña**.
    *   *Nota:* Al escribir la contraseña, no verás asteriscos ni caracteres moverse. Es normal (seguridad de Linux). Escribe y presiona Enter.

## 2. Configurar VS Code
Para editar el código cómodamente desde Windows pero ejecutarlo en Linux:

1.  Instala **Visual Studio Code** en Windows.
2.  Abre VS Code e instala la extensión: **WSL** (de Microsoft).
3.  (Opcional pero recomendado) Instala la extensión **NASM** (de AsciiDoc o similar) para que el código se vea con colores.

## 3. Instalar Herramientas de Compilación
Ahora trabajaremos dentro de la terminal de **Ubuntu**.

1.  Iniciala ejecutando en powershell
    ```powershell
        wsl
    ```
2.  Actualiza los repositorios e instala NASM, Make, GDB y Git:
    ```bash
    sudo apt update
    sudo apt install nasm build-essential gdb git -y
    ```

3.  **Mejorar el Debugger (Importante):**
    GDB puro es difícil de leer. Instalaremos **GEF**, que muestra los registros de la CPU en colores automáticamente. Ejecuta esto en la terminal de Ubuntu:
    ```bash
    bash -c "$(curl -fsSL https://gef.blah.cat/sh)"
    ```
4.  Cierra el terminal

## 4. Clonar el Proyecto desde GitHub
Descargaremos el repositorio desde ubuntu. En la terminal de Ubuntu, ejecuta:

1.  Ve a tu directorio principal y clona el repositorio:
    ```bash
    cd ~
    git clone https://github.com/CarvillF/NASM-PRESENT-encryptation.git
    ```
    *(En caso de haber cerrado el anterior terminal, simplemente abre powershell y ejecuta "wsl")*

2.  Entra en la carpeta del proyecto:
    ```bash
    cd NASM-PRESENT-encryptation
    ```

3.  Abre VS Code conectado a este entorno:
    ```bash
    code .
    ```
    *VS Code se abrirá en Windows, pero editando los archivos del entorno Linux.*


Cuando cierres VScode y el terminal la manera para reingresar al proyecto es repitiendo todos los pasos (menos la sentencia git clone)


## 5. Verificar y Ejecutar
Tienes dos comandos principales en la terminal de VS Code:

### A. Para verificar el entorno (`make test`)
Usa esto **ahora** para confirmar que instalaste todo bien.
1.  Abre la terminal **integrada en VS Code** (Ctrl + ñ). Asegúrate de que diga "wsl" o "bash" en la esquina inferior izquierda.
2.  Ejecuta:
    ```bash
    make test
    ```
3.  **Resultado esperado:**
    *   Compilará `src/test.asm`.
    *   Imprimirá: `VALIDACION EXITOSA: El entorno funciona correctamente.`


### B. Para desarrollar el proyecto (`make run`)
1.  Abre la terminal **integrada en VS Code** (Ctrl + ñ). Asegúrate de que diga "wsl" o "bash" en la esquina inferior izquierda.
2.  Compila y ejecuta:
    ```bash
    make run
    ```
    *Salida esperada:* `Ejecución del archivo`

## 6. Cómo Debuggear (Ver los registros)
Dado que el algoritmo PRESENT requiere ver bits individuales, usaremos GDB con GEF.

1.  En la terminal:
    ```bash
    gdb 02_bin/present
    ```
2.  Dentro de GDB:
    *   Escribe `break _start` (Pone un freno al inicio).
    *   Escribe `run` (Inicia el programa y se detiene).
    *   Verás un panel con colores mostrando los registros (`rax`, `rbx`, etc.).
    *   Escribe `ni` (Next Instruction) para avanzar línea por línea.
    *   Observa cómo cambian los valores de los registros.
    *   Escribe `quit` para salir.

---
**¡Listo!**


