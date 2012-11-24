-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Fri Nov 23 21:38:16 2012
-- 
;
--
-- Table: menus.
--
CREATE TABLE "menus" (
  "menu_id" serial NOT NULL,
  "name" character varying NOT NULL,
  "list" character varying NOT NULL,
  PRIMARY KEY ("menu_id"),
  CONSTRAINT "menus_name" UNIQUE ("name")
);

;
--
-- Table: users.
--
CREATE TABLE "users" (
  "user_id" serial NOT NULL,
  "name" character varying NOT NULL,
  "full" character varying NOT NULL,
  "password" character varying NOT NULL,
  "is_author" bool DEFAULT '0' NOT NULL,
  "is_admin" bool DEFAULT '0' NOT NULL,
  PRIMARY KEY ("user_id"),
  CONSTRAINT "users_name" UNIQUE ("name")
);

;
--
-- Table: pages.
--
CREATE TABLE "pages" (
  "page_id" serial NOT NULL,
  "author_id" integer NOT NULL,
  "name" character varying NOT NULL,
  "title" character varying NOT NULL,
  "html" character varying NOT NULL,
  "md" character varying NOT NULL,
  PRIMARY KEY ("page_id"),
  CONSTRAINT "pages_name" UNIQUE ("name")
);
CREATE INDEX "pages_idx_author_id" on "pages" ("author_id");

;
--
-- Foreign Key Definitions
--

;
ALTER TABLE "pages" ADD CONSTRAINT "pages_fk_author_id" FOREIGN KEY ("author_id")
  REFERENCES "users" ("user_id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

