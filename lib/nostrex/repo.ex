defmodule Nostrex.Repo do
  use Ecto.Repo,
    otp_app: :nostrex,
    adapter: Ecto.Adapters.Postgres
end
