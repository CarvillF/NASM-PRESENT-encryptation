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
    
    msg_input_prompt db "[*] Ingrese el texto a cifrar (máx 4096 bytes): ", 0
    len_msg_input_prompt equ $ - msg_input_prompt
    
    msg_read_error db "[ERROR] Fallo al leer entrada.", 10, 0
    len_msg_read_error equ $ - msg_read_error
    
    msg_eof db "[INFO] EOF detectado. No hay datos para procesar.", 10, 0
    len_msg_eof equ $ - msg_eof
    
    msg_bytes_read db "[*] Bytes leídos: ", 0
    len_msg_bytes_read equ $ - msg_bytes_read
    
    ; Mensajes para manejo de archivos (Phase 11)
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
    ; --- BUFFERS DE MEMORIA ---
    align 16
    master_key resb 16     ; Clave Maestra
    round_keys resq 32     ; Subclaves expandidas
    iv resq 1              ; Vector de Inicialización
    
    ; Buffers expandidos a 4KB con alineación de cache line (64 bytes)
    align 64
    plaintext resb 4096     ; Buffer entrada (4KB)
    align 64
    ciphertext resb 4096    ; Buffer salida (4KB)
    align 64
    decrypted_text resb 4096 ; Buffer descifrado (4KB)
    
    ; Variable para almacenar longitud real leída
    actual_read_length resq 1  ; Bytes realmente leídos por sys_read
    
    ; Variable para almacenar el file descriptor (Phase 11)
    file_descriptor resq 1     ; FD del archivo abierto

section .text
    global _start

_start:
    ; -------------------------------------------------------------------------
    ; PHASE 11 - Task A: Command Line Argument Parsing (argv)
    ; -------------------------------------------------------------------------
    ; Stack structure at startup:
    ;   [rsp]     = argc (number of arguments)
    ;   [rsp+8]   = argv[0] (program name)
    ;   [rsp+16]  = argv[1] (first argument - filename)
    ; -------------------------------------------------------------------------
    
    ; Paso 1: Verificar argc
    mov rax, [rsp]              ; RAX = argc
    cmp rax, 2                  ; ¿Tenemos al menos 2 argumentos?
    jl .show_usage              ; Si argc < 2, mostrar uso y salir
    
    ; Paso 2: Obtener puntero al filename (argv[1])
    mov r13, [rsp + 16]         ; R13 = argv[1] (puntero al filename)
                                ; R13 se usará durante todo el programa
    
    ; -------------------------------------------------------------------------
    ; 1. IMPRIMIR HEADER
    ; -------------------------------------------------------------------------
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [msg_start]
    mov rdx, len_msg_start
    syscall

    ; -------------------------------------------------------------------------
    ; PHASE 11 - Task B: Implement sys_open
    ; -------------------------------------------------------------------------
    ; Mostrar mensaje de apertura de archivo
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_open]
    mov rdx, len_msg_file_open
    syscall
    
    ; Calcular longitud del filename
    mov rsi, r13                ; Filename
    call strlen                 ; RAX = longitud
    mov r15, rax                ; Guardar longitud en R15
    
    ; Imprimir nombre del archivo
    mov rax, 1
    mov rdi, 1
    mov rsi, r13                ; Filename desde argv[1]
    mov rdx, r15                ; Longitud calculada
    syscall
    
    ; Salto de línea
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
    
    ; Abrir el archivo
    mov rax, 2                  ; sys_open
    mov rdi, r13                ; Filename (argv[1])
    mov rsi, 0                  ; Flags: O_RDONLY (solo lectura)
    mov rdx, 0                  ; Mode: no importa para lectura
    syscall
    
    ; Verificar resultado
    cmp rax, 0
    jl .file_open_error         ; Si RAX < 0, error al abrir
    
    ; Guardar file descriptor
    mov r14, rax                ; R14 = File Descriptor
    lea rbx, [file_descriptor]
    mov [rbx], rax              ; Guardar en memoria también
    
    ; Mostrar mensaje de éxito
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_success]
    mov rdx, len_msg_file_success
    syscall

    ; Imprimir etiqueta "Mensaje Original: "
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_orig]
    mov rdx, len_msg_orig
    syscall

    ; -------------------------------------------------------------------------
    ; PHASE 11 - Task C: Refactor read_input_dynamic
    ; -------------------------------------------------------------------------
    ; Leer contenido del archivo usando el FD en R14
    mov rdi, r14                ; Pasar FD como primer argumento
    lea rsi, [plaintext]        ; Buffer de destino como segundo argumento
    call read_input_dynamic
    ; RAX y R12 ahora contienen los bytes leídos
    ; actual_read_length también tiene el valor
    
    ; -------------------------------------------------------------------------
    ; PHASE 11 - Task D: Implement sys_close
    ; -------------------------------------------------------------------------
    ; Cerrar el archivo después de leer
    mov rax, 3                  ; sys_close
    mov rdi, r14                ; FD del archivo
    syscall
    
    ; Mostrar cuántos bytes se leyeron
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_bytes_read]
    mov rdx, len_msg_bytes_read
    syscall
    
    mov rax, r12            ; Recuperar bytes leídos
    call print_decimal      ; Imprimir número
    
    ; Salto de línea
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
    ; Ya NO necesitamos copiar el mensaje de prueba porque ya está en plaintext
    ; desde read_input_dynamic

    ; Aplicar Padding PKCS#7
    lea rdi, [plaintext]            ; Inicio buffer
    mov rsi, r12                    ; Longitud original (bytes leídos)
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
    ; IMPORTANTE: Usa RCX (64-bit) para soportar > 255 bloques
    pop rax                         ; Recuperar longitud total en bytes
    push rax                        ; Guardarla de nuevo para el descifrado
    shr rax, 3                      ; Convertir a número de bloques (dividir por 8)
    mov rcx, rax                    ; RCX = contador de bloques (64-bit)
    lea rsi, [ciphertext]           ; Puntero al inicio del resultado

