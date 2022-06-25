defmodule PermServer.Router do
  use Plug.Router
  use Plug.Debugger

  plug(:match)
  plug(:dispatch)

  post "/init" do
    IO.inspect conn.query_params
    IO.inspect conn.body_params
    t = Permissions.create_tree(Map.get(conn.body_params,"org_name"))
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: "Created new organization named " <> t.name}))
  end

  post "/add" do
    org_name = Map.get(conn.body_params, "org_name")
    name = Map.get(conn.body_params, "name")
    additions = Map.get(conn.body_params, "additions")
    subtractions = Map.get(conn.body_params, "subtractions")
    t = Permissions.load_tree(org_name)
    Permissions.add_new_node(t, name, additions, subtractions)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: "Created new node in " <> org_name <> " named " <> name}))
  end

  post "/edit" do
    org_name = Map.get(conn.body_params, "org_name")
    from = Map.get(conn.body_params, "from")
    to = Map.get(conn.body_params, "to")
    is_addition = Map.get(conn.body_params, "is_addition")
    is_create = Map.get(conn.body_params, "is_create")
    t = Permissions.load_tree(org_name)
    Permissions.edit_connections(t, from, to, is_addition, is_create)
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
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{message: action <> " " <> type <>" from " <> from <> " to " <> to <> " in " <> org_name}))
  end

  get "/view" do
    org_name = Map.get(conn.query_params, "org_name")
    name = Map.get(conn.query_params, "name")
    t = Permissions.load_tree(org_name)
    results = Permissions.get_leaves(t, name)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{results: results}))
  end

  get "/contains" do
    org_name = Map.get(conn.query_params, "org_name")
    perm = Map.get(conn.query_params, "perm")
    role = Map.get(conn.query_params, "role")
    t = Permissions.load_tree(org_name)
    contains = Permissions.contains(t, role, perm)
    Permissions.dump_tree(t)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{contains: contains}))
  end


end
