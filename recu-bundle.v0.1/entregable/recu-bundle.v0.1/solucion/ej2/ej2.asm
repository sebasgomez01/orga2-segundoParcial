global combinarImagenes_asm

section .data 

mascara_setear_alpha: DD 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000 
mascara_shuffle_caso_1_comparacion: DB 1, 1, 1, 1, 5, 5, 5, 5, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff  
mascara_suma_componente_b_shuffle: DB 2, 0xff, 0xff, 0xff, 6, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
mascara_suma_componente_b_and: DD 0x000000FF, 0x000000FF, 0x00, 0x00
mascara_resta_componente_r_shuffle: DB 0xff, 0xff, 0, 0xff, 0xff, 0xff, 4, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
mascara_resta_componente_r_and: DD 0x00FF0000, 0x00FF0000, 0x00, 0x00
mascara_resta_componente_g_and: DD 0x0000FF00, 0x0000FF00, 0x00, 0x00
mascara_todos_unos: DD 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000, 0x00000000

;########### SECCION DE TEXTO (PROGRAMA)
section .text

; Signatura de la función:
; void combinarImagenes(uint8_t *src1, uint8_t *src2, uint8_t *dst, uint32_t width, uint32_t height)

; Mapeo de parámetros a registros: 
; rdi[src1]. rsi[src2], rdx[dst], rcx[width], r8[height]

; CASO 1) A[ij] G > B[ij] G
; la idea en el caso 1 es guardar en un xmm solo los componentes G del pixel de A y en otro xmm solo los componentes G del pixel de B
; Así puedo hacer la comparación:
; | AG | AG | AG | AG | > | BG | BG | BG | BG |
; De este modo descarto los píxeles que no cumplen la primera condición
; En el caso 2 simplemente es negar el resultado de esa comparación
; La máscara del shufle que me sirve para esto es: | 1 | 1 | 1 | 1 | 5 | 5 | 5 | 5 | ff | ff | ff | ff | ff | ff | ff | ff | 
; Pues el índice del valor green es el 1 si pensamos los xmm en 16 paquetes de 8 bits


