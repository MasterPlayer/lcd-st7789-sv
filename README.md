# lcd st7789 sv
 simple demo hardware code for implement access to ST7789 LCD display from FPGA


## Eng 

LCD display based upon ST7789 IC
Resolution : 240x240 pixels

CHIP SELECT in zero constantly, control display only for control CLK signal

Interface over Display and FPGA - SPI without ChipSelect

Two Components realize access to display : 
1. st7789_driver - implement serial access with SPI to display for control them
2. st7789_mgr - command processor for initialize data transmission and command transmission for driver on byte level

Components works on AXI-Stream support

mgr perform initialize display by sending required commands. For this version user can perform only one command - fill display RGB colors and internal fsm changes this colors for next time

Initialize includes next steps : 
1. Send command RESET_SW(0x01)
2. Pause
3. Send command SLEEP_OUT(0x11)
4. Send command INV_ON(0x21) 
5. Send command DISP_ON(0x29)
6. Send command RASET(0x2B)
7. Send command CASET(0x2A)

Data transmission is possible up to 75 Mhz (SCL clock period). When exceeded this frequency, transmitted data was corrupted, and display filled with impure color


## Rus 

Дисплей используется на основе контроллера ST7789. 
Разрешение экрана - 240х240 точек. 

У дисплея есть особенность - CHIP_SELECT установлен в постоянный ноль, а это значит что управление дисплеем возможно только используя управление CLK. 

Интерфейс к дисплею - SPI без CS. 

Пара компонентов реализующая доступ к дисплею:
1. st7789_driver - компонент для реализации последовательной передачи к дисплею данных и управляющих сигналов
2. st7789_mgr - обработчик команд. Инициирует корректную передачу данных на последующую реализацию, сопровождая необходимыми сигналами 

Компоненты работают по AXI-Stream. 

mgr сейчас выполняет инициализацию дисплея отправляя необходимые команды. Пользователь может в данном случае выполнять только одну команду - заполнение дисплея цветами RGB константными значениями. Дисплей в таком случае заполнится целиком одним цветом, который будет меняться по мере работы

Инициализация происходит по следующей последовательности : 
1. Отправка команды RESET_SW(0x01)
2. Пауза 
3. Отправка команды SLEEP_OUT(0x11)
4. Отправка команды INV_ON(0x21) 
5. Отправка команды DISP_ON(0x29)
6. Отправка команды RASET(0x2B)
7. Отправка команды CASET(0x2A)

Отправка данных возможна до 75 МГц(частота тактирования SCL). При превышении частоты возникают эффекты, связанные с тем, что данные начинают ехать, тем самым, дисплей заполняется цветом, только цвет неоднородный. 

Таким образом гарантируется обмен между дисплеем и FPGA со скоростью 75 МБит/с.




# Versions 
1.0 Initial version
