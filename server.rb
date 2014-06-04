require 'sinatra'
require 'pg'
require 'net/http'
require 'uri'

use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']

######################## USER INPUT VALIDATIONS #############################

def validate_no_blanks
  fields = [ params["title"], params["url"], params["desc"] ]
  !fields.any? {|field| field == "" || field == nil}
end

def validate_comment_not_blank
  params["body"] != nil 
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
        response.code == "200"
    rescue
        false
    end
  else
    false
  end
end

######################## SIGN UP VALIDATIONS #############################

def username_available?(users, username_desired)
  users.none? { |user| user["username"] == username_desired }
end

def password_ok?(password_desired)
  if password_desired.length > 9
    password_desired.split("").any? {|char| char.match(/\d/)} 
  else
    false
  end
end

def password_match?(password_desired, confirmation)
  password_desired == confirmation
end

######################## LOGIN VALIDATIONS #############################

def valid_password?(users, username, password)
  users.each do |user| 
    if user["username"] == username
      user["password"] == password 
    end
  end
end

def logged_in?
  session[:user_id] != nil
end


######################## SQL QUERIES #############################

def access_database
  begin
    connection = PG.connect(dbname: "slacker_news")
    yield(connection)
  ensure
    connection.close
  end
end

def search_articles
  query = "SELECT
           articles.title, articles.url, articles.description, 
           articles.id, users.username  
           FROM articles
           JOIN users ON articles.user_id = users.id
           WHERE title ILIKE $1 OR description ILIKE $1
           ORDER BY articles.id"
end

def find_all_articles
  query = "SELECT
           title, url, description, id
           FROM articles
           ORDER BY id"
end

def find_comments
  query = "SELECT comments.body, comments.posted_at, 
           comments.article_id, users.username
           FROM comments
           JOIN users ON users.id = comments.user_id
           JOIN articles ON articles.id = comments.article_id
           WHERE articles.id = $1
           ORDER BY comments.posted_at"
end

def find_all_users
  query = "SELECT users.username, users.password, users.id 
           FROM users"
end

######################## SQL INSERT STATEMENTS #############################

def sql_insert_into_articles
  query = "INSERT INTO articles (title, url, description, posted_at, user_id)
           VALUES ($1, $2, $3, $4, $5)"
end

def sql_insert_into_comments
  query = "INSERT INTO comments (body, posted_at, article_id, user_id)
           VALUES ($1, $2, $3, $4)"
end

def sql_insert_into_users
  query = "INSERT INTO users (username, password)
           VALUES ($1, $2)"
end

######################## INDEX PAGE (ALL ARTICLES) ROUTES #############################

get '/articles' do
  search ||= params[:search]
  @articles = access_database do|conn| 
    conn.exec_params(search_articles, ["%#{search}%"]) 
  end
  erb :index
end


get '/' do
  redirect "/articles"
end

get '/submit' do
  redirect '/login' if !logged_in?
  
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

  if !validate_no_blanks
    @error_message = "No blank fields please."
    erb :submit
  elsif !validate_desc_length
    @error_message = "Please enter a description of 20 or more characters."
    erb :submit
  elsif !validate_unique_url(@articles)
    @error_message = "Sorry, that article has already been submitted!"
    erb :submit
  elsif !validate_good_url(@url)
    @error_message = "Sorry, we didn't recognize that URL.  Make sure you begin with http:// or https://"
    erb :submit
  else
    access_database do |conn|
      conn.exec_params(sql_insert_into_articles, [ params["title"], params["url"], params["desc"], Time.now, session[:user_id] ])
    end
    redirect '/articles'
  end
 
end

######################## COMMENTS ROUTES #############################

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
  @articles = access_database do |conn| 
    conn.exec(find_all_articles) 
  end
  @comments = access_database do |conn|
    conn.exec_params(find_comments, [@article_id])
  end

  if !logged_in?
    @error_message = "Please log in to post comments."
    erb :comments
  elsif !validate_comment_not_blank
    @error_message = "Can't submit a blank form."
    erb :comments
  else
    access_database do |conn|
      conn.exec_params(sql_insert_into_comments, [@comment_body, Time.now, @article_id, session[:user_id] ])
    end
    redirect "/articles/#{@article_id}/comments"
  end
end

######################## SIGN UP & LOG IN ROUTES #############################

get '/sign_up' do
  erb :sign_up
end

post '/sign_up' do
  @users = access_database {|conn| conn.exec(find_all_users) }
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
  @users = access_database {|conn| conn.exec(find_all_users) }
  @username = params[:username]
  @password = params[:password]

  if username_available?(@users, @username)
    @error_message = "That username is not registered."
    erb :login
  elsif !valid_password?(@users, @username, @password)
    @error_message = "Password and username don't match."
    erb :login
  else
    @users.each do |user|
      if user["username"] == @username
        session[:user_id] = user["id"].to_i 
      end
    end
    redirect '/articles'
  end
end


