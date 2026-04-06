defmodule Kontor.Auth.GoogleBehaviour do
  @callback exchange_code(String.t()) :: {:ok, map()} | {:error, term()}
  @callback refresh_token(String.t()) :: {:ok, map()} | {:error, term()}
end
