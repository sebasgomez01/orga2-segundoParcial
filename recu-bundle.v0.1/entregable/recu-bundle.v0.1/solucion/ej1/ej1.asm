; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

%define OFFSET_FIRST 0
%define OFFSET_LAST 8

%define OFFSET_NEXT 0
%define OFFSET_PREVIOUS 8
%define OFFSET_TYPE 16
%define OFFSET_HASH 24

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern calloc
extern malloc
extern free
extern str_concat

; Signatura de la función:
; string_proc_list* string_proc_list_create_asm(void);
; Inicializa una estructura de lista.

; Mapeo de parámetros a registros:
; La función no recibe ninguún parámetro

; Idea de la implementación: 
; Tengo que pedir memoria para la estructura, que ocupa 16 bytes, pues son dos punteros


string_proc_list_create_asm:
    ; prólogo
    push rbp
    mov rbp, rsp
    

    ; cuerpo
    ; Quiero llamar a calloc(numElems = 1, sizeElems = 16)
    ; cargo los parámetros:
    mov rdi, 1
    mov rsi, 16
    call calloc

    ; ahora tengo un rax el puntero a la posición de memoria reservada
    ; uso calloc que ya me pone todo en cero, pues quiero que sean punteros nulos
    ; como ya tengo en rax el puntero que tengo que devolver, no tengo que hacer más nada :)

    ; epílogo
    pop rbp 
    ret



; Signatura de la función:
; string_proc_node* string_proc_node_create_asm(uint8_t type, char* hash);

; Mapeo de parámetros a registros:
; rdi[type], rsi[hash]

; Idea de la implementación:


; Tengo que crear el nodo, para esto tengo que reservar 32 bytes de memoria, 
; una vez creado el nodo inicializo los campos, type, hash. El campo next lo inicializo como nulo, pues es el último nodo
; y el camplo previous también como null, pues es el primer nodo 

string_proc_node_create_asm:
    ; prólogo
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    ; cuerpo
    ; Primero me guardo los parámetros en registros no volátiles para no perderlos al llamar a calloc
    xor r15, r15 ; limpio r15
    xor r14, r14 ; limpio r14
    mov r15, rdi ; r15 = type
    mov r14, rsi ; r14 = hash

    ; Ahora quiero llamar calloc(numElems = 1, sizeElems = 32); 
    ; cargo los parámetros:
    mov rdi, 1
    mov rsi, 32
    call calloc 
    ; ahora tengo en rax el puntero al nodo
    ; Inicializo los campos type y hash:
    mov byte [rax + OFFSET_TYPE], r15b
    mov qword [rax + OFFSET_HASH], r14
    ; los punteros next y previous del nodo está inicalizados como nulos, pues use calloc
    ; como ya tengo en rax el puntero que quiero devolver, no tengo que hacer nada más

    ; epílogo
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; Signatura de la función: 
; void string_proc_list_add_node_asm(string_proc_list* list, uint8_t type, char* hash)

; Mapeo de parámetros a registros:
; rdi[list], rsi[type], rdx[hash]

; Idea de la implementación:
; Puedo llamar a la función string_proc_node* string_proc_node_create_asm(uint8_t type, char* hash);
; para crear un nodo con el type y el hash pasados como parámetro, next debe quedarse como un puntero nulo, pues es el último nodo,
; y previous debe apuntar al último nodo de la lista
; luego tengo que ir al último nodo de la lista y setear el campo next como el puntero al nodo recién creado
; por último hacer list.last = puntero al nodo creado

