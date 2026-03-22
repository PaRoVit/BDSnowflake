-- Заполнение измерений и факта из staging.mock_data_raw
-- «Снежинка»: товар и магазин/поставщик «разложены» на нормализованные справочники

-- Значения по умолчанию для обязательных FK у товара (если в CSV пусто)
INSERT INTO snowflake.d_product_categories (category_name) VALUES ('Unknown') ON CONFLICT (category_name) DO NOTHING;
INSERT INTO snowflake.d_brands (brand_name) VALUES ('Unknown') ON CONFLICT (brand_name) DO NOTHING;
INSERT INTO snowflake.d_materials (material_name) VALUES ('Unknown') ON CONFLICT (material_name) DO NOTHING;
INSERT INTO snowflake.d_sizes (size_label) VALUES ('Unknown') ON CONFLICT (size_label) DO NOTHING;
INSERT INTO snowflake.d_colors (color_name) VALUES ('Unknown') ON CONFLICT (color_name) DO NOTHING;
INSERT INTO snowflake.d_product_pet_segments (segment_name) VALUES ('Unknown') ON CONFLICT (segment_name) DO NOTHING;

-- Страны (все встречающиеся в источнике)
INSERT INTO snowflake.d_countries (country_name)
SELECT DISTINCT trim(c) AS country_name
FROM (
  SELECT customer_country AS c FROM staging.mock_data_raw
  UNION ALL SELECT seller_country FROM staging.mock_data_raw
  UNION ALL SELECT store_country FROM staging.mock_data_raw
  UNION ALL SELECT supplier_country FROM staging.mock_data_raw
) x
WHERE c IS NOT NULL AND trim(c) <> ''
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO snowflake.d_pet_types (type_name)
SELECT DISTINCT trim(customer_pet_type)
FROM staging.mock_data_raw
WHERE customer_pet_type IS NOT NULL AND trim(customer_pet_type) <> ''
ON CONFLICT (type_name) DO NOTHING;

INSERT INTO snowflake.d_pet_breeds (breed_name)
SELECT DISTINCT trim(customer_pet_breed)
FROM staging.mock_data_raw
WHERE customer_pet_breed IS NOT NULL AND trim(customer_pet_breed) <> ''
ON CONFLICT (breed_name) DO NOTHING;

INSERT INTO snowflake.d_product_categories (category_name)
SELECT DISTINCT trim(product_category)
FROM staging.mock_data_raw
WHERE product_category IS NOT NULL AND trim(product_category) <> ''
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO snowflake.d_brands (brand_name)
SELECT DISTINCT trim(product_brand)
FROM staging.mock_data_raw
WHERE product_brand IS NOT NULL AND trim(product_brand) <> ''
ON CONFLICT (brand_name) DO NOTHING;

INSERT INTO snowflake.d_materials (material_name)
SELECT DISTINCT trim(product_material)
FROM staging.mock_data_raw
WHERE product_material IS NOT NULL AND trim(product_material) <> ''
ON CONFLICT (material_name) DO NOTHING;

INSERT INTO snowflake.d_sizes (size_label)
SELECT DISTINCT trim(product_size)
FROM staging.mock_data_raw
WHERE product_size IS NOT NULL AND trim(product_size) <> ''
ON CONFLICT (size_label) DO NOTHING;

INSERT INTO snowflake.d_colors (color_name)
SELECT DISTINCT trim(product_color)
FROM staging.mock_data_raw
WHERE product_color IS NOT NULL AND trim(product_color) <> ''
ON CONFLICT (color_name) DO NOTHING;

INSERT INTO snowflake.d_product_pet_segments (segment_name)
SELECT DISTINCT trim(pet_category)
FROM staging.mock_data_raw
WHERE pet_category IS NOT NULL AND trim(pet_category) <> ''
ON CONFLICT (segment_name) DO NOTHING;

-- Города: сначала из магазинов (есть штат), затем из поставщиков (штат не задан — '')
INSERT INTO snowflake.d_cities (city_name, state_province, country_id)
SELECT DISTINCT
  NULLIF(trim(m.store_city), ''),
  COALESCE(NULLIF(trim(m.store_state), ''), ''),
  co.country_id
FROM staging.mock_data_raw m
JOIN snowflake.d_countries co ON co.country_name = NULLIF(trim(m.store_country), '')
WHERE NULLIF(trim(m.store_city), '') IS NOT NULL
ON CONFLICT (city_name, state_province, country_id) DO NOTHING;

INSERT INTO snowflake.d_cities (city_name, state_province, country_id)
SELECT DISTINCT
  NULLIF(trim(m.supplier_city), ''),
  '',
  co.country_id
FROM staging.mock_data_raw m
JOIN snowflake.d_countries co ON co.country_name = NULLIF(trim(m.supplier_country), '')
WHERE NULLIF(trim(m.supplier_city), '') IS NOT NULL
ON CONFLICT (city_name, state_province, country_id) DO NOTHING;

