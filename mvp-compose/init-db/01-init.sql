-- This script runs on the first initialization of the database.
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Insert some initial data for testing purposes.
INSERT INTO users(name) VALUES ('Alice'), ('Bob')
ON CONFLICT DO NOTHING;