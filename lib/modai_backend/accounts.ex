defmodule ModaiBackend.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias ModaiBackend.Repo
  alias ModaiBackend.Accounts.User

  @doc """
  Authenticates a user by username and password.

  Returns `{:ok, user}` if authentication succeeds, or `{:error, :unauthorized}` if it fails.
  """
  def authenticate_user(username, password) do
    user = Repo.get_by(User, username: username)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :unauthorized}

      true ->
        # Hash a dummy password to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :unauthorized}
    end
  end

  @doc """
  Gets a single user by email.
  """
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @doc """
  Gets a single user by username and email, verifying they match.
  """
  def get_user_by_username_and_email(username, email) do
    user = Repo.get_by(User, username: username)

    if user && user.email == email do
      user
    else
      nil
    end
  end

  @doc """
  Gets a single user by ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates user role. Role can only be set directly in database.
  """
  def update_user_role(user, role) when role in ["user", "admin"] do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:role, role)
    |> Repo.update()
  end

  @doc """
  Generates a reset token for password reset by email.

  Returns `{:ok, user}` if user exists, or `{:error, :not_found}` if user doesn't exist.
  """
  def generate_reset_token(email) do
    case get_user_by_email(email) do
      nil ->
        # Generate dummy token to prevent timing attacks
        _dummy = :crypto.strong_rand_bytes(32)
        {:error, :not_found}

      user ->
        reset_token = generate_secure_token()

        user
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_change(:reset_token, reset_token)
        |> Ecto.Changeset.put_change(:reset_token_sent_at, DateTime.truncate(DateTime.utc_now(), :second))
        |> Repo.update()
    end
  end

  @doc """
  Generates a reset token for password reset by username and email.
  Verifies that username and email match before generating token.

  Returns `{:ok, user}` if user exists and matches, or `{:error, :not_found}` if not found.
  """
  def generate_reset_token_by_username_and_email(username, email) do
    case get_user_by_username_and_email(username, email) do
      nil ->
        # Generate dummy token to prevent timing attacks
        _dummy = :crypto.strong_rand_bytes(32)
        {:error, :not_found}

      user ->
        reset_token = generate_secure_token()

        case user
             |> Ecto.Changeset.change()
             |> Ecto.Changeset.put_change(:reset_token, reset_token)
             |> Ecto.Changeset.put_change(:reset_token_sent_at, DateTime.truncate(DateTime.utc_now(), :second))
             |> Repo.update() do
          {:ok, updated_user} -> {:ok, updated_user}
          error -> error
        end
    end
  end

  @doc """
  Gets a user by reset token.
  """
  def get_user_by_reset_token(token) do
    Repo.get_by(User, reset_token: token)
  end

  @doc """
  Resets password using reset token.

  Returns `{:ok, user}` if successful, or `{:error, reason}` if failed.
  """
  def reset_password(reset_token, new_password) do
    case get_user_by_reset_token(reset_token) do
      nil ->
        # Hash a dummy password to prevent timing attacks
        _dummy = Bcrypt.hash_pwd_salt("dummy")
        {:error, :invalid_token}

      user ->
        user
        |> User.password_reset_changeset(%{password: new_password})
        |> Ecto.Changeset.put_change(:reset_token, nil)
        |> Ecto.Changeset.put_change(:reset_token_sent_at, nil)
        |> Repo.update()
    end
  end

  @doc """
  Saves refresh token hash to user.
  """
  def save_refresh_token(user, refresh_token) do
    refresh_token_hash = Bcrypt.hash_pwd_salt(refresh_token)
    expires_at = ModaiBackendWeb.Auth.JWT.refresh_token_expires_at()

    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:refresh_token_hash, refresh_token_hash)
    |> Ecto.Changeset.put_change(:refresh_token_expires_at, expires_at)
    |> Repo.update()
  end

  @doc """
  Verifies refresh token and returns user if valid.
  """
  def verify_refresh_token(refresh_token) do
    # Find user by checking refresh_token_hash
    # We need to check all users with non-null refresh_token_hash
    # and verify the token matches
    users = Repo.all(from u in User, where: not is_nil(u.refresh_token_hash))

    Enum.find_value(users, fn user ->
      if Bcrypt.verify_pass(refresh_token, user.refresh_token_hash) do
        # Check if token is expired
        if user.refresh_token_expires_at && DateTime.compare(user.refresh_token_expires_at, DateTime.utc_now()) == :gt do
          user
        else
          nil
        end
      else
        nil
      end
    end)
  end

  @doc """
  Revokes refresh token by clearing it from user.
  """
  def revoke_refresh_token(user) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:refresh_token_hash, nil)
    |> Ecto.Changeset.put_change(:refresh_token_expires_at, nil)
    |> Repo.update()
  end

  defp generate_secure_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.replace(~r/[+\/=]/, "")
  end
end
