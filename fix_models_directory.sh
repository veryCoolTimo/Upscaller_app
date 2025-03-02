#!/bin/bash

# Скрипт для исправления структуры директорий моделей во всех экземплярах XPC сервиса

echo "Исправление структуры директорий моделей..."

# Определяем пути
DERIVED_DATA_DIR=$(find ~/Library/Developer/Xcode/DerivedData -name "upscallerapp-*" -type d | head -n 1)
BUILD_DIR="$DERIVED_DATA_DIR/Build/Products/Debug"
INDEX_BUILD_DIR="$DERIVED_DATA_DIR/Index.noindex/Build/Products/Debug"
APP_PATH="$BUILD_DIR/upscallerapp.app"
XPC_PATH="$APP_PATH/Contents/XPCServices/ImageUpscalerService.xpc"
STANDALONE_XPC_PATH="$BUILD_DIR/ImageUpscalerService.xpc"
INDEX_XPC_PATH="$INDEX_BUILD_DIR/ImageUpscalerService.xpc"

echo "Путь к DerivedData: $DERIVED_DATA_DIR"
echo "Путь к приложению: $APP_PATH"
echo "Путь к XPC сервису в приложении: $XPC_PATH"
echo "Путь к отдельному XPC сервису: $STANDALONE_XPC_PATH"
echo "Путь к XPC сервису в Index: $INDEX_XPC_PATH"

# Функция для исправления структуры директории моделей
fix_models_directory() {
    local xpc_resources="$1"
    
    if [ ! -d "$xpc_resources" ]; then
        echo "Директория $xpc_resources не существует, пропускаем"
        return
    fi
    
    echo "Исправление структуры в $xpc_resources"
    
    # Проверяем, существует ли директория models-cunet
    if [ ! -d "$xpc_resources/models-cunet" ]; then
        echo "Создание директории models-cunet в $xpc_resources"
        mkdir -p "$xpc_resources/models-cunet"
    fi
    
    # Проверяем, есть ли файлы моделей в корневой директории
    if ls "$xpc_resources"/noise*.bin >/dev/null 2>&1 || ls "$xpc_resources"/scale*.bin >/dev/null 2>&1; then
        echo "Перемещение файлов моделей в models-cunet"
        mv "$xpc_resources"/noise*.bin "$xpc_resources"/noise*.param "$xpc_resources"/scale*.bin "$xpc_resources"/scale*.param "$xpc_resources/models-cunet/" 2>/dev/null
    fi
    
    # Проверяем, есть ли бинарный файл waifu2x-ncnn-vulkan
    if [ -f "$xpc_resources/waifu2x-ncnn-vulkan" ]; then
        echo "Установка прав на исполнение для waifu2x-ncnn-vulkan"
        chmod +x "$xpc_resources/waifu2x-ncnn-vulkan"
    else
        echo "Бинарный файл waifu2x-ncnn-vulkan не найден в $xpc_resources"
    fi
    
    # Выводим содержимое директории models-cunet
    if [ -d "$xpc_resources/models-cunet" ]; then
        echo "Содержимое директории models-cunet в $xpc_resources:"
        ls -la "$xpc_resources/models-cunet"
    fi
}

# Исправляем структуру директорий моделей во всех экземплярах XPC сервиса
fix_models_directory "$XPC_PATH/Contents/Resources"
fix_models_directory "$STANDALONE_XPC_PATH/Contents/Resources"
fix_models_directory "$INDEX_XPC_PATH/Contents/Resources"

echo "Исправление структуры директорий моделей завершено." 