defmodule Kontor.Accounts.Behaviour do
  @callback get_user_by_email(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  @callback upsert_user(map(), String.t()) :: {:ok, term()} | {:error, term()}
end
