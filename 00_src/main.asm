; =============================================================================
; PROYECTO FINAL: IMPLEMENTACIÓN DE PRESENT-80 (ASM X86-64)
; Autores: Carlos Flores, Benjamín Dillon
; Funcionalidad: Cifrado CBC con Padding PKCS#7 y gestión de claves
; =============================================================================

section .data
    ; Tablas criptográficas
    sbox db 0xC, 0x5, 0x6, 0xB, 0x9, 0x0, 0xA, 0xD, 0x3, 0xE, 0xF, 0x8, 0x4, 0x7, 0x1, 0x2
    inv_sbox db 0x5, 0xE, 0xF, 0x8, 0xC, 0x1, 0x2, 0xD, 0xB, 0x4, 0x6, 0x3, 0x0, 0x7, 0x9, 0xA

    pbox db 0, 16, 32, 48, 1, 17, 33, 49, 2, 18, 34, 50, 3, 19, 35, 51
         db 4, 20, 36, 52, 5, 21, 37, 53, 6, 22, 38, 54, 7, 23, 39, 55
         db 8, 24, 40, 56, 9, 25, 41, 57, 10, 26, 42, 58, 11, 27, 43, 59
         db 12, 28, 44, 60, 13, 29, 45, 61, 14, 30, 46, 62, 15, 31, 47, 63

    inv_pbox db 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60
             db 1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61
             db 2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62
             db 3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 51, 55, 59, 63
    
    ; Datos de prueba
    test_msg db "Hola Mundo" 
    len_test_msg equ $ - test_msg

    ; Mensajes de interfaz
    msg_start db "===============================================", 10, "PROYECTO PRESENT-80: Cifrado CBC + Padding", 10, "===============================================", 10, 0
    len_msg_start equ $ - msg_start
    
    msg_orig db "[*] Mensaje Original: ", 0
    len_msg_orig equ $ - msg_orig

    msg_pad  db "[*] Padding PKCS#7 aplicado correctamente.", 10, 0
    len_msg_pad equ $ - msg_pad

    msg_res  db "[*] Resultado Cifrado (Hexadecimal):", 10, 0
    len_msg_res equ $ - msg_res

    msg_dec_res db 10, "[*] Resultado Descifrado (Texto): ", 0
    len_msg_dec_res equ $ - msg_dec_res
    
    msg_input_prompt db "[*] Ingrese el texto a cifrar (máx 4096 bytes): ", 0
    len_msg_input_prompt equ $ - msg_input_prompt
    
    msg_read_error db "[ERROR] Fallo al leer entrada.", 10, 0
    len_msg_read_error equ $ - msg_read_error
    
    msg_eof db "[INFO] EOF detectado. No hay datos para procesar.", 10, 0
    len_msg_eof equ $ - msg_eof
    
    msg_bytes_read db "[*] Bytes leídos: ", 0
    len_msg_bytes_read equ $ - msg_bytes_read
    
    ; Mensajes para manejo de archivos
    msg_usage db "Uso: ./present <archivo>", 10, "Ejemplo: ./present input.txt", 10, 0
    len_msg_usage equ $ - msg_usage
    
    msg_file_open db "[*] Abriendo archivo: ", 0
    len_msg_file_open equ $ - msg_file_open
    
    msg_file_error db "[ERROR] No se pudo abrir el archivo.", 10, 0
    len_msg_file_error equ $ - msg_file_error
    
    msg_file_success db "[*] Archivo abierto exitosamente.", 10, 0
    len_msg_file_success equ $ - msg_file_success
    
    newline db 10, 0

section .bss
    ; Buffers de memoria
    align 16
    master_key resb 16
    round_keys resq 32
    iv resq 1
    
    ; Buffers expandidos a 4KB con alineación de 64 bytes
    align 64
    plaintext resb 4096
    align 64
    ciphertext resb 4096
    align 64
    decrypted_text resb 4096
    
    actual_read_length resq 1
    file_descriptor resq 1

section .text
    global _start