.print_loop:
    push rcx                        ; Guardar contador de bloques
    push rsi                        ; Guardar puntero actual
    
    mov rax, [rsi]                  ; Cargar bloque actual de 8 bytes
    call print_hex                  ; Imprimir en HEX
    
    pop rsi                         ; Recuperar puntero
    pop rcx                         ; Recuperar contador
    
    add rsi, 8                      ; Avanzar al siguiente bloque (64-bit)
    dec rcx                         ; Decrementar contador (64-bit)
                                    ; CRÍTICO: RCX soporta > 255 iteraciones
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
    ; 8. SALIDA NORMAL
    ; -------------------------------------------------------------------------
    mov rax, 60                     ; sys_exit
    xor rdi, rdi                    ; código 0
    syscall

; =============================================================================
; MANEJADORES DE ERROR (PHASE 11)
; =============================================================================

.show_usage:
    ; Mostrar mensaje de uso cuando no se proporciona archivo
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_usage]
    mov rdx, len_msg_usage
    syscall
    
    ; Salir con código de error
    mov rax, 60
    mov rdi, 1                      ; exit code 1
    syscall

.file_open_error:
    ; Mostrar mensaje de error al abrir archivo
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_file_error]
    mov rdx, len_msg_file_error
    syscall
    
    ; Salir con código de error
    mov rax, 60
    mov rdi, 2                      ; exit code 2 (file error)
    syscall


; =============================================================================
; RUTINAS Y FUNCIONES AUXILIARES
; =============================================================================

