section .text

; Принимает код возврата и завершает текущий процесс
exit:
    mov rax, 60
    syscall

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax ; обнуляем rax, чтобы начать с 0 (длина строки)
    xor rcx, rcx ; обнуляем rcx (будет использоваться для обхода строки)
    .loop:
        mov al, byte [rdi + rcx] ; загружаем байт строки в al
        cmp al, 0                ; проверяем, является ли это нулевым байтом
        je .done                 ; если да, переходим к завершению
        inc rcx                  ; увеличиваем счетчик
        jmp .loop                ; повторяем цикл
    .done:
        mov rax, rcx            ; помещаем длину строки в rax
        ret                      ; возвращаемся

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
; Вход: rdi - указатель на строку
print_string:
    ; Предполагаем, что указатель на строку передан в rdi
    xor rax, rax              ; заношу 0 в rax (можно не обязательно, но для чистоты)
    ; Проверяем, не нулевой ли указатель
    test rdi, rdi
    jz .done               ; Если указатель нулевой, просто выходим
    mov rsi, rdi           ; Указатель на строку
    ; Получаем длину строки
    push rsi    
    call string_length     ; В rax теперь длина строки
    pop rsi
    ; Параметры для системного вызова
    mov rdx, rax           ; Длина строки    
    mov rdi, 1             ; 1 - дескриптор stdout
    mov rax, 1             ; Системный вызов sys_write (1)
    syscall                ; Вызов системного вызова
    ret
    .done:
        ret

; Принимает код символа и выводит его в stdout
print_char:
    ; Принимаем код символа в rdi
    push rdi
    mov rax, 1                 ; Номер системного вызова write
    mov rdi, 1                 ; Файл дескриптор 1 (stdout)
    ; Подготовка к записи символа
    mov rsi, rsp               ; Указываем на стек для хранения символа
    mov rdx, 1                 ; Количество байт для записи (один символ)
    syscall                    ; Выполняем системный вызов для вывода символа
    pop rdi
    ret                        ; Возвращаемся из функции

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, 10           ; Код символа новой строки (0xA) в rdi
    call print_char       ; Вызов функции print_char для вывода новой строки
    ret                   ; Возврат из функции     



print_uint:
 xor  r9, r9                ; couter
 mov  rsi, 10               ; divisor
 mov  rax, rdi
 .loop:
  xor rdx, rdx
  inc  r9
  div  rsi                  ; rdx contains the remainder of div instruction
  add  rdx, 48              ; convert digit to ASCII
  push rdx                  ; save symbol on stack
  test rax, rax
  jnz  .loop
  jmp  .result
 .result:
  dec  r9    
  mov  rsi, rsp
  mov  rdx, 1
  mov  rax, 1
  mov  rdi, 1
  syscall                   ; print saved symbol
  pop  rax
  test r9, r9
  jz  .end
  jmp  .result
 .end:
  ret
 

print_int:
 test rdi, rdi
 jge  .print                ; check if number is positive or negative
 neg  rdi                   
 push rdi
 mov  rdi, '-'
 
 call print_char
 pop  rdi
 .print:
  sub  rsp, 8               ; align stack
  call print_uint
  add  rsp, 8
  ret  


string_equals:
 xor  rcx, rcx              ; counter
 .loop:
  mov  al, byte[rdi + rcx]
  cmp  al, byte[rsi + rcx]
  jne  .false               ; check if symbols are equal
  inc  rcx
  test al, al
  jnz  .loop
  mov  rax, 1
  ret
 .false:
  xor  rax, rax
  ret

read_char:
 xor  rax, rax
 xor  rdi, rdi
 mov  rdx, 1
 push 0                     ; free space on stack
 mov  rsi, rsp              ; rsp points on top of the stack
 syscall                    ; after syscall symbol will be on top of the stack
 pop  rax
 ret


read_word:
 push rdi                   ; save original value of rdi
 push r12                   ; save calle-saved r12
 mov  r12, rdi              ; points to empty space in buffer
 push r13                   ; save calle-saved r13
 mov  r13, rsi              ; counter for buffer length 
 .check:                    ; section for skipping ' ', '\n' and '\t' symbols
  call  read_char           
  cmp  rax, 0x20            ; ' ' symbol check
  jz  .check
  cmp  rax, 0x9             ; '\t' symbol check
  jz  .check
  cmp  rax, 0xA             ; '\n' symbol check
  jz  .check
  cmp  rax, 0               ; input end check
  jz  .end
  jmp  .place
 .loop:                     ; section for symbols which go after ' ', '\n' and '\t' symbols
  call read_char            
  cmp     rax, 0
  jz  .end
  cmp  rax, 0x20
  jz  .end
  cmp  rax, 0x9
  jz  .end
  cmp  rax, 0xA
  jz  .end
 .place:                    ; place symbol in buffer
  mov  byte[r12], al
  inc  r12
  dec  r13
  test r13, r13
  jge  .loop
  mov  rax, 0
  pop  r13
  pop  r12
  pop  rdi
  ret
 .end:  
  mov  byte[r12], 0         ; add null terminator
  mov  rdx, r12             
  pop  r13
  pop  r12
  pop  rax                  ; restore original value of rdi in rax
  sub  rdx, rax             ; r12 (last buffer index) - rdi (first buffer index) = length
  ret

parse_uint:
 xor  rax, rax              
 xor  rcx, rcx              ; counter
 mov  rsi, 10               
 xor  r9, r9                ; buffer
 .loop: 
  mov  r9b, byte[rdi + rcx] ; place symbol in buffer
  cmp  r9, 48               ; check if ASCII code is less than code of '0'
  jl  .end
  cmp  r9, 57               ; check if ASCII code is bigger than code of '9'
  jg  .end
  mul  rsi
  sub  r9, 48               ; convert from ASCII to digit
  add  rax, r9
  inc  rcx
  cmp  rcx, 1
  jnz  .loop
  test rax, rax
  jz  .end
  jmp  .loop
 .end:
  mov  rdx, rcx
  ret

parse_int:
 xor  rax, rax              
 xor  r9, r9                ; buffer
 mov  r9b, byte[rdi]
 cmp  r9, '-'               
 jz  .minus                 ; check if first symbol is '-'
 sub  rsp, 8                ; align stack
 call parse_uint
 add  rsp, 8
 ret
 .minus:
  inc  rdi                  ; rdi should point to the new symbol 
  sub  rsp, 8               ; align stack
  call parse_uint
  add  rsp, 8
  neg  rax
  test rdx, rdx             
  jz  .end
  inc  rdx                  ; add 1 to length if at least one digit come after '-'
 .end:
  ret

string_copy:
 xor  rcx, rcx              ; counter
 .loop:
  cmp  rdx, rcx             ; check if counter is less than length of buffer
  jle  .fail
  mov  al, [rdi + rcx]
  mov  [rsi + rcx], al
  inc  rcx
  test al, al               ; check null terminator
  jnz  .loop
  mov  rax, rcx
  ret
 .fail:
  xor  rax, rax
 ret
