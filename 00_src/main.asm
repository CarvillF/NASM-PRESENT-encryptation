; =============================================================================
; PROYECTO FINAL: IMPLEMENTACIÓN DE PRESENT-80 (ASM X86-64)
; Autores: Carlos Flores, Benjamín Dillon
; Funcionalidad: Cifrado CBC con Padding PKCS#7 y gestión de claves.
; =============================================================================

section .data
    ; --- TABLAS CRIPTOGRÁFICAS ---
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
    
    ; --- DATOS DE PRUEBA (MODIFICABLE) ---
    ; Puedes cambiar el texto entre comillas. El programa se ajustará solo.
    test_msg db "Hola Mundo" 
    len_test_msg equ $ - test_msg

    ; --- MENSAJES DE INTERFAZ DE USUARIO ---
    ; Nota: Usamos 'equ' para calcular la longitud de cada mensaje automáticamente.

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
    
    newline db 10, 0

section .bss
    ; --- BUFFERS DE MEMORIA ---
    align 16
    master_key resb 16     ; Clave Maestra
    round_keys resq 32     ; Subclaves expandidas
    iv resq 1              ; Vector de Inicialización
    
    plaintext resb 256     ; Buffer entrada
    ciphertext resb 256    ; Buffer salida
    decrypted_text resb 256 ; Buffer descifrado

section .text
    global _start

_start:
    ; -------------------------------------------------------------------------
    ; 1. IMPRIMIR HEADER Y MENSAJE ORIGINAL
    ; -------------------------------------------------------------------------
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [msg_start]
    mov rdx, len_msg_start
    syscall

    ; Imprimir etiqueta "Mensaje Original: "
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_orig]
    mov rdx, len_msg_orig
    syscall

    ; Imprimir el contenido del mensaje de prueba
    mov rax, 1
    mov rdi, 1
    lea rsi, [test_msg]
    mov rdx, len_test_msg
    syscall

    ; Salto de línea estético
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall

    ; -------------------------------------------------------------------------
    ; 2. CONFIGURACIÓN CRIPTOGRÁFICA (Key & IV)
    ; -------------------------------------------------------------------------
    ; Clave = 0 (Para prueba)
    lea rdi, [master_key]
    mov qword [rdi], 0              
    mov word [rdi+8], 0
    call generate_round_keys

    ; IV = 0x0123456789ABCDEF
    lea rdi, [iv]
    mov rax, 0x0123456789ABCDEF     
    mov [rdi], rax

    ; -------------------------------------------------------------------------
    ; 3. PREPARACIÓN Y PADDING
    ; -------------------------------------------------------------------------
    ; Copiar mensaje de prueba al buffer de trabajo
    lea rsi, [test_msg]
    lea rdi, [plaintext]
    mov rcx, len_test_msg
    rep movsb                       

    ; Aplicar Padding PKCS#7
    lea rdi, [plaintext]            ; Inicio buffer
    mov rsi, len_test_msg           ; Longitud original
    call apply_padding
    
    ; RAX devuelve la NUEVA longitud total. La guardamos.
    push rax                        

    ; Imprimir confirmación de padding
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_pad]
    mov rdx, len_msg_pad
    syscall

    ; -------------------------------------------------------------------------
    ; 4. CIFRADO CBC (Bloque a Bloque)
    ; -------------------------------------------------------------------------
    pop rax                         ; Recuperar longitud total
    push rax                        ; Guardarla otra vez (la necesitaremos para imprimir)
    
    shr rax, 3                      ; Dividir por 8 para saber cuántos bloques son
    mov rcx, rax                    ; RCX = Contador de bloques para el cifrado

    lea rsi, [plaintext]            
    lea rdi, [ciphertext]           
    call present_encrypt_cbc

    ; -------------------------------------------------------------------------
    ; 5. MOSTRAR RESULTADOS
    ; -------------------------------------------------------------------------
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_res]
    mov rdx, len_msg_res
    syscall

    ; Bucle para imprimir TODOS los bloques cifrados
    pop rax                         ; Recuperar longitud total en bytes
    push rax                        ; Guardarla de nuevo para el descifrado
    shr rax, 3                      ; Convertir a número de bloques
    mov rcx, rax                    ; Usar como contador del bucle
    lea rsi, [ciphertext]           ; Puntero al inicio del resultado

.print_loop:
    push rcx                        ; Guardar contador de bloques
    push rsi                        ; Guardar puntero actual
    
    mov rax, [rsi]                  ; Cargar bloque actual de 8 bytes
    call print_hex                  ; Imprimir en HEX
    
    pop rsi                         ; Recuperar puntero
    pop rcx                         ; Recuperar contador
    
    add rsi, 8                      ; Avanzar al siguiente bloque
    dec rcx                         
    jnz .print_loop                 ; Repetir si quedan bloques

    ; -------------------------------------------------------------------------
    ; 6. DESCIFRADO (EXTENSION)
    ; -------------------------------------------------------------------------
    ; Restaurar IV original para descifrado
    lea rdi, [iv]
    mov rax, 0x0123456789ABCDEF     
    mov [rdi], rax

    ; Calcular número de bloques nuevamente
    pop rax                         ; Recuperar longitud total (estaba en el stack)
    push rax                        ; Mantener en stack por si acaso
    shr rax, 3                      ; Bloques
    mov rcx, rax
    
    lea rsi, [ciphertext]
    lea rdi, [decrypted_text]
    call present_decrypt_cbc

    ; -------------------------------------------------------------------------
    ; 7. MOSTRAR RESULTADO DESCIFRADO
    ; -------------------------------------------------------------------------
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_dec_res]
    mov rdx, len_msg_dec_res
    syscall

    ; Imprimir texto descifrado
    mov rax, 1
    mov rdi, 1
    lea rsi, [decrypted_text]
    pop rdx                         ; Longitud total (incluye padding)
    syscall
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall

    ; -------------------------------------------------------------------------
    ; 6. SALIDA
    ; -------------------------------------------------------------------------
    mov rax, 60                     ; sys_exit
    xor rdi, rdi                    ; código 0
    syscall


