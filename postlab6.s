; Archivo: postlab6.s
; Dispositivo: PIC16F887 
; Autor: Brandon Cruz
; Copilador: pic-as (v2.30), MPLABX v5.40
;
; Programa: TMR1 e incremento de variable cada segundo, y timer 2 encender un led que pase 500ms apagado y encendido
; Hardware: Incrementar una variable cada 1s y encendemos un led cada 500ms
;
; Creado: 28 de febrero , 2022
; Última modificación: 5 marzo, 2022
    
PROCESSOR 16F887
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF            ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
  
; -------------- MACROS --------------- 
  ; Macro para reiniciar el valor del TMR0
RESET_TMR0 MACRO 
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   250
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM

; Macro para reiniciar el valor del TMR1
; Recibe el valor a configurar en TMR1_H y TMR1_L
;***RESET_TMR1 MACRO TMR1_L, TMR1_H (En clase coloqué intercambiados estos valores)
RESET_TMR1 MACRO TMR1_H, TMR1_L	 ; Esta es la forma correcta
    BANKSEL TMR1H
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM
    
 
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
PSECT udata_bank0
    SEGUNDO:            DS 1    ; Para hacer la division
    SEGUNDO1:           DS 1    ; Para hacer la division
    SEGUNDO2:           DS 1    ; Para hacer la division
    VALOR:              DS 1    ; Para hacer la division
    CONTA:              DS 1    ; Para hacer la division
    DECENA:             DS 1
    UNIDADES:           DS 1
    banderas:		DS 1	; Indica que display hay que encender
    display:		DS 2	; Representación de cada nibble en el display de 7-seg


PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h			    ; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP	    ; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP	    ; Guardamos STATUS
    
ISR:
    BTFSC   T0IF	    ; Interrupcion de TMR0?
    CALL    INT_TMR0
    
    BTFSC   TMR1IF	    ; Interrupcion de TMR1?
    CALL    INT_TMR1
    
    BTFSC   TMR2IF	    ; Interrupcion de TMR2?
    CALL    INT_TMR2

POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS	    ; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W	    ; Recuperamos valor de W
    RETFIE		    ; Regresamos a ciclo principal


;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO	    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    ; Configuración de TMR0
    CALL    CONFIG_TMR1	    ; Configuración de TMR1
    CALL    CONFIG_TMR2	    ; Configuración de TMR2
    CALL    CONFIG_INT	    ; Configuración de interrupciones
    BANKSEL PORTA	    ; Cambio a banco 00
    
LOOP:
    ; Código que se va a estar ejecutando mientras no hayan interrupciones
    CALL    SET_DISPLAY		; Guardamos los valores a enviar en PORTC para mostrar valor en decimales
    CALL    OBTENER_DIVISION	; Obtenemos las centenas/decenas y unidades
    GOTO    LOOP	    
    
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    
    BANKSEL TRISA
    bcf     TRISB,0	    ; PORTB como salida
    CLRF    TRISC	    ; PORTC como salida
    CLRF    TRISD	    ; PORTD como salida
    
    BANKSEL PORTB
    CLRF    PORTB	    ; Apagamos PORTB
    CLRF    PORTC	    ; Apagamos PORTA
    CLRF    PORTD	    ; Apagamos PORTA    
    CLRF    DECENA		; Limpiamos VARIABLES
    CLRF    UNIDADES		; Limpiamos VARIABLES
    CLRF    SEGUNDO1		; Limpiamos VARIABLES
    RETURN
    
    ; ------ SUBRUTINAS DE INTERRUPCIONES ------
INT_TMR0:
    RESET_TMR0  	    ; Reiniciamos TMR0 para 50ms
    CALL MOSTRAR_VALOR	    ; Se llama a la rutina para mostrar en el display
    RETURN

SET_DISPLAY:
    MOVF    UNIDADES, W		; Movemos la variable UNIDADES a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display		; Guardamos en display
    
    MOVF    DECENA, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+1		; Guardamos en display
    
    RETURN

MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY1		; 
 
DISPLAY0:			
    MOVF    display, W	; Movemos display a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 1	; Encendemos display de nibble bajo
    BSF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

DISPLAY1:
    MOVF    display +1, W	; Movemos display+1 a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 0	; Encendemos display de nibble alto
    BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

