require 'pry'
require 'sinatra'
require 'pg'
require 'net/http'
require 'uri'

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
  begin
      address = URI(url)
      response = Net::HTTP.get_response(url)
      true if response.code == "200"
  rescue
      url.start_with?("http://") || url.start_with?("https://")
  end
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

def sql_insert_into_article
  sql_statement = "INSERT INTO articles (title, url, description, posted_at)
                   VALUES ( $1, $2, $3, $4)"
end

def sql_insert_into_comments
  sql_statement = "INSERT INTO comments (body, posted_at, article_id)
                   VALUES ( $1, $2, $3)"
end

def find_articles
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

######################## ROUTING & CONTROLLER LOGIC #############################

get '/articles' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  erb :'index.html'
end


get '/' do
  redirect "/articles"
end

get '/submit' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  @title = params["title"]
  @url = params["url"]
  @desc = params["desc"]

  erb :'submit.html'
end

post '/submit' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  @title = params["title"]
  @url = params["url"]
  @desc = params["desc"]

  if validate_no_blanks && validate_desc_length && validate_unique_url(@articles) && validate_good_url(@url)
    access_database do |conn|
      conn.exec_params(sql_insert_into_article, [ params["title"], params["url"], params["desc"], Time.now ] )
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
  erb :'submit.html'
end

get '/articles/:id/comments' do
  @articles = access_database{ |conn| conn.exec(find_articles) }
  @article_id = params[:id].to_i
  @comments = access_database do |conn|
    conn.exec_params(find_comments, [@article_id])
  end
  erb :'comments.html'
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
     erb :'comments.html'
  end
end
