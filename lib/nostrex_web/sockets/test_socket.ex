defmodule NostrexWeb.TestSocket do
  @behaviour Phoenix.Socket.Transport

  def child_spec(opts) do
    IO.inspect(opts)
    IO.puts "RUNNING"
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(state) do
    IO.puts "CONNECT #{inspect(state)}"
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    {:ok, state}
  end

  def init(state) do
    IO.puts "INIT #{inspect(state)}"
    # Now we are effectively inside the process that maintains the socket.
    {:ok, state}
  end

  def handle_in({text, _opts}, state) do
    {:reply, :ok, {:text, text}, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
