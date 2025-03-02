#!/bin/bash

# Скрипт для загрузки моделей waifu2x-ncnn-vulkan

# Создаем директорию для моделей
MODELS_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/models-cunet"
mkdir -p "$MODELS_DIR"

echo "Загрузка моделей waifu2x в $MODELS_DIR"

# URL репозитория с моделями
REPO_URL="https://github.com/nihui/waifu2x-ncnn-vulkan"
MODELS_BRANCH="models"

# Временная директория для клонирования
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Клонируем только ветку с моделями (shallow clone)
git clone --depth 1 --branch "$MODELS_BRANCH" --single-branch "$REPO_URL" waifu2x-models

# Копируем модели cunet
cp -R waifu2x-models/models-cunet/* "$MODELS_DIR/"

# Выводим список скопированных файлов
echo "Скопированные модели:"
ls -la "$MODELS_DIR"

# Очищаем временную директорию
rm -rf "$TMP_DIR"

echo "Загрузка моделей завершена" 