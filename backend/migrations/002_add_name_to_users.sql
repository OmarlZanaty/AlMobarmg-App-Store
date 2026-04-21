ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255) NOT NULL DEFAULT '';
UPDATE users SET name = split_part(email, '@', 1) WHERE name = '';
