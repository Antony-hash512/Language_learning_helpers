#!/bin/bash

# --- Colors setup ---
source colors.sh

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
        echo "Лог будет записан в $LOGFILE" >&3
    fi
    echo "Логирование включено." >&3
    # Redirect stdout and stderr to tee, which writes to file and original stdout
    exec 1> >(tee -a "$LOGFILE") 2>&1
    LOG_ACTIVE=true
}

# Function to disable logging
disable_log() {
    echo "Логирование отключено." >&3
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

# Проверяем, существует ли файл
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Ошибка: Файл '$INPUT_FILE' не найден!"
    exit 1
fi

check_translation_function() {
    echo "$sentence"
    echo ""
    read -p "Введите перевод данного слова в данном контексте: " translation </dev/tty
    echo ""

    PROMPT_CHECK_TRANSLATION="Проверь, правильно ли переведено слово '${word}' в предложении: '${sentence}' на ${LANGUAGE} как '${translation}'\
    ответь либо 'да' либо 'нет'"

    check_translation=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CHECK_TRANSLATION" < /dev/null)
    echo "$check_translation"

    if [[ "$check_translation" == "да" || "$check_translation" == "Да" || "$check_translation" == "ДА" ]]; then
        echo "Перевод правильный"
    else
        echo "Перевод неправильный"
        IS_MISTAKE=true
        echo "$(gemini -m "$MODEL_GEMINI" -p "Объясни, почему слово '${word}' в предложении '${sentence}' нельзя перевести как '${translation}'" < /dev/null)"
    fi
}

move_current_word() {
     if [[ "$IS_MISTAKE" == true ]]; then
        echo "$word" >> "$MISTAKES_OUTPUT_FILE"
    else
        echo "$word" >> "$NO_MISTAKES_OUTPUT_FILE"
    fi
    
    sed -i '1d' "$INPUT_FILE"
    echo "Слово '$word' обработано и удалено из файла."
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

    echo "--- Обрабатываю слово: '$word' ---"

    # Формируем промпт для Gemini.
    # Вы можете менять его как угодно.
    # Например, попросить составить предложение для определенного уровня языка (A2, B1, C1).
    PROMPT_CREATE_SENTENCE="Составь одно предложение ${LANGUAGE_INPUT} со словом '${word}'."

    # Вызываем gemini-cli, передавая ему промпт.
    # Кавычки вокруг "$PROMPT" обязательны, чтобы промпт передался как один аргумент.
    sentence=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CREATE_SENTENCE" < /dev/null)
    all_sentences="$sentence"

    check_translation_function

    # Command loop for the current word
    while true; do
        echo "Команды: [с]ледующее слово, другой [к]онтекст, [п]еревод предложения, [л]ог (вкл/выкл), [в]ыход "
        read -p "Введите команду: " cmd </dev/tty
        case "$cmd" in
            с|n) # next word
                echo "Переход к следующему слову."
                break
                ;;
            к|k) # another context
                echo "Запрашиваю другой контекст..."
                all_sentences="${all_sentences}\n${sentence}"
                sentence=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CREATE_SENTENCE Придумай новое предложение со словом '${word}', которое существенно отличается от следующих предложений: ${all_sentences}. По возможности, используй слово '${word}' в новом контексте." < /dev/null)
                check_translation_function
                ;;
            п|t) # show translations
                echo "Запрашиваю варианты перевода..."
                echo "$(gemini -m "$MODEL_GEMINI" -p "Напиши несколько возможных вариантов перевода предложения '${sentence}' на ${LANGUAGE}.'" < /dev/null)"
                ;;
            л|l) # toggle logging
                toggle_log
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
                echo "Неизвестная команда: '$cmd'"
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