_start:
    ; Verificar argumentos de línea de comandos
    ; Estructura del stack: [rsp]=argc, [rsp+8]=argv[0], [rsp+16]=argv[1]
    mov rax, [rsp]
    cmp rax, 2
    jl .show_usage
    
    mov r13, [rsp + 16]         ; R13 = puntero al nombre del archivo
    
    ; Imprimir encabezado
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_start]
    mov rdx, len_msg_start
    syscall

    ; Abrir archivo
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_open]
    mov rdx, len_msg_file_open
    syscall
    
    ; Calcular longitud del nombre de archivo
    mov rsi, r13
    call strlen
    mov r15, rax
    
    ; Imprimir nombre del archivo
    mov rax, 1
    mov rdi, 1
    mov rsi, r13
    mov rdx, r15
    syscall
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
    
    ; sys_open
    mov rax, 2
    mov rdi, r13
    mov rsi, 0                  ; O_RDONLY
    mov rdx, 0
    syscall
    
    cmp rax, 0
    jl .file_open_error
    
    mov r14, rax                ; R14 = file descriptor
    lea rbx, [file_descriptor]
    mov [rbx], rax
    
    ; Confirmar apertura exitosa
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_success]
    mov rdx, len_msg_file_success
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_orig]
    mov rdx, len_msg_orig
    syscall

    ; Leer contenido del archivo
    mov rdi, r14
    lea rsi, [plaintext]
    call read_input_dynamic
    
    ; Cerrar archivo
    mov rax, 3
    mov rdi, r14
    syscall
    
    ; Mostrar bytes leídos
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_bytes_read]
    mov rdx, len_msg_bytes_read
    syscall
    
    mov rax, r12
    call print_decimal
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall

    ; Configuración criptográfica
    lea rdi, [master_key]
    mov qword [rdi], 0
    mov word [rdi+8], 0
    call generate_round_keys

    lea rdi, [iv]
    mov rax, 0x0123456789ABCDEF
    mov [rdi], rax

    ; Aplicar padding
    lea rdi, [plaintext]
    mov rsi, r12
    call apply_padding
    
    push rax

    ; Confirmar padding
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_pad]
    mov rdx, len_msg_pad
    syscall

    ; Cifrado CBC
    pop rax
    push rax
    
    shr rax, 3
    mov rcx, rax

    lea rsi, [plaintext]
    lea rdi, [ciphertext]
    call present_encrypt_cbc

    ; Mostrar resultado cifrado
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_res]
    mov rdx, len_msg_res
    syscall

    ; Imprimir bloques cifrados
    pop rax
    push rax
    shr rax, 3
    mov rcx, rax
    lea rsi, [ciphertext]

.print_loop:
    push rcx
    push rsi
    
    mov rax, [rsi]
    call print_hex
    
    pop rsi
    pop rcx
    
    add rsi, 8
    dec rcx
    jnz .print_loop

    ; Descifrado CBC
    lea rdi, [iv]
    mov rax, 0x0123456789ABCDEF
    mov [rdi], rax

    pop rax
    push rax
    shr rax, 3
    mov rcx, rax
    
    lea rsi, [ciphertext]
    lea rdi, [decrypted_text]
    call present_decrypt_cbc

    ; Mostrar resultado descifrado
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_dec_res]
    mov rdx, len_msg_dec_res
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [decrypted_text]
    pop rdx
    syscall
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall

    ; Salida normal
    mov rax, 60
    xor rdi, rdi
    syscall

; Manejadores de error
.show_usage:
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_usage]
    mov rdx, len_msg_usage
    syscall
    
    mov rax, 60
    mov rdi, 1
    syscall

.file_open_error:
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_error]
    mov rdx, len_msg_file_error
    syscall
    
    mov rax, 60
    mov rdi, 2
    syscall







; FUNCIONES AUXILIARES

; Padding PKCS#7
; Entrada: RDI = buffer, RSI = longitud
; Salida: RAX = nueva longitud
apply_padding:
    mov rax, rsi
    and rax, 7                  ; length % 8
    
    mov rcx, 8
    sub rcx, rax                ; bytes a agregar
    
    mov rdx, rcx
    add rdi, rsi
    
    mov al, dl
