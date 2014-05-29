require 'pry'
require 'sinatra'
require 'pg'

def save_article(article)




end

def query_database
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
  @articles = query_database{ |conn| conn.exec(find_articles) }


  erb :'index.html'
end


get '/' do
  redirect "/articles"
end

get '/articles/:id' do
  erb :'show.html'
end

get '/articles/new' do
  erb :'new.html'
end

post '/articles/new' do
  save_article(params)
  redirect '/articles/new'
end

# get '/articles/:id/comments' do
#   erb :'comments.html'
# end

# post '/articles/:id/comments' do

# end
