# PRESENT-80 Quick Reference Guide

## 🚀 Quick Start

```bash
# Build
make

# Encrypt a file
./02_bin/present myfile.txt

# Clean build
make clean
```

---

## 📝 Command Syntax

```
./02_bin/present <filename>
```

**Arguments**:
- `<filename>`: Path to file to encrypt (max 4096 bytes)

**Exit Codes**:
- `0` = Success
- `1` = No filename provided
- `2` = File error (not found/no permissions)

---

## 🔑 Cipher Specifications

| Parameter | Value |
|-----------|-------|
| **Algorithm** | PRESENT-80 |
| **Block Size** | 64 bits (8 bytes) |
| **Key Size** | 80 bits (10 bytes) |
| **Rounds** | 31 |
| **Mode** | CBC (Cipher Block Chaining) |
| **Padding** | PKCS#7 |
| **IV** | 0x0123456789ABCDEF (fixed) |
| **Key** | 0x00000000000000000000 (test key) |

---

## 📊 Output Format

```
===============================================
PROYECTO PRESENT-80: Cifrado CBC + Padding
===============================================
[*] Abriendo archivo: <filename>
[*] Archivo abierto exitosamente.
[*] Mensaje Original: [*] Bytes leídos: <N>
[*] Padding PKCS#7 aplicado correctamente.
[*] Resultado Cifrado (Hexadecimal):
<16-character hex blocks, one per line>

[*] Resultado Descifrado (Texto): <original text>
```

---

## 🧮 Size Calculations

**Padded Size Formula**:
```
padded_size = original_size + (8 - (original_size % 8))
if original_size % 8 == 0:
    padded_size = original_size + 8
```

**Block Count**:
```
blocks = padded_size / 8
```

**Examples**:
| Original | Padded | Blocks |
|----------|--------|--------|
| 5 bytes | 8 bytes | 1 |
| 8 bytes | 16 bytes | 2 |
| 17 bytes | 24 bytes | 3 |
| 100 bytes | 104 bytes | 13 |
| 1024 bytes | 1024 bytes | 128 |

---

## 🔧 Build System

**Makefile Targets**:
```bash
make          # Build project
make clean    # Remove binaries
make run      # Build and run (with test data)
make test     # Run test suite
```

**Manual Build**:
```bash
nasm -f elf64 -g -F dwarf 00_src/main.asm -o 01_obj/main.o
ld -o 02_bin/present 01_obj/main.o
```

---

## 🧪 Testing Examples

### Test 1: Small File
```bash
echo "Hello" > test.txt
./02_bin/present test.txt
# Expected: 1 block (6 bytes → 8 bytes padded)
```

### Test 2: Exact Block
```bash
printf "12345678" > test.txt
./02_bin/present test.txt
# Expected: 2 blocks (8 bytes → 16 bytes with padding)
```

### Test 3: Large File
```bash
perl -e 'print "A" x 1000' > test.txt
./02_bin/present test.txt
# Expected: 126 blocks (1000 → 1008 bytes)
```

### Test 4: Maximum Size
```bash
perl -e 'print "X" x 4096' > test.txt
./02_bin/present test.txt
# Expected: 513 blocks (4096 → 4104 bytes)
```

### Test 5: Error Cases
```bash
./02_bin/present                    # Exit 1: Usage error
./02_bin/present nonexistent.txt    # Exit 2: File error
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────┐
│           PRESENT-80 Cipher             │
├─────────────────────────────────────────┤
│                                         │
│  64-bit Block                           │
│      ↓                                  │
│  ┌──────────────────┐                   │
│  │ For i = 1 to 31: │                   │
│  │  • AddRoundKey   │                   │
│  │  • sBoxLayer     │                   │
│  │  • pLayer        │                   │
│  └──────────────────┘                   │
│      ↓                                  │
│  AddRoundKey(K32)                       │
│      ↓                                  │
│  64-bit Ciphertext                      │
│                                         │
└─────────────────────────────────────────┘
```

---

## 📋 Function Reference

### Main Functions

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `_start` | Entry point | argc, argv | - |
| `present_encrypt_block` | Encrypt one block | RAX=plaintext | RAX=ciphertext |
| `present_decrypt_block` | Decrypt one block | RAX=ciphertext | RAX=plaintext |
| `present_encrypt_cbc` | CBC encryption | RSI=input, RDI=output, RCX=blocks | - |
| `present_decrypt_cbc` | CBC decryption | RSI=input, RDI=output, RCX=blocks | - |

### Utility Functions

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `apply_padding` | Add PKCS#7 padding | RDI=buffer, RSI=length | RAX=new_length |
| `read_input_dynamic` | Read from file | RDI=FD, RSI=buffer | RAX/R12=bytes_read |
| `print_hex` | Print 64-bit hex | RAX=value | - |
| `print_decimal` | Print decimal | RAX=value | - |
| `strlen` | String length | RSI=string | RAX=length |

### Cryptographic Primitives

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `sBoxLayer` | Apply S-box | RAX=state | RAX=substituted |
| `inv_sBoxLayer` | Inverse S-box | RAX=state | RAX=substituted |
| `pLayer` | Bit permutation | RAX=state | RAX=permuted |
| `inv_pLayer` | Inverse permutation | RAX=state | RAX=permuted |
| `generate_round_keys` | Key schedule | [master_key] | [round_keys] |

---

## 🐛 Troubleshooting

### Issue: "Uso: ./present <archivo>"
**Cause**: No filename provided  
**Solution**: Provide a filename: `./02_bin/present myfile.txt`

### Issue: "[ERROR] No se pudo abrir el archivo."
**Cause**: File doesn't exist or no read permissions  
**Solution**: 
- Check file exists: `ls -l myfile.txt`
- Check permissions: `chmod +r myfile.txt`

### Issue: Compilation warnings about .bss section
**Cause**: Harmless warnings about alignment directives  
**Solution**: Ignore - these don't affect functionality

### Issue: File too large
**Cause**: File exceeds 4096 bytes  
**Solution**: Split file or increase buffer size in code

---

## 📈 Performance Tips

1. **File Size**: Keep files under 4KB for best performance
2. **Alignment**: Buffers are cache-aligned for optimal speed
3. **Batch Processing**: Process multiple small files separately

---

## 🔐 Security Warnings

⚠️ **DO NOT USE IN PRODUCTION**

This implementation:
- Uses fixed IV (insecure)
- Uses test key (zero key)
- No authentication
- No secure key storage
- Educational purpose only

---

## 📚 Additional Resources

- **Full Documentation**: See `README.md`
- **Phase 9 Tests**: See `03_docs/phase9_test_results.md`
- **Phase 11 Details**: See `03_docs/phase11_file_input.md`
- **Source Code**: See `00_src/main.asm`

---

## 💡 Common Use Cases

### Encrypt a message
```bash
echo "My secret message" > msg.txt
./02_bin/present msg.txt
```

### Verify encryption works
```bash
# The program automatically decrypts and shows the result
# Compare "Resultado Descifrado" with original input
```

### Process multiple files
```bash
for file in *.txt; do
    echo "Encrypting $file"
    ./02_bin/present "$file"
done
```

---

**Quick Reference Version**: 1.0  
**Last Updated**: December 2, 2025
