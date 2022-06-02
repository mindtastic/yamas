defmodule DSearch.SharedStoreTests do
  import SharedTests

  share_tests do
    alias DSearch.BTree

    @value BTree.__value__()

    test "put_node/2 and get_node/2 set and get a note a specific location", %{store: store} do
      Enum.each(1..10, fn val ->
        loc = DSearch.Store.put_node(store, {@value, val})
        assert {@value, val} == DSearch.Store.get_node(store, loc)
      end)
    end

    test "get_node/2 errors if no node is present at the given location", %{store: store} do
      assert_raise ArgumentError, fn ->
        DSearch.Store.get_node(store, 32)
      end
    end

    test "put_header/2 sets a header", %{store: store} do
      root_location = DSearch.Store.put_node(store, {@value, 1})
      location = DSearch.Store.put_header(store, {root_location, 1})
      assert {^location, {^root_location, 1}} = DSearch.Store.get_last_header(store)
    end

    test "get_last_header/1 returns the most recently stored header", %{store: store} do
      DSearch.Store.put_node(store, {@value, 1})
      DSearch.Store.put_node(store, {@value, 2})
      DSearch.Store.put_header(store, {0, 0})
      DSearch.Store.put_node(store, {@value, 3})
      location = DSearch.Store.put_header(store, {32, 0})
      DSearch.Store.put_node(store, {@value, 4})
      assert {^location, {32, 0}} = DSearch.Store.get_last_header(store)
    end

    test "emtpy?/1 returns true if no store is present and else otherwise", %{store: store} do
      assert DSearch.Store.empty?(store) == true
      DSearch.Store.put_node(store, {@value, 1})
      DSearch.Store.put_header(store, {0, 0})
      DSearch.Store.sync(store)
      assert DSearch.Store.empty?(store) == false
    end

    test "close/1 returns :ok", %{store: store} do
      assert DSearch.Store.close(store) == :ok
    end
  end
end
