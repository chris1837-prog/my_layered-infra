exports.up = (pgm) => {
  pgm.createTable('users', {
    id: 'id',
    name: { type: 'text', notNull: true },
    created_at: { type: 'timestamptz', default: pgm.func('now()') },
  });

  pgm.sql(`INSERT INTO users (name) VALUES ('Alice'), ('Bob');`);
};

exports.down = (pgm) => {
  pgm.dropTable('users');
};
