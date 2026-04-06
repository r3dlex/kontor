defmodule Kontor.Repo do
  use Ecto.Repo,
    otp_app: :kontor,
    adapter: Ecto.Adapters.Postgres
end
