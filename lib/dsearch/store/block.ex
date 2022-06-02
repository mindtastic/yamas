defmodule DSearch.Store.Chunks do
  @moduledoc false

  # The Chunks module is built for operating on files.
  # In order to locate the latest record for an entity, we divide the database file
  # into 1 KB chunks. Each chunk start with an 1 Byte header, indicating it's type.
  #
  # We have two distinct kinds of chunks
  #   * Header Chunks:  Contains only record headers
  #   * Data Chunks:    Contains actual record data
  #
  # As a record header has a fixed size, we read them by length, starting from start of the chunk.
  # Therefore, we pad the unused spaced in a header chunk with zeroes.
  #

  @chunk_size 1024
  @data_type_indicator 0
  @header_type_indicator 128  # MSB of a chunk header will be 1 for a header chunk

  # API function

  @spec add_chunk_headers(binary, non_neg_integer, non_neg_integer) :: [binary]

  def add_chunk_headers(bin, loc, chunk_size \\ @chunk_size) do
    at_chunk_boundary(bin, loc, chunk_size, &add_headers/3)
  end

  @spec strip_chunk_headers(binary, non_neg_integer, non_neg_integer) :: [binary]

  def strip_chunk_headers(bin, loc, chunk_size \\ @chunk_size) do
    at_chunk_boundary(bin, loc, chunk_size, &strip_headers/3)
  end

  @spec size_with_headers(non_neg_integer, non_neg_integer, non_neg_integer) :: non_neg_integer

  def size_with_headers(loc, length, chunk_size \\ @chunk_size) do
    case rem(loc, chunk_size) do
      0 ->
        trunc(headers_length(length, chunk_size) + length)
      r ->
        prefix = chunk_size - r
        rest = length - prefix
        trunc(prefix + headers_length(rest, chunk_size) + rest)
    end
  end

  @spec add_header(binary, non_neg_integer, non_neg_integer) :: {non_neg_integer, [binary]}
  def add_header(bin, loc, chunk_size \\ @chunk_size) do
    case rem(loc, chunk_size) do
      0 ->
        {loc, [<<@header_type_indicator>> | add_headers(bin, loc + 1, chunk_size)]}
      r ->
        chunk_rest = chunk_size - r
        pad = String.pad_leading(<<>>, chunk_rest, <<@data_type_indicator>>)
        header_bytes = add_headers(bin, loc + chunk_rest + 1, chunk_size)
        {loc + chunk_rest, [pad | [<<@header_type_indicator>> | header_bytes]]}
    end
  end

  @spec latest_possible_header_position(non_neg_integer, non_neg_integer) :: non_neg_integer
  def latest_possible_header_position(loc, chunk_size \\ @chunk_size) do
    div(loc - 1, chunk_size) * chunk_size
  end

  @spec header_chunk_header?(byte) :: boolean
  def header_chunk_header?(byte) do
    byte == @header_type_indicator
  end

  # Private functions

  defp at_chunk_boundary(bin, loc, chunk_size, func) do
    case rem(loc, chunk_size) do
      0 -> func.(bin, [], chunk_size)
      r ->
        chunk_rest = chunk_size - r
        if byte_size(bin) <= chunk_rest do
          [bin]
        else
            <<prefix::binary - size(chunk_rest), rest::binary>> = bin
            func.(rest, [prefix], chunk_size)
        end
    end
  end

  defp add_headers(bin, acc, chunk_size) do
    data_size = chunk_size - 1

    if byte_size(bin) <= data_size do
      [bin | [<<@data_type_indicator>>| acc]] |> Enum.reverse()
    else
      <<chunk::binary - size(data_size), rest::binary>> = bin
      add_headers(rest, [chunk | [<<@data_type_indicator>> | acc]], chunk_size)
    end
  end

  defp strip_headers(bin, acc, chunk_size) do
    if byte_size(bin) <= chunk_size do
      <<_::binary - 1, chunk::binary>> = bin
      [chunk | acc] |> Enum.reverse()
    else
      data_size = chunk_size - 1
      <<_::binary-1, chunk::binary - size(data_size), rest::binary>> = bin
      strip_headers(rest, [chunk | acc], chunk_size)
    end
  end

  defp headers_length(length, chunk_size) do
    Float.ceil(length / (chunk_size - 1))
  end
end
