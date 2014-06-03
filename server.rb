require 'pry'
require 'sinatra'
require 'pg'
require 'net/http'
require 'uri'
# require 'securerandom'

use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']

######################## USER INPUT VALIDATIONS #############################

def validate_no_blanks
  fields = [ params["title"], params["url"], params["desc"] ]
  !fields.any? {|field| field == "" || field == nil}
end

def validate_comment_not_blank
  true if params["body"] != nil 
end

def validate_desc_length
  params["desc"].length < 20 ? false : true
end

def validate_unique_url(articles)
  articles.each { |article| article["url"] != params["url"] } ? true : false
end

def validate_good_url(url) 
  if url.start_with?("http://") || url.start_with?("https://")
    begin
        address = URI(url)
        response = Net::HTTP.get_response(address)
        true if response.code == "200"
    rescue
        false
    end
  else
    false
  end
end

######################## SIGN UP VALIDATIONS #############################

def username_available?(users, username_desired)
  !users.any? { |user| user["username"] == username_desired }
end

def password_ok?(password_desired)
  password_desired.length > 9
  #Does it include a number and letter?
end

def password_match?(password_desired, confirmation)
  password_desired == confirmation
end

######################## LOGIN VALIDATIONS #############################

def valid_user?
  #Does username exist?
  #Does it match password on file?
end


######################## SQL COMMANDS #############################

def access_database
  begin
    connection = PG.connect(dbname: "slacker_news")
    yield(connection)
  ensure
    connection.close
  end
end

def sql_insert_into_articles
  sql_statement = "INSERT INTO articles (title, url, description, posted_at)
                   VALUES ( $1, $2, $3, $4)"
end

def sql_insert_into_comments
  sql_statement = "INSERT INTO comments (body, posted_at, article_id)
                   VALUES ( $1, $2, $3)"
end

def sql_insert_into_users
  sql_statement = "INSERT INTO users (username, password)
                   VALUES ($1, $2)"
end

def find_articles
  query = "SELECT
           title, url, description, id 
           FROM articles
           WHERE title ILIKE $1 OR description ILIKE $1
           ORDER BY id"
end

def find_all_articles
  query = "SELECT
           title, url, description, id 
           FROM articles
           ORDER BY id"
end

def find_comments
  sql = "SELECT comments.body, comments.posted_at, comments.article_id
         FROM comments
         JOIN articles ON articles.id = comments.article_id
         WHERE articles.id = $1
         ORDER BY comments.posted_at"
end

def find_users
  query = "SELECT users.username, users.password, articles.user_id, comments.user_id 
           FROM users
           JOIN articles ON articles.user_id = users.id
           JOIN comments ON comments.user_id = users.id"
end

######################## ROUTING & CONTROLLER LOGIC #############################

get '/articles' do
  search ||= params[:search]
  @articles = access_database do|conn| 
    conn.exec_params(find_articles, ["%#{search}%"]) 
  end

  erb :index
end


get '/' do
  redirect "/articles"
end

get '/submit' do
  @articles = access_database do |conn| 
    conn.exec(find_all_articles) 
  end

  @title = params["title"]
  @url = params["url"]
  @desc = params["desc"]

  erb :submit
end

post '/submit' do
  @articles = access_database do |conn| 
    conn.exec(find_all_articles) 
  end

  @title = params["title"]
  @url = params["url"]
  @desc = params["desc"]

  if validate_no_blanks && validate_desc_length && validate_unique_url(@articles) && validate_good_url(@url)
    access_database do |conn|
      conn.exec_params(sql_insert_into_articles, [ params["title"], params["url"], params["desc"], Time.now ] )
    end
    redirect '/articles'
  else
    @error_message = ""
      if !validate_no_blanks
        @error_message = "No blank fields please."
      elsif !validate_desc_length
        @error_message = "Please enter a description of 20 or more characters."
      elsif !validate_unique_url(@articles)
        @error_message = "Sorry, that article has already been submitted!"
      elsif !validate_good_url(@url)
        @error_message = "Sorry, we didn't recognize that URL.  Make sure you begin with http:// or https://"
      else
        @error_message = ""
      end
  end
  erb :submit
end

get '/articles/:id/comments' do
  @articles = access_database do |conn| 
    conn.exec(find_all_articles) 
  end

  @article_id = params[:id].to_i

  @comments = access_database do |conn|
    conn.exec_params(find_comments, [@article_id])
  end

  erb :comments
end

post '/articles/:id/comments' do  
  @article_id = params[:id]
  @comment_body = params[:body]

  if validate_comment_not_blank
    access_database do |conn|
      conn.exec_params(sql_insert_into_comments, [@comment_body, Time.now, @article_id])
    end
    redirect "/articles/#{@article_id}/comments"
  else
     @error_message = "Can't submit a blank form."
     erb :comments
  end
end

get '/sign_up' do
  erb :sign_up
end

post '/sign_up' do
  @users = access_database {|conn| conn.exec(find_users) }
  @username = params[:username]
  @password = params[:password]
  @confirmation = params[:confirmation]

  if !username_available?(@users, @username)
    @error_message = "Sorry, that username is already taken!"
    erb :sign_up
  elsif !password_ok?(@password)
    @error_message = "Please enter a password of at least 10 characters, including one letter and one number."
    erb :sign_up
  elsif !password_match?(@password, @confirmation)
    @error_message = "Oops, those passwords don't match."
    erb :sign_up
  else
    access_database do |conn|
      conn.exec_params(sql_insert_into_users, [@username, @password])
    end
    redirect '/articles'
  end
end

get '/login' do
  erb :login
end

post '/login' do
  @users = access_database {|conn| conn.exec(find_users) }
  @username = params[:username]
  @password = params[:password]

  redirect '/articles'
end


