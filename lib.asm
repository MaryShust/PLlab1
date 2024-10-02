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
        
        
        
        


; Выводит беззнаковое 8-байтовое число в десятичном формате
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    ; rdi содержит число, которое необходимо распечатать
    sub rsp, 32                ; Выделяем место (32 байта для буфера)
    lea rsi, [rsp + 31]        ; Указываем на конец выделенного места
    mov byte [rsi], 0          ; Помещаем null-терминатор в конец
    ; Проверяем случай, когда число равно нулю
    cmp rdi, 0
    je .print_zero
    .convert_to_string:
        ; Преобразуем число в строку с конца
        mov rax, rdi               ; Копируем число в rax для деления
    .next_digit:
        xor rdx, rdx               ; Обнуляем rdx перед делением
        mov rcx, 10                ; Делитель 10
        div rcx                    ; rax = rax / 10, rdx = остаток
        add dl, '0'                ; Преобразуем остаток в ASCII символ
        dec rsi                    ; Сдвигаем указатель буфера влево
        mov [rsi], dl              ; Записываем символ в буфер
        test rax, rax              ; Проверяем, не равно ли rax нулю
        jnz .next_digit            ; Если не ноль, продолжаем делить
        ; Печатаем строку
        mov rdi, rsi               ; Указатель на строку для вывода
        call print_string
        add rsp, 32                ; Освобождаем стек
        ret
    .print_zero:
        mov byte [rsi - 1], '0'    ; Записываем '0' в буфер
        mov rdi, rsi               ; Указатель на строку для вывода
        call print_string          ; Печатаем строку '0'
        add rsp, 32                ; Освобождаем стек
        ret

; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    ; Вход: RDI содержит знаковое 8-байтовое число
    xor rax, rax          ; Обнуляем RAX для работы
    ; Проверка на ноль
    test rdi, rdi         ; Проверяем, является ли число 0
    jz .print_zero        ; Если 0, сразу выводим '0'
    ; Проверка на знак
    cmp rdi, 0
    jl .print_negative ; если rdi < 0, переход к метке .print_negative
    ; Положительное число или ноль
    jmp .print_positive
    .print_negative:
        ; Печать знака '-'
        mov rdi, '-'
        call print_char
        neg rdi
        ; Перемещаем положительное число в rsi
        mov rsi, rdi 
        jmp .print_positive
    .print_positive:
        mov rsi, rdi ; Передаем положительное число в rsi
        call print_uint
        ret
    .print_zero:
        ; Обработка вывода нуля
        mov rdi, '0'
        call print_char
        ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
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

; Принимает: адрес начала буфера, размер буфера
; Эта функция должна дописывать к слову нуль-терминатор        
read_word:
    push rdi
    push rbx    
    push r12
    mov rbx,rdi ; moving buffer adress to rbx 
    mov r12,rsi ; moving buffer len to r12
    .lp1:
         call read_char
         cmp rax, 0x20 ; compare to space
         je .lp1
         cmp rax, 0x9 ; compare to tab
         je .lp1
         cmp rax, 0xA ; compare to \n
         je .lp1
    .mnlp: ;main loop
        cmp rax, 0x20 ; compare to space
        je .end
        cmp rax, 0x9 ; compare to tab
        je .end
        cmp rax, 0xA ; compare to \n
        je .end
        cmp rax, NULL_TERMINATED ; compare to null_terminated
        je .end
        dec r12
        cmp r12, 0
        jbe .overflow
        mov byte [rbx], al
        call read_char
        inc rbx
        jmp .mnlp
    .end:
        mov byte [rbx], NULL_TERMINATED
        pop r12
        pop rbx
        mov rdi, [rsp]
        call string_length
        mov rdx,rax
        pop rax
        ret
    .overflow:
        pop r12
        pop rbx
        pop rdi
        xor rax, rax
        ret

; Принимает указатель на строку, пытается
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rdx, rdx
	xor rcx, rcx
	.loop:
		xor rcx,rcx
		mov cl, [rdx + rdi]
		cmp cl, '0'
		jc .stop
		cmp cl, '9'
		ja .stop
		sub rcx, '0'
		
		mov r11,10
		push rdx
		mul r11
		pop rdx
		
		add rax, rcx
		inc rdx
		jmp .loop
	.stop:
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
        
        
        
        