; =============================================================================
; RUTINAS Y FUNCIONES AUXILIARES
; =============================================================================

; --- PADDING PKCS#7 ---
; Calcula cuánto falta para múltiplo de 8 y rellena con ese valor.
apply_padding:
    mov rax, rsi        ; Longitud actual
    and rax, 7          ; Modulo 8
    
    mov rcx, 8
    sub rcx, rax        ; Bytes a agregar (Pad Size)
    
    mov rdx, rcx        ; Guardar el valor del byte de relleno
    add rdi, rsi        ; Mover puntero al final del mensaje

    mov al, dl          ; Valor a escribir
.pad_loop:
    mov [rdi], al       ; Escribir byte
    inc rdi
    dec rcx
    jnz .pad_loop

    lea rax, [rsi + rdx] ; Retornar nueva longitud total
    ret

; --- MODO CBC ---
present_encrypt_cbc:
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r15
    mov r15, [iv]       ; Cargar IV inicial

.cbc_loop:
    mov rax, [rsi]      ; Leer Plaintext
    xor rax, r15        ; XOR con (IV o Bloque Anterior)
    call present_encrypt_block
    mov [rdi], rax      ; Guardar Ciphertext
    mov r15, rax        ; Actualizar feedback
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

; --- ENCRIPTAR UN BLOQUE (PRESENT CORE) ---
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
    xor rax, rbx        ; addRoundKey
    add rsi, 8
    
    push rcx
    push rsi
    call sBoxLayer      ; sBoxLayer
    pop rsi
    pop rcx
    
    push rcx
    push rsi
    call pLayer         ; pLayer
    pop rsi
    pop rcx
    
    inc rcx
    cmp rcx, 32
    jl .encrypt_loop

    mov rbx, [rsi]      ; Ronda final (solo clave)
    xor rax, rbx
    
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; --- KEY SCHEDULE ---
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
    ; Rotación 61 bits izquierda
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
    ; S-Box 4 bits altos
    mov rbx, rdx
    shr rbx, 12
    and rbx, 0x0F
    lea rsi, [sbox]
    mov bl, [rsi + rbx]
    and rdx, 0x0FFF
    shl rbx, 12
    or rdx, rbx
    ; XOR Contador
    mov r8, rcx
    shl r8, 15
    xor rax, r8
    inc rcx
    jmp .kloop
.kdone:
    ret

; --- CAPA S-BOX ---
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

; --- CAPA P-LAYER ---
pLayer:
    push rbx            ; Guardar RBX (Callee-saved)
    push rdx            ; Guardar RDX (Usado como índice)

    xor rcx, rcx        ; Acumulador para el resultado
    xor rdx, rdx        ; Índice de bit (0..63)
    lea rsi, [pbox]     ; Tabla de permutación

.ploop:
    bt rax, rdx         ; ¿Bit RDX encendido en entrada (RAX)?
    jnc .skip           ; Si no, saltar

    movzx rbx, byte [rsi + rdx] ; Obtener nueva posición desde pbox
    bts rcx, rbx        ; Encender bit en la nueva posición

.skip:
    inc rdx
    cmp rdx, 64
    jl .ploop

    mov rax, rcx        ; Retornar resultado
    
    pop rdx             ; Restaurar RDX
    pop rbx             ; Restaurar RBX
    ret

; --- CAPA P-LAYER INVERSA ---
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

; --- CAPA S-BOX INVERSA ---
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

; --- DESCIFRADO CBC ---
present_decrypt_cbc:
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r15
    push r14
    
    mov r15, [iv]       ; Cargar IV inicial
    
.cbc_dec_loop:
    mov rax, [rsi]      ; Leer Ciphertext (C_i)
    mov r14, rax        ; Guardar C_i para siguiente ronda (IV futuro)
    
    call present_decrypt_block ; Decrypt(C_i) -> D(C_i)
    
    xor rax, r15        ; P_i = D(C_i) XOR IV_prev
    mov [rdi], rax      ; Guardar Plaintext
    
    mov r15, r14        ; Actualizar IV = C_i
    
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

; --- DESCIFRAR UN BLOQUE ---
present_decrypt_block:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    lea rsi, [round_keys]
    add rsi, 248        ; Apuntar a Key 32 (31 * 8)

    ; Paso 1: AddRoundKey K32
    mov rbx, [rsi]
    xor rax, rbx
    
    mov rcx, 31         ; Contador de rondas (31 a 1)

.decrypt_loop:
    sub rsi, 8          ; Apuntar a clave anterior (Ki)
    
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
    
    mov rbx, [rsi]      ; Ki
    xor rax, rbx        ; addRoundKey
    
    dec rcx
    jnz .decrypt_loop

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; --- UTILIDAD: PRINT HEX ---
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
    push rcx        ; Proteger RCX de syscall
    push dx
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall
    pop dx
    pop rcx         ; Restaurar RCX
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