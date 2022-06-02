defmodule DSearch.BTree.DFS do
  @moduledoc false

  # `DSearch.BTree.DFS` implements a depth-first-search btree traversal function
  # exposed via a reduced function, so it can be used on the btree
  # to implement the `Enumerable` interface.

  alias DSearch.BTree
  alias DSearch.Store

  @leaf BTree.__leaf__()
  @branch BTree.__branch__()
  @value BTree.__value__()
  @deleted BTree.__deleted__()

  @spec reduce(
    BTree.t(),
    Enumerable.acc(),
    Enumerable.reducer(),
    (BTree.node_type(),
    Store.t() -> any)
    ) :: Enumerable.result()

  def reduce(%BTree{root: root, store: store}, cmd_acc, fun, get_children) do
    perform_reduce({[], [[{nil, root}]]}, cmd_acc, fun, get_children, store)
  end

  defp perform_recude(_, {:halt, acc}, _, _, _) do
    {:halted, acc}
  end

  defp perform_recude(t, {:suspend, acc}, fun, get_children, store) do
    {:suspended, acc, &perform_recude(t, &1, fun, get_children, store)}
  end

  defp perform_reduce(t, {:cont, acc}, fun, get_children, store) do
    case next(t, store, get_children) do
      {t, item} -> perform_reduce(t, fun.(item, acc), fun, get_children, store)
      :done -> {:done, acc}
    end
  end

  defp next({[], [[] | rest]}, store, get_children) do
    case rest do
      [] -> :done
      _ -> next({[], rest}, store, get_children)
    end
  end

  defp next({[], [[{_, leaf = {@leaf, _}} | siblings] | rest]}, store, get_children) do
    children = get_children.(leaf, store)
    next({children, [siblings | rest]}, store, get_children)
  end

  defp next({[], [[{_, branch = {@branch, _}} | siblings] | rest]}, store, get_children) do
    children = get_children.(branch, store)
    next({[], [children | [siblings | rest]]}, store, get_children)
  end

  defp next({[{key, value = {@value, _}} | siblings], rest}, store, get_children) do
    {{siblings, rest}, {key, get_children.(value, store)}}
  end

  defp next({[{key, @deleted} | siblings], rest}, store, get_children) do
    {{siblings, rest}, {key, get_children.(@deleted, store)}}
  end

end
