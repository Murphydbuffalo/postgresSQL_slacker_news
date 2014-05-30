require 'pry'
require 'sinatra'
require 'pg'

def access_database
  begin
    connection = PG.connect(dbname: "slacker_news")
    yield(connection)
  ensure
    connection.close
  end
end

def sql_insert_into_article
  sql_statement = "INSERT INTO articles (title, url, description, posted_at)
                   VALUES ( $1, $2, $3, $4)"
end

def sql_insert_into_comments
  sql_statement = "INSERT INTO comments (body, posted_at, article_id)
                   VALUES ( $1, $2, $3)"
end

def find_articles#(user_search)
  # search ||= user_search
  query = "SELECT
           title, url, description, id 
           FROM articles
           ORDER BY id"
           # WHERE articles.title = #{search}
end

def find_comments
  sql = "SELECT comments.body, comments.posted_at, comments.article_id
         FROM comments
         JOIN articles ON articles.id = comments.article_id
         WHERE articles.id = $1
         ORDER BY comments.posted_at"
end

get '/articles' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  erb :'index.html'
end


get '/' do
  redirect "/articles"
end

get '/submit' do
  erb :'submit.html'
end

post '/submit' do
  params["user_id"] ||= 1
  access_database do |conn|
    conn.exec_params(sql_insert_into_article, [ params["title"], params["url"], params["desc"], Time.now ] )
  end
  redirect '/articles'
end

get '/articles/:id/comments' do
  @article_id = params[:id].to_i
  @comments = access_database do |conn|
    conn.exec_params(find_comments, [@article_id])
  end
  erb :'comments.html'
end

post '/articles/:id/comments' do
  @article_id = params[:id]
  @comment_body = params[:body]
  access_database do |conn|
    conn.exec_params(sql_insert_into_comments, [@comment_body, Time.now, @article_id])
  end
  redirect '/articles/:id/comments'
end
