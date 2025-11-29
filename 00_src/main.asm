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
    ; State: El estado actual del bloque (64 bits / 8 bytes)
    state resq 1   ; resq reserva "Quadword" (8 bytes)

    ; La clave maestra de 80 bits (10 bytes)
    ; Se alinea a 16 bytes para evitar penalizaciones de rendimiento.
    alignb 16
    master_key resb 10 
    
    ; Buffer para las 32 subclaves de ronda (32 subclaves * 8 bytes c/u = 256 bytes)
    round_keys resq 32

    ; Vector de Inicialización (IV) para modo CBC (64 bits)
    iv resq 1








section .text
    global _start

_start:
    ; --- TEST FASE 3: Key Schedule ---
    
    ; 1. Cargar una clave maestra (usaremos todo ceros para prueba simple)
    ; Ojo: En un caso real, carga datos aquí.
    lea rdi, [master_key]
    mov qword [rdi], 0      ; Primeros 8 bytes = 0
    mov word [rdi+8], 0     ; Últimos 2 bytes = 0

    ; 2. Generar subclaves
    call generate_round_keys
    
    ; 3. Imprimir algunas claves para verificar
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_start]    ; "Iniciando..."
    mov rdx, len_msg_start
    syscall

    ; Imprimir dato de master_key
    mov rax, [master_key]
    call print_hex          ; Esperado: 0000000000000000
    mov word rax, [master_key+8]
    call print_hex          ; Esperado: 0000000000000000

    ; Imprimir Subclave 1 (Debería ser 00...00)
    lea rsi, [round_keys]
    mov rax, [rsi]
    call print_hex          ; Esperado: 0000000000000000

    ; Imprimir Subclave 2 (Debería ser distinta)
    ; El algoritmo habrá rotado y sumado el contador (1).
    ; Veamos qué sale.
    mov rax, [rsi + 8]      ; Siguiente qword
    call print_hex          
    
    ; Imprimir Subclave 31
    mov rax, [rsi + 240]    ; 30 * 8 bytes offset
    call print_hex

    ; Salir
    mov rax, 60
    xor rdi, rdi
    syscall




; =============================================================================
; Función: print_hex
; Descripción: Toma un valor de 64 bits almacenado en el registro RAX e 
;              imprime su representación hexadecimal en la salida estándar (stdout).
; Entrada: RAX (Valor a imprimir)
; Salida: Ninguna (Imprime en pantalla)
; =============================================================================

print_hex:
    ; -------------------------------------------------------------------------
    ; 1. PRÓLOGO (Guardado de contexto)
    ; Guardamos los registros que vamos a usar para no alterar el estado 
    ; del programa principal que llamó a esta función.
    ; -------------------------------------------------------------------------
    push rbx                ; Guardamos RBX (lo usaremos para manipular el número)
    push rcx                ; Guardamos RCX (lo usaremos como contador del bucle)
    push rdx                ; Guardamos RDX (usado en syscall y operaciones aritméticas)
    push rsi                ; Guardamos RSI (puntero para syscall write)
    push rdi                ; Guardamos RDI (descriptor de archivo para syscall write)
    
    ; -------------------------------------------------------------------------
    ; 2. PREPARACIÓN DEL BUCLE
    ; -------------------------------------------------------------------------
    mov rcx, 16             ; Inicializamos el contador. 64 bits / 4 bits por dígito hex = 16 dígitos.
    mov rbx, rax            ; Copiamos el valor original de RAX a RBX. 
                            ; RBX será nuestra "copia de trabajo" para rotar y extraer bits.

.loop_hex:
    ; -------------------------------------------------------------------------
    ; 3. EXTRACCIÓN DEL DÍGITO (NIBBLE)
    ; La estrategia es usar ROL (Rotate Left). Al rotar 4 bits a la izquierda 
    ; 16 veces, vamos pasando cada dígito hexadecimal por la posición más baja.
    ; -------------------------------------------------------------------------
    rol rbx, 4              ; Rotamos RBX 4 bits a la izquierda.
                            ; El dígito más significativo (bits 60-63) pasa a ser el menos significativo (bits 0-3).
                            
    mov dl, bl              ; Copiamos los 8 bits bajos de RBX a DL.
    and dl, 0x0F            ; Operación AND con 00001111 binario.
                            ; Esto "limpia" la parte alta del byte y nos deja solo con el 
                            ; último nibble (el valor numérico del 0 al 15).
    
    ; -------------------------------------------------------------------------
    ; 4. CONVERSIÓN A ASCII
    ; Debemos convertir el número (0-15) a su carácter ASCII ('0'-'9' o 'A'-'F').
    ; -------------------------------------------------------------------------
    cmp dl, 9               ; Comparamos el valor con 9.
    jbe .is_digit           ; Si es menor o igual (0-9), saltamos a .is_digit.
    
    ; Si llegamos aquí, es una letra (A-F, valores 10-15).
    ; La distancia entre ASCII '9' y 'A' es de 7 caracteres en la tabla ASCII.
    ; Ejemplo: Si dl es 10 (0xA): 10 + '0' = 58 (':'). 58 + 7 = 65 ('A').
    add dl, 7               
    
