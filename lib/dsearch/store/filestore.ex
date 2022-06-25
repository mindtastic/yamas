defmodule DSearch.Store.FileStore do

  @type t :: %__MODULE__{
          pid: pid,
          path: binary
        }

  @enforce_keys [:pid, :path]
  defstruct [:pid, :path]

  # Initializers

  def create(path) do
    with {:ok, pid} <- Agent.start_link(fn -> init(path) end) do
      {:ok, %DSearch.Store.FileStore{pid: pid, path: path}}
    end
  end

  def init(path) do
    exclusive_access!(path)
    {:ok, file} = :file.open(path, [:read, :append, :raw, :binary])
    {:ok, pos} = :file.position(file, :eof)

    {file, pos}
  end

  defp exclusive_access!(path) do
    if not :global.set_lock({{__MODULE__, path}, self()}, [node()], 0) do
      raise ArgumentError, message: "DB file is already in use by another BEAM process: '#{path}"
    end
  end
end

defimpl DSearch.Store, for: DSearch.Store.FileStore do
  alias DSearch.Store.FileStore
  alias DSearch.Store.Chunks

  # API functions

  def get_node(%FileStore{pid: pid}, location) do
    case Agent.get(pid, fn {file, _} -> read_term(file, location) end, :infinity) do
      {:ok, term} -> term
      {:error, error} -> raise(error)
    end
  end

  def put_node(%FileStore{pid: pid}, node) do
    Agent.get_and_update(
      pid,
      fn {file, pos} ->
        bytes = serialize(node)

        case append_chunks(file, bytes, pos) do
          {:ok, bytes_written} ->
            {pos, {file, pos + bytes_written}}

          _ ->
            {:ok, pos} = :file.position(file, :eof)
            {{:error, "Write error"}, {file, pos}}
        end
      end,
      :infinity
    )
  end

  def put_header(%FileStore{pid: pid}, header) do
    Agent.get_and_update(
      pid,
      fn {file, pos} ->
        header_bytes = serialize(header)

        case append_header(file, header_bytes, pos) do
          {:ok, loc, bytes_written} ->
            {loc, {file, pos + bytes_written}}

          _ ->
            {:ok, pos} = :file.position(file, :eof)
            {{:error, "Write error"}, {file, pos}}
        end
      end,
      :infinity
    )
  end

  def sync(%FileStore{pid: pid}) do
    Agent.get(pid, fn {file, _} -> :file.sync(file) end, :infinity)
  end

  def get_last_header(%FileStore{pid: pid}) do
    Agent.get(pid, fn {file, pos} -> get_latest_header(file, pos) end, :infinity)
  end

  def close(%FileStore{pid: pid}) do
    with :ok <-
           Agent.update(
             pid,
             fn {file, pos} ->
               :file.sync(file)
               {file, pos}
             end,
             :infinity
           ) do
      Agent.stop(pid)
    end
  end

  def empty?(%FileStore{path: path}) do
    case File.stat!(path) do
      %{size: 0} -> true
      _ -> false
    end
  end

  def open?(%FileStore{pid: pid}) do
    Process.alive?(pid)
  end

  # Private functions

  defp locate_last_header(_, location) when location <= 0, do: nil

  defp locate_last_header(file, location) do
    loc = Chunks.latest_possible_header_position(location)

    with {:ok, <<chunk_header::8>>} <- :file.pread(file, loc, 1) do
      case Chunks.header_chunk_header?(chunk_header) do
        true -> loc
        false -> locate_last_header(file, loc)
      end
    end
  end

  defp get_latest_header(file, pos) do
    case locate_last_header(file, pos) do
      nil -> nil
      location -> read_header(file, location)
    end
  end

  defp read_header(file, location) do
    case read_term(file, location) do
      {:ok, term} -> {location, term}
      {:error, _} -> get_latest_header(file, location - 1)
    end
  end

  defp read_term(file, location) do
    with {:ok, <<length::32>>, len} <- read_chunks(file, location, 4),
         {:ok, bytes, _} <- read_chunks(file, location + len, length) do
      {:ok, deserialize(bytes)}
    end
  rescue
    error -> {:error, error}
  end

  defp read_chunks(file, location, len) do
    size_with_headers = Chunks.size_with_headers(location, len)

    case :file.pread(file, location, size_with_headers) do
      {:ok, bin} ->
        bytes = Chunks.strip_chunk_headers(bin, location, size_with_headers) |> Enum.join()
        {:ok, bytes, size_with_headers}

      :eof ->
        {:error, %ArgumentError{message: "unexpected EOF by read parameters"}}
    end
  end

  defp append_chunks(file, bytes, pos) do
    chunk_list = Chunks.add_chunk_headers(bytes, pos)

    with :ok <- :file.write(file, chunk_list) do
      {:ok, chunk_list_bytes(chunk_list)}
    end
  end

  defp append_header(file, bytes, pos) do
    {loc, chunk_list} = Chunks.add_header(bytes, pos)

    with :ok <- :file.write(file, chunk_list) do
      {:ok, loc, chunk_list_bytes(chunk_list)}
    end
  end

  defp serialize(node) do
    bytes = :erlang.term_to_binary(node)
    size = byte_size(bytes)
    <<size::32>> <> bytes
  end

  defp deserialize(bytes) do
    :erlang.binary_to_term(bytes)
  end

  defp chunk_list_bytes(chunk_list) do
    chunk_list
    |> Enum.reduce(0, fn bytes, size -> size + byte_size(bytes) end)
  end
end
