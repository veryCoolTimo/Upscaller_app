#!/bin/bash

# Скрипт для подготовки приложения к запуску

# Определяем пути
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DERIVED_DATA_DIR=$(find ~/Library/Developer/Xcode/DerivedData -name "upscallerapp-*" -type d | head -n 1)
BUILD_DIR="$DERIVED_DATA_DIR/Build/Products/Debug"
APP_PATH="$BUILD_DIR/upscallerapp.app"
XPC_PATH="$APP_PATH/Contents/XPCServices/ImageUpscalerService.xpc"
APP_RESOURCES="$APP_PATH/Contents/Resources"
XPC_RESOURCES="$XPC_PATH/Contents/Resources"

echo "Подготовка приложения к запуску..."
echo "Путь к DerivedData: $DERIVED_DATA_DIR"
echo "Путь к приложению: $APP_PATH"
echo "Путь к XPC сервису: $XPC_PATH"

# Проверяем, существует ли приложение
if [ ! -d "$APP_PATH" ]; then
    echo "Ошибка: Приложение не найдено. Сначала соберите проект в Xcode."
    exit 1
fi

# Создаем директорию для ресурсов XPC сервиса, если она не существует
mkdir -p "$XPC_RESOURCES"

# Копируем модели из ресурсов приложения в ресурсы XPC сервиса
if [ -d "$APP_RESOURCES/models-cunet" ]; then
    echo "Копирование моделей в XPC сервис..."
    cp -R "$APP_RESOURCES/models-cunet" "$XPC_RESOURCES/"
    echo "Модели скопированы."
else
    echo "Предупреждение: Директория с моделями не найдена в $APP_RESOURCES"
fi

# Копируем исполняемый файл waifu2x-ncnn-vulkan
if [ -f "$APP_RESOURCES/waifu2x-ncnn-vulkan" ]; then
    echo "Копирование waifu2x-ncnn-vulkan в XPC сервис..."
    cp "$APP_RESOURCES/waifu2x-ncnn-vulkan" "$XPC_RESOURCES/"
    chmod +x "$XPC_RESOURCES/waifu2x-ncnn-vulkan"
    echo "waifu2x-ncnn-vulkan скопирован и сделан исполняемым."
else
    echo "Предупреждение: Файл waifu2x-ncnn-vulkan не найден в $APP_RESOURCES"
fi

# Выводим содержимое директории ресурсов XPC сервиса
echo "Содержимое директории ресурсов XPC сервиса:"
ls -la "$XPC_RESOURCES"

echo "Подготовка приложения завершена."
echo "Теперь вы можете запустить приложение командой: open \"$APP_PATH\"" 