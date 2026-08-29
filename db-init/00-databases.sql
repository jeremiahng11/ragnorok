-- The main `ragnarok` database and the `ragnarok` user are created by the
-- MariaDB entrypoint from MARIADB_DATABASE / MARIADB_USER. rAthena also wants
-- a second database for logs, which we create here.

CREATE DATABASE IF NOT EXISTS ragnarok_logs
  CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

GRANT ALL PRIVILEGES ON ragnarok_logs.* TO 'ragnarok'@'%';
FLUSH PRIVILEGES;
