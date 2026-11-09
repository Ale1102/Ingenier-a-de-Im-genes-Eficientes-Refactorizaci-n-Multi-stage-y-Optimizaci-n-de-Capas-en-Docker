-- Script opcional: se ejecuta solo la primera vez que se crea el volumen de datos.
-- Garantiza charset utf8mb4 en la base de datos de la aplicación.
ALTER DATABASE `app_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
