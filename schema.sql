CREATE TABLE articles (
  id serial PRIMARY KEY,
  title varchar(200) NOT NULL,
  url varchar(1000) NOT NULL,
  description varchar(2500) NOT NULL,
  posted_at timestamp NOT NULL,
  user_id integer NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE comments (
  id serial PRIMARY KEY,
  body varchar(2500) NOT NULL,
  posted_at timestamp NOT NULL,
  article_id integer NOT NULL,
  user_id integer NOT NULL,
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE users (
  id serial PRIMARY KEY,
  username varchar(30) NOT NULL,
  password varchar(30) NOT NULL
);

