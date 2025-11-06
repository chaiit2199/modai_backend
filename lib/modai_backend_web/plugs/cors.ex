defmodule ModaiBackendWeb.Plugs.CORS do
  @moduledoc """
  CORS plug to handle cross-origin requests.
  """

  import Plug.Conn

  # Load allowed origins at runtime to allow config changes
  defp allowed_origins do
    Application.get_env(:modai_backend, __MODULE__)[:allowed_origins] || []
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_req_header(conn, "origin") |> List.first()
    is_allowed = origin && origin in allowed_origins()

    # Handle OPTIONS request first (preflight)
    if conn.method == "OPTIONS" do
      if is_allowed do
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header("access-control-max-age", "86400")
        |> send_resp(:no_content, "")
        |> halt()
      else
        # Still send CORS headers even if origin not in list, but return error
        conn
        |> put_resp_header("access-control-allow-origin", origin || "*")
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")
        |> send_resp(:forbidden, "")
        |> halt()
      end
    else
      # For non-OPTIONS requests, add CORS headers if origin is allowed
      if is_allowed do
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")
        |> put_resp_header("access-control-allow-credentials", "true")
      else
        # Still add CORS headers for debugging, but browser will block
        if origin do
          conn
          |> put_resp_header("access-control-allow-origin", origin)
        else
          conn
        end
      end
    end
  end
end