-- Клиенты и продавцы (по бизнес-ключам из CSV)
INSERT INTO snowflake.d_customers (
  source_customer_id, first_name, last_name, age, email, postal_code, pet_name,
  country_name, pet_type_id, pet_breed_id
)
SELECT DISTINCT ON (m.sale_customer_id::integer)
  m.sale_customer_id::integer,
  NULLIF(trim(m.customer_first_name), ''),
  NULLIF(trim(m.customer_last_name), ''),
  NULLIF(trim(m.customer_age), '')::integer,
  NULLIF(trim(m.customer_email), ''),
  NULLIF(trim(m.customer_postal_code), ''),
  NULLIF(trim(m.customer_pet_name), ''),
  NULLIF(trim(m.customer_country), ''),
  dpt.pet_type_id,
  dpb.pet_breed_id
FROM staging.mock_data_raw m
LEFT JOIN snowflake.d_pet_types dpt ON dpt.type_name = NULLIF(trim(m.customer_pet_type), '')
LEFT JOIN snowflake.d_pet_breeds dpb ON dpb.breed_name = NULLIF(trim(m.customer_pet_breed), '')
WHERE m.sale_customer_id IS NOT NULL AND trim(m.sale_customer_id) <> ''
ORDER BY m.sale_customer_id::integer, m.row_id;

INSERT INTO snowflake.d_sellers (
  source_seller_id, first_name, last_name, email, postal_code, country_name
)
SELECT DISTINCT ON (m.sale_seller_id::integer)
  m.sale_seller_id::integer,
  NULLIF(trim(m.seller_first_name), ''),
  NULLIF(trim(m.seller_last_name), ''),
  NULLIF(trim(m.seller_email), ''),
  NULLIF(trim(m.seller_postal_code), ''),
  NULLIF(trim(m.seller_country), '')
FROM staging.mock_data_raw m
WHERE m.sale_seller_id IS NOT NULL AND trim(m.sale_seller_id) <> ''
ORDER BY m.sale_seller_id::integer, m.row_id;

-- Товары (измерение «снежинка»: ссылки на подсправочники)
INSERT INTO snowflake.d_products (
  source_product_id, product_name, description, weight_kg, rating, reviews_count,
  release_date, expiry_date,
  category_id, brand_id, material_id, size_id, color_id, pet_segment_id
)
SELECT DISTINCT ON (m.sale_product_id::integer)
  m.sale_product_id::integer,
  COALESCE(NULLIF(trim(m.product_name), ''), 'Unknown product'),
  NULLIF(trim(m.product_description), ''),
  NULLIF(trim(m.product_weight), '')::numeric,
  NULLIF(trim(m.product_rating), '')::numeric,
  NULLIF(trim(m.product_reviews), '')::integer,
  CASE WHEN trim(m.product_release_date) <> '' THEN to_date(trim(m.product_release_date), 'MM/DD/YYYY') END,
  CASE WHEN trim(m.product_expiry_date) <> '' THEN to_date(trim(m.product_expiry_date), 'MM/DD/YYYY') END,
  pc.category_id,
  br.brand_id,
  mat.material_id,
  sz.size_id,
  cl.color_id,
  seg.segment_id
FROM staging.mock_data_raw m
JOIN snowflake.d_product_categories pc
  ON pc.category_name = COALESCE(NULLIF(trim(m.product_category), ''), 'Unknown')
JOIN snowflake.d_brands br
  ON br.brand_name = COALESCE(NULLIF(trim(m.product_brand), ''), 'Unknown')
JOIN snowflake.d_materials mat
  ON mat.material_name = COALESCE(NULLIF(trim(m.product_material), ''), 'Unknown')
JOIN snowflake.d_sizes sz
  ON sz.size_label = COALESCE(NULLIF(trim(m.product_size), ''), 'Unknown')
JOIN snowflake.d_colors cl
  ON cl.color_name = COALESCE(NULLIF(trim(m.product_color), ''), 'Unknown')
JOIN snowflake.d_product_pet_segments seg
  ON seg.segment_name = COALESCE(NULLIF(trim(m.pet_category), ''), 'Unknown')
WHERE m.sale_product_id IS NOT NULL AND trim(m.sale_product_id) <> ''
ORDER BY m.sale_product_id::integer, m.row_id;

-- Магазины (уникальность по стабильному ключу из атрибутов)
INSERT INTO snowflake.d_stores (store_key, store_name, location_line, phone, email, city_id)
SELECT DISTINCT ON (sk.store_key)
  sk.store_key,
  sk.store_name,
  sk.location_line,
  sk.phone,
  sk.email,
  ci.city_id