string_proc_list_add_node_asm:
    ; prólogo
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    ; cuerpo
    ; Primero me guardo los parámetros originales en registros no volátiles para que no se pierdan al realizar llamados a funciones
    ; limpio los no volátiles y rax:
    xor r15, r15
    xor r14, r14
    xor r13, r13
    xor r12, r12
    xor rax, rax
    mov r15, rdi ; r15 = list
    mov r14, rsi ; r14 = type
    mov r13, rdx ; r13 = hash

    ; Quiero llamar a la función: string_proc_node* string_proc_node_create_asm(uint8_t type, char* hash);
    ; cargo los parámetros:
    mov rdi, r14 ; rdi = type
    mov rsi, r13 ; rsi = hash
    call string_proc_node_create_asm 

    ; ahora tengo en rax el puntero al nodo creado, con los campos type y hash ya inicializados con el valor correspondiente
    ; me lo guardo en un registro no volátil
    mov r12, rax ; r12 = nodo*
    
    ; Tengo que inicializar el campo previous con el puntero al último nodo de la lista pasada por parámetro, osea nodo.previous = list.last
    mov r11, qword [r15 + OFFSET_LAST]           ; r11 = list.last
    ; ahora tengo en r11 el puntero last, chequeo si la lista no es vacía
    cmp r11, 0
    je .lista_vacia

    ; si la lista no es vacía:
    ; tengo que ir al último nodo de la lista y setear el campo next como el puntero al nodo recién creado
    ; En r11 tengo el puntero al último nodo de la lista Y en r12 el puntero al nodo creado
    mov qword [r11 + OFFSET_NEXT], r12 
    jmp .lista_no_vacia

    .lista_vacia:
        mov qword [r15 + OFFSET_FIRST], r12 

    .lista_no_vacia:
        ; por último hacer list.last = puntero al nodo creado
        ; en r15 tengo list 
        mov qword [r12 + OFFSET_PREVIOUS], r11 ; nodo.previous = list.last
        mov qword [r15 + OFFSET_LAST], r12


    ; epílogo
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; Signatura de la función: 
; char* string_proc_list_concat_asm(string_proc_list* list, uint8_t type, char* hash);

; Genera un nuevo hash concatenando el pasado por parámetro con todos los hashes de los nodos
; de la lista cuyos tipos coinciden con el pasado por parámetro.

; Mapeo de parámetros a registros: 
; rdi[list], rsi[type], rdx[hash]

; Idea de la implementación:
; Lo que tengo que hacer es ir recorriendo los nodos, me traigo el valor de type, comparo con el valor pasado por parámetro
; Si los type coinciden, concateno los strings
; Si los type NO COINCIDEN, paso al siguiente nodo
; 

string_proc_list_concat_asm:
    ; prólogo
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    push rbx 
    sub rsp, 8

    ; cuerpo
    ; Primero me guardo los parámetros originales de la función en registros no volátiles, para no perderlos al hacer llamadas a funciones:
    xor r15, r15
    xor r14, r14
    xor r13, r13
    xor r12, r12
    xor rbx, rbx
    mov r15, rdi ; r15 = list
    mov r14, rsi ; r14 = type 
    mov r13, rdx ; r13 = hash
    ;mov rbx, r13 ; rbx = hash // esta copia me la hago para poder comprar después y saber si esto ó no en la primera iteración
    ; si no estoy en la primera iteración, quiero hacer free con el puntero que estaba guardado en r13 

    mov r12, [r15 + OFFSET_FIRST] ; r12 = list->first
    ; chequeo si el puntero es nulo:
    cmp r12, 0
    je .fin

    .bucle:
        mov r11b, byte [r12 + OFFSET_TYPE] ; r11b = nodo.type
        cmp r14b, r11b ; comparo el type del nodo con el ṕasado por parámetro
        jne .avanzar_nodo
        ; En el caso de que el type coincida quiero concatenar los hashs
        mov r10, [r12 + OFFSET_HASH] ; r10 = nodo.hash
        ; quiero llamar a la función: char* str_concat(char* a, char* b);
        ; cargo los parámetros:
        mov rdi, r13 ; rdi = hash (en la primera iteración), luego la concatenación de hashes
        mov rsi, r10 ; rsi = nodo.hash
        call str_concat
        ; Ahora tengo  en rax el puntero al hash creado al concatenar ambos
        ; me lo guardo en un registro no volátil: 
        ; Si es la primera iteración, en r13 tengo el hash pasado por parámetro, así que no necesito hacer free
        ;mov r13, rax
        ;cmp r13, rbx
        ;je .no_hacer_free
        ;cmp r12, [r15]
        ;je .no_hacer_free 

        ;.hacer_free: 
        ;    mov rbx, rax ; 
            ; Si los punteros no son iguales, quiere decir que no estoy en la primera iteración, y necesito hacer free:
            ; quiero llamar la función: void free(void *ptr)
            ; cargo el parámetro
        ;    mov rdi, r13
        ;    call free

        ;.no_hacer_free:
        mov r13, rax
        ;mov r13, rbx


        ; Como cada vez que itere voy a llamar a str_concat y este me va a concatenar los parámetros creando uno nuevo, 
        ; necesito liberar la memoria


        .avanzar_nodo:
            mov r12, [r12 + OFFSET_NEXT] ; me guardo el puntero al siguiente nodo en r12
            ; chequeo si el puntero es nulo:
            cmp r12, 0
            je .fin
            jmp .bucle

    .fin:
    mov r13, rax
    ; epílogo
    add rsp, 8
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp

    ret 
