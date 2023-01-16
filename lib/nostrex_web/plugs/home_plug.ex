# defmodule NostrexWeb.HomePlug do
#   import Plug.Conn
#   require Logger

#   def init(options) do
#     options
#   end

#   def call(conn, _opts) do
#     Logger.info("Runing NIP 11 logic")

#     if accept_header == "application/nostr+json" do
#       conn
#       |> put_resp_header("Access-Control-Allow-Origin", "*")
#       |> put_resp_header("Access-Control-Allow-Headers", "*")
#       |> put_resp_header("Access-Control-Allow-Methods", "*")
#       |> send_resp(200, get_nip11_json())
#       |> halt()
#     else
#       Logger.info("Not NIP 11 request")
#       conn
#     end
#   end

#   defp get_home_html() do
#     %{
#       name: "River",
#       description: "Nostrex relay by River.com",
#       pubkey: "npub139nl9yxvwayl60fr97m3zrq9md6x5v0uup344mkyuyg6mzlusyxs4zkwf4",
#       contact: "N/A",
#       supported_nips: [1, 4],
#       software: "https://github.com/RiverFinancial/nostrex",
#       version: "0.0.1"
#     }
#     |> Jason.encode!()
#   end
# end
