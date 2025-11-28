; 00_src/main.asm
section .data
    ; S-Box: S[0..F] = {C,5,6,B,9,0,A,D,3,E,F,8,4,7,1,2}
    sbox db 0xC, 0x5, 0x6, 0xB, 0x9, 0x0, 0xA, 0xD, 0x3, 0xE, 0xF, 0x8, 0x4, 0x7, 0x1, 0x2

    ; S-Box Inversa (Para desencriptacion): InvS[0..F] = {5,E,F,8,C,1,2,D,B,4,6,3,0,7,9,A}
    inv_sbox db 0x5, 0xE, 0xF, 0x8, 0xC, 0x1, 0x2, 0xD, 0xB, 0x4, 0x6, 0x3, 0x0, 0x7, 0x9, 0xA

    ; Mensajes para la interfaz
    msg_start db "Iniciando Cifrado PRESENT...", 10
    len_msg_start equ $ - msg_start
    newline db 10



section .bss
    ; El estado actual del bloque (64 bits / 8 bytes)
    state resq 1   ; resq reserva "Quadword" (8 bytes)

    ; La clave maestra de 80 bits (10 bytes)
    ; Nota: Se alineará a 16 bytes para evitar penalizaciones de rendimiento, aunque usemos 10.
    align 16
    master_key resb 10 
    
    ; Buffer para las 32 subclaves de ronda (32 subclaves * 8 bytes c/u = 256 bytes)
    round_keys resq 32

    ; Vector de Inicialización (IV) para modo CBC (64 bits)
    iv resq 1





section .text
    global _start

_start:
    
    ; 1. Prueba de print_hex
    mov rax, 0x123456789ABCDEF0 ; Un patrón reconocible
    call print_hex              ; Debería imprimir 123456789ABCDEF0 en consola

    ; 2. Prueba básica de acceso a S-Box (Consultar el valor '0xC')
    ; Queremos ver qué hay en la posición 0xC de la tabla (Debería ser 0x4 según la tabla definida arriba)
    lea rbx, [sbox]             ; Cargar dirección base de la tabla
    mov al, 0xC                 ; Índice que queremos buscar
    xlat                        ; Instrucción mágica: AL = [RBX + AL]. Reemplaza AL con el valor de la tabla.
    
    ; Para imprimir este byte resultado, limpiamos el resto de RAX y llamamos print
    and rax, 0xFF               ; Dejamos solo el byte bajo
    call print_hex              ; Debería imprimir ...000004

    ; Salir del programa
    mov rax, 60                 ; sys_exit
    xor rdi, rdi                ; código 0
    syscall



; Función para imprimir un valor hexadecimal de 64 bits en RAX
print_hex:
    push rbx                
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rcx, 16             ; Contador del bucle (16 nibbles)
    mov rbx, rax            ; Copia de seguridad del valor

.loop_hex:
    rol rbx, 4              ; Rotar 4 bits
    mov dl, bl              ; Copiar byte bajo
    and dl, 0x0F            ; Aislar nibble
    
    cmp dl, 9
    jbe .is_digit
    add dl, 7
.is_digit:
    add dl, '0'

    ; --- INICIO DE CORRECCIÓN ---
    push rcx                ; <--- SALVAR RCX: syscall lo destruirá
    
    push dx                 ; Guardamos el caracter en el stack
    mov rax, 1              ; sys_write
    mov rdi, 1              ; fd: stdout
    mov rsi, rsp            ; buffer: stack pointer
    mov rdx, 1              ; len: 1 byte
    syscall
    pop dx                  ; Limpiamos el caracter del stack
    
    pop rcx                 ; <--- RESTAURAR RCX: recuperamos el contador
    ; --- FIN DE CORRECCIÓN ---

    dec rcx                 ; Ahora sí, decrementamos el 16, 15, 14...
    jnz .loop_hex

    ; Imprimir salto de línea (Aquí no importa si RCX muere porque ya salimos del bucle)
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]      
    mov rdx, 1
    syscall

    pop rdi                 
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret