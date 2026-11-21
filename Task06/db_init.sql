-- ============================================================================
-- Лабораторная работа 6. Проектирование и создание базы данных для приложения
-- Приложение: Автоматизация работы парикмахерской
-- Файл: Task06/db_init.sql
-- СУБД: SQLite
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. Удаление таблиц в обратном порядке зависимостей
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS completed_works;
DROP TABLE IF EXISTS appointment_services;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS masters;

DROP VIEW IF EXISTS v_salary_report;
DROP VIEW IF EXISTS v_services_stats;
DROP VIEW IF EXISTS v_employees;

-- ----------------------------------------------------------------------------
-- 2. Создание таблиц
-- ----------------------------------------------------------------------------

-- 2.1. Мастера (кадровый учет)
-- При увольнении сотрудника статус меняется на 'уволен', выставляется fire_date.
-- Благодаря ON DELETE RESTRICT все данные о выполненной работе сохраняются в базе.
CREATE TABLE masters (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    phone           TEXT NOT NULL UNIQUE,
    specialization  TEXT NOT NULL CHECK (specialization IN ('мужской', 'женский', 'универсал')),
    commission_rate REAL NOT NULL CHECK (commission_rate > 0 AND commission_rate <= 100),
    hire_date       TEXT NOT NULL DEFAULT (date('now')),
    fire_date       TEXT,
    status          TEXT NOT NULL DEFAULT 'работает' CHECK (status IN ('работает', 'уволен'))
);

