alias Kontor.Repo
alias Kontor.Accounts.User

tenant_id = Application.get_env(:kontor, :tenant_id, "default")

case Repo.get_by(User, tenant_id: tenant_id, email: "admin@kontor.local") do
  nil ->
    %User{}
    |> User.changeset(%{
      tenant_id: tenant_id,
      email: "admin@kontor.local",
      name: "Admin"
    })
    |> Repo.insert!()

    IO.puts("Created default admin user for tenant: #{tenant_id}")

  user ->
    IO.puts("Admin user already exists: #{user.email}")
end
