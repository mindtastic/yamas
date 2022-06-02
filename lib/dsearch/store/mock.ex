defmodule DSearch.Store.MockStore do
  @moduledoc false

  # MockStore is an implementation of the DSearch.Store protocol
  # to allow testing without actually writing to the file system
  @type t :: %__MODULE__{
    pid: pid
  }

  defstruct pid: nil

  @spec create() :: {:ok, t} | {:error, term}
  def create do
    with {:ok, pid} <- Agent.start_link(fn -> {%{}, nil} end) do
      {:ok, %DSearch.Store.MockStore{pid: pid}}
    end
  end

end

defimpl DSearch.Store, for: DSearch.Store.MockStore do
  alias DSearch.Store.MockStore

  def get_node(%MockStore{pid: pid}, loc) do
    case Agent.get(pid, fn {map, _} -> Map.fetch(map, loc) end) do
      {:ok, value} -> value
      :error -> raise(ArgumentError, message: "End of file")
    end
  end

  def put_node(%MockStore{pid: pid}, node) do
    Agent.get_and_update(
      pid,
      fn {map, _} ->
        new_loc = Enum.count(map)
        {new_loc, Map.put(map, new_loc, node)}
      end,
      :infinity
    )
  end

  def put_header(%MockStore{pid: pid}, header) do
    Agent.get_and_update(
      pid,
      fn {map, _} ->
        new_loc = Enum.count(map)
        {new_loc, {Map.put(map, new_loc, header), new_loc}}
      end,
      :infinity
    )
  end

  def get_last_header(%MockStore{pid: pid}) do
    Agent.get(
      pid,
      fn
        {_, nil} -> nil
        {map, last_header_location} -> {last_header_location, Map.get(map, last_header_location)}
      end,
      :infinity
    )
  end

  def sync(_), do: :ok

  def close(%MockStore{pid: pid}) do
    Agent.stop(pid)
  end

  def empty?(%MockStore{pid: pid}) do
    Agent.get(
      pid,
      fn
        {_, nil} -> true
        _ -> false
      end,
      :infinity
    )
  end

  def open?(%MockStore{pid: pid}) do
    Process.alive?(pid)
  end

end
