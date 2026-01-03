import Config
if config_env() == :prod do

  config :modai_backend, ModaiBackend.Repo,
    username: System.get_env("DB_USERNAME") || raise("No DB_USERNAME config."),
    password: System.get_env("DB_PASSWORD") || raise("No DB_PASSWORD config."),
    hostname: System.get_env("DB_HOST") || raise("No DB_HOST config."),
    database: System.get_env("DB") || raise("No DB config."),
    port: System.get_env("DB_PORT") || raise("No DB_PORT config."),
    pool_size:
      String.to_integer(
        System.get_env("DB_POOL_SIZE") || raise("No DB_POOL_SIZE config.")
      ),
    stacktrace: (System.get_env("DB_STACKTRACE") || "false") in ["true"],
    show_sensitive_data_on_connection_error: false,
    log: false

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("HOST") || "example.com"
  http_port = String.to_integer(System.get_env("HTTP_PORT") || "8088")
  https_port = String.to_integer(System.get_env("HTTPS_PORT") || "4000")
  allow_iframe = System.get_env("CHECK_ORIGIN") |> String.replace("//", "")
  check_origin = System.get_env("CHECK_ORIGIN") |> String.split(",")

  config :modai_backend, ModaiBackendWeb.Endpoint,
    server: true,
    url: [
      host: host,
      port: if(host_scheme == "https", do: https_port, else: http_port),
      scheme: host_scheme
    ],
    http: [ip: {0, 0, 0, 0}, port: http_port],
    secret_key_base: secret_key_base,
    check_origin: check_origin,
    allow_check_origin: allow_iframe,
    API_KEY_GEMINI: System.get_env("API_KEY_GEMINI"),
    URL_GEMINI: System.get_env("URL_GEMINI")
    if host_scheme == "https" do
      host_cert_file = System.get_env("HOST_CERT_FILE") || raise "No host cert file config."
      host_key_file = System.get_env("HOST_KEY_FILE") || raise "No host key file config."

      config :apg_web, ApgWebWeb.Endpoint,
        https: [
          otp_app: :apg_web,
          port: https_port,
          cipher_suite: :strong,
          keyfile: host_key_file,
          certfile: host_cert_file
        ]
    end


  config :modai_backend, ModaiBackend.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: "smtp.gmail.com",
    username: "chaiit2199@gmail.com",
    password: "ptwgutbreoowsdtu",
    ssl: false,
    tls: :always,
    tls_options: [
      verify: :verify_none
    ],
    auth: :always,
    port: 587,
    retries: 2

  # JWT Configuration
  config :modai_backend, ModaiBackendWeb.Guardian,
    issuer: "modai_backend",
    secret_key: secret_key_base

  # CORS Configuration
  config :modai_backend, ModaiBackendWeb.Plugs.CORS,
    allowed_origins: check_origin

end
