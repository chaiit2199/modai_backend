defmodule ModaiBackendWeb.Plugs.OriginAllowlist do
  @moduledoc """
  Chặn đầu /api: chỉ cho qua khi header x-authen-key trùng với X_AUTHEN_KEY trong env.
  Không kiểm tra origin.
  """

  require Logger
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not api_request?(conn) do
      conn
    else

      expected_key = get_x_authen_key()

      if expected_key == nil or expected_key == "" do
        conn
      else
        received = Plug.Conn.get_req_header(conn, "x-authen-key") |> List.first()

        if is_binary(received) and Plug.Crypto.secure_compare(received, expected_key) do
          conn
        else
          forbidden(conn)
        end
      end
    end
  end

  defp api_request?(conn), do: String.starts_with?(conn.request_path, "/api")

  # Lấy x_authen_key từ config Endpoint
  defp get_x_authen_key do
    Application.get_env(:modai_backend, ModaiBackendWeb.Endpoint, [])
    |> Keyword.get(:x_authen_key)
  end

  defp forbidden(conn) do
    Logger.info("OriginAllowlist 403 path=#{conn.request_path} x-authen-key missing or not match")
    body = Jason.encode!(%{error: "invalid or missing x-authen-key"})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:forbidden, body)
    |> halt()
  end
end
