# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ModaiBackend.Repo.insert!(%ModaiBackend.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ModaiBackend.Accounts

# Tạo user test để login
Accounts.create_user(%{
  username: "testuser",
  email: "test@example.com",
  password: "password123"
})
|> case do
  {:ok, user} ->
    IO.puts("✅ Created test user: #{user.username} (#{user.email}) - Role: #{user.role}")

  {:error, changeset} ->
    IO.puts("⚠️  User might already exist or error occurred")
    IO.inspect(changeset.errors)
end

# Tạo admin user (tạo user trước, sau đó set role admin)
Accounts.create_user(%{
  username: "admin",
  email: "admin@example.com",
  password: "admin123"
})
|> case do
  {:ok, user} ->
    # Set role to admin directly in database
    case Accounts.update_user_role(user, "admin") do
      {:ok, admin_user} ->
        IO.puts("✅ Created admin user: #{admin_user.username} (#{admin_user.email}) - Role: #{admin_user.role}")

      {:error, changeset} ->
        IO.puts("⚠️  Failed to set admin role")
        IO.inspect(changeset.errors)
    end

  {:error, changeset} ->
    IO.puts("⚠️  Admin user might already exist or error occurred")
    IO.inspect(changeset.errors)
end
