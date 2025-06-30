#!/bin/bash

# --- Colors setup ---
source colors.sh
HOTKEY_COLOR=$YELLOW

# --- Logging setup ---
# Save original stdout and stderr
exec 3>&1 4>&2

LOG_ACTIVE=false
LOGFILE=""

# Function to enable logging
enable_log() {
    if [[ ! -d "logs" ]]; then
        mkdir -p logs
    fi
    if [[ -z "$LOGFILE" ]]; then
        LOGFILE="logs/log-$(date '+%Y-%m-%d_%H-%M-%S').txt"
        echo -e "${GREEN}Лог будет записан в ${BOLD}$LOGFILE${RESET_BOLD}${NC}" >&3
    fi
    echo -e "${GREEN}Логирование включено.${NC}" >&3
    # Перенаправляем stdout и stderr в 'tee'.
    # 'tee' отправляет копию на /dev/stderr (наш терминал), чтобы мы видели цветной вывод.
    # Вторую копию 'tee' через pipe | отправляет в 'sed', который убирает цвета и пишет в лог-файл.
    exec 1> >(tee /dev/stderr | sed -r 's/\x1b\[[0-9;]*m//g' >> "$LOGFILE") 2>&1
    LOG_ACTIVE=true
}

# Function to disable logging
disable_log() {
    echo -e "${YELLOW}Логирование отключено.${NC}" >&3
    # Restore stdout and stderr
    exec 1>&3 2>&4
    LOG_ACTIVE=false
}

# Toggle logging
toggle_log() {
    if $LOG_ACTIVE; then
        disable_log
    else
        enable_log
    fi
}


# Process --log flag
if [[ "$1" == "--log" ]]; then
    enable_log
    shift
fi

# --- Script configuration ---
INPUT_FILE=${1:-"words.txt"}
NO_MISTAKES_OUTPUT_FILE="no_mistakes.txt"
MISTAKES_OUTPUT_FILE="mistakes.txt"
IS_MISTAKE=false
MODEL_GEMINI=${2:-"gemini-2.5-flash"}
LANGUAGE="русский язык"
LANGUAGE_INPUT="на английском языке"
LANGUAGE_INPUT_CODE="en"
EXAMPLE_FILE="example-words.txt"




# Проверяем, существует ли файл со словами
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${YELLOW}Файл '$INPUT_FILE' не найден, но можем попробовать задействовать файл с примерами!${NC}"
    if [[ ! -f "$EXAMPLE_FILE" ]]; then
        echo -e "${RED}Ошибка: Файлы '$INPUT_FILE' или '$EXAMPLE_FILE' не найдены!${NC}"
        exit 1
    else
        if cp "$EXAMPLE_FILE" "$INPUT_FILE"; then
            echo -e "${GREEN}Файл '$INPUT_FILE' был создан из файла '$EXAMPLE_FILE'.${NC}"
        else
            echo -e "${RED}Ошибка: Не удалось создать файл '$INPUT_FILE' из файла '$EXAMPLE_FILE'!${NC}"
            exit 1
        fi
    fi
fi

# --- Database setup ---
DB_FILE="sentences_cache.sqlite"

# Создаем таблицу. Используем TEXT для хранения JSON-строки.
sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS sentences (word_key TEXT PRIMARY KEY NOT NULL, sentences_array TEXT);"

