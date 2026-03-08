defmodule ModaiBackendWeb.Plugs.OriginAllowlist do
  @moduledoc """
  Blocks requests that send an Origin header not in the allowlist (403).
  Use with CORSPlug: this plug runs first and halts; CORSPlug sets CORS headers.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only check origin for /api (and /api/*) so dev tools (LiveDashboard, etc.) still work
    if not api_request?(conn) do
      conn
    else
      whitelist = get_origins_list()

      # Whitelist rỗng = không cho phép bất kỳ origin nào (kể cả request không có Origin)
      if whitelist == [] do
        forbidden(conn)
      else
        case Plug.Conn.get_req_header(conn, "origin") do
          [origin_value | _] ->
            if origin_in_whitelist?(origin_value, whitelist) do
              conn
            else
              forbidden(conn)
            end

          [] ->
            # No Origin: block unless config allows (e.g. for Postman in dev set block_missing_origin: false)
            if block_missing_origin?() do
              forbidden(conn)
            else
              conn
            end
        end
      end
    end
  end

  defp api_request?(conn), do: String.starts_with?(conn.request_path, "/api")

  defp block_missing_origin? do
    Application.get_env(:modai_backend, ModaiBackendWeb.Plugs.OriginAllowlist, [])
    |> Keyword.get(:block_missing_origin, true)
  end

  defp forbidden(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:forbidden, ~s|{"error":"origin not allowed"}|)
    |> halt()
  end

  @doc "Returns list of allowed origins for this request (used by CORSPlug with arity 1)."
  def get_origins(conn) do
    whitelist = get_origins_list()

    case Plug.Conn.get_req_header(conn, "origin") do
      [origin_value | _] ->
        if origin_in_whitelist?(origin_value, whitelist), do: [origin_value], else: []

      [] ->
        []
    end
  end

  defp get_origins_list do
    (Application.get_env(:modai_backend, ModaiBackendWeb.Endpoint)[:allow_check_origin] || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp origin_in_whitelist?(origin_value, whitelist) do
    Enum.any?(whitelist, fn allowed ->
      allowed = String.trim(allowed)
      if String.contains?(allowed, "://") do
        # Full origin: compare normalized (scheme + host + port)
        normalize_origin(origin_value) == normalize_origin(allowed)
      else
        # Host only (e.g. "localhost", "lichtot365.com"): match if request origin has this host
        origin_host(origin_value) == String.downcase(allowed)
      end
    end)
  end

  defp origin_host(origin) when is_binary(origin) do
    case URI.new(origin) do
      {:ok, %URI{host: host}} when is_binary(host) ->
        String.downcase(host)

      _ ->
        nil
    end
  end

  defp normalize_origin(origin) when is_binary(origin) do
    case URI.new(origin) do
      {:ok, %URI{scheme: scheme, host: host, port: port}} when is_binary(host) ->
        scheme = scheme && String.downcase(scheme)
        host = String.downcase(host)
        port = port || default_port(scheme)
        "#{scheme}://#{host}:#{port}"

      _ ->
        origin
    end
  end

  defp default_port("https"), do: 443
  defp default_port(_), do: 80
end
