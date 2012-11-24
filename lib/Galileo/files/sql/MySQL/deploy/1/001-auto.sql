-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Nov 23 21:38:16 2012
-- 
;
SET foreign_key_checks=0;
--
-- Table: `menus`
--
CREATE TABLE `menus` (
  `menu_id` integer NOT NULL auto_increment,
  `name` VARCHAR NOT NULL,
  `list` VARCHAR NOT NULL,
  PRIMARY KEY (`menu_id`),
  UNIQUE `menus_name` (`name`)
);
--
-- Table: `users`
--
CREATE TABLE `users` (
  `user_id` integer NOT NULL auto_increment,
  `name` VARCHAR NOT NULL,
  `full` VARCHAR NOT NULL,
  `password` VARCHAR NOT NULL,
  `is_author` BOOL NOT NULL DEFAULT '0',
  `is_admin` BOOL NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`),
  UNIQUE `users_name` (`name`)
) ENGINE=InnoDB;
--
-- Table: `pages`
--
CREATE TABLE `pages` (
  `page_id` integer NOT NULL auto_increment,
  `author_id` integer NOT NULL,
  `name` VARCHAR NOT NULL,
  `title` VARCHAR NOT NULL,
  `html` VARCHAR NOT NULL,
  `md` VARCHAR NOT NULL,
  INDEX `pages_idx_author_id` (`author_id`),
  PRIMARY KEY (`page_id`),
  UNIQUE `pages_name` (`name`),
  CONSTRAINT `pages_fk_author_id` FOREIGN KEY (`author_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
SET foreign_key_checks=1