section .text

%define SYS_WRITE 1

%define SYS_1 1
%define SYS_0 0
; Принимает код возврата и завершает текущий процесс
exit:
    mov rax, 60
    syscall

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax ; обнуляем rax, чтобы начать с 0 (длина строки)
    xor rcx, rcx ; обнуляем rcx (будет использоваться для обхода строки)
    .loop:
        cmp byte [rdi + rcx], 0 ; проверяем, является ли это нулевым байтом              
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
    mov rdi, SYS_WRITE             ; 1 - дескриптор stdout
    mov rax, SYS_WRITE             ; Системный вызов sys_write (1)
    syscall                ; Вызов системного вызова
    ret
    .done:
        ret

; Принимает код символа и выводит его в stdout
print_char:
    ; Принимаем код символа в rdi
    push rdi
    mov rax, SYS_WRITE                 ; Номер системного вызова write
    mov rdi, SYS_WRITE                 ; Файл дескриптор 1 (stdout)
    ; Подготовка к записи символа
    mov rsi, rsp               ; Указываем на стек для хранения символа
    mov rdx, 1                 ; Количество байт для записи (один символ)
    syscall                    ; Выполняем системный вызов для вывода символа
    pop rdi
    ret                        ; Возвращаемся из функции

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, 10           ; Код символа новой строки (0xA) в rdi
    jmp print_char                  ; Возврат из функции     




print_uint:
	push rbp
	mov rbp, rsp			;в rbp теперь указатель на вершину стека
	mov rax, rdi			;переместить число в rax
	mov rdi, 10				;чтобы делить на 10
	sub  rsp, 32			;выделить место на стеке
	dec  rbp				;положить туда 0
	mov  byte[rbp], 0
	.loop:
		dec  rbp			;подвинуть указатель
	  xor  rdx, rdx
	  div  rdi				;разделить на 10
	  add  rdx, '0'			;добавить код нуля, чтобы получить цифру
	  mov  byte[rbp], dl	;положить на стек
	  test rax, rax			;закончить цикл, если всё число рассмотрено
	  jnz  .loop
	mov rdi, rbp			;печать числа
	call print_string
	add rsp, 32			;вернуть стек на место, убрать выделенный буфер
	pop rbp
    ret


; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
	test rdi, rdi 	;установка флагов
	jns .unsigned 	;если беззнаковое, печатать через print_uint
	push rdi 		;сохранить число
	mov rdi, '-' 	;напечатать минус
    call print_char ;восстановить число
	pop rdi
	neg rdi 		;сделать число положительным
	.unsigned:
		jmp print_uint

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
    sub rsp, SYS_1             ; Выделяем 1 байт на стеке
    xor rax, rax             ; Код системного вызова для read
    mov rdi, SYS_0             ; Дескриптор файла 0 (stdin)
    lea rsi, [rsp]         ; Адрес буфера - адрес на стеке
    mov rdx, SYS_1             ; Читаем 1 байт
    syscall                 ; Вызываем системный вызов
    ; Проверяем, сколько байт было прочитано
    cmp rax, SYS_1             ; Если прочитано 1 байт
    je .char_read          ; Переходим к возвращению символа
    ; Если rax не равен 1, значит, либо ошибка, либо eof
    mov eax, SYS_0             ; Возвращаем 0 (оконечный символ)
    add rsp, SYS_1             ; Восстанавливаем стек
    ret                     ; Выходим из функции
    .char_read:
        ; Если символ успешно прочитан
        movzx rax, byte [rsp]  ; Загружаем символ в rax (расширяем до 64 бит)
        add rsp, SYS_1             ; Восстанавливаем стек
        ret                     ; Возвращаем символ

read_word:
	push r14
  push r15
  xor r14, r14
  mov r15, rsi
  dec r15

  .read_first:
	  push rdi
	  call read_char
	  pop rdi
	  cmp al, ' '
	  je .read_first
	  cmp al, 10
	  je .read_first
	  cmp al, 13
	  je .read_first
	  cmp al, 9
	  je .read_first
	  test al, al
	  jz .read_success

  .read_next:
	  mov byte [rdi + r14], al
	  inc r14

	  push rdi
	  call read_char
	  pop rdi
	  cmp al, ' '
	  je .read_success
	  cmp al, 10
	  je .read_success
	  cmp al, 13
	  je .read_success
	  cmp al, 9
	  je .read_success
	  test al, al
	  jz .read_success
	  cmp r14, r15
	  je .read_err
	  jmp .read_next

  .read_success:
	  mov byte [rdi + r14], 0
	  mov rax, rdi
	  mov rdx, r14
	  pop r15
	  pop r14
	  ret

  .read_err:
	  xor rax, rax
		xor rdx, rdx
	  pop r15
	  pop r14
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
    xor rax, rax                 ; Обнуляем счетчик длины
    xor rcx, rcx                 ; Обнуляем rcx для хранения символа

.looper:                         ; [Итерация по строке]
    mov byte cl, [rdi + rax]     ; Загружаем символ из исходной строки
    test cl, cl                    ; Проверяем, достигли ли конца строки
    jz .done                     ; Если да, выходим

    mov byte [rsi + rax], cl     ; Копируем символ в буфер
    inc rax                      ; Увеличиваем счетчик
    jmp .looper                  ; Продолжаем цикл

.done:
    mov byte [rsi + rax], 0      ; Добавляем нулевой терминатор в конец скопированной строки

    cmp rax, rdx                  ; Сравниваем длину строки и буфера
    jl .return                    ; Если длина строки меньше буфера, возвращаем
    xor eax, eax                  ; Иначе обнуляем rax

.return:
    ret


