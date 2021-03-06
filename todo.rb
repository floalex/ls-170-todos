require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret' #don't specify value 
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}

    incomplete_lists.each(&block)
    complete_lists.each(&block)
    # older solution:
    # incomplete_lists = {}
    # complete_lists = {}

    # lists.each_with_index do |list, index|
    #   if list_complete?(list)
    #     complete_lists[list] = index
    #   else
    #     incomplete_lists[list] = index
    #   end
    # end

    # incomplete_lists.each(&block)
    # complete_lists.each(&block) #{ |list, id| yield list, id }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def load_list(id)
    list = session[:lists].find { |list| list[:id] == id }
    return list if list 

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

  def next_element_id(elements)
    max = elements.map { |todo| todo[:id] }.max || 0
    max + 1
  end

  # Return an error message if the name is invalid. Return nil if name is valid.
  def error_for_list_name(name)
    if !(1..100).cover? name.size
      "List name must be between 1 and 100 characters."
    elsif session[:lists].any? {|list| list[:name] == name}
      "List name must be unique."
    end
  end

  # Return an error message if the name is invalid. Return nil if name is valid.
  def error_for_todo(name)
    if !(1..100).cover? name.size
      "Todo name must be between 1 and 100 characters."
    end
  end
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

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
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
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  # first thing is to find the list
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false}
    
    session[:success] = "The todo item has been added."
    redirect "/lists/#{@list_id}"
  end
end 

# Delete a todo frmo a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do # we use id here since we use nested objects
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"  
end