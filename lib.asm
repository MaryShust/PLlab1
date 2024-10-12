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
 



; Выводит знаковое 8-байтовое число в десятичном формате 
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

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    xor rcx, rcx  
    xor rax, rax
    .loop:
        mov  al, byte[rdi + rcx]
        cmp  al, byte[rsi + rcx]  ; сравниваем байты               
        jne  .not_equal             
        inc  rcx
        test al, al
        jnz  .loop
        mov  rax, 1
        ret
    .not_equal:
        xor  rax, rax
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    ; Подготовка для чтения символа из stdin
    ; Используем системный вызов read (номер 0 по умолчанию) 
    ; Создаем буфер для хранения символа
    sub rsp, 1             ; Выделяем 1 байт на стеке
    mov rax, 0             ; Код системного вызова для read
    mov rdi, 0             ; Дескриптор файла 0 (stdin)
    lea rsi, [rsp]         ; Адрес буфера - адрес на стеке
    mov rdx, 1             ; Читаем 1 байт
    syscall                 ; Вызываем системный вызов
    ; Проверяем, сколько байт было прочитано
    cmp rax, 1             ; Если прочитано 1 байт
    je .char_read          ; Переходим к возвращению символа
    ; Если rax не равен 1, значит, либо ошибка, либо eof
    mov eax, 0             ; Возвращаем 0 (оконечный символ)
    add rsp, 1             ; Восстанавливаем стек
    ret                     ; Выходим из функции
    .char_read:
        ; Если символ успешно прочитан
        movzx rax, byte [rsp]  ; Загружаем символ в rax (расширяем до 64 бит)
        add rsp, 1             ; Восстанавливаем стек
        ret                     ; Возвращаем символ

read_word:
    push rdi                     ; сохранить значение rdi
    push r12                     ; сохранить r12
    push r13                     ; сохранить r13
    mov r12, rdi                 ; r12 - указатель на буфер
    mov r13, rsi                 ; r13 - длина буфера

.skip_whitespace:                ; пропуск пробелов
    call read_char
    cmp rax, 0x20                ; проверка на пробел
    je .skip_whitespace
    cmp rax, 0x9                 ; проверка на табуляцию
    je .skip_whitespace
    cmp rax, 0xA                 ; проверка на перевод строки
    je .skip_whitespace

    cmp rax, 0                   ; конец ввода
    je .end

.write_loop:                    ; основной цикл записи символов
    mov [r12], al                ; записать символ в буфер
    inc r12                      ; увеличить указатель на буфер
    dec r13                     ; уменьшить счетчик длины буфера
    call read_char               ; считать следующий символ
    cmp rax, 0                   ; проверить конец ввода
    je .end                      ; перейти к завершению, если конец
    cmp rax, 0x20                ; проверить пробел
    je .end                      ; завершить, если пробел
    cmp rax, 0x9                 ; проверить табуляцию
    je .end                      ; завершить, если табуляция
    cmp rax, 0xA                 ; проверить перевод строки
    je .end                      ; завершить, если перевод строки
    jmp .write_loop              ; повторить для следующего символа

.end:
    mov byte [r12], 0            ; добавить нуль-терминатор
    mov rdx, r12                 ; сохранить адрес конца слова
    sub rdx, rdi                 ; вычислить длину слова
    pop r13                      ; восстановить r13
    pop r12                      ; восстановить r12
    pop rdi                      ; восстановить rdi
    ret

parse_uint:
  push rbx
  xor rdx, rdx
  xor rax, rax
  xor rbx, rbx
  .loop:
    mov bl, byte [rdi + rdx]
    sub bl, '0'
    jl .return
    cmp bl, 9
    jg .return
    push rdx
    mov rdx, 10
    mul rdx       ; rax *= 10
    pop rdx
    add rax, rbx  ; rax += rbx
    inc rdx
    jmp .loop
  .return:
    pop rbx
    ret

; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был)
; rdx = 0 если число прочитать не удалось
parse_int:
    xor rax, rax ; Обнуляем rax для хранения результата
    push rbx
    mov bl, byte[rdi]
    cmp bl,'-'
    je  .negative
    jmp .positive
    .negative:
        inc rdi
        call parse_uint
        inc rdx
        neg rax
        jmp .end
    .positive:
        call parse_uint
    .end:
        pop rbx
        ret


; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rax, rax
    xor eax, eax              ; Обнуляем счетчик длины
    .looper:                 ; [Итерация по строке]
        mov byte cl, [rdi + rax]  ; Символ в rcx
        mov byte [rsi + rax], cl  ; rcx в буфер
        inc rax               ; Увеличиваем счетчик
        cmp cl, 0               ; Если символ != null-terminator
        jnz .looper              ; То продолжаем
    cmp rax, rdx                  ; Сравниваем длину строки и буфера
    jl .return                    ; Если меньше, то возврат
    xor eax, eax                  ; Иначе обнуляем rax
    .return:                      ; [Возврат]
        ret   

