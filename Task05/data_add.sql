PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- 1. Добавление пяти новых пользователей (без дубликатов и с однократным поиском профессии)
WITH new_users(first_name, last_name, email, gender, occupation_name) AS (
    VALUES
        ('Глеб',    'Вельдяскин', 'gleb.veldyaskin@gmail.com', 'M', 'student'),
        ('Алексей', 'Воронин',    'aleksey.voronin@gmail.com', 'M', 'student'),
        ('Максим',  'Денисов',    'maksim.denisov@gmail.com',  'M', 'student'),
        ('Кирилл',  'Ефимкин',    'kirill.efimkin@gmail.com',  'M', 'student'),
        ('Виталий', 'Зюзин',      'vitaliy.zyuzin@gmail.com',  'M', 'student')
)
INSERT INTO users (first_name, last_name, email, gender, occupation_id)
SELECT u.first_name, u.last_name, u.email, u.gender, o.id
FROM new_users u
JOIN occupations o ON o.name = u.occupation_name
ON CONFLICT (email) DO NOTHING;

-- 2. Добавление трёх новых фильмов (с защитой от дубликатов)
INSERT INTO movies (title, year)
VALUES
    ('Dune: Part Two', 2024),
    ('Oppenheimer', 2023),
    ('The Grand Budapest Hotel', 2014)
ON CONFLICT (title, year) DO NOTHING;

-- Привязка жанров к добавленным фильмам
WITH movie_genre_map(title, year, genre_name) AS (
    VALUES
        ('Dune: Part Two', 2024, 'Sci-Fi'),
        ('Dune: Part Two', 2024, 'Adventure'),
        ('Oppenheimer', 2023, 'Drama'),
        ('Oppenheimer', 2023, 'Thriller'),
        ('The Grand Budapest Hotel', 2014, 'Comedy'),
        ('The Grand Budapest Hotel', 2014, 'Drama')
)
INSERT INTO movie_genres (movie_id, genre_id)
SELECT m.id, g.id
FROM movie_genre_map map
JOIN movies m ON m.title = map.title AND m.year = map.year
JOIN genres g ON g.name = map.genre_name
ON CONFLICT (movie_id, genre_id) DO NOTHING;

-- 3. Добавление трёх новых отзывов от Максима Денисова (поиск по уникальному email)
WITH new_ratings(title, year, rating) AS (
    VALUES
        ('Dune: Part Two', 2024, 5.0),
        ('Oppenheimer', 2023, 4.5),
        ('The Grand Budapest Hotel', 2014, 4.8)
)
INSERT INTO ratings (user_id, movie_id, rating)
SELECT u.id, m.id, r.rating
FROM new_ratings r
CROSS JOIN (SELECT id FROM users WHERE email = 'maksim.denisov@gmail.com') u
JOIN movies m ON m.title = r.title AND m.year = r.year
ON CONFLICT (user_id, movie_id) DO NOTHING;

COMMIT;