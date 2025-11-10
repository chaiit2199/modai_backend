defmodule ModaiBackendWeb.Plugs.CORS do
  @moduledoc """
  CORS plug to handle cross-origin requests.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    whitelist =
      (Application.get_env(:modai_backend, ModaiBackendWeb.Endpoint)[:allow_check_origin] || "")
      |> String.split(",")

    origin =
      with [host_request] <- Plug.Conn.get_req_header(conn, "origin"),
          {:ok, %URI{host: host}} <- URI.new(host_request || ""),
          true <- Enum.any?(whitelist, &Regex.match?(~r/^([A-Za-z0-9-]+\.)?(#{&1})$/, host)) do
        host_request
      else
        _ -> ""
      end

    # Kiểm tra xem có phải là auth route không
    is_auth_route = String.starts_with?(conn.request_path, "/api/login") or
                    String.starts_with?(conn.request_path, "/api/register") or
                    String.starts_with?(conn.request_path, "/api/forgot-password") or
                    String.starts_with?(conn.request_path, "/api/reset-password") or
                    String.starts_with?(conn.request_path, "/api/refresh-token") or
                    String.starts_with?(conn.request_path, "/api/posts/delete/:id") or
                    String.starts_with?(conn.request_path, "/api/posts/update/:id") or
                    String.starts_with?(conn.request_path, "/api/posts/update") or
                    String.starts_with?(conn.request_path, "/api/posts/create")

    # Handle OPTIONS request first (preflight)
    if conn.method == "OPTIONS" do
      if origin != "" do
        conn = conn
          |> put_resp_header("access-control-allow-origin", origin)
          |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")
          |> put_resp_header("access-control-allow-credentials", "true")
          |> put_resp_header("access-control-max-age", "86400")

        # Chỉ thêm access-control-allow-methods cho auth routes
        conn = if is_auth_route do
          put_resp_header(conn, "access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        else
          conn
        end

        conn
        |> send_resp(:no_content, "")
        |> halt()
      else
        # Still send CORS headers even if origin not in list, but return error
        conn = conn
          |> put_resp_header("access-control-allow-origin", origin || "*")
          |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")

        # Chỉ thêm access-control-allow-methods cho auth routes
        conn = if is_auth_route do
          put_resp_header(conn, "access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        else
          conn
        end

        conn
        |> send_resp(:forbidden, "")
        |> halt()
      end
    else
      # For non-OPTIONS requests, add CORS headers if origin is allowed
      if origin != "" do
        conn = conn
          |> put_resp_header("access-control-allow-origin", origin)
          |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization, Accept")
          |> put_resp_header("access-control-allow-credentials", "true")

        # Chỉ thêm access-control-allow-methods cho auth routes
        conn = if is_auth_route do
          put_resp_header(conn, "access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        else
          conn
        end

        conn
      else
        # Still add CORS headers for debugging, but browser will block
        if origin != "" do
          conn
          |> put_resp_header("access-control-allow-origin", origin)
        else
          conn
        end
      end
    end
  end
end
