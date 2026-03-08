defmodule ModaiBackendWeb.Plugs.OriginAllowlist do
  @moduledoc """
  Blocks requests that send an Origin header not in the allowlist (403).
  Use with CORSPlug: this plug runs first and halts; CORSPlug sets CORS headers.
  """

  require Logger
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only check origin for /api (and /api/*) so dev tools (LiveDashboard, etc.) still work
    if not api_request?(conn) do
      conn
    else
      whitelist = get_origins_list()
      origin_value = get_origin_value(conn)

      # Whitelist rỗng = không cho phép bất kỳ origin nào (kể cả request không có Origin)
      if whitelist == [] do
        forbidden(conn, "empty_whitelist", nil)
      else
        case origin_value do
          nil ->
            if block_missing_origin?() do
              log_origin_headers(conn, "missing_origin")
              forbidden(conn, "missing_origin", nil)
            else
              conn
            end

          value ->
            if origin_in_whitelist?(value, whitelist) do
              conn
            else
              forbidden(conn, "origin_not_allowed", value)
            end
        end
      end
    end
  end

  # Đọc Origin: 1) origin  2) header fallback (X-Original-Origin)  3) Referer (khi bật use_referer_fallback)
  defp get_origin_value(conn) do
    case Plug.Conn.get_req_header(conn, "origin") do
      [v | _] when is_binary(v) and v != "" -> v
      _ -> origin_fallback_header(conn) || referer_as_origin(conn)
    end
  end

  defp origin_fallback_header(conn) do
    case Application.get_env(:modai_backend, ModaiBackendWeb.Plugs.OriginAllowlist, [])
         |> Keyword.get(:origin_fallback_header) do
      nil -> nil
      "" -> nil
      header ->
        case Plug.Conn.get_req_header(conn, header) do
          [v | _] when is_binary(v) and v != "" -> v
          _ -> nil
        end
    end
  end

  # Khi không có Origin (proxy strip / same-origin): dùng Referer để kiểm tra whitelist (bật USE_REFERER_FALLBACK=true)
  defp referer_as_origin(conn) do
    if Application.get_env(:modai_backend, ModaiBackendWeb.Plugs.OriginAllowlist, [])
       |> Keyword.get(:use_referer_fallback, false) do
      case Plug.Conn.get_req_header(conn, "referer") do
        [referer | _] when is_binary(referer) and referer != "" ->
          referer_to_origin(referer)
        _ -> nil
      end
    else
      nil
    end
  end

  defp referer_to_origin(referer) do
    case URI.new(referer) do
      {:ok, %URI{scheme: scheme, host: host, port: port}} when is_binary(host) ->
        port = port || default_port(scheme)
        "#{scheme}://#{host}:#{port}"
      _ -> nil
    end
  end

  defp api_request?(conn), do: String.starts_with?(conn.request_path, "/api")

  defp block_missing_origin? do
    Application.get_env(:modai_backend, ModaiBackendWeb.Plugs.OriginAllowlist, [])
    |> Keyword.get(:block_missing_origin, true)
  end

  defp log_origin_headers(conn, reason) do
    headers =
      ["origin", "referer", "x-original-origin"]
      |> Enum.map(fn name -> {name, Plug.Conn.get_req_header(conn, name) |> List.first()} end)
      |> Enum.reject(fn {_, v} -> v == nil or v == "" end)
      |> Map.new()
    Logger.info("OriginAllowlist 403 reason=#{reason} path=#{conn.request_path} headers=#{inspect(headers)}")
  end

  defp forbidden(conn, reason, received_origin) do
    unless reason == "missing_origin" do
      Logger.info(
        "OriginAllowlist 403 path=#{conn.request_path} reason=#{reason}" <>
          if(received_origin, do: " received_origin=#{received_origin}", else: "")
      )
    end

    body =
      %{error: "origin not allowed", reason: reason}
      |> maybe_put(:received_origin, received_origin)
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:forbidden, body)
    |> halt()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  @doc "Returns list of allowed origins for this request (used by CORSPlug with arity 1)."
  def get_origins(conn) do
    whitelist = get_origins_list()
    origin_value = get_origin_value(conn)

    case origin_value do
      nil -> []
      value -> if origin_in_whitelist?(value, whitelist), do: [value], else: []
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
        # Host only (e.g. "localhost", "lichtot365.com"): exact host hoặc subdomain
        allowed_lower = String.downcase(allowed)
        req_host = origin_host(origin_value)
        req_host == allowed_lower or
          (req_host != nil and String.ends_with?(req_host, "." <> allowed_lower))
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
