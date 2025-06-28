#!/bin/bash

# Основные цвета
export RED='\033[31m'
export GREEN='\033[32m'
export YELLOW='\033[33m'
export BLUE='\033[34m'
export PURPLE='\033[35m'
export MAGENTA='\033[35m'
export LIGHT_PURPLE='\033[95m'
export CYAN='\033[36m'
export GRAY='\033[90m'
export BLACK='\033[30m'
export WHITE='\033[37m'
export LIGHT_WHITE='\033[97m'

# Форматы текста
export BOLD='\033[1m'
export ITALIC='\033[3m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'          # Мигающий текст (поддерживается не всеми терминалами)
export REVERSE='\033[7m'        # Инверсия цветов фона и текста
export HIDDEN='\033[8m'         # Скрытый текст
export STRIKETHROUGH='\033[9m'  # Зачеркнутый текст (поддерживается не всеми терминалами)
export DOUBLE_UNDERLINE='\033[21m' # Двойное подчеркивание (поддерживается не всеми терминалами)

# Сброс стилей
export RESET_BOLD='\033[22m'    # Сброс жирного/тусклого текста
export RESET_ITALIC='\033[23m'  # Сброс курсива
export RESET_UNDERLINE='\033[24m' # Сброс подчеркивания
export RESET_BLINK='\033[25m'   # Сброс мигания
export RESET_REVERSE='\033[27m' # Сброс инверсии
export RESET_HIDDEN='\033[28m'  # Сброс скрытого текста
export RESET_STRIKETHROUGH='\033[29m' # Сброс зачеркивания

# True Color (24-bit) примеры
# Формат: \033[38;2;R;G;Bm для текста, \033[48;2;R;G;Bm для фона
export TRUE_RED='\033[38;2;255;0;0m'
export TRUE_GREEN='\033[38;2;0;255;0m'
export TRUE_BLUE='\033[38;2;0;0;255m'
export TRUE_YELLOW='\033[38;2;255;255;0m'
export TRUE_PURPLE='\033[38;2;128;0;128m'
export TRUE_ORANGE='\033[38;2;255;165;0m'
export TRUE_PINK='\033[38;2;255;192;203m'

# Фоновые True Color примеры
export BG_TRUE_RED='\033[48;2;255;0;0m'
export BG_TRUE_GREEN='\033[48;2;0;255;0m'
export BG_TRUE_BLUE='\033[48;2;0;0;255m'
export BG_TRUE_YELLOW='\033[48;2;255;255;0m'

# Яркие версии стандартных цветов
export LIGHT_RED='\033[91m'
export LIGHT_GREEN='\033[92m'
export LIGHT_YELLOW='\033[93m'
export LIGHT_BLUE='\033[94m'
export LIGHT_CYAN='\033[96m'

# Дополнительные цвета из 256-цветной палитры
export PINK='\033[38;5;213m'
export LIME='\033[38;5;119m'
export TEAL='\033[38;5;23m'
export GOLD='\033[38;5;220m'
export BROWN='\033[38;5;130m'
export TURQUOISE='\033[38;5;45m'
export ORANGE='\033[38;5;208m'

# Популярные комбинации
export BOLD_RED='\033[1;31m'
export ITALIC_BLUE='\033[3;34m'
export UNDERLINE_GREEN='\033[4;32m'
export BOLD_UNDERLINE='\033[1;4m'
export BOLD_RED_BG_YELLOW='\033[1;31;43m'

# Фоновые цвета
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'
export BG_BLACK='\033[40m'

# Фоновые яркие цвета
export BG_LIGHT_BLACK='\033[100m'
export BG_LIGHT_RED='\033[101m'
export BG_LIGHT_GREEN='\033[102m'
export BG_LIGHT_YELLOW='\033[103m'
export BG_LIGHT_BLUE='\033[104m'
export BG_LIGHT_MAGENTA='\033[105m'
export BG_LIGHT_CYAN='\033[106m'
export BG_LIGHT_WHITE='\033[107m'

# Сброс всех настроек (должна быть в конце любого цветного вывода)
export NC='\033[0m' 
