defmodule ModaiBackend.Repo do
  use Ecto.Repo,
    otp_app: :modai_backend,
    adapter: Ecto.Adapters.Postgres
end
