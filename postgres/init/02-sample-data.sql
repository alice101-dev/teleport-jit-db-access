-- Sample tables and rows for trying queries, access requests and alerts.
-- All names and numbers are made up.
BEGIN;

CREATE TABLE customers (
    id          serial PRIMARY KEY,
    name        text NOT NULL UNIQUE,
    email       text NOT NULL,
    phone       text,
    city        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO customers (name, email, phone, city) VALUES
    ('PT Maju Jaya',      'pembelian@majujaya.example',   '021-555-0101',  'Jakarta'),
    ('CV Sumber Rejeki',  'admin@sumberrejeki.example',   '031-555-0102',  'Surabaya'),
    ('Toko Sinar Abadi',  'sinarabadi@toko.example',      '022-555-0103',  'Bandung'),
    ('UD Tani Makmur',    'order@tanimakmur.example',     '061-555-0104',  'Medan'),
    ('PT Agro Lestari',   'procurement@agrolestari.example', '0411-555-0105', 'Makassar'),
    ('Koperasi Subur',    'pengurus@kopsubur.example',    '0274-555-0106', 'Yogyakarta'),
    ('CV Panen Raya',     'cs@panenraya.example',         '024-555-0107',  'Semarang'),
    ('Toko Hijau Daun',   'hijaudaun@toko.example',       '0361-555-0108', 'Denpasar');

CREATE TABLE products (
    id        serial PRIMARY KEY,
    sku       text NOT NULL UNIQUE,
    name      text NOT NULL,
    category  text NOT NULL,
    price     numeric(12, 2) NOT NULL,
    stock     integer NOT NULL DEFAULT 0
);

INSERT INTO products (sku, name, category, price, stock) VALUES
    ('PPK-NPK-50',  'Pupuk NPK 16-16-16 50 kg',    'pupuk',     250000.00, 420),
    ('PPK-UREA-50', 'Pupuk Urea 50 kg',            'pupuk',     185000.00, 610),
    ('PPK-ORG-25',  'Pupuk Organik Granul 25 kg',  'pupuk',      72000.00, 300),
    ('BNH-JGG-01',  'Benih Jagung Hibrida 1 kg',   'benih',     120000.00, 150),
    ('BNH-PDI-05',  'Benih Padi Unggul 5 kg',      'benih',      95000.00, 240),
    ('BNH-CBI-10G', 'Benih Cabai Rawit 10 g',      'benih',      38500.00, 500),
    ('PST-INS-1L',  'Insektisida Cair 1 L',        'pestisida', 164000.00,  90),
    ('PST-HRB-1L',  'Herbisida Sistemik 1 L',      'pestisida', 112000.00, 130),
    ('ALT-SPR-16',  'Sprayer Punggung 16 L',       'alat',      385000.00,  45),
    ('ALT-STG-01',  'Sarung Tangan Kebun',         'alat',       96500.00, 200);

-- Orders gain a number, a link to the customer and a status.
ALTER TABLE orders
    ADD COLUMN order_no     text UNIQUE,
    ADD COLUMN customer_id  integer REFERENCES customers (id),
    ADD COLUMN status       text NOT NULL DEFAULT 'paid';

UPDATE orders o
SET order_no    = 'INV-' || lpad(o.id::text, 4, '0'),
    customer_id = c.id
FROM customers c
WHERE c.name = o.customer;

INSERT INTO orders (order_no, customer, customer_id, amount, status, created_at)
SELECT x.order_no, c.name, c.id, 0, x.status, now() - make_interval(days => x.days_ago)
FROM (VALUES
    ('INV-0004', 'UD Tani Makmur',   'paid',      28),
    ('INV-0005', 'PT Agro Lestari',  'paid',      25),
    ('INV-0006', 'Koperasi Subur',   'paid',      21),
    ('INV-0007', 'PT Maju Jaya',     'paid',      18),
    ('INV-0008', 'CV Panen Raya',    'paid',      14),
    ('INV-0009', 'Toko Hijau Daun',  'cancelled', 11),
    ('INV-0010', 'CV Sumber Rejeki', 'paid',       9),
    ('INV-0011', 'PT Agro Lestari',  'paid',       6),
    ('INV-0012', 'Toko Sinar Abadi', 'pending',    4),
    ('INV-0013', 'UD Tani Makmur',   'pending',    2),
    ('INV-0014', 'Koperasi Subur',   'paid',       1),
    ('INV-0015', 'PT Maju Jaya',     'pending',    0)
) AS x (order_no, customer, status, days_ago)
JOIN customers c ON c.name = x.customer;

CREATE TABLE order_items (
    id          serial PRIMARY KEY,
    order_id    integer NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id  integer NOT NULL REFERENCES products (id),
    qty         integer NOT NULL CHECK (qty > 0),
    unit_price  numeric(12, 2) NOT NULL
);

INSERT INTO order_items (order_id, product_id, qty, unit_price)
SELECT o.id, p.id, x.qty, p.price
FROM (VALUES
    ('INV-0001', 'PPK-NPK-50',   5),
    ('INV-0002', 'BNH-JGG-01',   4),
    ('INV-0003', 'ALT-STG-01',   1),
    ('INV-0004', 'PPK-UREA-50', 20), ('INV-0004', 'BNH-PDI-05',  10),
    ('INV-0005', 'PPK-NPK-50',  40), ('INV-0005', 'PST-HRB-1L',  12), ('INV-0005', 'ALT-SPR-16', 3),
    ('INV-0006', 'PPK-ORG-25',  30), ('INV-0006', 'BNH-CBI-10G', 25),
    ('INV-0007', 'PPK-NPK-50',  10), ('INV-0007', 'PST-INS-1L',   6),
    ('INV-0008', 'BNH-JGG-01',  15), ('INV-0008', 'PPK-UREA-50',  8),
    ('INV-0009', 'ALT-SPR-16',   2),
    ('INV-0010', 'BNH-PDI-05',  20), ('INV-0010', 'PPK-ORG-25',  10), ('INV-0010', 'ALT-STG-01', 12),
    ('INV-0011', 'PST-INS-1L',  10), ('INV-0011', 'PST-HRB-1L',  10),
    ('INV-0012', 'BNH-CBI-10G', 40), ('INV-0012', 'ALT-STG-01',   5),
    ('INV-0013', 'PPK-UREA-50', 15),
    ('INV-0014', 'PPK-ORG-25',  50), ('INV-0014', 'BNH-PDI-05',   8),
    ('INV-0015', 'PPK-NPK-50',  25), ('INV-0015', 'ALT-SPR-16',   1)
) AS x (order_no, sku, qty)
JOIN orders o ON o.order_no = x.order_no
JOIN products p ON p.sku = x.sku;

UPDATE orders o
SET amount = t.total
FROM (SELECT order_id, sum(qty * unit_price) AS total FROM order_items GROUP BY order_id) t
WHERE t.order_id = o.id;

CREATE TABLE payments (
    id        serial PRIMARY KEY,
    order_id  integer NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    method    text NOT NULL,
    amount    numeric(12, 2) NOT NULL,
    paid_at   timestamptz NOT NULL
);

INSERT INTO payments (order_id, method, amount, paid_at)
SELECT id,
       (ARRAY['transfer', 'qris', 'virtual_account'])[1 + id % 3],
       amount,
       created_at + interval '6 hours'
FROM orders
WHERE status = 'paid';

-- Deliberately sensitive, for trying alerts on dumps and narrower grants.
CREATE TABLE employees (
    id           serial PRIMARY KEY,
    name         text NOT NULL,
    email        text NOT NULL UNIQUE,
    department   text NOT NULL,
    salary       numeric(12, 2) NOT NULL,
    national_id  text NOT NULL
);

INSERT INTO employees (name, email, department, salary, national_id) VALUES
    ('Rina Kartika',    'rina.kartika@cucumber.example',    'finance',    14500000.00, '0000000000000001'),
    ('Bagus Santoso',   'bagus.santoso@cucumber.example',   'sales',       9800000.00, '0000000000000002'),
    ('Dewi Anggraini',  'dewi.anggraini@cucumber.example',  'sales',      10200000.00, '0000000000000003'),
    ('Yusuf Hidayat',   'yusuf.hidayat@cucumber.example',   'warehouse',   7400000.00, '0000000000000004'),
    ('Maria Lestari',   'maria.lestari@cucumber.example',   'hr',         11800000.00, '0000000000000005'),
    ('Andi Pratama',    'andi.pratama@cucumber.example',    'it',         16500000.00, '0000000000000006'),
    ('Sari Wulandari',  'sari.wulandari@cucumber.example',  'finance',    12300000.00, '0000000000000007'),
    ('Putu Wirawan',    'putu.wirawan@cucumber.example',    'warehouse',   7100000.00, '0000000000000008');

-- The grants in 01-schema.sql only covered the tables that existed then.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO db_read;
-- pg_dump reads sequence values, so a read-only user needs this to run it.
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO db_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO db_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO db_writer;

COMMIT;