combinarImagenes_asm:

    PUSH rbp
    MOV rbp, rsp
    ; cuerpo
	; 1. Busco la cantidad de pixeles a pintar: width * height
    MOV RAX, R8  ; Me traigo el alto a rax
    MOV R9, RDX
    IMUL RCX      ; Multiplico el ancho x alto
    MOV RDX, R9

    .pintar_pixeles:
        ; 2. Cargo 2 pixeles a registros, para luego verificar a que caso pertenecen y pintarlos de esa manera en el destino
        MOVQ XMM1, [RDI] ; XMM = B1 G1 R1 A1 B2 G2 R2 A2 XX XX XX XX XX XX XX XX (128 bits) (2 PIXELES DE LA IMAGEN A)
        MOVQ XMM2, XMM1 

        MOVQ XMM3, [RSI] ; (2 PIXELES DE LA IMAGEN B)
        MOVQ XMM4, XMM3  

        ; CASO 1) A[ij] G > B[ij] G:
        MOVDQU XMM5, [mascara_shuffle_caso_1_comparacion]
        PSHUFB XMM1, XMM5  ; XMM1 =  | AG1 | AG1 | AG1 | AG1 |  AG2 | AG2 | AG2 | AG2 | XX | XX | XX | XX | XX | XX | XX | XX |
        PSHUFB XMM3, XMM5  ; XMM2 =  | BG1 | BG1 | BG1 | BG1 |  BG2 | BG2 | BG2 | BG2 | XX | XX | XX | XX | XX | XX | XX | XX |
        ; ERROR EN ESTA COMPARACION EN LA ITERACION 6, POR ALGUNA RAZON LA COMPARACION DA MAL
        PCMPGTB XMM1, XMM3 ; HAGO LA COMPARACIÓN DE LAS COMPONENTES G DE AMBOS PÍXELES: A[ij] G > B[ij] G, GUARDO EL RESULTADO EN XMM1
        PAND XMM2, XMM1    ; GUARDO EN XMM2 LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        PAND XMM4, XMM1    ; GUARDO EN XMM4 LOS PIXELES DE B QUE CUMPLEN LA CONDICION
        MOVQ XMM1, XMM2    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        MOVQ XMM7, XMM2    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        MOVQ XMM9, XMM2    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        MOVQ XMM3, XMM4    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 
        MOVQ XMM8, XMM4    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 
        MOVQ XMM10, XMM4    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 

        ; Ahora quiero sumarle a la componente B del pixel de A la componente R del pixel de B:
        MOVQ XMM6, [mascara_suma_componente_b_shuffle]
        PSHUFB XMM4, XMM6
        ; AL HACER ESTE SHUFLE CON ESA MÁSCARA CON LOS PIXELES DE B QUE CUMPLEN LA CONDICION, LO QUE HAGO ES PONER EL VALOR DE LA COMPONENTE 
        ; R DE LOS PÍXELES DE B EN LA POSICION CORRESPONDIENTE A LA COMPONENTE B DE LOS PIXELES DE A Y CERO EN EL RESTO DE LOS COMPONENTES
        MOVQ XMM6, [mascara_suma_componente_b_and]
        PAND XMM2, XMM6 
        ; AL HACER ESTE AND CON LOS PIXELES DE LA IMAGEN A, LO QUE HAGO ES MANTENER SOLAMENTE EL VALOR DE LOS COMPONENTES B Y PONER EL RESTO EN CERO
        ; DE ESTE MODO PUEDO HACER LA SUMA: A[ij]B + B[ij]R
        PADDB XMM2, XMM4
        ; AHORA TENGO EN XMM2:
        ; | AB1 + BR1 | 0 | 0 | 0 | AB2 + BR2 | 0 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 

        ; AHORA QUIERO RESTARLE A LA COMPONENTE BLUE DEL PIXEL DE LA IMAGEN B EL COMPONENTE RED DEL PIXEL DE LA IMAGEN A
        ; HAGO ALGO PARECIDO A LO QUE HICE ANTERIORMENTE:
        MOVQ XMM4, XMM3    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION EN XMM4

        ; LINEA AGREGADA:
        MOVQ XMM5, XMM1    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION EN XMM5

        MOVQ XMM6, [mascara_resta_componente_r_shuffle]
        PSHUFB XMM4, XMM6
        ; AL HACER ESTE SHUFFLE CON ESA MASCARA CON LOS PIXELES DE B QUE CUMPLEN LA CONDICION, LO QUE HAGO ES PONER EL VALOR DE LA COMPONENTE
        ; BLUE DE LOS PIXELES DE B EN LA POSICION CORRESPONDIENTE A LA COMPONENTE RED Y CERO EN EL RESTO DE LOS COMPONENTES
        
        ; LINEA COMENTADA
        ; MOVQ XMM8, XMM4    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 

        ; /* LINEAS AGREGADAS:
        MOVQ XMM6, [mascara_resta_componente_r_and]
        PAND XMM5, XMM6
        ; */

        PSUBB XMM4, XMM5
        ; AHORA TENGO EN XMM4:
        ; | 0 | 0 | BB1 - AR1 | 0 | 0 | 0 | BB2 - AR2 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        
        ; AHORA QUIERO RESTARLE A LA COMPONENTE GREEN DE A LA COMPONENTE GREEN DE B:
        MOVQ XMM6, [mascara_resta_componente_g_and]
        PAND XMM7, XMM6 ; PIXELES DE A
        PAND XMM8, XMM6 ; PIXELES DE B
        ; AL HACER ESTOS AND CON LOS PIXELES DE A (GUARDADOS EN XMM7) Y LOS PIXELES DE B (GUARDADOS EN XMM8) LO QUE HAGO ES QUEDARME SOLAMENTO
        ; CON LOS COMPONENTES GREEN DE CADA LOS PIXELES Y PONER EN CERO EL RESTO
        ; DE ESTE MODO AHORA PUEDO HACER B[ij] B − A[ij] R
        PSUBB XMM7, XMM8 
        ; AHORA TENGO EN XMM7:
        ; | 0 | AG1 - BG1 | 0 | 0 | 0 | AG2 - BG2 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 


        ; RESUMIENDO: 
        ; TENGO EN XMM2:
        ; | AB1 + BR1 | 0 | 0 | 0 | AB2 + BR2 | 0 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        ; TENGO EN XMM4:
        ; | 0 | 0 | BB1 - AR1 | 0 | 0 | 0 | BB2 - AR2 | 0 | XX | XX | XX | XX | XX | XX | XX | XX |
        ; TENGO EN XMM7:
        ; | 0 | AG1 - BG1 | 0 | 0 | 0 | AG2 - BG2 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        
        ; AHORA ME FALTA UNIRLOS:
        POR XMM2, XMM4
        POR XMM2, XMM7

        ; Ahora tengo en XMM2 LOS PIXELES QUE ENTRAN EN EL CASO 1 YA PROCESADOS, SOLO FALTA PONER LAS COMPONENTE ALPHA EN 255
        ; LO HAG0 AL FINAL DE TODO YA QUE TENGO QUE HACERLO PARA AMBOS CASOS



        ; CASO 2) !(A[ij] G > B[ij] G) :
        ; HAGO LA COMPARACIÓN COMO EL PRIMER CASO Y LA NIEGO:
        ; TENGO EN XMM9 LOS PIXELES DE A
        ; TENGO EN XMM10 LOS PIXELES DE B
        ; ME HAGO UNAS COPIAS MÁS:
        MOVDQU XMM11, XMM9
        MOVDQU XMM12, XMM10
        MOVDQU XMM5, [mascara_shuffle_caso_1_comparacion]
        PSHUFB XMM11, XMM5  ; XMM1 =  | AG1 | AG1 | AG1 | AG1 |  AG2 | AG2 | AG2 | AG2 | XX | XX | XX | XX | XX | XX | XX | XX |
        PSHUFB XMM12, XMM5  ; XMM2 =  | BG1 | BG1 | BG1 | BG1 |  BG2 | BG2 | BG2 | BG2 | XX | XX | XX | XX | XX | XX | XX | XX |
        PCMPGTB XMM11, XMM12 ; HAGO LA COMPARACIÓN DE LAS COMPONENTES G DE AMBOS PÍXELES: A[ij] G > B[ij] G, GUARDO EL RESULTADO EN XMM1
        ; AHORA TENGO QUE NEGAR EL RESULTADO DE XMM11:
        MOVDQU XMM6, [mascara_todos_unos]
        PXOR XMM11, XMM6

        ; AHORA TENGO EN XMM11 UNOS EN LA POSICIONES DE LOS PIXELES QUE ENTRAN EN EL CASO 2 Y CERO EN LOS QUE NO

        PAND XMM9, XMM11    ; GUARDO EN XMM9 LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        PAND XMM10, XMM11   ; GUARDO EN XMM10 LOS PIXELES DE B QUE CUMPLEN LA CONDICION
        MOVQ XMM3, XMM9    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        MOVQ XMM4, XMM9    ; ME GUARDO UNA COPIA DE LOS PIXELES DE A QUE CUMPLEN LA CONDICION 
        MOVQ XMM5, XMM10    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 
        MOVQ XMM6, XMM10    ; ME GUARDO UNA COPIA DE LOS PIXELES DE B QUE CUMPLEN LA CONDICION 

        ; ESTO ES IGUAL AL CASO 1
        ; Ahora quiero sumarle a la componente B del pixel de A la componente R del pixel de B:
        MOVQ XMM14, [mascara_suma_componente_b_shuffle]
        PSHUFB XMM5, XMM14
        ; AL HACER ESTE SHUFLE CON ESA MÁSCARA CON LOS PIXELES DE B QUE CUMPLEN LA CONDICION, LO QUE HAGO ES PONER EL VALOR DE LA COMPONENTE 
        ; R DE LOS PÍXELES DE B EN LA POSICION CORRESPONDIENTE A LA COMPONENTE B DE LOS PIXELES DE A Y CERO EN EL RESTO DE LOS COMPONENTES
        MOVQ XMM14, [mascara_suma_componente_b_and]
        PAND XMM3, XMM14 
        ; AL HACER ESTE AND CON LOS PIXELES DE LA IMAGEN A, LO QUE HAGO ES MANTENER SOLAMENTE EL VALOR DE LOS COMPONENTES B Y PONER EL RESTO EN CERO
        ; DE ESTE MODO PUEDO HACER LA SUMA: A[ij]B + B[ij]R
        PADDB XMM3, XMM5
        ; AHORA TENGO EN XMM3:
        ; | AB1 + BR1 | 0 | 0 | 0 | AB2 + BR2 | 0 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 


        ; ESTO TAMBIPEN ES IGUAL AL CASO 1:
        ; AHORA QUIERO RESTARLE A LA COMPONENTE BLUE DEL PIXEL DE LA IMAGEN B EL COMPONENTE RED DEL PIXEL DE LA IMAGEN A
        ; HAGO ALGO PARECIDO A LO QUE HICE ANTERIORMENTE:
        
        MOVQ XMM14, [mascara_resta_componente_r_shuffle]
        PSHUFB XMM6, XMM14
        ; AL HACER ESTE SHUFFLE CON ESA MASCARA CON LOS PIXELES DE B QUE CUMPLEN LA CONDICION, LO QUE HAGO ES PONER EL VALOR DE LA COMPONENTE
        ; BLUE DE LOS PIXELES DE B EN LA POSICION CORRESPONDIENTE A LA COMPONENTE RED Y CERO EN EL RESTO DE LOS COMPONENTES
        
        MOVQ XMM14, [mascara_resta_componente_r_and]
        PAND XMM4, XMM14
        ; AL HACER ESTE AND CON LOS PIXELES DE LA IMAGEN A, LO QUE HAGO ES MANTENER SOLAMENTE EL VALOR DE LOS COMPONENTES RED Y PONER EL RESTO EN CERO
        ; DE ESTE MODO PUEDO HACER LA RESTA: B[ij]B - A[ij]R
        PSUBB XMM6, XMM4
        ; AHORA TENGO EN XMM6:
        ; | 0 | 0 | BB1 - AR1 | 0 | 0 | 0 | BB2 - AR2 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        
        ; ESTO SÍ ES DIFERENTE AL CASO 1:
        ; AHORA QUIERO HACER  res[ij]G = promedio(A[ij] G , B[ij] G )
        MOVQ XMM14, [mascara_resta_componente_g_and]
        PAND XMM9, XMM6 ; PIXELES DE A
        PAND XMM10, XMM6 ; PIXELES DE B
        ; AL HACER ESTOS AND CON LOS PIXELES DE A (GUARDADOS EN XMM9) Y LOS PIXELES DE B (GUARDADOS EN XMM10) LO QUE HAGO ES QUEDARME SOLAMENTO
        ; CON LOS COMPONENTES GREEN DE CADA LOS PIXELES Y PONER EN CERO EL RESTO
        ; DE ESTE MODO AHORA PUEDO USAR pavgb PARA CALCULAR EL PROMEDIO:
        pavgb XMM9, XMM10
        ; AHORA TENGO EN XMM9:
        ; | 0 | PROMEDIO(AG1, BG1) | 0 | 0 | 0 | PROMEDIO(AG2, BG2) | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 

        ; RESUMIENDO: 
        ; TENGO EN XMM3:
        ; | AB1 + BR1 | 0 | 0 | 0 | AB2 + BR2 | 0 | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        ; TENGO EN XMM6:
        ; | 0 | 0 | BB1 - AR1 | 0 | 0 | 0 | BB2 - AR2 | 0 | XX | XX | XX | XX | XX | XX | XX | XX |
        ; TENGO EN XMM9:
        ; | 0 | PROMEDIO(AG1, BG1) | 0 | 0 | 0 | PROMEDIO(AG2, BG2) | 0 | 0 | XX | XX | XX | XX | XX | XX | XX | XX | 
        
        ; AHORA ME FALTA UNIRLOS:
        POR XMM3, XMM6
        POR XMM3, XMM9

        ; AHORA TENGO EN XMM2 LOS PIXELES DEL CASO 1 Y EN XMM3 LOS PIXELES DEL CASO 2, LOS UNO
        POR XMM2, XMM3

        ; AHORA PONGO LA COMPONENTE ALPHA EN 255:
        MOVDQU XMM4, [mascara_setear_alpha]
        POR XMM2, XMM4
        

        ; AHORA TENGO EN XMM2 LOS DOS PIXELES LISTOS PARA CARGAR EN MEMORIA:


        ; 4. Ahora tengo los píxeles finales a guardar en el destino
        MOVQ [RDX], XMM2
        ; 4.2 Avanzo a los siguientes
        ADD RDI, 8
        ADD RSI, 8     ; avanzo el RSI 8 bytes (4 píxeles)
        ADD RDX, 8
        SUB RAX, 2
        CMP RAX, 0
        JNE .pintar_pixeles


    XOR rax, rax

    ; epílogo
    POP rbp
    RET

    ret