defprotocol DSearch.Store do
  @moduledoc false

  # We define a store protocol which can be then used to test

  alias DSearch.Btree

  @spec get_node(t, Btree.location()) :: Btree.btree_node() | {:error, String.t()}
  def get_node(store, location)

  @spec put_node(t, Btree.btree_node()) :: Btree.location()
  def put_node(store, node)

  @spec put_header(t, Btree.tree_header()) :: Btree.location()
  def put_header(store, header)

  @spec get_last_header(t) :: {Btree.location(), Btree.tree_header()} | nil
  def get_last_header(store)

  @spec sync(t) :: :ok | {:error, String.t()}
  def sync(store)

  @spec close(t) :: :ok | {:error, String.t()}
  def close(store)

  @spec empty?(t) :: boolean
  def empty?(store)

  @spec open?(t) :: boolean
  def open?(store)
end
