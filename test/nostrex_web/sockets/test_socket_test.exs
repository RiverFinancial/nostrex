defmodule NostrexWeb.TestSocketTest do
  # use NostrexWeb.ChannelCase
  # use ExUnit.CaseTemplate
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  require Logger
  # alias NostrexWeb.TestSocket
  alias NostrexWeb.WebsocketClient

  setup_all do
    capture_log(fn -> NostrexWeb.Endpoint.start_link() end)
    :ok
  end


  test "ping pong" do
    IO.puts "BEFORE CONNECT"
    # send(self(), "test")
    assert {:ok, client} = WebsocketClient.connect(self(), "ws://127.0.0.1:4002/", :noop)
    WebsocketClient.send(client, {:text, "abc"})
    assert_receive {:text, "abc"}
    # socket = TestSocket.init(%{a: "b"})
    # push(socket, "ping")
    # send(socket.pid)
    # ref = push(socket, "ping")
  end
end
