; src/main.asm
section .data
    ; Aquí irán las tablas S-Box y variables

section .bss
    ; Aquí irán los buffers (texto plano, cifrado, claves)

section .text
    global _start

_start:
    ; --- AQUÍ COMENZARÁ EL CÓDIGO DEL PROYECTO ---
    
    ; Por ahora, solo salimos limpiamente para comprobar compilación
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; exit code 0
    syscall