FROM (
  SELECT
    md5(concat_ws(
      E'\x1e',
      trim(m.store_name),
      trim(m.store_location),
      coalesce(trim(m.store_city), ''),
      coalesce(trim(m.store_state), ''),
      coalesce(trim(m.store_country), ''),
      coalesce(trim(m.store_phone), ''),
      coalesce(trim(m.store_email), '')
    )) AS store_key,
    COALESCE(NULLIF(trim(m.store_name), ''), '(unknown store)') AS store_name,
    NULLIF(trim(m.store_location), '') AS location_line,
    NULLIF(trim(m.store_phone), '') AS phone,
    NULLIF(trim(m.store_email), '') AS email,
    NULLIF(trim(m.store_city), '') AS city_name,
    COALESCE(NULLIF(trim(m.store_state), ''), '') AS state_province,
    NULLIF(trim(m.store_country), '') AS country_name
  FROM staging.mock_data_raw m
) sk
LEFT JOIN snowflake.d_countries co ON co.country_name = sk.country_name
LEFT JOIN snowflake.d_cities ci
  ON ci.country_id = co.country_id
 AND ci.city_name = sk.city_name
 AND ci.state_province = sk.state_province
ORDER BY sk.store_key;

-- Поставщики (география строкой, без связи с d_cities)
INSERT INTO snowflake.d_suppliers (supplier_key, name, contact, email, phone, address_line, city_name, country_name)
SELECT DISTINCT ON (sk.supplier_key)
  sk.supplier_key,
  sk.name,
  sk.contact,
  sk.email,
  sk.phone,
  sk.address_line,
  sk.city_name,
  sk.country_name
FROM (
  SELECT
    md5(concat_ws(
      E'\x1e',
      coalesce(trim(m.supplier_name), ''),
      coalesce(trim(m.supplier_contact), ''),
      coalesce(trim(m.supplier_email), ''),
      coalesce(trim(m.supplier_phone), ''),
      coalesce(trim(m.supplier_address), ''),
      coalesce(trim(m.supplier_city), ''),
      coalesce(trim(m.supplier_country), '')
    )) AS supplier_key,
    COALESCE(NULLIF(trim(m.supplier_name), ''), '(unnamed supplier)') AS name,
    NULLIF(trim(m.supplier_contact), '') AS contact,
    NULLIF(trim(m.supplier_email), '') AS email,
    NULLIF(trim(m.supplier_phone), '') AS phone,
    NULLIF(trim(m.supplier_address), '') AS address_line,
    NULLIF(trim(m.supplier_city), '') AS city_name,
    NULLIF(trim(m.supplier_country), '') AS country_name
  FROM staging.mock_data_raw m
) sk
ORDER BY sk.supplier_key;

-- Календарь по датам продаж
INSERT INTO snowflake.d_date (date_id, full_date, year, quarter, month, day_of_month)
SELECT DISTINCT
  to_char(d, 'YYYYMMDD')::integer,
  d::date,
  extract(year FROM d)::integer,
  extract(quarter FROM d)::integer,
  extract(month FROM d)::integer,
  extract(day FROM d)::integer
FROM (
  SELECT to_date(trim(m.sale_date), 'MM/DD/YYYY') AS d
  FROM staging.mock_data_raw m
  WHERE m.sale_date IS NOT NULL AND trim(m.sale_date) <> ''
) x
WHERE d IS NOT NULL
ON CONFLICT (date_id) DO NOTHING;

-- Факт продаж: одна строка источника = одна строка факта
INSERT INTO snowflake.f_sales (
  date_id, customer_id, seller_id, product_id, store_id, supplier_id,
  quantity, total_price, unit_price, source_row_id
)
SELECT
  dd.date_id,
  c.customer_id,
  sel.seller_id,
  p.product_id,
  st.store_id,
  sup.supplier_id,
  m.sale_quantity::integer,
  m.sale_total_price::numeric,
  NULLIF(trim(m.product_price), '')::numeric,
  m.row_id
FROM staging.mock_data_raw m
JOIN snowflake.d_date dd
  ON dd.full_date = to_date(trim(m.sale_date), 'MM/DD/YYYY')
JOIN snowflake.d_customers c ON c.source_customer_id = m.sale_customer_id::integer
JOIN snowflake.d_sellers sel ON sel.source_seller_id = m.sale_seller_id::integer
JOIN snowflake.d_products p ON p.source_product_id = m.sale_product_id::integer
JOIN snowflake.d_stores st
  ON st.store_key = md5(concat_ws(
    E'\x1e',
    trim(m.store_name),
    trim(m.store_location),
    coalesce(trim(m.store_city), ''),
    coalesce(trim(m.store_state), ''),
    coalesce(trim(m.store_country), ''),
    coalesce(trim(m.store_phone), ''),
    coalesce(trim(m.store_email), '')
  ))
JOIN snowflake.d_suppliers sup
  ON sup.supplier_key = md5(concat_ws(
    E'\x1e',
    coalesce(trim(m.supplier_name), ''),
    coalesce(trim(m.supplier_contact), ''),
    coalesce(trim(m.supplier_email), ''),
    coalesce(trim(m.supplier_phone), ''),
    coalesce(trim(m.supplier_address), ''),
    coalesce(trim(m.supplier_city), ''),
    coalesce(trim(m.supplier_country), '')
  ))
WHERE m.row_id IS NOT NULL;
