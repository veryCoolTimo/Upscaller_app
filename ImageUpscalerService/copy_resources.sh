#!/bin/bash

# Скрипт для копирования ресурсов в XPC сервис

# Путь к ресурсам в основном приложении
APP_RESOURCES="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources"

# Путь к ресурсам в XPC сервисе
XPC_RESOURCES="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/XPCServices/ImageUpscalerService.xpc/Contents/Resources"

# Создаем директорию для ресурсов в XPC сервисе
mkdir -p "$XPC_RESOURCES"

echo "Копирование ресурсов из $APP_RESOURCES в $XPC_RESOURCES"

# Копируем модели
if [ -d "$APP_RESOURCES/models-cunet" ]; then
    echo "Копирование моделей..."
    cp -R "$APP_RESOURCES/models-cunet" "$XPC_RESOURCES/"
    echo "Модели скопированы"
else
    echo "Директория моделей не найдена: $APP_RESOURCES/models-cunet"
fi

# Копируем бинарный файл waifu2x
if [ -f "$APP_RESOURCES/waifu2x-ncnn-vulkan" ]; then
    echo "Копирование waifu2x-ncnn-vulkan..."
    cp "$APP_RESOURCES/waifu2x-ncnn-vulkan" "$XPC_RESOURCES/"
    chmod +x "$XPC_RESOURCES/waifu2x-ncnn-vulkan"
    echo "waifu2x-ncnn-vulkan скопирован"
else
    echo "Бинарный файл waifu2x не найден: $APP_RESOURCES/waifu2x-ncnn-vulkan"
fi

# Выводим список скопированных файлов
echo "Содержимое директории ресурсов XPC сервиса:"
ls -la "$XPC_RESOURCES"

echo "Копирование ресурсов завершено" 