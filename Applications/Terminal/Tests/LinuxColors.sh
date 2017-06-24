# !/bin/sh
# Outputs colors of linux console
echo -e "\e[1mColors with only foreground specified:\e[0m"
#echo -e "Colors:  \e[0m[ ]\e[30m[ ]\e[31m[ ]\e[32m[ ]\e[33m[ ]\e[34m[ ]\e[35m[ ]\e[36m[ ]\e[37m[ ]\e[0m"
echo -e "Black:   \e[30m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Red:     \e[31m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Green:   \e[32m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Brown:   \e[33m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Blue:    \e[34m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Magenta: \e[35m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "Cyan:    \e[36m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"
echo -e "White:   \e[37m X \e[40m X \e[41m X \e[42m X \e[43m X \e[44m X \e[45m X \e[46m X \e[47m X \e[0m"

echo -e "\e[0m"

echo -e " \e[37m\e[40m White on black \e[0m"

echo -e "\e[0m"

echo -e "\e[1mColors with only background specified:\e[0m"
echo ""
echo -e -n "\e[40m  0  \e[0m"
echo -e -n "\e[41m  1  \e[0m"
echo -e -n "\e[42m  2  \e[0m"
echo -e -n "\e[43m  3  \e[0m"
echo -e -n "\e[44m  4  \e[0m"
echo -e -n "\e[45m  5  \e[0m"
echo -e -n "\e[46m  6  \e[0m"
echo -e "\e[47m  7  \e[0m"
echo ""

echo -e "Example of \e[1m bold \e[0m text"
echo -e "Example of \e[4m underlined \e[24m text"
echo -e "Example of \e[5m blink \e[25m text"
echo -e "Example of \e[7m reverse video \e[27m text"

echo -e "\e[0m"

echo -e "\e[1mUsing default FG (TEXT_NORM) and BG (WIN_BG):\e[0m"
echo -e "\e[0m FG == TEXT_NORM, BG == Blue(43)    \t\e[44m FG == TEXT_NORM, BG == Blue   \e[0m"
echo -e "\e[0m FG == TEXT_NORM, BG == Black(40)   \t\e[40m FG == TEXT_NORM, BG == Black  \e[0m"
echo -e "\e[0m FG == Black(30), BG == WIN_BG      \t\e[30m FG == Black,     BG == WIN_BG \e[0m"
echo -e "\e[0m FG == White(37), BG == WIN_BG      \t\e[37m FG == White,     BG == WIN_BG \e[0m"

echo -e "\e[1mExplicitly specified colours:\e[0m"
echo -e "\e[0m White  / Black  (37/40)  \t \e[37m \e[40m FG == White, BG == Black   \e[0m"
echo -e "\e[0m Black  / White  (30/47)) \t \e[30m \e[47m FG == Black, BG == White   \e[0m"

echo -e "\e[0m Yellow / Black  (33/40)  \t \e[33m \e[40m FG == Yellow, BG == Black  \e[0m"
echo -e "\e[0m Black  / Black  (30/40)  \t \e[30m \e[40m FG == Black,  BG == Black  \e[0m"

echo -e "\e[0m White  / Blue   (37/44)) \t \e[37m \e[44m FG == White, BG == Blue    \e[0m"

echo -e "\e[0m"
