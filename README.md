Later i will write all of this for C(which will be easier) but i just like Zig a lot

Hello there!
To test the program first compile it all with `zig build` command
Then open Binaries/TestApp in disassembler and find the function which uses "hunter2" password(string), then open it in hexdump and copy first 18 bytes(from byte 0x55 to byte 0xE8), put them into `const Pattern` and then just run Binaries/Injector.exe
If you are having any issues open issue on a git hub or try checking the code again, maybe i missed something, also, this code is for **x64 Only** and i haven't tested it on Arm so good luck!

Вітаю!
Щоб випробувати програму спочатку зберіть її запустивши `zig build`
Далі відкрийте Binaries/TestApp в дизасемблері і знайдіть функцію яка використовує пароль(string) "hunter2", далі відкрийте цю функцію в hexdump і скопіюйте перші байти від байту 0x55 до байту 0чE8, далі внесіть їх до `const Pattern` і згодом запустіть Binaries/Injector.exe
Якщо є якісь проблеми ви можете відкрити запит у Issues в цій github сторінці або перевірити код ще раз, також може я щось пропустив, також цей код зроблений **Лише для x64** і я не тестував його на Arm тож удачі з цим!
