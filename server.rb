require 'pry'
require 'sinatra'
require 'pg'

def generate_sql
  sql_statement = "INSERT INTO articles (title, url, description, user_id)
                   VALUES ( $1, $2,
                   $3, $4)"
end

def access_database
  begin
    connection = PG.connect(dbname: "slacker_news")
    yield(connection)
  ensure
    connection.close
  end
end

def find_articles#(user_search)
  # search ||= user_search
  query = "SELECT
           articles.title, articles.url, articles.description, users.name AS user
           FROM articles
           JOIN users ON users.id = articles.user_id"
           # WHERE articles.title = #{search}
end


get '/articles' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  erb :'index.html'
end


get '/' do
  redirect "/articles"
end

get '/articles/:id' do
  erb :'show.html'
end

get '/submit' do
  erb :'submit.html'
end

post '/submit' do
  params["user_id"] ||= 1
  access_database do |conn|
    conn.exec_params(generate_sql, [ params["title"], params["url"], params["desc"], params["user_id"] ] )
  end
  redirect '/articles'
end

# get '/articles/:id/comments' do
#   erb :'comments.html'
# end

# post '/articles/:id/comments' do

# end
