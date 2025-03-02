#!/bin/bash

# Скрипт для добавления скрипта исправления структуры директорий моделей в качестве скрипта сборки в Xcode

echo "Добавление скрипта исправления структуры директорий моделей в качестве скрипта сборки в Xcode..."

# Путь к проекту
PROJECT_DIR="$(pwd)"
FIX_SCRIPT="$PROJECT_DIR/fix_models_directory.sh"

# Проверяем, существует ли скрипт
if [ ! -f "$FIX_SCRIPT" ]; then
    echo "Ошибка: Скрипт fix_models_directory.sh не найден в $PROJECT_DIR"
    exit 1
fi

# Создаем директорию для скриптов сборки, если она не существует
mkdir -p "$PROJECT_DIR/Scripts"

# Копируем скрипт в директорию скриптов сборки
cp "$FIX_SCRIPT" "$PROJECT_DIR/Scripts/"
chmod +x "$PROJECT_DIR/Scripts/fix_models_directory.sh"

echo "Скрипт скопирован в директорию Scripts"
echo "Теперь вам нужно добавить скрипт в качестве скрипта сборки в Xcode:"
echo "1. Откройте проект в Xcode"
echo "2. Выберите проект в навигаторе проектов"
echo "3. Выберите таргет ImageUpscalerService"
echo "4. Перейдите на вкладку 'Build Phases'"
echo "5. Нажмите '+' и выберите 'New Run Script Phase'"
echo "6. Введите следующий скрипт:"
echo "   \$PROJECT_DIR/Scripts/fix_models_directory.sh"
echo "7. Перетащите этот скрипт перед фазой 'Copy Bundle Resources'"
echo "8. Повторите шаги 3-7 для таргета upscallerapp"

echo "Готово! Теперь скрипт будет автоматически выполняться при каждой сборке проекта." 