; --- PADDING PKCS#7 ---
; Task A (Benjamín): Padding Calculation Adaptation
; Calcula cuánto falta para múltiplo de 8 y rellena con ese valor.
; IMPORTANTE: Usa aritmética de 64 bits para soportar buffers grandes (hasta 4KB)
; Entrada: RDI = puntero al buffer
;          RSI = longitud actual del mensaje (64-bit, puede ser > 255)
; Salida:  RAX = nueva longitud total (original + padding)
; Registros modificados: RAX, RCX, RDX
apply_padding:
    ; Paso 1: Calcular padding necesario usando aritmética de 64 bits
    ; Fórmula: pad_size = 8 - (length % 8)
    ; Si length % 8 == 0, entonces pad_size = 8 (siempre agregamos padding)
    
    mov rax, rsi        ; RAX = Longitud actual (64-bit completo)
    and rax, 7          ; RAX = length % 8 (usando AND para modulo rápido)
                        ; Esto funciona porque 8 = 2^3, entonces % 8 = AND 7
    
    ; Paso 2: Calcular bytes a agregar
    mov rcx, 8          ; RCX = 8 (tamaño de bloque)
    sub rcx, rax        ; RCX = 8 - (length % 8) = pad_size
                        ; RCX ahora contiene el número de bytes de padding (1-8)
    
    ; Paso 3: Guardar el valor del byte de relleno
    mov rdx, rcx        ; RDX = pad_size (valor que se escribirá en cada byte)
    
    ; Paso 4: Calcular posición final del mensaje
    ; CRÍTICO: Usar ADD de 64 bits para soportar offsets grandes
    add rdi, rsi        ; RDI = base_address + actual_length
                        ; Ahora RDI apunta al primer byte después del mensaje
    
    ; Paso 5: Escribir bytes de padding
    ; Nota: Usamos AL (8-bit) solo para ESCRIBIR bytes individuales,
    ; pero el CONTADOR (RCX) es de 64 bits para soportar loops grandes
    mov al, dl          ; AL = valor del byte de padding (1-8)
    
.pad_loop:
    mov [rdi], al       ; Escribir byte de padding
    inc rdi             ; Avanzar puntero (64-bit)
    dec rcx             ; Decrementar contador (64-bit)
    jnz .pad_loop       ; Continuar si RCX != 0
    
    ; Paso 6: Calcular y retornar nueva longitud total
    ; CRÍTICO: Usar LEA de 64 bits para soportar longitudes grandes
    lea rax, [rsi + rdx] ; RAX = original_length + pad_size
                         ; Retorna la nueva longitud total
    ret

; --- LECTURA DINÁMICA CON MANEJO DE ERRORES ---
; PHASE 11 - Task C: Refactor read_input_dynamic
; Lee datos desde un file descriptor con manejo completo de errores
; Entrada: RDI = file descriptor (0 para stdin, o FD de archivo)
;          RSI = puntero al buffer de destino
; Salida: RAX = bytes leídos (o código de error)
;         R12 = bytes leídos (preservado para uso posterior)
;         actual_read_length = bytes leídos (guardado en memoria)
read_input_dynamic:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    ; Guardar argumentos
    mov r15, rdi                ; R15 = File Descriptor
    mov r12, rsi                ; R12 = Buffer pointer
    
    ; Preparar sys_read
    mov rax, 0              ; sys_read
    mov rdi, r15            ; File descriptor (parámetro de entrada)
    mov rsi, r12            ; buffer destino (parámetro de entrada)
    mov rdx, 4096           ; máximo a leer (4KB)
    syscall
    
    ; Verificar resultado en RAX
    cmp rax, 0
    jl .read_error          ; Si RAX < 0, error de lectura
    je .read_eof            ; Si RAX == 0, EOF
    
    ; Lectura exitosa
    mov r12, rax            ; Guardar bytes leídos en R12
    lea rbx, [actual_read_length]
    mov [rbx], rax          ; Guardar en memoria también
    
    ; Restaurar registros y retornar
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
    
.read_error:
    ; Manejar error de lectura
    push rax                ; Guardar código de error
    
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [msg_read_error]
    mov rdx, len_msg_read_error
    syscall
    
    pop rax                 ; Recuperar código de error
    mov rax, 60             ; sys_exit
    mov rdi, 1              ; exit code 1 (error)
    syscall
    
.read_eof:
    ; Manejar EOF (sin datos)
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [msg_eof]
    mov rdx, len_msg_eof
    syscall
    
    mov rax, 60             ; sys_exit
    xor rdi, rdi            ; exit code 0 (normal)
    syscall

; --- UTILIDAD: IMPRIMIR NÚMERO DECIMAL ---
; Imprime el valor en RAX como número decimal
; Entrada: RAX = número a imprimir
print_decimal:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rcx, 0              ; Contador de dígitos
    mov rbx, 10             ; Base decimal
    
    ; Caso especial: si es 0
    cmp rax, 0
    jne .convert_loop
    
    push '0'
    inc rcx
    jmp .print_digits
    
