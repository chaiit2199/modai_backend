defmodule ModaiBackendWeb.Auth.JWT do
  @moduledoc """
  JWT token generation and verification module.
  """

  @secret_key "ufNYrVWX67bKKx9l4zUOprb3tg3FtKUUULd6U9cUeisigGdq9ad/pd+8ApiiNZFQ"
  @access_token_expiration_minutes 30
  @refresh_token_expiration_days 1

  @doc """
  Generates an access token for a user.

  Access token expires after 30 minutes.
  """
  def generate_access_token(user) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    exp = now + (@access_token_expiration_minutes * 60)

    extra_claims = %{
      "sub" => to_string(user.id),
      "username" => user.username,
      "email" => user.email,
      "role" => user.role,
      "type" => "access",
      "iat" => now,
      "exp" => exp
    }

    signer = Joken.Signer.create("HS256", @secret_key)

    case Joken.generate_and_sign(%{}, extra_claims, signer) do
      {:ok, token, _claims} -> {:ok, token}
      error -> error
    end
  end

  @doc """
  Generates a refresh token for a user.

  Refresh token expires after 1 day.
  Returns the token string (not JWT, just a secure random token).
  """
  def generate_refresh_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.replace(~r/[+\/=]/, "")
  end

  @doc """
  Verifies and decodes a JWT token.

  Returns `{:ok, claims}` if valid, or `{:error, reason}` if invalid.
  """
  def verify_token(token) do
    signer = Joken.Signer.create("HS256", @secret_key)

    case Joken.verify_and_validate(token, %{}, signer) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies that a token is an access token (not refresh token).
  """
  def verify_access_token(token) do
    case verify_token(token) do
      {:ok, claims} ->
        case Map.get(claims, "type") do
          "access" -> {:ok, claims}
          _ -> {:error, :invalid_token_type}
        end
      error -> error
    end
  end

  @doc """
  Gets user ID from token claims.
  """
  def get_user_id(claims) do
    case Map.get(claims, "sub") do
      nil -> nil
      user_id_string -> String.to_integer(user_id_string)
    end
  end

  @doc """
  Gets refresh token expiration datetime.
  """
  def refresh_token_expires_at do
    DateTime.utc_now()
    |> DateTime.add(@refresh_token_expiration_days, :day)
    |> DateTime.truncate(:second)
  end
end
