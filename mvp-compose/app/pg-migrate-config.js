const {
  DATABASE_URL,
  DB_HOST = 'localhost',
  DB_PORT = '5432',
  DB_NAME = 'myapp',
  DB_USER = 'myuser',
  DB_PASSWORD = 'mypassword',
  DB_SCHEMA = 'public',
  DB_SSL,
} = process.env;

const parsePort = (value) => {
  const parsed = Number(value);
  return Number.isNaN(parsed) ? 5432 : parsed;
};

const connection =
  DATABASE_URL ||
  {
    host: DB_HOST,
    port: parsePort(DB_PORT),
    database: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    ssl: DB_SSL ? DB_SSL.toLowerCase() === 'true' : undefined,
  };

module.exports = {
  dir: 'migrations',
  migrationsTable: 'pgmigrations',
  databaseUrl: connection,
  schema: DB_SCHEMA,
};
