defmodule Kontor.AI.MinimaxClientBehaviour do
  @callback complete(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