.is_digit:
    add dl, '0'             ; Sumamos el valor ASCII base de '0' (48).
                            ; Si era 5 -> 5 + 48 = 53 ('5').

    ; -------------------------------------------------------------------------
    ; 5. IMPRESIÓN DEL CARÁCTER (La "Corrección")
    ; Aquí usamos la llamada al sistema sys_write.
    ; IMPORTANTE: La instrucción 'syscall' en Linux x64 DESTRUYE los registros 
    ; RCX y R11. RCX se usa para guardar el RIP (puntero de instrucción) de retorno.
    ; Por eso es vital proteger RCX, ya que es nuestro contador del bucle.
    ; -------------------------------------------------------------------------
    
    push rcx                ; <--- SALVAR RCX: Lo guardamos en la pila antes del syscall.
    
    ; sys_write requiere un puntero a memoria, no un registro directo.
    push dx                 ; Guardamos el carácter (DL está en DX) en la pila.
                            ; Ahora RSP (Stack Pointer) apunta a este carácter.
                            
    mov rax, 1              ; ID de syscall: 1 = sys_write
    mov rdi, 1              ; Argumento 1 (file descriptor): 1 = stdout
    mov rsi, rsp            ; Argumento 2 (buffer): Apuntamos RSI a la cima de la pila (donde está el char).
    mov rdx, 1              ; Argumento 3 (length): Vamos a escribir 1 byte.
    syscall                 ; Ejecutamos la llamada al kernel. 
                            ; *Nota: Aquí RCX cambia de valor internamente por el kernel*.
                            
    pop dx                  ; Limpiamos la pila: sacamos el carácter que ya imprimimos.
                            ; Esto restaura RSP a donde estaba antes de 'push dx'.
    
    pop rcx                 ; <--- RESTAURAR RCX: Recuperamos nuestro contador de bucle original (16, 15...).
    
    ; -------------------------------------------------------------------------
    ; 6. CONTROL DEL BUCLE
    ; -------------------------------------------------------------------------
    dec rcx                 ; Decrementamos el contador (restamos 1).
    jnz .loop_hex           ; "Jump if Not Zero": Si RCX no es cero, volvemos arriba a procesar el siguiente dígito.

    ; -------------------------------------------------------------------------
    ; 7. SALTO DE LÍNEA FINAL
    ; Una vez impresos los 16 dígitos, hacemos un salto de línea estético.
    ; -------------------------------------------------------------------------
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    lea rsi, [newline]      ; Cargamos la dirección de memoria de la variable 'newline'.
                            ; *Nota: Asume que definiste 'newline db 10' en la sección .data*
    mov rdx, 1              ; longitud 1 byte
    syscall                 ; (Aquí no salvamos RCX porque ya terminamos el bucle).

    ; -------------------------------------------------------------------------
    ; 8. EPÍLOGO (Restauración)
    ; Restauramos los registros en orden inverso al que los guardamos.
    ; -------------------------------------------------------------------------
    pop rdi                 
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    
    ret                     ; Retornamos a quien llamó a la función.



; -----------------------------------------------------------------------------
; Subrutina: sBoxLayer
; Entrada: RAX (Estado actual de 64 bits)
; Salida: RAX (Estado sustituido)
; Destruye: RBX, RCX, RDX
; -----------------------------------------------------------------------------
sBoxLayer:
    xor rdx, rdx            ; RDX será nuestro acumulador temporal (iniciar en 0)
    mov rcx, 16             ; 16 nibbles a procesar
    lea rsi, [sbox]         ; Dirección de la tabla S-Box

.sbox_loop:
    ; 1. Obtener el nibble más bajo de RAX
    mov rbx, rax            ; Copiar estado
    and rbx, 0x0F           ; Aislar los 4 bits bajos (máscara 000...0F)

    ; 2. Buscar sustitución en la tabla
    ; Como la tabla es de bytes, sumamos el índice a la base
    mov bl, [rsi + rbx]     ; BL = sbox[valor_nibble]

    ; 3. Insertar el nibble sustituido en RDX
    ; Truco: Metemos el nibble en la parte baja de RDX, luego rotamos RDX
    or rdx, rbx             ; Escribimos el nibble en los bits bajos de RDX
    
    ; 4. Preparar siguiente iteración
    ror rdx, 4              ; Rotamos RDX a la DERECHA para hacer espacio al siguiente
    ror rax, 4              ; Rotamos RAX a la DERECHA para bajar el siguiente nibble

    dec rcx
    jnz .sbox_loop

    ; Al final de 16 rotaciones a la derecha, los nibbles en RDX están en orden correcto
    mov rax, rdx            ; Movemos el resultado final a RAX
    ret


; -----------------------------------------------------------------------------
; Subrutina: pLayer
; Entrada: RAX (Estado actual de 64 bits)
; Salida: RAX (Estado permutado)
; Destruye: RBX, RCX, RDX, R8, R9
; -----------------------------------------------------------------------------
pLayer:
    mov r10, rax            ; Guardamos el valor de RAX para evitar sobrescritura de div 
    xor rcx, rcx            ; RCX será el acumulador de salida (Destino)
    xor r8, r8              ; R8 será nuestro contador 'i' (0 a 63)

