defmodule Kontor.Accounts do
  @moduledoc "Context module for users, mailboxes, and credentials."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Accounts.{User, Mailbox, Credential}

  # --- Users ---

  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def upsert_user(attrs) do
    email = attrs[:email] || attrs["email"]

    existing = if is_nil(email), do: nil, else: get_user_by_email(email)

    case existing do
      nil ->
        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()
      user ->
        user |> User.changeset(attrs) |> Repo.update()
    end
  end

  def list_tenant_ids do
    Repo.all(from u in User, select: u.tenant_id, distinct: true)
  end

  # --- Mailboxes ---

  def list_mailboxes(tenant_id) do
    Repo.all(from m in Mailbox, where: m.tenant_id == ^tenant_id)
  end

  def get_mailbox(id, tenant_id) do
    case Repo.get_by(Mailbox, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      mb -> {:ok, mb}
    end
  end

  def create_mailbox(attrs, tenant_id) do
    attrs = stringify_keys(attrs) |> Map.put("tenant_id", tenant_id)
    result =
      %Mailbox{}
      |> Mailbox.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, mailbox} ->
        enqueue_style_extraction(mailbox.user_id, tenant_id)
        {:ok, mailbox}

      error ->
        error
    end
  end

  defp enqueue_style_extraction(nil, tenant_id) do
    case Repo.get_by(User, tenant_id: tenant_id) do
      nil -> :ok
      user -> Kontor.AI.StyleExtractor.enqueue(user.id, tenant_id)
    end
  end

  defp enqueue_style_extraction(user_id, tenant_id) do
    Kontor.AI.StyleExtractor.enqueue(user_id, tenant_id)
  end

  def update_mailbox(id, attrs, tenant_id) do
    with {:ok, mailbox} <- get_mailbox(id, tenant_id) do
      mailbox |> Mailbox.changeset(attrs) |> Repo.update()
    end
  end

  # 2-arg version for MailboxController (struct + attrs)
  def update_mailbox(%Mailbox{} = mailbox, attrs) do
    mailbox |> Mailbox.changeset(attrs) |> Repo.update()
  end

  def delete_mailbox(%Mailbox{} = mailbox) do
    Repo.delete(mailbox)
  end

  def upsert_user_from_google(%{"email" => email} = profile, tokens) do
    tenant_id = Application.get_env(:kontor, :tenant_id, "default")
    expires_at = DateTime.add(DateTime.utc_now(), tokens["expires_in"] || 3600)
                 |> DateTime.truncate(:second)

    with {:ok, user} <- upsert_user(%{
           email: email,
           name: profile["name"],
           tenant_id: tenant_id
         }),
         {:ok, _cred} <- upsert_credential(%{
           tenant_id: tenant_id,
           user_id: user.id,
           provider: "google",
           access_token_encrypted: Kontor.Vault.encrypt!(tokens["access_token"] || ""),
           refresh_token_encrypted: Kontor.Vault.encrypt!(tokens["refresh_token"] || ""),
           expires_at: expires_at
         }) do
      {:ok, user}
    end
  end

  def upsert_user_from_microsoft(%{"mail" => email} = profile, tokens) do
    tenant_id = Application.get_env(:kontor, :tenant_id, "default")
    expires_at = DateTime.add(DateTime.utc_now(), tokens["expires_in"] || 3600)
                 |> DateTime.truncate(:second)
    display_name = profile["displayName"] || profile["mail"]

    with {:ok, user} <- upsert_user(%{
           email: email,
           name: display_name,
           tenant_id: tenant_id
         }),
         {:ok, _cred} <- upsert_credential(%{
           tenant_id: tenant_id,
           user_id: user.id,
           provider: "microsoft",
           access_token_encrypted: Kontor.Vault.encrypt!(tokens["access_token"] || ""),
           refresh_token_encrypted: Kontor.Vault.encrypt!(tokens["refresh_token"] || ""),
           expires_at: expires_at
         }) do
      {:ok, user}
    end
  end

  # --- Credentials ---

  def get_credential(user_id, provider) do
    Repo.get_by(Credential, user_id: user_id, provider: provider)
  end

  def upsert_credential(attrs) do
    user_id = attrs[:user_id] || attrs["user_id"]
    provider = attrs[:provider] || attrs["provider"]

    existing =
      if is_nil(user_id) or is_nil(provider),
        do: nil,
        else: Repo.get_by(Credential, user_id: user_id, provider: provider)

    case existing do
      nil ->
        %Credential{}
        |> Credential.changeset(attrs)
        |> Repo.insert()
      cred ->
        cred |> Credential.changeset(attrs) |> Repo.update()
    end
  end

  def get_access_token(tenant_id, provider) do
    case Repo.get_by(Credential, tenant_id: tenant_id, provider: provider) do
      nil -> {:error, :no_credential}
      cred ->
        {:ok, Kontor.Vault.decrypt!(cred.access_token_encrypted)}
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end

defmodule Kontor.Auth do
  def get_microsoft_token(tenant_id) do
    Kontor.Accounts.get_access_token(tenant_id, "microsoft")
  end

  def get_google_token(tenant_id) do
    Kontor.Accounts.get_access_token(tenant_id, "google")
  end
end