.convert_loop:
    cmp rax, 0
    je .print_digits
    
    xor rdx, rdx            ; Limpiar RDX para división
    div rbx                 ; RAX = RAX / 10, RDX = RAX % 10
    add rdx, '0'            ; Convertir a ASCII
    push rdx                ; Guardar dígito en stack
    inc rcx
    jmp .convert_loop
    
.print_digits:
    cmp rcx, 0
    je .done
    
    pop rdx                 ; Obtener dígito
    push rcx                ; Proteger contador
    push rdx                ; Poner dígito en stack para imprimir
    
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    mov rsi, rsp            ; Apuntar al dígito en stack
    mov rdx, 1              ; 1 byte
    syscall
    
    pop rdx                 ; Limpiar stack
    pop rcx                 ; Recuperar contador
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

; --- UTILIDAD: CALCULAR LONGITUD DE STRING ---
; Calcula la longitud de un string terminado en null
; Entrada: RSI = puntero al string
; Salida: RAX = longitud del string (sin contar el null)
strlen:
    push rsi
    push rcx
    
    xor rax, rax            ; Contador = 0
    
.strlen_loop:
    cmp byte [rsi], 0       ; ¿Es null terminator?
    je .strlen_done
    inc rsi
    inc rax
    jmp .strlen_loop
    
.strlen_done:
    pop rcx
    pop rsi
    ret

; --- MODO CBC ---
; Joint Task (Pair Programming): Register Audit
; Cifrado en modo CBC (Cipher Block Chaining)
; IMPORTANTE: Usa RCX (64-bit) como contador de bloques para soportar
;             archivos grandes (4KB = 512 bloques de 8 bytes)
; Entrada: RSI = puntero al plaintext
;          RDI = puntero al buffer de salida (ciphertext)
;          RCX = número de bloques a cifrar (64-bit, puede ser > 255)
;          [iv] = Vector de Inicialización
; Salida:  Ciphertext escrito en el buffer apuntado por RDI
present_encrypt_cbc:
    push rax
    push rbx
    push rdx
    push rsi
    push rdi
    push r15
    mov r15, [iv]       ; Cargar IV inicial

.cbc_loop:
    mov rax, [rsi]      ; Leer Plaintext (8 bytes)
    xor rax, r15        ; XOR con (IV o Bloque Anterior)
    call present_encrypt_block
    mov [rdi], rax      ; Guardar Ciphertext (8 bytes)
    mov r15, rax        ; Actualizar feedback para siguiente bloque
    add rsi, 8          ; Avanzar puntero de entrada (64-bit)
    add rdi, 8          ; Avanzar puntero de salida (64-bit)
    dec rcx             ; Decrementar contador de bloques (64-bit)
                        ; CRÍTICO: RCX es 64-bit, soporta > 255 bloques
    jnz .cbc_loop       ; Continuar si quedan bloques

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
; Joint Task (Pair Programming): Register Audit
; Descifrado en modo CBC (Cipher Block Chaining)
; IMPORTANTE: Usa RCX (64-bit) como contador de bloques para soportar
;             archivos grandes (4KB = 512 bloques de 8 bytes)
; Entrada: RSI = puntero al ciphertext
;          RDI = puntero al buffer de salida (plaintext)
;          RCX = número de bloques a descifrar (64-bit, puede ser > 255)
;          [iv] = Vector de Inicialización
; Salida:  Plaintext escrito en el buffer apuntado por RDI
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
    mov rax, [rsi]      ; Leer Ciphertext (C_i) - 8 bytes
    mov r14, rax        ; Guardar C_i para siguiente ronda (IV futuro)
    
    call present_decrypt_block ; Decrypt(C_i) -> D(C_i)
    
    xor rax, r15        ; P_i = D(C_i) XOR IV_prev
    mov [rdi], rax      ; Guardar Plaintext (8 bytes)
    
    mov r15, r14        ; Actualizar IV = C_i
    
    add rsi, 8          ; Avanzar puntero de entrada (64-bit)
    add rdi, 8          ; Avanzar puntero de salida (64-bit)
    dec rcx             ; Decrementar contador de bloques (64-bit)
                        ; CRÍTICO: RCX es 64-bit, soporta > 255 bloques
    jnz .cbc_dec_loop   ; Continuar si quedan bloques

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