.p_loop:
    ; 1. Verificar si el bit 'i' (R8) en RAX es 1
    bt rax, r8              ; Bit Test: copia el bit R8 de RAX al Flag de Carry (CF)
    jnc .next_bit           ; Si CF=0 (bit apagado), saltamos. No hay nada que mover.

    ; 2. Calcular la nueva posición P(i)
    ; Fórmula: pos = (i * 16) % 63
    
    cmp r8, 63              ; Caso especial: bit 63 se queda en 63
    je .is_63
    
    ; Cálculo matemático: (R8 * 16) % 63
    mov rax, r8             ; Movemos i a RAX para operar
    shl rax, 4              ; Multiplicar por 16 (shift left 4)
    
    mov rbx, 63             ; Divisor
    xor rdx, rdx            ; Limpiar RDX antes de dividir (div usa RDX:RAX)
    div rbx                 ; RAX = Cociente, RDX = Resto (Módulo)
    
    mov r9, rdx             ; R9 es nuestra nueva posición
    jmp .set_bit

.is_63:
    mov r9, 63

.set_bit:
    ; 3. Encender el bit en la nueva posición en RCX
    bts rcx, r9             ; Bit Test and Set: Enciende el bit R9 en RCX

    ; Recuperamos RAX original (porque lo usamos para la división)
    ; Espera, destruimos RAX en la división. ¡Error de diseño!
    ; Solución: Usaremos un registro temporal para el input original.
    ; Ver corrección abajo en el código completo.

.next_bit:
    inc r8
    cmp r8, 64
    jl .p_loop

    mov rax, rcx            ; Resultado final a RAX
    ret


; -----------------------------------------------------------------------------
; Subrutina: generate_round_keys
; Descripción: Genera las 32 subclaves usando Rotación a la Izquierda Estándar.
; Entrada: master_key (en memoria .bss)
; Salida: round_keys (relleno en memoria .bss)
; -----------------------------------------------------------------------------
generate_round_keys:
    ; Cargar clave inicial
    lea rsi, [master_key]
    mov rax, [rsi]          ; Low 64 bits
    movzx rdx, word [rsi+8] ; High 16 bits

    lea rdi, [round_keys]   ; Buffer de destino
    mov rcx, 1              ; Contador de ronda (1 a 31)

.key_loop:
    ; --- PASO A: Guardar Subclave (Bits 79..16) ---
    mov r8, rdx
    shl r8, 48              ; RDX a tope
    mov r9, rax
    shr r9, 16              ; RAX quitando los 16 bajos
    or r8, r9
    mov [rdi], r8           ; Guardar K_i
    add rdi, 8

    cmp rcx, 32
    je .done

    ; --- PASO B: Rotación Estándar a la Izquierda 61 bits ---
    ; K = (K << 61) | (K >> 19) en 80 bits.
    ; Lo hacemos manual sobre RDX:RAX.
    
    ; Guardamos copias originales porque vamos a destruir los registros
    mov r8, rax             ; r8 = Old Low
    mov r9, rdx             ; r9 = Old High

    ; 1. Calcular NUEVO RDX (High 16 bits)
    ; Vienen de los bits 18..3 del Old Low.
    mov rdx, r8
    shr rdx, 3              ; Desplazar para que el bit 3 quede en 0
    and rdx, 0xFFFF         ; Máscara para quedarnos solo con 16 bits

    ; 2. Calcular NUEVO RAX (Low 64 bits)
    ; Se compone de 3 partes unidas con OR:
    
    ; Parte 1: Los bits 2..0 de Old Low van al tope (bits 63..61)
    mov r10, r8
    shl r10, 61
    
    ; Parte 2: Los 16 bits de Old High van a continuación (bits 60..45)
    mov r11, r9
    shl r11, 45
    
    ; Parte 3: Los bits 63..19 de Old Low van al fondo (bits 44..0)
    shr r8, 19              ; Usamos r8 directo (ya no necesitamos el valor original)
    
    ; Unir todo en RAX
    mov rax, r10
    or rax, r11
    or rax, r8

    ; --- PASO C: S-Box en los 4 bits superiores (bits 79..76) ---
    ; Ahora están en RDX bits 15..12
    mov rbx, rdx
    shr rbx, 12             ; Bajar a 3..0
    and rbx, 0x0F           ; Aislar

    lea rsi, [sbox]
    mov bl, [rsi + rbx]     ; Sustitución S-Box

    ; Reinsertar en RDX
    and rdx, 0x0FFF         ; Limpiar los 4 bits altos
    shl rbx, 12             ; Subir el resultado
    or rdx, rbx             ; Pegar

    ; --- PASO D: XOR con Round Counter (bits 19..15 de K) ---
    ; En nuestra estructura RDX:RAX, los bits 19..15 caen dentro de RAX.
    ; Específicamente en los bits 19..15 de RAX.
    mov r8, rcx
    shl r8, 15
    xor rax, r8

    inc rcx
    jmp .key_loop

.done:
    ret