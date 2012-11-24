-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Nov 23 21:38:16 2012
-- 

;
BEGIN TRANSACTION;
--
-- Table: menus
--
CREATE TABLE menus (
  menu_id INTEGER PRIMARY KEY NOT NULL,
  name VARCHAR NOT NULL,
  list VARCHAR NOT NULL
);
CREATE UNIQUE INDEX menus_name ON menus (name);
--
-- Table: users
--
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY NOT NULL,
  name VARCHAR NOT NULL,
  full VARCHAR NOT NULL,
  password VARCHAR NOT NULL,
  is_author BOOL NOT NULL DEFAULT '0',
  is_admin BOOL NOT NULL DEFAULT '0'
);
CREATE UNIQUE INDEX users_name ON users (name);
--
-- Table: pages
--
CREATE TABLE pages (
  page_id INTEGER PRIMARY KEY NOT NULL,
  author_id INT NOT NULL,
  name VARCHAR NOT NULL,
  title VARCHAR NOT NULL,
  html VARCHAR NOT NULL,
  md VARCHAR NOT NULL,
  FOREIGN KEY (author_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX pages_idx_author_id ON pages (author_id);
CREATE UNIQUE INDEX pages_name ON pages (name);
COMMIT