# --- Functions ---
add_sentence_to_db() {
    local word="$1"
    local sentence="$2"

    # если по какой-то причине слово пустое – сразу выходим
    [[ -z "$word" ]] && return

    # Получаем текущий JSON-массив из SQLite
    current_sentences=$(get_sentence_from_db "$word")

    if [[ -z "$current_sentences" ]]; then
        # Если ключа нет или значения пусты, создаем новый массив
        updated_sentences=$(jq -n --arg sentence "$sentence" '[$sentence]')
    else
        # Используем jq для добавления нового значения в JSON-массив
        if ! echo "$current_sentences" | jq -e . >/dev/null 2>&1; then
            current_sentences="[]"
        fi
        updated_sentences=$(echo "$current_sentences" | jq --arg sentence "$sentence" '. + [$sentence]')
    fi

    # Заменяем одинарные кавычки на двойные для безопасной вставки в SQL.
    # Это стандартный способ экранирования для SQL.
    local word_escaped=${word//\'/\'\'}
    local sentences_escaped=${updated_sentences//\'/\'\'}

    # Формируем и выполняем SQL-запрос.
    local sql="INSERT OR REPLACE INTO sentences (word_key, sentences_array) VALUES ('$word_escaped', '$sentences_escaped');"
    sqlite3 "$DB_FILE" "$sql"
}

get_sentence_from_db() {
    local word="$1"
    # Экранируем одинарные кавычки для безопасного поиска.
    local word_escaped=${word//\'/\'\'}
    local sql="SELECT sentences_array FROM sentences WHERE word_key = '$word_escaped';"
    sqlite3 "$DB_FILE" "$sql"
}


check_translation_function() {
    echo -e "${CYAN}$sentence${NC}"
    echo ""
    read -p "Введите перевод данного слова в данном контексте: " translation </dev/tty
    echo ""

    PROMPT_CHECK_TRANSLATION="Проверь, правильно ли переведено слово '${word}' в предложении: '${sentence}' на ${LANGUAGE} как '${translation}'\
    ответь либо 'да' либо 'нет'"

    check_translation=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CHECK_TRANSLATION" < /dev/null)
    echo "$check_translation"

    if [[ "$check_translation" == "да" || "$check_translation" == "Да" || "$check_translation" == "ДА" ]]; then
        echo -e "${GREEN}Перевод правильный${NC}"
    else
        echo -e "${RED}Перевод неправильный${NC}"
        IS_MISTAKE=true
        echo -e "${BOLD_RED}$(gemini -m "$MODEL_GEMINI" -p "Объясни, почему слово '${word}' в предложении '${sentence}' нельзя перевести как '${translation}'" < /dev/null)${NC}"
    fi
}

move_current_word() {
     if [[ "$IS_MISTAKE" == true ]]; then
        echo "$word" >> "$MISTAKES_OUTPUT_FILE"
    else
        echo "$word" >> "$NO_MISTAKES_OUTPUT_FILE"
    fi
    
    sed -i '1d' "$INPUT_FILE"
    echo -e "${YELLOW}Слово '$word' обработано и удалено из файла.${NC}"
}

# Читаем файл построчно
# IFS= и -r нужны для корректного чтения строк, содержащих пробелы или спецсимволы
while [[ -s "$INPUT_FILE" ]]; do
    word=$(head -n 1 "$INPUT_FILE")
    IS_MISTAKE=false
    # Пропускаем пустые строки
    if [[ -z "$word" ]]; then
        sed -i '1d' "$INPUT_FILE"
        continue
    fi

    echo -e "${PURPLE}--- Обрабатываю слово: '$word' ---${NC}"

    # Формируем промпт для Gemini.
    # Вы можете менять его как угодно.
    # Например, попросить составить предложение для определенного уровня языка (A2, B1, C1).
    PROMPT_CREATE_SENTENCE="Составь одно предложение ${LANGUAGE_INPUT} со словом '${word}'."

    # Вызываем gemini-cli, передавая ему промпт.
    # Кавычки вокруг "$PROMPT" обязательны, чтобы промпт передался как один аргумент.
    all_sentences_from_db=$(get_sentence_from_db "$word")
    # Проверяем, что all_sentences_from_db не пустая и существует
    if [[ -n "$all_sentences_from_db" ]]; then
        EXTRA_PROMPT_SENTENCE="Список предложений, которые также нельзя повторять: ${all_sentences_from_db}"
    else
        EXTRA_PROMPT_SENTENCE=""
    fi

    sentence=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CREATE_SENTENCE $EXTRA_PROMPT_SENTENCE" < /dev/null)
    sentence=$(echo "$sentence" | sed 's/\*//g')
    colored_sentence=$(echo "$sentence" | sed "s/$word/${BLUE}&${NC}${CYAN}/gi")
    add_sentence_to_db "$word" "$sentence"

    check_translation_function

    # Command loop for the current word
    while true; do
        echo -e "Команды: [${HOTKEY_COLOR}с${NC}]ледующее слово, другой [${HOTKEY_COLOR}к${NC}]онтекст, [${HOTKEY_COLOR}п${NC}]ереводы предложения, [${HOTKEY_COLOR}о${NC}]звучить предложение, напомнить п[${HOTKEY_COLOR}р${NC}]едложение, [${HOTKEY_COLOR}л${NC}]ог (вкл/выкл), [${HOTKEY_COLOR}в${NC}]ыход"
        read -p "Введите команду: " cmd </dev/tty
        case "$cmd" in
            с|n) # next word
                echo "Переход к следующему слову."
                break
                ;;
            к|k) # another context
                echo "Запрашиваю другой контекст..."
                all_sentences="${all_sentences} \n ${sentence}"
                PROMPT_GET_DIFFERENT_SENTENCE="Придумай предложение со словом '${word}' ${LANGUAGE_INPUT}, которое существенно отличается от следующих предложений: ${all_sentences}. По возможности, используй слово '${word}' в контексте, которого не было в тех предложениях. ${EXTRA_PROMPT_SENTENCE}"
                sentence=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_GET_DIFFERENT_SENTENCE" < /dev/null)
                add_sentence_to_db "$word" "$sentence"
                check_translation_function
                ;;
            п|t) # show translations
                echo "Запрашиваю варианты перевода..."
                echo -e "${CYAN}$(gemini -m "$MODEL_GEMINI" -p "Напиши несколько возможных вариантов перевода предложения '${sentence}' на ${LANGUAGE}.'" < /dev/null)${NC}"
                ;;
            о|o) # narrate sentence
                echo ""
                echo -e "${BLUE}Озвучиваю предложение:${NC}"
                echo -e "${CYAN}$colored_sentence${NC}"
                ENCODED_TEXT=$(jq -rn --arg x "$sentence" '$x|@uri')
                mpv "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&q=${ENCODED_TEXT}&tl=${LANGUAGE_INPUT_CODE}"
                echo ""
                ;;
            л|l) # toggle logging
                toggle_log
                ;;
            р|r) # repeat sentence
                echo ""
                echo -e "${CYAN}$colored_sentence${NC}"
                echo ""
                ;;
            в|q) # exit
                echo "Выход из скрипта."
                echo "В следующей сессии надо будет перейти сразу к следующему слову? (да/нет)"
                read -p "Введите ответ: " cmd </dev/tty
                if [[ "$cmd" == "да" || "$cmd" == "Да" || "$cmd" == "ДА" ]]; then
                    move_current_word
                fi
                # Restore descriptors before exiting
                if $LOG_ACTIVE; then
                  disable_log
                fi
                exit 0
                ;;
            *)
                echo -e "${RED}Неизвестная команда: '$cmd'${NC}"
                ;;
        esac
    done

    move_current_word

done

echo "Все слова в файле '$INPUT_FILE' были обработаны."

# Restore descriptors at the end of the script
if $LOG_ACTIVE; then
  disable_log
fi

