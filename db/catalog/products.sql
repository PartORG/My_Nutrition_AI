-- products.db, catalogue v4 (docs/PLAN.md "Catalogue v4", decisions 4, 7, 12): every branded food — packaged
-- products (Open Food Facts, USDA FDC Branded, other branded tables) and chain menu items. Downloaded once, kept on
-- the phone, read-only. Built by tool/catalog. Search shows these after generic foods; recipes never use them.
--
-- Rules as in nutri.sql: per 100 g, NULL = unknown, the NUTRIENTS marker from db/catalog/nutrients.tsv.

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,   -- schema_version (4), built_at, rows
  value TEXT NOT NULL
);

CREATE TABLE sources (
  id      TEXT PRIMARY KEY,   -- 'off', 'usda_fdc_branded', 'menu_chains', ...
  name    TEXT NOT NULL,
  licence TEXT NOT NULL,
  url     TEXT
);

CREATE TABLE products (
  id          INTEGER PRIMARY KEY,
  barcode     TEXT,                 -- EAN/UPC; NULL for menu items
  name        TEXT NOT NULL,
  brand       TEXT,                 -- the maker or chain: "Lindt", "McDonald's"
  kind        TEXT NOT NULL DEFAULT 'packaged' CHECK (kind IN ('packaged', 'menu')),
  source_id   TEXT NOT NULL REFERENCES sources (id),
  serving_g   REAL,
  serving     TEXT,
  /*NUTRIENTS*/
);
-- One row per barcode: the most complete label wins when sources overlap.
CREATE UNIQUE INDEX products_barcode ON products (barcode) WHERE barcode IS NOT NULL;

CREATE TABLE product_allergens (
  product_id INTEGER NOT NULL REFERENCES products (id),
  allergen   TEXT NOT NULL,
  PRIMARY KEY (product_id, allergen)
) WITHOUT ROWID;

CREATE VIRTUAL TABLE products_fts USING fts5 (name, brand, content = 'products', content_rowid = 'id');
