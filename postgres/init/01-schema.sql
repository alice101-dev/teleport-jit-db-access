-- Database users that Teleport roles map to. No passwords: they authenticate
-- only with a Teleport-issued client certificate (pg_hba.conf).
CREATE USER db_read;
CREATE USER db_writer;

CREATE TABLE orders (
    id          serial PRIMARY KEY,
    customer    text NOT NULL,
    amount      numeric(12, 2) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO orders (customer, amount) VALUES
    ('PT Maju Jaya', 1250000.00),
    ('CV Sumber Rejeki', 480000.00),
    ('Toko Sinar Abadi', 96500.00);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO db_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO db_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO db_writer;
