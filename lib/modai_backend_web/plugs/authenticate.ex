defmodule ModaiBackendWeb.Plugs.Authenticate do
  @moduledoc """
  Plug to authenticate requests using JWT token.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias ModaiBackendWeb.Auth.JWT
  alias ModaiBackend.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_token(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{message: "Authentication required"})
        |> halt()

      token ->
        case JWT.verify_access_token(token) do
          {:ok, claims} ->
            user_id = JWT.get_user_id(claims)

            case Accounts.get_user(user_id) do
              nil ->
                conn
                |> put_status(:unauthorized)
                |> json(%{message: "User not found"})
                |> halt()

              user ->
                assign(conn, :current_user, user)
            end

          {:error, :invalid_token_type} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{message: "Invalid token type. Access token required."})
            |> halt()

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{message: "Invalid or expired access token"})
            |> halt()
        end
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end
