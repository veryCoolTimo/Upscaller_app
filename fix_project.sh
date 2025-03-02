#!/bin/bash

# Скрипт для исправления проблемы с дублированием ресурсов в проекте Xcode

echo "Исправление проблемы с дублированием ресурсов в проекте..."

# Удаляем директорию с моделями из ImageUpscalerService, так как мы будем копировать их из основного приложения
if [ -d "ImageUpscalerService/Resources/models-cunet" ]; then
    echo "Удаление дублирующихся моделей из ImageUpscalerService/Resources/models-cunet..."
    rm -rf "ImageUpscalerService/Resources/models-cunet"
    echo "Модели удалены."
fi

# Удаляем бинарный файл waifu2x из ImageUpscalerService, так как мы будем копировать его из основного приложения
if [ -f "ImageUpscalerService/Resources/waifu2x-ncnn-vulkan" ]; then
    echo "Удаление дублирующегося файла waifu2x-ncnn-vulkan из ImageUpscalerService/Resources..."
    rm -f "ImageUpscalerService/Resources/waifu2x-ncnn-vulkan"
    echo "Файл удален."
fi

# Создаем директорию для ресурсов в ImageUpscalerService, если она не существует
mkdir -p "ImageUpscalerService/Resources"

echo "Проблема с дублированием ресурсов исправлена."
echo "Теперь вы можете собрать проект в Xcode и запустить скрипт prepare_app.sh для подготовки приложения к запуску." 