defmodule PermServer.Router do
  use Plug.Router
  use Plug.Debugger

  plug(:match)
  plug(:dispatch)

  post "/init" do
    %{"org_name"=>org_name} = conn.body_params
    t = Permissions.create_tree(org_name)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: "Created new organization named " <> t.name}))
  end

  post "/add" do
    %{"org_name"=>org_name,"name"=>name,"additions"=>additions,"subtractions"=>subtractions} = conn.body_params
    t = Permissions.load_tree(org_name)
    Permissions.add_new_node(t, name, additions, subtractions)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: "Created new node in " <> org_name <> " named " <> name}))
  end

  post "/delete" do
    %{"org_name"=>org_name,"name"=>name} = conn.body_params
    t = Permissions.load_tree(org_name)
    Permissions.delete_node(t, name)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: "Delete node in " <> org_name <> " named " <> name}))
  end

  post "/edit" do
    %{"org_name"=>org_name,"from"=>from,"to"=>to,"is_addition"=>is_addition,"is_create"=>is_create} = conn.body_params
    t = Permissions.load_tree(org_name)
    success = Permissions.edit_connections(t, from, to, is_addition, is_create)
    Permissions.dump_tree(t)
    type = if is_addition do
      "addition"
    else
      "subtraction"
    end

    action = if is_create do
      "Created"
    else
      "Removed"
    end
    if success do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Poison.encode!(%{message: action <> " " <> type <>" from " <> from <> " to " <> to <> " in " <> org_name}))
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Poison.encode!(%{message: "Failed to connect " <> type <>" from " <> from <> " to " <> to <> " in " <> org_name <> " due to a cycle."}))
    end
  end

  get "/view" do
    %{"org_name"=>org_name,"name"=>name} = conn.body_params
    t = Permissions.load_tree(org_name)
    results = Permissions.get_leaves(t, name)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{results: results}))
  end

  get "/contains" do
    %{"org_name"=>org_name,"perm"=>perm,"role"=>role} = conn.body_params
    t = Permissions.load_tree(org_name)
    contains = Permissions.contains(t, role, perm)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{contains: contains}))
  end

  get "/load" do
    %{"org_name"=>org_name} = conn.body_params
    t = Permissions.load_tree(org_name)
    perm_list = Enum.map(:ets.tab2list(t.permissions), fn {_,v} -> v end)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!%{permissions: perm_list})
  end
end
