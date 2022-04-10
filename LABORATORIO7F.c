/*
 * File:   laboratorio.c
 * Author: Brandon Cruz
 *
 * Created on 8 de abril de 2022, 05:34 PM
 */

// PIC16F887 Configuration Bit Settings

// 'C' source line config statements

// CONFIG1
#pragma config FOSC = INTRC_NOCLKOUT// Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
#pragma config WDTE = OFF       // Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
#pragma config PWRTE = OFF      // Power-up Timer Enable bit (PWRT disabled)
#pragma config MCLRE = OFF      // RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
#pragma config CP = OFF         // Code Protection bit (Program memory code protection is disabled)
#pragma config CPD = OFF        // Data Code Protection bit (Data memory code protection is disabled)
#pragma config BOREN = OFF      // Brown Out Reset Selection bits (BOR disabled)
#pragma config IESO = OFF       // Internal External Switchover bit (Internal/External Switchover mode is disabled)
#pragma config FCMEN = OFF      // Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
#pragma config LVP = OFF        // Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

// CONFIG2
#pragma config BOR4V = BOR40V   // Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
#pragma config WRT = OFF        // Flash Program Memory Self Write Enable bits (Write protection off)

// #pragma config statements should precede project file includes.
// Use project enums instead of #define for ON and OFF.

#include <xc.h>
#include <stdint.h>

/*------------------------------------------------------------------------------
 * CONSTANTES 
 ------------------------------------------------------------------------------*/
#define INC PORTBbits.RB1     // Asignamos un alias a RB0
#define DEC PORTBbits.RB0     // Asignamos un alias a RB1
#define _tmr0_value 217       // 5 ms tiempo de retardo
#define _XTAL_FREQ 4000000    // Oscilacion de 4MHz
/*------------------------------------------------------------------------------
 * VARIABLES 
 ------------------------------------------------------------------------------*/
// Ejemplos:
// uint8_t var;      // Solo declarada
// uint8_t var2 = 0; // Declarada e inicializada
char display[10]={0x3F,0X06,0X5B,0X04F,0X66,0X6D,0X7D,0X07,0X7F,0X67}; // Se hizo un STRUCT para guardar para hacer la traducciones a los display

uint8_t banderas;
uint8_t unidades;
uint8_t decenas;
uint8_t centenas;
uint8_t contador;
uint8_t residuo;

/*------------------------------------------------------------------------------
 * PROTOTIPO DE FUNCIONES 
 ------------------------------------------------------------------------------*/
void setup(void);
void isr (void);                 //Interrupciones
int divisiones(void);            //Donde se hara las divisiones de unidade, decenas y centenas

/*------------------------------------------------------------------------------
 * INTERRUPCIONES 
 ------------------------------------------------------------------------------*/
void __interrupt() isr (void){
    if(INTCONbits.RBIF){            // Fue interrupción del PORTB
        if(!INC){                 // Verificamos si fue RB0 quien generó la interrupción
            PORTC++;                // Incremento del PORTA 
        }
        if (!DEC){                 // Verificamos si fue RB0 quien generó la interrupción
            PORTC--;               // Decremento del PORTA
        }
        INTCONbits.RBIF = 0;    // Limpiamos bandera de interrupción
    }    
    if(T0IF == 1){             // Fue interrupción del TMR0
        PORTE=0X00;            // Limpia para poder habilitat que display encender
        
        if (banderas == 0b00000000){
            PORTEbits.RE2 = 0;
            PORTEbits.RE0 = 1;
            PORTD = (display[unidades]);
            banderas = 0b00000001;
        }
    
        else if (banderas == 0b00000001){
            PORTEbits.RE0 = 0;
            PORTEbits.RE1 = 1;
            PORTD = (display[decenas]);
            banderas = 0b00000010;        
        }
        else if (banderas == 0b00000010){
            PORTEbits.RE1 = 0;
            PORTEbits.RE2 = 1;
            PORTD = (display[centenas]);
            banderas = 0b00000000;            
        } 
        INTCONbits.T0IF = 0;
        TMR0 = _tmr0_value;
    }
    
    return;
}


/*------------------------------------------------------------------------------
 * CICLO PRINCIPAL
 ------------------------------------------------------------------------------*/
void main(void) {
    setup();                        // Llamamos a la función de configuraciones
    while(1){
        divisiones();               // Llamamos a la funcion de diviciones para dividir en unidades,decenas y centenas
        contador = PORTC;           // Mandamos lo de contador en PORTC a la variable contador para dividirlo 
    }
    return;
}

/*------------------------------------------------------------------------------
 * CONFIGURACION 
 ------------------------------------------------------------------------------*/
void setup(void){
    
    ANSEL = 0;
    ANSELH = 0b00000000;        // Usaremos solo I/O digitales
        
    TRISC = 0b00000000;               // PORTC como salida
    PORTC = 0;                        // Limpiamos PORTC
    TRISD = 0b00000000;               // PORTD como salida
    PORTD = 0;                        // Limpiamos PORTD
    TRISE = 0b00000000;               // PORTE como salida
    PORTE = 0;                        // Limpiamos PORTE

    TRISBbits.TRISB0 = 1;       // RB0 como entrada (configurada con control de bits)
    TRISBbits.TRISB1 = 1;       // RB1 como entrada (configurada con control de bits)

    OSCCONbits.IRCF2 = 1;       // Con un oscilador de 4MHz
    OSCCONbits.IRCF1 = 1;
    OSCCONbits.IRCF0 = 0;
    OSCCONbits.SCS = 1;
    
    OPTION_REGbits.nRBPU = 0;   // Habilitamos resistencias de pull-up del PORTB
    WPUBbits.WPUB0 = 1;         // Habilitamos resistencia de pull-up de RB0
    WPUBbits.WPUB1 = 1;         // Habilitamos resistencia de pull-up de RB1

    
    INTCONbits.GIE = 1;         // Habilitamos interrupciones globales
    INTCONbits.T0IE = 1;        // Habilitamos interrupciones del TMR0
    INTCONbits.RBIE = 1;        // Habilitamos interrupciones del PORTB
    IOCBbits.IOCB0 = 1;         // Habilitamos interrupción por cambio de estado para RB0
    IOCBbits.IOCB1 = 1;         // Habilitamos interrupción por cambio de estado para RB1
    INTCONbits.RBIF = 0;        // Limpiamos bandera de interrupción del PORTB
    INTCONbits.T0IF = 0;        // Limpiamos bandera de interrupción del TMR0
    
    OPTION_REGbits.PSA = 0;     //Un TMR0 con un Prescaler 1:256
    OPTION_REGbits.T0CS = 0;
    OPTION_REGbits.PS2 = 1;
    OPTION_REGbits.PS1 = 1;
    OPTION_REGbits.PS0 = 1;    
    
    TMR0= _tmr0_value;          // Reiniciamos el TMR0 a 271 para tener un retardo de 5ms
    
    banderas = 0b00000000;      // Limpiamos la variable de banderas
}

/*------------------------------------------------------------------------------
 * FUNCIONES 
 ------------------------------------------------------------------------------*/
int divisiones(void){
    centenas = contador/100;    //Dividimos lo que esta en PORTC entre 100 para obtener las centenas
    residuo = contador%100;     //Ocupamos el modulo de division para obtener el residuo
    
    decenas = residuo/10;        // Este residuo del modulo lo dividimos entre 10 para las decenas
    unidades = residuo%10;       // Ocupamos el residuo restante del modulo para ponerlo en las unidades
}
