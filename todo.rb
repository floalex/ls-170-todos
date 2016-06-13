require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret' #don't specify value 
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# GET  /lists         -> view all lists
# GET  /new_list      -> new list form
# POST /lists         -> create new list
# GET  /lists/1       -> view a single list


# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
  # # if list_name.size >= 1 && list_name.size <= 100
  # if !(1..100).cover? list_name.size #use cover to ensure value is within the range
  #   session[:error] = "List name must be between 1 and 100 characters."
  #   erb :new_list, layout: :layout
  # elsif session[:lists].any? { |list| list[:name] == list_name }
  #   session[:error] = "List name must be unique."
  #   erb :new_list, layout: :layout
  # else
  #   session[:lists] << {name: list_name, todos: []}
  #   session[:success] = "The list has been created"
  #   redirect "/lists"    
  # end
end

# Display a single todo list
get "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :list, layout: :layout
end
