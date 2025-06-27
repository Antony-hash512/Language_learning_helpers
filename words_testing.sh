#!/bin/bash

# Обработка ключа --log
LOG=false
if [[ "$1" == "--log" ]]; then
    LOG=true
    shift
fi

# Файл, из которого читаем слова
INPUT_FILE=${1:-"words.txt"}
MODEL_GEMINI=${2:-"gemini-2.5-flash"}
LANGUAGE="русский язык"
LANGUAGE_INPUT="на английском языке"

if [[ "$LOG" == true ]]; then
    mkdir -p logs
    LOGFILE="logs/log-$(date '+%Y-%m-%d_%H-%M-%S').txt"
    echo "Лог будет записан в $LOGFILE"
    exec > >(tee -a "$LOGFILE") 2>&1
fi

# Проверяем, существует ли файл
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Ошибка: Файл '$INPUT_FILE' не найден!"
    exit 1
fi

function check_translation_function() {
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
        #echo "$(gemini -m "$MODEL_GEMINI" -p "Как ещё слово '${word}' в предложении '${sentence}' можно перевести на ${LANGUAGE} помимо '${translation}' (если есть другие варианты)?" < /dev/null)"
    else
        echo "Перевод неправильный"
        echo "$(gemini -m "$MODEL_GEMINI" -p "Объясни, почему слово '${word}' в предложении '${sentence}' нельзя перевести как '${translation}'" < /dev/null)"
    fi

    read -p "Хотите получить варианты перевода предложения? (да/нет): " get_translations </dev/tty
    if [[ "$get_translations" =~ ^(д|Д|да|Да|ДА|y|Y|yes|Yes|YES)$ ]]; then
        echo "$(gemini -m "$MODEL_GEMINI" -p "Напиши несколько возможных вариантов перевода предложения '${sentence}' на ${LANGUAGE}.'" < /dev/null)"
    fi
}


function another_context() {
    local new_sentence=$1
    local all_sentences=${2:-""}

    all_sentences="${all_sentences}\n${new_sentence}"
    
    sentence=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT_CREATE_SENTENCE Придумай новое предложение, которое существенно отличается от следующих предложений: ${all_sentences}. По возможности, используй слово '${word}' в новом контексте." < /dev/null)
    check_translation_function
     # Спрашиваем у пользователя, хочет ли он получить другой контекст данного слова
    read -p "Хотите получить другой контекст данного слова? (да/нет): " get_context </dev/tty
    if [[ "$get_context" =~ ^(д|Д|да|Да|ДА|y|Y|yes|Yes|YES)$ ]]; then
        another_context "$sentence" "$all_sentences"
    fi
}

# Читаем файл построчно
# IFS= и -r нужны для корректного чтения строк, содержащих пробелы или спецсимволы
while IFS= read -r word || [[ -n "$word" ]]; do
    # Пропускаем пустые строки
    if [[ -z "$word" ]]; then
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
    

    check_translation_function

     # Спрашиваем у пользователя, хочет ли он получить другой контекст данного слова
    read -p "Хотите получить другой контекст данного слова? (да/нет): " get_context </dev/tty
    if [[ "$get_context" =~ ^(д|Д|да|Да|ДА|y|Y|yes|Yes|YES)$ ]]; then
        another_context "$sentence"
    fi

    echo ""
    
    # Добавляем пустую строку для лучшей читаемости вывода
    echo ""

done < "$INPUT_FILE"

