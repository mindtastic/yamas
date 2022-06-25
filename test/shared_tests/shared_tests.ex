defmodule SharedTests do
  # `SharedTests` is a helper module, allowing to run the same tests
  # against different protocol implementation without repeating.

  defmacro share_tests(do: block) do
    quote do
      defmacro __using__(options) do
        block = unquote(Macro.escape(block))

        quote do
          @moduletag unquote(options)
          unquote(block)
        end
      end
    end
  end
end
