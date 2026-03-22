-- Аналитическая схема «снежинка»: измерения нормализованы (подуровни), один факт продаж
CREATE SCHEMA IF NOT EXISTS snowflake;

-- Общий справочник стран (магазины/города в снежинке; у клиентов и продавцов страна хранится в самом измерении)
CREATE TABLE snowflake.d_countries (
  country_id   SERIAL PRIMARY KEY,
  country_name TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_pet_types (
  pet_type_id SERIAL PRIMARY KEY,
  type_name   TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_pet_breeds (
  pet_breed_id SERIAL PRIMARY KEY,
  breed_name   TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_product_categories (
  category_id   SERIAL PRIMARY KEY,
  category_name TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_brands (
  brand_id   SERIAL PRIMARY KEY,
  brand_name TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_materials (
  material_id   SERIAL PRIMARY KEY,
  material_name TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_sizes (
  size_id    SERIAL PRIMARY KEY,
  size_label TEXT NOT NULL UNIQUE
);

CREATE TABLE snowflake.d_colors (
  color_id   SERIAL PRIMARY KEY,
  color_name TEXT NOT NULL UNIQUE
);

-- Сегмент «для каких питомцев» товар (колонка pet_category в CSV)
CREATE TABLE snowflake.d_product_pet_segments (
  segment_id   SERIAL PRIMARY KEY,
  segment_name TEXT NOT NULL UNIQUE
);

-- Город в иерархии: город -> страна (снежинка относительно магазина/поставщика)
CREATE TABLE snowflake.d_cities (
  city_id         SERIAL PRIMARY KEY,
  city_name       TEXT NOT NULL,
  state_province  TEXT NOT NULL DEFAULT '',
  country_id      INTEGER NOT NULL REFERENCES snowflake.d_countries (country_id),
  UNIQUE (city_name, state_province, country_id)
);

CREATE TABLE snowflake.d_customers (
  customer_id         SERIAL PRIMARY KEY,
  source_customer_id  INTEGER NOT NULL UNIQUE,
  first_name          TEXT,
  last_name           TEXT,
  age                 INTEGER,
  email               TEXT,
  postal_code         TEXT,
  pet_name            TEXT,
  country_name        TEXT,
  pet_type_id         INTEGER REFERENCES snowflake.d_pet_types (pet_type_id),
  pet_breed_id        INTEGER REFERENCES snowflake.d_pet_breeds (pet_breed_id)
);

CREATE TABLE snowflake.d_sellers (
  seller_id        SERIAL PRIMARY KEY,
  source_seller_id INTEGER NOT NULL UNIQUE,
  first_name       TEXT,
  last_name        TEXT,
  email            TEXT,
  postal_code      TEXT,
  country_name     TEXT
);

-- Товар со ссылками на нормализованные атрибуты (не «толстое» измерение)
CREATE TABLE snowflake.d_products (
  product_id          SERIAL PRIMARY KEY,
  source_product_id   INTEGER NOT NULL UNIQUE,
  product_name        TEXT NOT NULL,
  description         TEXT,
  weight_kg           NUMERIC(10, 3),
  rating              NUMERIC(4, 2),
  reviews_count       INTEGER,
  release_date        DATE,
  expiry_date         DATE,
  category_id         INTEGER NOT NULL REFERENCES snowflake.d_product_categories (category_id),
  brand_id            INTEGER NOT NULL REFERENCES snowflake.d_brands (brand_id),
  material_id         INTEGER NOT NULL REFERENCES snowflake.d_materials (material_id),
  size_id             INTEGER NOT NULL REFERENCES snowflake.d_sizes (size_id),
  color_id            INTEGER NOT NULL REFERENCES snowflake.d_colors (color_id),
  pet_segment_id      INTEGER NOT NULL REFERENCES snowflake.d_product_pet_segments (segment_id)
);

CREATE TABLE snowflake.d_stores (
  store_id      SERIAL PRIMARY KEY,
  store_key     TEXT NOT NULL UNIQUE,
  store_name    TEXT NOT NULL,
  location_line TEXT,
  phone         TEXT,
  email         TEXT,
  city_id       INTEGER REFERENCES snowflake.d_cities (city_id)
);

CREATE TABLE snowflake.d_suppliers (
  supplier_id   SERIAL PRIMARY KEY,
  supplier_key  TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  contact       TEXT,
  email         TEXT,
  phone         TEXT,
  address_line  TEXT,
  city_name     TEXT,
  country_name  TEXT
);

CREATE TABLE snowflake.d_date (
  date_id       INTEGER PRIMARY KEY,
  full_date     DATE NOT NULL UNIQUE,
  year          INTEGER NOT NULL,
  quarter       INTEGER NOT NULL,
  month         INTEGER NOT NULL,
  day_of_month  INTEGER NOT NULL
);

CREATE TABLE snowflake.f_sales (
  sales_fact_id SERIAL PRIMARY KEY,
  date_id       INTEGER NOT NULL REFERENCES snowflake.d_date (date_id),
  customer_id   INTEGER NOT NULL REFERENCES snowflake.d_customers (customer_id),
  seller_id     INTEGER NOT NULL REFERENCES snowflake.d_sellers (seller_id),
  product_id    INTEGER NOT NULL REFERENCES snowflake.d_products (product_id),
  store_id      INTEGER NOT NULL REFERENCES snowflake.d_stores (store_id),
  supplier_id   INTEGER NOT NULL REFERENCES snowflake.d_suppliers (supplier_id),
  quantity      INTEGER NOT NULL,
  total_price   NUMERIC(14, 2) NOT NULL,
  unit_price    NUMERIC(14, 2),
  source_row_id INTEGER NOT NULL UNIQUE
);

CREATE INDEX idx_f_sales_date ON snowflake.f_sales (date_id);
CREATE INDEX idx_f_sales_customer ON snowflake.f_sales (customer_id);
CREATE INDEX idx_f_sales_product ON snowflake.f_sales (product_id);
