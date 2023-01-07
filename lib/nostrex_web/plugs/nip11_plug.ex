defmodule NostrexWeb.Nip11Plug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    accept_header = Enum.at(get_req_header(conn, "accept"), 0)

    if accept_header == "application/nostr+json" do
      conn
      |> send_resp(200, get_nip11_json())
      |> halt()
    else
      conn
    end
  end

  defp get_nip11_json() do
    %{
      name: "River",
      description: "Nostrex relay by River.com",
      pubkey: "npub139nl9yxvwayl60fr97m3zrq9md6x5v0uup344mkyuyg6mzlusyxs4zkwf4",
      contact: "N/A",
      supported_nips: [1, 4],
      software: "https://github.com/RiverFinancial/nostrex",
      version: "0.0.1"
    }
    |> Jason.encode!()
  end
end