OBTENER_DIVISION:	        ;    Ejemplo:
    BANKSEL PORTA
    CLRF    DECENA		; Limpiamos la variable
    CLRF    UNIDADES            ; Limpiamos la variable
    ; Obtenemos DECENAS
    MOVF    SEGUNDO2, W		;
    MOVWF   SEGUNDO1
    MOVLW   10            ; Se agrega 100 a w
    SUBWF   SEGUNDO1, F		;
    INCF    DECENA             ; Se incrementa 1 a la variable CENTENA
    BTFSC   STATUS,0            ; Se verifica la bandera BOROOW
    
    GOTO    $-4                 ; Si esta encendida la bandera se regresa a 4 instrucciones 
    DECF    DECENA
    
    MOVLW   10	
    ADDWF   SEGUNDO1,F
    CALL    OBTENER_UNIDADES    ; Se llama la rutina para obtener las decenas
    RETURN
    
OBTENER_UNIDADES:	        ;    Ejemplo:
    ; Obtenemos UNIDADES
    MOVLW   1                   ; Se agrega 1 a w
    SUBWF   SEGUNDO1,F		;
    INCF    UNIDADES             ; Se incrementa 1 a la variable CENTENA
    BTFSC   STATUS,0            ; Se verifica la bandera BOROOW
    
    GOTO    $-4                 ; Si esta encendida la bandera se regresa a 4 instrucciones 
    DECF    UNIDADES
    
    MOVLW   1		
    ADDWF   SEGUNDO1,F
    RETURN
    
INT_TMR1:
    RESET_TMR1 0x0B, 0xDC   ; Reiniciamos TMR1 para 1s
    INCF  SEGUNDO	    ; Incremento la variable segundo
    BTFSS SEGUNDO,1
    RETURN
    CLRF SEGUNDO
    INCF SEGUNDO2
    MOVF SEGUNDO2,W
    MOVWF CONTA
    MOVLW 100
    SUBWF CONTA,F
    BTFSC ZERO
    CLRF SEGUNDO2
    RETURN
    
INT_TMR2:
    BCF	    TMR2IF	    ; Limpiamos bandera de interrupcion de TMR1
    INCF   VALOR
    BTFSS VALOR,1
    RETURN
    BTFSS VALOR,3
    RETURN
    CLRF VALOR
    INCF   PORTB	    ; Incremento en PORTB
    RETURN
    
PSECT code, delta=2, abs
ORG 100h		    ; posición 100h para el codigo

;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4	    ; IRCF<2:0> -> 110 4MHz
    RETURN
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    OPTION_REG, 5		; TMR0 como temporizador
    BCF	    OPTION_REG, 3			; prescaler a TMR0
    BSF	    OPTION_REG, 2
    BSF	    OPTION_REG, 1
    BSF	    OPTION_REG, 0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0   		; Reiniciamos TMR0 para 10ms
    RETURN 
    
; Configuramos el TMR0 para obtener un retardo de 50ms
  
CONFIG_TMR1:
    BANKSEL T1CON	    ; Cambiamos a banco 00
    BCF	    TMR1CS	    ; Reloj interno
    BCF	    T1OSCEN	    ; Apagamos LP
    BSF	    T1CKPS1	    ; Prescaler 2:0
    BSF	    T1CKPS0
    BCF	    TMR1GE	    ; TMR1 siempre contando
    BSF	    TMR1ON	    ; Encendemos TMR1
    
    RESET_TMR1 0x0B, 0xDC   ; TMR1 a 1s
    RETURN
    
    
CONFIG_TMR2:
    BANKSEL PR2		    ; Cambiamos a banco 01
    MOVLW   240		    ; Valor para interrupciones cada 500ms
    MOVWF   PR2		    ; Cargamos litaral a PR2
    
    BANKSEL T2CON	    ; Cambiamos a banco 00
    BSF	    T2CKPS1	    ; Prescaler 1:0
    BSF	    T2CKPS0
    
    BSF	    TOUTPS3	    ;Postscaler 16:0
    BSF	    TOUTPS2
    BCF	    TOUTPS1
    BCF	    TOUTPS0
    
    BSF	    TMR2ON	    ; Encendemos TMR2
    ;RETURN
        
CONFIG_INT:
    BANKSEL PIE1	    ; Cambiamos a banco 01
    BSF	    TMR1IE	    ; Habilitamos int. TMR1
    BSF	    TMR2IE	    ; Habilitamos int. TMR2
    
    BANKSEL INTCON	    ; Cambiamos a banco 00
    BSF	    PEIE	    ; Habilitamos int. perifericos
    BSF	    GIE		    ; Habilitamos interrupciones
    BSF	    T0IE	    ; Habilitamos interrupcion TMR0
    BCF	    T0IF	    ; Limpiamos bandera de TMR0
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF	    TMR2IF	    ; Limpiamos bandera de TMR2
    RETURN
    
ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END    
