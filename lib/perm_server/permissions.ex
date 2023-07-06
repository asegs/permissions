defmodule Permissions do

  defmodule Permission do
    @derive [Poison.Encoder]
    defstruct [:name, :additions, :subtractions, :parents]
  end

  defmodule Tree do
    defstruct [:name, :permissions, :cache]
  end

  defp create_table() do
    :ets.new(:buckets_registry, [:set, :protected])
  end

  def create_tree(name) do
    %Tree{name: name, permissions: create_table(), cache: create_table()}
  end

  def additive, do: true
  def subtractive, do: false
  def connect, do: true
  def disconnect, do: false

  defp lookup_val(%Tree{permissions: permissions}, key) do
    [{_,r}] = :ets.lookup(permissions, key)
    r
  end

  defp save_perm(%Tree{permissions: permissions}, perm) do
    :ets.insert(permissions, {perm.name, perm})
  end

  defp update_parent(t = %Tree{}, key, name) do
    perm = lookup_val(t, key)
    save_perm(t, %{perm | parents: MapSet.put(perm.parents, name)})
  end

  def add_new_node(t = %Tree{permissions: permissions}, name, additions, subtractions) do
    perm = create_permission(name, additions, subtractions)
    :ets.insert(permissions, {name, perm})
    for child <- Enum.to_list(MapSet.union(perm.additions, perm.subtractions)), do: update_parent(t, child, name)
  end

  defp modify_map(permissions, val, add) do
    if add do
      MapSet.put(permissions, val)
    else
      MapSet.delete(permissions, val)
    end
  end

  def edit_connections(t = %Tree{}, from, to, is_addition, is_create) do
    if connection_exists(t, from, to) and is_create do
      false
    else
      from_perm = lookup_val(t, from)
      to_perm = lookup_val(t, to)
      save_perm(t, %{from_perm | parents: modify_map(from_perm.parents, to, is_create)})
      updated_parent = if is_addition do
        %{to_perm | additions: modify_map(to_perm.additions, from, is_create)}
      else
        %{to_perm | subtractions: modify_map(to_perm.subtractions, from, is_create)}
      end
      save_perm(t, updated_parent)
      invalidate_caches(t, to)
    end
  end

  def edit_connections_old(t = %Tree{}, from, to, is_addition, is_create) do
    if connection_exists(t,from,to) do
      from_perm = lookup_val(t, from)
      to_perm = lookup_val(t, to)
      save_perm(t, %{from_perm | parents: modify_map(from_perm.parents, to, is_create)})
      updated_parent = if is_addition do
        %{to_perm | additions: modify_map(to_perm.additions, from, is_create)}
      else
        %{to_perm | subtractions: modify_map(to_perm.subtractions, from, is_create)}
      end
      save_perm(t, updated_parent)
      invalidate_caches(t, to)
    end
  end

  def contains(t = %Tree{}, key, perm) do
    MapSet.member?(get_leaves(t, key), perm)
  end

  defp create_permission(name, additions, subtractions) do
    create_permission(name, additions, subtractions, [])
  end

  defp create_permission(name, additions, subtractions, parents) do
    %Permission{name: name, additions: MapSet.new(additions), subtractions: MapSet.new(subtractions), parents: MapSet.new(parents)}
  end

  defp compose(t, [head|tail]) do
    MapSet.union(get_leaves(t, head), compose(t, tail))
  end

  defp compose(_, []) do
    MapSet.new()
  end

  defp invalidate_caches(t = %Tree{cache: cache}, name) do
    perm = lookup_val(t, name)
    :ets.delete(cache, name)
    for parent <- Enum.to_list(perm.parents), do: invalidate_caches(t, parent)
  end

  defp handle_cache(t = %Tree{cache: cache}, name, []) do
    perm = lookup_val(t, name)
    result_set = if Enum.count(perm.additions) > 0 || Enum.count(perm.subtractions) > 0 do
      additions = compose(t, Enum.to_list(perm.additions))
      subtractions = compose(t, Enum.to_list(perm.subtractions))
      MapSet.union(MapSet.new([name]),MapSet.difference(additions,subtractions))
    else
      MapSet.new([name])
    end
    :ets.insert(cache, {name, result_set})
    result_set
  end

  defp handle_cache(_, _, [{_,result_set}]) do
    result_set
  end

  def get_leaves(t = %Tree{cache: cache}, name) do
    cached = :ets.lookup(cache, name)
    handle_cache(t, name, cached)
  end

  #Should delete recursively through parents and children.
  def delete_node(t = %Tree{permissions: permissions, cache: cache}, name) do
    invalidate_caches(t, name)
    :ets.delete(permissions, name)
    :ets.delete(cache, name)
  end


  def dump_tree(%Tree{name: name, permissions: permissions, cache: cache}) do
    perm_list = Enum.map(:ets.tab2list(permissions), fn {k,v} -> [k,v] end)
    cache_list = Enum.map(:ets.tab2list(cache), fn {k,v} -> [k,v] end)
    json_perms = Poison.encode!(perm_list)
    json_cache = Poison.encode!(cache_list)
    perm_path = "lib/records/permissions/" <> name <> ".json"
    cache_path = "lib/records/caches/" <> name <> ".json"
    File.mkdir_p!(Path.dirname(perm_path))
    File.mkdir_p!(Path.dirname(cache_path))
    File.write(perm_path, json_perms)
    File.write(cache_path, json_cache)
  end

  def load_tree(name) do
    perm_path = "lib/records/permissions/" <> name <> ".json"
    cache_path = "lib/records/caches/" <> name <> ".json"
    {:ok, perm_file} = File.open(perm_path)
    {:ok, cache_file} = File.open(cache_path)
    perm_list = Poison.decode!(IO.read(perm_file, :all))
    cache_list = Poison.decode!(IO.read(cache_file, :all))
    File.close(perm_file)
    File.close(cache_file)
    permissions = create_table()
    cache = create_table()
    f_perm_list = Enum.map(perm_list, fn [key, %{"additions" => additions, "subtractions" => subtractions, "parents" => parents}] -> create_permission(key, additions, subtractions, parents) end)
    for perm <- f_perm_list, do: :ets.insert(permissions, {perm.name, perm})
    for [key, list] <- cache_list, do: :ets.insert(cache, {key, MapSet.new(list)})
    %Tree{name: name, permissions: permissions, cache: cache}
  end

  def dfs_recurse(graph,vertex_name,target,path) do
    if Enum.member?(path,vertex_name) do
      false
    else
      dfs(graph,vertex_name,target,path)
    end
  end

  def dfs(t = %Tree{},from, to, path) do
    if from == to do
      true
    else
      included_path = [from | path]
      vertex = lookup_val(t, from)
      children = MapSet.union(vertex.additions, vertex.subtractions)
      Enum.any?(children, fn child -> dfs_recurse(t,child,to,included_path) end)
    end
  end

  #This is backwards!
  def connection_exists(t=%Tree{},from,to) do
    dfs(t,from,to,[])
  end

end