-- 2.2. Индивидуальный график работы мастеров
CREATE TABLE schedules (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    master_id  INTEGER NOT NULL,
    work_date  TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time   TEXT NOT NULL,
    UNIQUE (master_id, work_date),
    FOREIGN KEY (master_id) REFERENCES masters(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 2.3. Справочник предоставляемых услуг
CREATE TABLE services (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    name             TEXT NOT NULL UNIQUE,
    gender           TEXT NOT NULL CHECK (gender IN ('мужской', 'женский', 'универсал')),
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    price            REAL NOT NULL CHECK (price >= 0)
);

-- 2.4. Клиенты
CREATE TABLE clients (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name   TEXT NOT NULL,
    phone  TEXT NOT NULL UNIQUE,
    gender TEXT NOT NULL CHECK (gender IN ('мужской', 'женский'))
);

-- 2.5. Предварительная запись к мастеру
CREATE TABLE appointments (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id        INTEGER NOT NULL,
    master_id        INTEGER NOT NULL,
    appointment_date TEXT NOT NULL,
    start_time       TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'запланировано' CHECK (status IN ('запланировано', 'выполнено', 'отменено')),
    FOREIGN KEY (client_id) REFERENCES clients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (master_id) REFERENCES masters(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 2.6. Выбранные услуги при предварительной записи (связь многие-ко-многим)
CREATE TABLE appointment_services (
    appointment_id INTEGER NOT NULL,
    service_id     INTEGER NOT NULL,
    PRIMARY KEY (appointment_id, service_id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 2.7. Учет фактически выполненных работ
-- Фиксирует оказанную услугу, мастера, клиента, дату и фактическую стоимость.
CREATE TABLE completed_works (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER,
    master_id      INTEGER NOT NULL,
    client_id      INTEGER NOT NULL,
    service_id     INTEGER NOT NULL,
    work_date      TEXT NOT NULL,
    price          REAL NOT NULL CHECK (price >= 0),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    FOREIGN KEY (master_id) REFERENCES masters(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (client_id) REFERENCES clients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (service_id) REFERENCES services(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- 3. Индексы
-- ----------------------------------------------------------------------------
CREATE INDEX idx_masters_name    ON masters(name);
CREATE INDEX idx_clients_phone   ON clients(phone);
CREATE INDEX idx_services_name   ON services(name);
CREATE INDEX idx_app_master_date ON appointments(master_id, appointment_date);
CREATE INDEX idx_works_master    ON completed_works(master_id, work_date);

-- ----------------------------------------------------------------------------
-- 4. Заполнение тестовыми данными
-- ----------------------------------------------------------------------------
BEGIN TRANSACTION;

-- Мастера (включая работающих и уволенного с сохраненной историей)
INSERT INTO masters (id, name, phone, specialization, commission_rate, hire_date, fire_date, status) VALUES
    (1, 'Воронин Алексей',   '+79270000001', 'мужской',   40.0, '2023-01-15', NULL,         'работает'),
    (2, 'Смирнова Елена',    '+79270000002', 'женский',   45.0, '2023-03-01', NULL,         'работает'),
    (3, 'Денисов Максим',    '+79270000003', 'универсал', 50.0, '2022-09-01', NULL,         'работает'),
    (4, 'Кузнецова Анна',    '+79270000004', 'универсал', 45.0, '2023-06-10', NULL,         'работает'),
    (5, 'Соколов Дмитрий',   '+79270000005', 'мужской',   35.0, '2022-01-10', '2024-05-31', 'уволен');

-- Индивидуальный график работы мастеров
INSERT INTO schedules (master_id, work_date, start_time, end_time) VALUES
    (1, '2026-11-10', '09:00', '18:00'),
    (1, '2026-11-12', '09:00', '18:00'),
    (2, '2026-11-10', '10:00', '19:00'),
    (2, '2026-11-11', '10:00', '19:00'),
    (3, '2026-11-10', '11:00', '20:00'),
    (3, '2026-11-11', '11:00', '20:00'),
    (4, '2026-11-12', '09:00', '18:00'),
    (5, '2024-04-15', '09:00', '18:00');

-- Справочник услуг (для мужчин, женщин и универсальные)
INSERT INTO services (id, name, gender, duration_minutes, price) VALUES
    (1, 'Мужская стрижка',              'мужской',   45, 1200.0),
    (2, 'Стрижка бороды',               'мужской',   30,  700.0),
    (3, 'Мужской комплекс',             'мужской',   60, 1700.0),
    (4, 'Женская модельная стрижка',    'женский',   60, 1800.0),
    (5, 'Повседневная укладка',         'женский',   40, 1300.0),
    (6, 'Окрашивание волос',            'женский',  120, 3500.0),
    (7, 'Мытье и сушка головы',         'универсал', 15,  400.0),
    (8, 'Детская стрижка',              'универсал', 30,  900.0);

-- Клиенты
INSERT INTO clients (id, name, phone, gender) VALUES
    (1, 'Вельдяскин Глеб',  '+79170010001', 'мужской'),
    (2, 'Ефимкин Кирилл',   '+79170010002', 'мужской'),
    (3, 'Николаева Ольга',  '+79170010003', 'женский'),
    (4, 'Морозова Татьяна', '+79170010004', 'женский'),
    (5, 'Петров Иван',      '+79170010005', 'мужской');

-- Предварительная запись
INSERT INTO appointments (id, client_id, master_id, appointment_date, start_time, status) VALUES
    (1, 1, 1, '2026-11-10', '10:00', 'выполнено'),
    (2, 2, 3, '2026-11-10', '12:00', 'выполнено'),
    (3, 3, 2, '2026-11-11', '14:00', 'выполнено'),
    (4, 4, 3, '2026-11-11', '16:00', 'выполнено'),
    (5, 5, 1, '2026-11-12', '11:00', 'запланировано'),
    (6, 5, 5, '2024-04-15', '10:00', 'выполнено');

-- Выбранные услуги при записи
INSERT INTO appointment_services (appointment_id, service_id) VALUES
    (1, 1),
    (2, 3),
    (3, 4),
    (3, 7),
    (4, 6),
    (5, 1),
    (6, 1);

-- Фактически выполненные работы
INSERT INTO completed_works (id, appointment_id, master_id, client_id, service_id, work_date, price) VALUES
    (1, 1, 1, 1, 1, '2026-11-10', 1200.0),
    (2, 2, 3, 2, 3, '2026-11-10', 1700.0),
    (3, 3, 2, 3, 4, '2026-11-11', 1800.0),
    (4, 3, 2, 3, 7, '2026-11-11',  400.0),
    (5, 4, 3, 4, 6, '2026-11-11', 3500.0),
    -- Работа без предварительной записи (живая очередь):
    (6, NULL, 1, 5, 2, '2026-11-12', 700.0),
    -- Архивная работа уволенного мастера:
    (7, 6, 5, 5, 1, '2024-04-15', 1000.0);

COMMIT;

-- ----------------------------------------------------------------------------
-- 5. Представления (Views) для отчетов и расчета зарплаты
-- ----------------------------------------------------------------------------

-- 5.1. Расчет зарплаты мастеров в процентах от выручки за все время
CREATE VIEW v_salary_report AS
SELECT
    m.id AS master_id,
    m.name AS master_name,
    m.status,
    m.commission_rate,
    COUNT(cw.id) AS works_count,
    COALESCE(SUM(cw.price), 0.0) AS total_revenue,
    ROUND(COALESCE(SUM(cw.price), 0.0) * (m.commission_rate / 100.0), 2) AS salary
FROM masters m
LEFT JOIN completed_works cw ON cw.master_id = m.id
GROUP BY m.id;

-- 5.2. Статистика по популярности услуг
CREATE VIEW v_services_stats AS
SELECT
    s.name AS service_name,
    s.gender,
    COUNT(cw.id) AS orders_count,
    COALESCE(SUM(cw.price), 0.0) AS total_revenue
FROM services s
LEFT JOIN completed_works cw ON cw.service_id = s.id
GROUP BY s.id
ORDER BY orders_count DESC;

-- 5.3. Просмотр работающих и уволенных сотрудников
CREATE VIEW v_employees AS
SELECT
    id,
    name,
    phone,
    specialization,
    commission_rate || '%' AS rate,
    hire_date,
    fire_date,
    status
FROM masters;
