; src/test.asm
section .data
    msg db "VALIDACION EXITOSA: El entorno funciona correctamente.", 0xA
    len equ $ - msg

section .text
    global _start

_start:
    ; --- 1. Prueba de Syscall (Escribir en pantalla) ---
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, msg        ; mensaje
    mov rdx, len        ; longitud
    syscall

    ; --- 2. Prueba de Registros (Para ver en Debugger) ---
    mov rbx, 0xCAFEBABE ; Cargar valor hexadecimal
    not rbx             ; Invertir bits
    
    ; --- 3. Salir ---
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; exit code 0
    syscall