.pad_loop:
    mov [rdi], al
    inc rdi
    dec rcx
    jnz .pad_loop
    
    lea rax, [rsi + rdx]
    ret

; Lectura dinámica desde file descriptor
; Entrada: RDI = file descriptor, RSI = buffer
; Salida: RAX/R12 = bytes leídos
read_input_dynamic:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov r15, rdi
    mov r12, rsi
    
    ; sys_read
    mov rax, 0
    mov rdi, r15
    mov rsi, r12
    mov rdx, 4096
    syscall
    
    cmp rax, 0
    jl .read_error
    je .read_eof
    
    mov r12, rax
    lea rbx, [actual_read_length]
    mov [rbx], rax
    
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
    
.read_error:
    push rax
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_read_error]
    mov rdx, len_msg_read_error
    syscall
    
    pop rax
    mov rax, 60
    mov rdi, 1
    syscall
    
.read_eof:
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_eof]
    mov rdx, len_msg_eof
    syscall
    
    mov rax, 60
    xor rdi, rdi
    syscall

; Imprimir número decimal
; Entrada: RAX = número
print_decimal:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rcx, 0
    mov rbx, 10
    
    cmp rax, 0
    jne .convert_loop
    
    push '0'
    inc rcx
    jmp .print_digits
    
.convert_loop:
    cmp rax, 0
    je .print_digits
    
    xor rdx, rdx
    div rbx
    add rdx, '0'
    push rdx
    inc rcx
    jmp .convert_loop
    
.print_digits:
    cmp rcx, 0
    je .done
    
    pop rdx
    push rcx
    push rdx
    
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall
    
    pop rdx
    pop rcx
    dec rcx
    jmp .print_digits
    
.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Calcular longitud de string
; Entrada: RSI = string
; Salida: RAX = longitud
strlen:
    push rsi
    push rcx
    
    xor rax, rax
    
.strlen_loop:
    cmp byte [rsi], 0
    je .strlen_done
    inc rsi
    inc rax
    jmp .strlen_loop
    
.strlen_done:
    pop rcx
    pop rsi
    ret

; Cifrado CBC
; Entrada: RSI = plaintext, RDI = ciphertext, RCX = bloques
present_encrypt_cbc:
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r15
    mov r15, [iv]

.cbc_loop:
    mov rax, [rsi]
    xor rax, r15
    call present_encrypt_block
    mov [rdi], rax
    mov r15, rax
    add rsi, 8
    add rdi, 8
    dec rcx
    jnz .cbc_loop

    pop r15
    pop rdi
    pop rsi
    pop rdx
    pop rbx
    pop rax
    ret

; Cifrar un bloque PRESENT
; Entrada: RAX = plaintext
; Salida: RAX = ciphertext
present_encrypt_block:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    lea rsi, [round_keys]
    mov rcx, 1

.encrypt_loop:
    mov rbx, [rsi]
    xor rax, rbx
    add rsi, 8
    
    push rcx
    push rsi
    call sBoxLayer
    pop rsi
    pop rcx
    
    push rcx
    push rsi
    call pLayer
    pop rsi
    pop rcx
    
    inc rcx
    cmp rcx, 32
    jl .encrypt_loop

    mov rbx, [rsi]
    xor rax, rbx
    
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Generación de claves de ronda
generate_round_keys:
    lea rsi, [master_key]
    mov rax, [rsi]
    movzx rdx, word [rsi+8]
    lea rdi, [round_keys]
    mov rcx, 1
.kloop:
    mov r8, rdx
    shl r8, 48
    mov r9, rax
    shr r9, 16
    or r8, r9
    mov [rdi], r8
    add rdi, 8
    cmp rcx, 32
    je .kdone
    
    ; Rotación 61 bits
    mov r8, rax
    mov r9, rdx
    mov rdx, r8
    shr rdx, 3
    and rdx, 0xFFFF
    mov r10, r8
    shl r10, 61
    mov r11, r9
    shl r11, 45
    shr r8, 19
    mov rax, r10
    or rax, r11
    or rax, r8
    
    ; S-Box
    mov rbx, rdx
    shr rbx, 12
    and rbx, 0x0F
    lea rsi, [sbox]
    mov bl, [rsi + rbx]
    and rdx, 0x0FFF
    shl rbx, 12
    or rdx, rbx
    
    ; XOR con contador
    mov r8, rcx
    shl r8, 15
    xor rax, r8
    inc rcx
    jmp .kloop
