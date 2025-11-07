defmodule ModaiBackend.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :role, :string, default: "user"
    field :password_hash, :string
    field :password, :string, virtual: true
    field :reset_token, :string
    field :reset_token_sent_at, :utc_datetime
    field :refresh_token_hash, :string
    field :refresh_token_expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @email_regex ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "can only contain letters, numbers, and underscores")
    |> validate_format(:email, @email_regex, message: "must be a valid email")
    |> validate_length(:email, max: 255)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_default_role()
    |> put_password_hash()
  end

  defp put_default_role(%Ecto.Changeset{valid?: true} = changeset) do
    # Set default role to "user" if not already set
    case Ecto.Changeset.get_field(changeset, :role) do
      nil -> change(changeset, role: "user")
      _ -> changeset
    end
  end

  defp put_default_role(changeset), do: changeset

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    change(changeset, password_hash: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  @doc false
  def password_reset_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6)
    |> put_password_hash()
  end
end
