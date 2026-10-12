-- Tables named like a production application database, so test queries and
-- their alerts look realistic. All rows are made up, including the hashes.
BEGIN;

CREATE TABLE users (
    id             serial PRIMARY KEY,
    email          text NOT NULL UNIQUE,
    full_name      text NOT NULL,
    password_hash  text NOT NULL,
    role           text NOT NULL,
    is_active      boolean NOT NULL DEFAULT true,
    last_login_at  timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now()
);

INSERT INTO users (email, full_name, role, is_active, last_login_at, password_hash)
SELECT x.email, x.full_name, x.role, x.is_active,
       now() - make_interval(hours => x.hours_ago),
       '$2b$12$' || md5(x.email) || substr(md5(x.full_name), 1, 21)
FROM (VALUES
    ('admin@cucumber.example',         'Administrator',   'admin',     true,    2),
    ('rina.kartika@cucumber.example',  'Rina Kartika',    'finance',   true,    5),
    ('sari.wulandari@cucumber.example','Sari Wulandari',  'finance',   true,   26),
    ('bagus.santoso@cucumber.example', 'Bagus Santoso',   'sales',     true,    1),
    ('dewi.anggraini@cucumber.example','Dewi Anggraini',  'sales',     true,    9),
    ('yusuf.hidayat@cucumber.example', 'Yusuf Hidayat',   'warehouse', true,   30),
    ('putu.wirawan@cucumber.example',  'Putu Wirawan',    'warehouse', false, 720),
    ('integrasi@cucumber.example',     'Akun Integrasi',  'service',   true,    0)
) AS x (email, full_name, role, is_active, hours_ago);

CREATE TABLE invoices (
    id           serial PRIMARY KEY,
    invoice_no   text NOT NULL UNIQUE,
    order_id     integer NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    customer_id  integer REFERENCES customers (id),
    subtotal     numeric(14, 2) NOT NULL,
    tax          numeric(14, 2) NOT NULL,
    total        numeric(14, 2) NOT NULL,
    due_date     date NOT NULL,
    status       text NOT NULL
);

INSERT INTO invoices (invoice_no, order_id, customer_id, subtotal, tax, total, due_date, status)
SELECT 'FKT-' || to_char(o.created_at, 'YYYYMM') || '-' || lpad(o.id::text, 4, '0'),
       o.id, o.customer_id, o.amount, round(o.amount * 0.11, 2), round(o.amount * 1.11, 2),
       (o.created_at + interval '30 days')::date,
       CASE o.status WHEN 'paid' THEN 'paid' WHEN 'pending' THEN 'unpaid' ELSE 'void' END
FROM orders o;

CREATE TABLE transactions (
    id           bigserial PRIMARY KEY,
    reference    text NOT NULL UNIQUE,
    invoice_id   integer NOT NULL REFERENCES invoices (id) ON DELETE CASCADE,
    customer_id  integer REFERENCES customers (id),
    type         text NOT NULL,
    amount       numeric(14, 2) NOT NULL,
    currency     char(3) NOT NULL DEFAULT 'IDR',
    status       text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);

INSERT INTO transactions (reference, invoice_id, customer_id, type, amount, status, created_at)
SELECT 'TRX-' || to_char(o.created_at, 'YYYYMMDD') || '-' || lpad(i.id::text, 5, '0'),
       i.id, i.customer_id, 'payment', i.total,
       CASE i.status WHEN 'paid' THEN 'settled' WHEN 'unpaid' THEN 'pending' ELSE 'void' END,
       o.created_at + interval '6 hours'
FROM invoices i
JOIN orders o ON o.id = i.order_id;

-- Refunds for the cancelled orders.
INSERT INTO transactions (reference, invoice_id, customer_id, type, amount, status, created_at)
SELECT 'RFD-' || to_char(o.created_at, 'YYYYMMDD') || '-' || lpad(i.id::text, 5, '0'),
       i.id, i.customer_id, 'refund', i.total, 'settled', o.created_at + interval '2 days'
FROM invoices i
JOIN orders o ON o.id = i.order_id
WHERE o.status = 'cancelled';

CREATE TABLE audit_logs (
    id          bigserial PRIMARY KEY,
    actor       text NOT NULL,
    action      text NOT NULL,
    entity      text NOT NULL,
    entity_id   text,
    detail      jsonb NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO audit_logs (actor, action, entity, entity_id, detail, created_at)
SELECT u.email, 'user.login', 'users', u.id::text,
       jsonb_build_object('ip', '10.20.' || (u.id * 7 % 250) || '.' || (u.id * 13 % 250)),
       u.last_login_at
FROM users u
WHERE u.last_login_at IS NOT NULL;

INSERT INTO audit_logs (actor, action, entity, entity_id, detail, created_at)
SELECT (ARRAY['bagus.santoso@cucumber.example', 'dewi.anggraini@cucumber.example'])[1 + o.id % 2],
       'order.create', 'orders', o.id::text,
       jsonb_build_object('order_no', o.order_no, 'amount', o.amount),
       o.created_at
FROM orders o;

-- Cover the new tables, and any table created later by the same owner.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO db_read;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO db_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO db_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO db_writer;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO db_read;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO db_read;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO db_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO db_writer;

COMMIT;