.kdone:
    ret

; Capa S-Box
; Entrada: RAX = estado
; Salida: RAX = estado sustituido
sBoxLayer:
    xor rdx, rdx
    mov rcx, 16
    lea rsi, [sbox]
.sloop:
    mov rbx, rax
    and rbx, 0x0F
    mov bl, [rsi + rbx]
    or rdx, rbx
    ror rdx, 4
    ror rax, 4
    dec rcx
    jnz .sloop
    mov rax, rdx
    ret

; Capa P-Layer
; Entrada: RAX = estado
; Salida: RAX = estado permutado
pLayer:
    push rbx
    push rdx

    xor rcx, rcx
    xor rdx, rdx
    lea rsi, [pbox]

.ploop:
    bt rax, rdx
    jnc .skip

    movzx rbx, byte [rsi + rdx]
    bts rcx, rbx

.skip:
    inc rdx
    cmp rdx, 64
    jl .ploop

    mov rax, rcx
    
    pop rdx
    pop rbx
    ret

; Capa P-Layer inversa
inv_pLayer:
    push rbx
    push rdx

    xor rcx, rcx
    xor rdx, rdx
    lea rsi, [inv_pbox]

.iploop:
    bt rax, rdx
    jnc .iskip
    movzx rbx, byte [rsi + rdx]
    bts rcx, rbx
.iskip:
    inc rdx
    cmp rdx, 64
    jl .iploop

    mov rax, rcx
    pop rdx
    pop rbx
    ret

; Capa S-Box inversa
inv_sBoxLayer:
    xor rdx, rdx
    mov rcx, 16
    lea rsi, [inv_sbox]
.isloop:
    mov rbx, rax
    and rbx, 0x0F
    mov bl, [rsi + rbx]
    or rdx, rbx
    ror rdx, 4
    ror rax, 4
    dec rcx
    jnz .isloop
    mov rax, rdx
    ret

; Descifrado CBC
; Entrada: RSI = ciphertext, RDI = plaintext, RCX = bloques
present_decrypt_cbc:
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r15
    push r14
    
    mov r15, [iv]
    
.cbc_dec_loop:
    mov rax, [rsi]
    mov r14, rax
    
    call present_decrypt_block
    
    xor rax, r15
    mov [rdi], rax
    
    mov r15, r14
    
    add rsi, 8
    add rdi, 8
    dec rcx
    jnz .cbc_dec_loop

    pop r14
    pop r15
    pop rdi
    pop rsi
    pop rdx
    pop rbx
    pop rax
    ret

; Descifrar un bloque PRESENT
; Entrada: RAX = ciphertext
; Salida: RAX = plaintext
present_decrypt_block:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    lea rsi, [round_keys]
    add rsi, 248

    mov rbx, [rsi]
    xor rax, rbx
    
    mov rcx, 31

.decrypt_loop:
    sub rsi, 8
    
    push rcx
    push rsi
    call inv_pLayer
    pop rsi
    pop rcx
    
    push rcx
    push rsi
    call inv_sBoxLayer
    pop rsi
    pop rcx
    
    mov rbx, [rsi]
    xor rax, rbx
    
    dec rcx
    jnz .decrypt_loop

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Imprimir en hexadecimal
; Entrada: RAX = valor
print_hex:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    mov rcx, 16
    mov rbx, rax
.hex_loop:
    rol rbx, 4
    mov dl, bl
    and dl, 0x0F
    cmp dl, 9
    jbe .hdigit
    add dl, 7
.hdigit:
    add dl, '0'
    push rcx
    push dx
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall
    pop dx
    pop rcx
    dec rcx
    jnz .hex_loop
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