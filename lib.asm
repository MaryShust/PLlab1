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




; Выводит беззнаковое 8-байтовое число в десятичном формате
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    ; rdi содержит число, которое необходимо распечатать
    ; Создаем массив для хранения строкового представления числа
    sub rsp, 32           ; Выделяем место (20 байт для числа плюс 12 байт для выравнивания)
    ; Указатель на конец буфера
    lea rsi, [rsp + 31]   ; Указываем на конец выделенного места
    mov byte [rsi], 0     ; Помещаем null-терминатор в конец
    ; Проверяем случай, когда число равно нулю
    cmp rdi, 0            ; Если число равно 0
    je .print_zero        ; Переходим к обработке вывода нуля
    .convert_to_string:
        ; Преобразуем число в строку с конца
        mov rax, rdi           ; Копируем число в rax для деления
    .next_digit:
        ; Делим rax на 10, результат деления в rax, остаток в rdx
        xor rdx, rdx           ; Обнуляем rdx перед делением
        mov rcx, 10            ; Десятичная система
        div rcx                ; rax = rax / 10, rdx = rax % 10
        ; Преобразуем остаток от деления в ASCII символ
        add dl, '0'            ; Преобразуем остаток в ASCII код символа
        ; Записываем ASCII код символа в буфер
        dec rsi                ; Сдвигаем указатель буфера влево
        mov [rsi], dl          ; Записываем остаток в буфер
        ; Проверяем, всё ли число обработали
        test rax, rax         ; Проверяем, не равно ли rax нулю
        jnz .next_digit        ; Если не ноль, продолжаем делить
        ; Печатаем строку
        mov rdi, rsi          ; Указатель на строку для вывода
        call print_string
        ; Освобождаем стек
        add rsp, 32           ; Восстанавливаем стек
        ret                   ; Возвращаемся из функции
    .print_zero:
        ; Специальный случай вывода нуля
        mov byte [rsi - 1], '0' ; Записываем '0' в буфер
        mov rdi, rsi          ; Указатель на строку для вывода
        call print_string      ; Печатаем строку '0'
        ; Освобождаем стек
        add rsp, 32           ; Восстанавливаем стек
        ret                   ; Возвращаемся из функции

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
        mov rax, rdi
        mov rdi, '-'
        call print_char
        mov rdi, rax
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
    ; Входные параметры: 
    ; rdi - указатель на первую строку
    ; rsi - указатель на вторую строку
    xor rax, rax             ; Обнуляем rax (по умолчанию возвращаем 0)
    .loop:
        mov al, [rdi]            ; Получаем байт из первой строки
        mov bl, [rsi]            ; Получаем байт из второй строки
        ; Сравниваем байты
        cmp al, bl               ; Сравниваем байты
        jne .not_equal           ; Если не равны, переходим к возвращению 0
        test al, al              ; Проверяем, является ли текущий байт нулевым
        jz .equal                ; Если нулевой, обе строки равны
        inc rdi                  ; Переходим к следующему символу первой строки
        inc rsi                  ; Переходим к следующему символу второй строки
        jmp .loop                ; Продолжаем сравнение
    .equal:
        mov rax, 1               ; Если строки равны, возвращаем 1
        ret                      ; Возвращаемся из функции
    .not_equal:
        ret                      ; Возвращаемся из функции с rax = 0 (по умолчанию)


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

; Принимает: адрес начала буфера, размер буфера
; Эта функция должна дописывать к слову нуль-терминатор        
read_word:
    ; Принимаем в аргументах: адрес буфера в rdi и размер буфера в rsi
    ; rax - возвращаемый адрес буфера или 0
    ; rdx - длина слова
    xor rdx, rdx         ; Обнуляем rdx (это будет длина слова)
    .skip_whitespace:
        ; Читаем символы, пропуская пробелы
        call read_char       ; Считываем символ    
        cmp al, 0            ; Проверяем, не конец ли ввода (EOF)
        je .failure          ; Если конец, завершаем с ошибкой
        cmp al, 0x20         ; Проверяем, пробел (ASCII 32)
        je .skip_whitespace
        cmp al, 0x9          ; Проверяем, табуляция (ASCII 9)
        je .skip_whitespace
        cmp al, 0xa          ; Проверяем, перевод строки (ASCII 10)
        je .skip_whitespace
        ; Если мы дошли сюда, значит считанный символ не является пробельным
        ; Сохраняем символ в буфер
        mov [rdi + rdx], al  ; Сохраняем его по текущей длине слова
        inc rdx              ; Увеличиваем длину слова
        ; Проверяем, не превышаем ли размер буфера
        cmp rdx, rsi         ; Если длина > размер буфера
        jae .failure         ; Возвращаем ошибку
        ; Читаем следующий символ
        jmp .skip_whitespace 
    .end_read:
        ; Если цикл завершился
        ; Добавляем нулевой термингатор
        mov byte [rdi + rdx], 0
        mov rax, rdi         ; Возвращаем адрес буфера
        ret
    .failure:
        ; В случае ошибки, возвращаем 0
        xor rax, rax         ; Возвращаем 0
        ret

; Принимает указатель на строку, пытается
; rdx = 0 если число прочитать не удалось
parse_uint:
    ; Входные параметры:
    ; rdi - указатель на строку
    xor rax, rax            ; Обнуляем rax для хранения результата
    xor rcx, rcx            ; Обнуляем rcx для подсчета длины (количество символов)
    .next_char:
        movzx rbx, byte [rdi + rcx]  ; Загружаем текущий символ строки в rbx
        cmp rbx, '0'                  ; Проверяем, является ли символ меньше '0'
        jb .finish                     ; Если меньше, завершаем (нет числа)
        cmp rbx, '9'                  ; Проверяем, является ли символ больше '9'
        ja .finish                     ; Если больше, завершаем (нет числа)
        ; Добавляем цифру в rax
        sub rbx, '0'                  ; Преобразуем символ в число
        ; Проверяем на переполнение при умножении
        mov rdx, rax                  ; Сохраняем текущее значение rax в rdx
        shl rax, 3                    ; Умножаем rax на 8 (операцию простого умножения подтверждает)
        shl rax, 1                    ; Умножаем на 2 (итого на 10 для получения остатка 10)
        add rax, rbx                  ; Добавляем прочитанное число
        inc rcx                       ; Увеличиваем счетчик количества обработанных символов
        jmp .next_char                ; Переходим к следующему символу
    .finish:
        ; Если обработали хотя бы один символ, возвращаем длину и результат
        cmp rcx, 0                    ; Проверяем делали ли мы попытку чтения
        je .zero_result                ; Если длина равна 0, возвращаем ноль
        ; Возвращаем результат
        mov rdx, rcx                  ; Длина числа в rdx
        ret
    .zero_result:
        xor rax, rax                  ; Если не удалось прочитать число, возвращаем 0
        xor rdx, rdx                  ; Длина в rdx будет 0
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
