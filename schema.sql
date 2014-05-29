CREATE TABLE articles (
  id serial PRIMARY KEY,
  title varchar(200) NOT NULL,
  url varchar(1000) NOT NULL,
  description varchar(2500) NOT NULL,
  comments_id integer,
  user_id integer NOT NULL,
  FOREIGN KEY (comments_id) REFERENCES comments(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE comments (
  id serial PRIMARY KEY,
  body varchar(2500) NOT NULL,
  user_id integer,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE users (
  id serial PRIMARY KEY,
  name varchar(100) NOT NULL,
  post_count integer
);
