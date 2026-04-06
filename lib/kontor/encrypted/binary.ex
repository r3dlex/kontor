defmodule Kontor.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Kontor.Vault
end
