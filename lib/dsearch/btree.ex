defmodule DSearch.BTree do
  @moduledoc false
  # BTree is implementing an append-only, copy-on-write B+Tree.

  @leaf :leaf_node
  @branch :branch_node
  @value :value_node
  @deleted :tombstone_node

  def __leaf__, do: @leaf
  def __branch__, do: @branch
  def __value__, do: @value
  def __deleted__, do: @deleted

  require Record
  Record.defrecord(:leaf_node, children: [])
  Record.defrecord(:branch_node, children: [])
  Record.defrecord(:value_node, value: nil)

  @type key :: DSearch.key()
  @type value :: DSearch.value()
  @type size :: non_neg_integer()
  @type location :: non_neg_integer()
  @type capacity :: pos_integer()
  @type child_pointer :: {key, location}
  @type leaf_node :: record(:leaf_node, children: [child_pointer])
  @type branch_node :: record(:branch_node, children: [child_pointer])
  @type value_node :: record(:value_node, value: value)
  @type tombstone_node :: :tombstone_node
  @type structural_node :: leaf_node | branch_node
  @type terminal_node :: value_node | tombstone_node
  @type tree_node :: structural_node | terminal_node
  @type tree_header :: {size, location}
  @type node_type :: :leaf_node | :branch_node | :value_node | :tombstone_node

  @type t :: %__MODULE__{
    root: branch_node | leaf_node,
    root_location: location,
    size: size,
    store: Store.t(),
    capacity: non_neg_integer
  }

  @default_capacity 64
  @enforce_keys [:root, :root_location, :size, :store, :capacity]
  defstruct root: nil, root_location: nil, size: 0, store: nil, capacity: @default_capacity

  alias DSearch.Store
  alias DSearch.BTree

  # Public API functions

  @spec new(Store.t(), pos_integer) :: BTree.t()

  def new(store, cap \\ @default_capacity) do
    case Store.get_last_header(store) do
      {_, {s, loc}} ->
        root = Store.get_node(store, loc)
        %BTree{root: root, root_location: loc, size: s, capacity: cap, store: store}

      nil ->
        root = leaf_node()
        loc = Store.put_node(store, root)
        Store.put_header(store, {0, loc, 0})
        %BTree{root: root, root_location: loc, size: 0, capacity: cap, store: store}
    end
  end

  @spec load(Enumerable.t(), Store.t(), pos_integer) :: BTree.t()

  def load(enum, store, cap \\ @default_capacity) do
     unless Store.empty?(store), do: raise(ArgumentError, "cannot load into non-empty store")

      case Enum.reduce(enum, {[], 0}, fn {k, v}, {st, count} -> {load_node(store, k, value_node(value: v), st, 1, cap), count + 1} end) do
        {_ , 0} -> new(store, cap)
        {st, count} ->
           {root, root_location} = finalize_load(store, st, 1, cap)
           Store.put_header(store, {count, root_location, 0})
          %BTree{root: root, root_location: root_location, capacity: cap, store: store, size: count}
      end
  end


  # `fetch/2` retrieves the value for a given `key`
  # Returns:
  #   `{:ok, value}` on success
  #   `:error` otherwise
  def fetch(%BTree{root: root, store: store}, key) do

  end


  # Private functions

  @spec load_node(Store.t(), key, tree_node, [tree_node], pos_integer, capacity) :: [[child_pointer]]

  defp load_node(store, key, node, [], _, _) do
    [[{key, Store.put_node(store, node)}]]
  end

  defp load_node(store, key, node, [children | rest], level, cap) do
    children = [{key, Store.put_node(store, node)} | children]
    case length(children) do
      ^cap ->
        parent = make_node(store, node)
        parent_key = List.last(keys(children))
        [[] | load_node(store, parent_key, parent, rest, level + 1, cap)]
       _ ->
        [children | rest]
     end
  end

  @spec make_node([child_pointer], pos_integer) :: structural_node

  defp make_node(children, level) do
    children = Enum.reverse(children)

    case level do
      1 -> leaf_node(children: children)
      _ -> branch_node(children: children)
    end
  end


  # `leaf_for_key/4` finds the leaf node for a given
  #
  #
  defp leaf_for_key(branch = {@branch, children}, store, key, path) do

  end

  defp leaf_for_key(leaf = {@leaf, _}, _, _, path) do
    {leaf, path}
  end

  @spec finalize_load(Store.t(), [[child_pointer]], pos_integer, capacity) :: {tree_node, location}

  defp finalize_load(store, [children], level, _) do
    case children do
      [{_, loc}] when level > 1 ->
        {Store.get_node(store, loc), loc}
      _ ->
        node = make_node(children, level)
        {node, Store.put_node(store, node)}
    end
  end

  defp finalize_load(store, [children | rest], level, cap) do
    case children do
      [] ->
        finalize_load(store, rest, level + 1, cap)
      _ ->
        node = make_node(children, level)
        key = List.last(keys(children))
        stack = load_node(store, key, node, rest, level + 1, cap)
        finalize_load(store, stack, level + 1, cap)
    end
  end


  defp keys(tuples) do
    Enum.map(tuples, &elem(&1, 0))
  end

end

defimpl Enumerable, for: DSearch.BTree do
  # Enumberable implementation allows iterating and yielding entries sorted by keys

  alias DSearch.BTree
  alias DSearch.Store

  def reduce(btree, cmd_acc, fun) do
    BTree.DFS.reduce(btree, cmd_acc, fun, &get_children/2)
  end

  def count(%BTree{size: size}), do: {:ok, size}

  def slice(_), do: {:error, __MODULE__}

  # Private functions

  @spec get_children(BTree.tree_node(), Store.t()) :: any

  defp get_children({:value_node, v}, _), do: v

  defp get_children({_, locations}, store) do
    locations
    |> Enum.map(fn {k, loc} -> {k, Store.get_node(store, loc)} end)
    |> Enum.filter(fn {_, node} -> node != :tombstone_node end)
  end
end
