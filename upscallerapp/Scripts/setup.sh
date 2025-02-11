#!/bin/bash

# Определяем директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(dirname "$SCRIPT_DIR")/Resources"
MODELS_DIR="$RESOURCES_DIR/models-cunet"

echo "Директории:"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "RESOURCES_DIR: $RESOURCES_DIR"
echo "MODELS_DIR: $MODELS_DIR"

# Очищаем старые файлы
rm -rf "$RESOURCES_DIR/waifu2x-ncnn-vulkan"
rm -rf "$MODELS_DIR"

# Создаем директории
mkdir -p "$RESOURCES_DIR"
mkdir -p "$MODELS_DIR"

# Функция для проверки наличия команды
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Проверяем наличие curl
if ! check_command curl; then
    echo "curl не найден. Пожалуйста, установите curl"
    exit 1
fi

# Проверяем наличие unzip
if ! check_command unzip; then
    echo "unzip не найден. Пожалуйста, установите unzip"
    exit 1
fi

# Создаем временную директорию
TMP_DIR=$(mktemp -d)
echo "Временная директория: $TMP_DIR"

# Загружаем последнюю версию waifu2x-ncnn-vulkan
echo "Загрузка waifu2x-ncnn-vulkan..."
DOWNLOAD_URL="https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/20220728/waifu2x-ncnn-vulkan-20220728-macos.zip"
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/waifu2x.zip"

# Распаковываем архив
echo "Распаковка архива..."
unzip -o "$TMP_DIR/waifu2x.zip" -d "$TMP_DIR"

# Копируем файлы
echo "Копирование файлов..."
EXTRACTED_DIR="$TMP_DIR/waifu2x-ncnn-vulkan-20220728-macos"
cp "$EXTRACTED_DIR/waifu2x-ncnn-vulkan" "$RESOURCES_DIR/"
cp -r "$EXTRACTED_DIR/models-cunet/"* "$MODELS_DIR/"

# Делаем бинарный файл исполняемым
chmod +x "$RESOURCES_DIR/waifu2x-ncnn-vulkan"

# Удаляем временные файлы
rm -rf "$TMP_DIR"

# Проверяем установку
if [ -f "$RESOURCES_DIR/waifu2x-ncnn-vulkan" ] && [ -d "$MODELS_DIR" ] && [ "$(ls -A "$MODELS_DIR")" ]; then
    echo "waifu2x-ncnn-vulkan успешно установлен"
    echo "Путь к бинарному файлу: $RESOURCES_DIR/waifu2x-ncnn-vulkan"
    echo "Путь к моделям: $MODELS_DIR"
    
    echo "Содержимое директории моделей:"
    ls -la "$MODELS_DIR"
    
    # Проверяем работоспособность
    echo "Проверка версии..."
    "$RESOURCES_DIR/waifu2x-ncnn-vulkan" -v
else
    echo "Ошибка при установке waifu2x-ncnn-vulkan"
    echo "Проверка файлов:"
    echo "Бинарный файл существует: $([ -f "$RESOURCES_DIR/waifu2x-ncnn-vulkan" ] && echo "Да" || echo "Нет")"
    echo "Директория моделей существует: $([ -d "$MODELS_DIR" ] && echo "Да" || echo "Нет")"
    echo "Директория моделей не пуста: $([ "$(ls -A "$MODELS_DIR")" ] && echo "Да" || echo "Нет")"
    exit 1
fi 