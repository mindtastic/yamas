defmodule DSearch.Store.MockStoreTest do
  use ExUnit.Case, async: true
  use DSearch.SharedStoreTests

  alias DSearch.Store.MockStore

  setup do
    {:ok, store} = MockStore.create()
    {:ok, store: store}
  end

  test "start_link/0 start a MockStore" do
    {:ok, store} = MockStore.create()
    assert %MockStore{pid: pid} = store
    assert Process.alive?(pid)
  end

  test "close/1 stops the agent", %{store: store} do
    %MockStore{pid: pid} = store
    assert Process.alive?(pid)

    DSearch.Store.close(store)
    refute Process.alive?(pid)
  end

  test "open/1 return true if agent is running, false otherwise", %{store: store} do
    assert DSearch.Store.open?(store) == true
    DSearch.Store.close(store)
    assert DSearch.Store.open?(store) == false
  end
end
