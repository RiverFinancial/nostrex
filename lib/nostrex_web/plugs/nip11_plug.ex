defmodule NostrexWeb.Nip11Plug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    accept_header = Enum.at(get_req_header(conn, "accept"), 0)
    if accept_header == "application/nostr+json" do
      conn
      |> send_resp(200, ~s({"test": "test"}))
      |> halt()
    else
      conn
    end
  end
end
