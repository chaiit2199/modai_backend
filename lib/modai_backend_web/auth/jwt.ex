defmodule ModaiBackendWeb.Auth.JWT do
  @moduledoc """
  JWT token generation and verification module.
  """

  @secret_key Application.compile_env(:modai_backend, ModaiBackendWeb.Guardian)[:secret_key]
  @token_expiration_minutes 60

  @doc """
  Generates a JWT token for a user.

  Token expires after 1 hour by default.
  """
  def generate_token(user) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    exp = now + (@token_expiration_minutes * 60)

    extra_claims = %{
      "sub" => to_string(user.id),
      "username" => user.username,
      "email" => user.email,
      "role" => user.role,
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
  Gets user ID from token claims.
  """
  def get_user_id(claims) do
    case Map.get(claims, "sub") do
      nil -> nil
      user_id_string -> String.to_integer(user_id_string)
    end
  end
end
