#!/usr/bin/env python3
"""
Генератор SQL-скрипта db_init.sql.
Читает CSV-файлы из каталога dataset/ и формирует скрипт
с DROP/CREATE таблиц и INSERT данных.
"""

import csv
import time
from pathlib import Path

SQL_FILE = "db_init.sql"
DATASET_DIR = Path("dataset")

# Схема БД: типы полей соответствуют структуре исходных CSV
SCHEMA = {
    "movies": {
        "file": "movies.csv",
        "pk": "id",
        "cols": [
            ("id",     "INTEGER"),
            ("title",  "TEXT"),
            ("year",   "INTEGER"),
            ("genres", "TEXT"),
        ],
    },
    "ratings": {
        "file": "ratings.csv",
        "pk": "id",
        "cols": [
            ("id",        "INTEGER"),
            ("user_id",   "INTEGER"),
            ("movie_id",  "INTEGER"),
            ("rating",    "REAL"),
            ("timestamp", "INTEGER"),
        ],
    },
    "tags": {
        "file": "tags.csv",
        "pk": "id",
        "cols": [
            ("id",        "INTEGER"),
            ("user_id",   "INTEGER"),
            ("movie_id",  "INTEGER"),
            ("tag",       "TEXT"),
            ("timestamp", "INTEGER"),
        ],
    },
    "users": {
        "file": "users.csv",
        "pk": "id",
        "cols": [
            ("id",            "INTEGER"),
            ("name",          "TEXT"),
            ("email",         "TEXT"),
            ("gender",        "TEXT"),
            ("register_date", "TEXT"),
            ("occupation",    "TEXT"),
        ],
    },
}


def sql_literal(value: str) -> str:
    """Преобразует значение CSV в SQL-литерал."""
    if value is None or value.strip() == "":
        return "NULL"
    # Числа — без кавычек
    try:
        int(value)
        return value
    except ValueError:
        pass
    try:
        float(value)
        return value
    except ValueError:
        pass
    # Строки — в одинарных кавычках с экранированием
    return "'" + value.replace("'", "''") + "'"


def generate() -> None:
    start = time.time()
    out: list[str] = []

    # 1. Удаление старых таблиц (если существуют)
    for table in SCHEMA:
        out.append(f"DROP TABLE IF EXISTS {table};\n")

    # 2. Создание таблиц
    for table, info in SCHEMA.items():
        cols = ", ".join(
            f"{name} {type_}" + (" PRIMARY KEY" if name == info["pk"] else "")
            for name, type_ in info["cols"]
        )
        out.append(f"CREATE TABLE {table} ({cols});\n")

    # 3. Вставка данных в одной транзакции (для скорости)
    out.append("\nBEGIN TRANSACTION;\n")

    for table, info in SCHEMA.items():
        csv_path = DATASET_DIR / info["file"]
        if not csv_path.exists():
            out.append(f"-- [!] Файл {csv_path} не найден\n")
            continue

        names = [c[0] for c in info["cols"]]
        prefix = f"INSERT INTO {table} ({', '.join(names)}) VALUES"

        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter=",")
            for row in reader:
                vals = ", ".join(sql_literal(row.get(n, "")) for n in names)
                out.append(f"{prefix} ({vals});\n")

    out.append("COMMIT;\n")

    # 4. Запись скрипта
    with open(SQL_FILE, "w", encoding="utf-8") as f:
        f.writelines(out)

    print(f"Скрипт {SQL_FILE} сгенерирован за {time.time() - start:.3f} сек.")


if __name__ == "__main__":
    generate()