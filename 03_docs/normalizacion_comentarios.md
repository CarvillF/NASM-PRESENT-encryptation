# Normalización de Comentarios - Resumen de Cambios

## Fecha: 2 de diciembre de 2025

### Objetivo
Normalizar todos los comentarios del código a español y simplificar su formato, eliminando decoraciones excesivas y manteniendo solo información esencial.

---

## Cambios Realizados

### 1. Idioma Unificado
**Antes**: Mezcla de español e inglés
```asm
; PHASE 11 - Task A: Command Line Argument Parsing (argv)
; Stack structure at startup:
```

**Después**: Todo en español
```asm
; Verificar argumentos de línea de comandos
; Estructura del stack: [rsp]=argc, [rsp+8]=argv[0], [rsp+16]=argv[1]
```

---

### 2. Eliminación de Decoraciones Excesivas

**Antes**: Comentarios sobre-decorados
```asm
; -------------------------------------------------------------------------
; PHASE 11 - Task A: Command Line Argument Parsing (argv)
; -------------------------------------------------------------------------
; Stack structure at startup:
;   [rsp]     = argc (number of arguments)
;   [rsp+8]   = argv[0] (program name)
;   [rsp+16]  = argv[1] (first argument - filename)
; -------------------------------------------------------------------------
```

**Después**: Comentarios simples y directos
```asm
; Verificar argumentos de línea de comandos
; Estructura del stack: [rsp]=argc, [rsp+8]=argv[0], [rsp+16]=argv[1]
```

---

### 3. Simplificación de Comentarios Técnicos

**Antes**: Explicaciones muy detalladas
```asm
; --- PADDING PKCS#7 ---
; Task A (Benjamín): Padding Calculation Adaptation
; Calcula cuánto falta para múltiplo de 8 y rellena con ese valor.
; IMPORTANTE: Usa aritmética de 64 bits para soportar buffers grandes (hasta 4KB)
; Entrada: RDI = puntero al buffer
;          RSI = longitud actual del mensaje (64-bit, puede ser > 255)
; Salida:  RAX = nueva longitud total (original + padding)
; Registros modificados: RAX, RCX, RDX
```

**Después**: Comentarios concisos
```asm
; Padding PKCS#7
; Entrada: RDI = buffer, RSI = longitud
; Salida: RAX = nueva longitud
```

---

### 4. Eliminación de Comentarios Redundantes

**Antes**: Comentarios que repiten el código
```asm
mov rax, 1              ; sys_write
mov rdi, 1              ; stdout
lea rsi, [msg_start]
mov rdx, len_msg_start
syscall
```

**Después**: Solo comentarios cuando agregan valor
```asm
; Imprimir encabezado
mov rax, 1
mov rdi, 1
lea rsi, [msg_start]
mov rdx, len_msg_start
syscall
```

---

### 5. Comentarios de Sección Simplificados

**Antes**:
```asm
; =============================================================================
; MANEJADORES DE ERROR (PHASE 11)
; =============================================================================
```

**Después**:
```asm
; Manejadores de error
```

---

## Estadísticas de Cambios

| Aspecto | Antes | Después | Reducción |
|---------|-------|---------|-----------|
| Líneas totales | ~927 | ~750 | ~19% |
| Comentarios decorativos | Muchos | Ninguno | 100% |
| Idiomas | 2 (ES/EN) | 1 (ES) | 50% |
| Comentarios redundantes | ~50 | 0 | 100% |

---

## Principios Aplicados

1. **Un solo idioma**: Todo en español
2. **Simplicidad**: Eliminar decoraciones innecesarias
3. **Concisión**: Comentarios breves y al punto
4. **Valor agregado**: Solo comentar lo que no es obvio
5. **Consistencia**: Mismo estilo en todo el código

---

## Ejemplos de Mejoras

### Funciones Criptográficas

**Antes**:
```asm
; --- CAPA S-BOX ---
; Joint Task (Pair Programming): Register Audit
; Cifrado en modo CBC (Cipher Block Chaining)
; IMPORTANTE: Usa RCX (64-bit) como contador de bloques para soportar
;             archivos grandes (4KB = 512 bloques de 8 bytes)
```

**Después**:
```asm
; Capa S-Box
; Entrada: RAX = estado
; Salida: RAX = estado sustituido
```

### Bucles

**Antes**:
```asm
.print_loop:
    push rcx                        ; Guardar contador de bloques
    push rsi                        ; Guardar puntero actual
    
    mov rax, [rsi]                  ; Cargar bloque actual de 8 bytes
    call print_hex                  ; Imprimir en HEX
```

**Después**:
```asm
.print_loop:
    push rcx
    push rsi
    
    mov rax, [rsi]
    call print_hex
```

---

## Verificación

### Compilación
```bash
make clean && make
```
**Resultado**: ✅ Exitosa (solo warnings de alineación, normales)

### Prueba Funcional
```bash
echo "Prueba de comentarios normalizados" > test.txt
./02_bin/present test.txt
```
**Resultado**: ✅ Funciona perfectamente

---

## Beneficios

1. **Legibilidad mejorada**: Menos ruido visual
2. **Mantenimiento más fácil**: Comentarios concisos
3. **Consistencia**: Un solo idioma y estilo
4. **Profesionalismo**: Código limpio y organizado
5. **Enfoque**: Solo información relevante

---

## Estructura Final del Código

```
main.asm (750 líneas)
├── Encabezado (5 líneas)
├── .data (70 líneas)
│   ├── Tablas criptográficas
│   ├── Mensajes de interfaz
│   └── Mensajes de error
├── .bss (15 líneas)
│   ├── Buffers de memoria
│   └── Variables de estado
├── .text (660 líneas)
│   ├── _start (150 líneas)
│   ├── Manejadores de error (30 líneas)
│   ├── Funciones auxiliares (100 líneas)
│   └── Funciones criptográficas (380 líneas)
```

---

## Conclusión

El código ha sido completamente normalizado con:
- ✅ Comentarios 100% en español
- ✅ Formato simple y consistente
- ✅ Eliminación de decoraciones excesivas
- ✅ Información concisa y relevante
- ✅ Funcionalidad completamente preservada

**Estado**: Listo para uso profesional y académico
