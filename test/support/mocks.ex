defmodule Kontor.Auth.GoogleBehaviour do
  @moduledoc """
  Behaviour for the Google OAuth client.

  The auth controller calls:
    - exchange_code/1  (code only — no redirect_uri, controller passes just the code)
    - get_profile/1    (access_token)

  Note: the underlying Kontor.Auth.Google module has exchange_code/2 and
  get_user_info/1. The controller uses a simplified 1-arg form and get_profile/1.
  These behaviour callbacks reflect what the controller actually calls so that
  Mox can intercept them in tests.
  """

  @callback exchange_code(code :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback get_profile(access_token :: String.t()) ::
              {:ok, map()} | {:error, term()}
end

defmodule Kontor.Auth.MicrosoftBehaviour do
  @moduledoc """
  Behaviour for the Microsoft OAuth client.

  The auth controller calls:
    - exchange_code/1  (code only)
    - get_profile/1    (access_token)
  """

  @callback exchange_code(code :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback get_profile(access_token :: String.t()) ::
              {:ok, map()} | {:error, term()}
end

defmodule Kontor.Accounts.Behaviour do
  @moduledoc "Behaviour for the Accounts context used by the auth controller."

  @callback upsert_user_from_google(profile :: map(), tokens :: map()) ::
              {:ok, struct()} | {:error, term()}

  @callback upsert_user_from_microsoft(profile :: map(), tokens :: map()) ::
              {:ok, struct()} | {:error, term()}
end

defmodule Kontor.AI.MinimaxClientBehaviour do
  @moduledoc "Behaviour for the MinimaxClient used in the AI pipeline and chat channel."

  @callback complete(prompt :: String.t(), tenant_id :: String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @callback complete(prompt :: String.t(), tenant_id :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
end
