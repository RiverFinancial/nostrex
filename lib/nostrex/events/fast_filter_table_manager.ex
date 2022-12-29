defmodule Nostrex.FastFilterTableManager do
  use GenServer

  @moduledoc """
  The reason this is in a Genserver is that the lifecycle of an ETS table is tied to the lifecycle 
  of the process that created it, so by putting it in a permanent "dumb" Genserver we can ensure that
  the ETS tables we're using for our FastFilter logic don't get deleted until the application shuts down
  """
  @ets_tables ~w(nostrex_ff_pubkeys nostrex_ff_etags nostrex_ff_ptags)a
  def ets_tables, do: @ets_tables

  # This gets called by the child startup logic in application.ex
  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default)
  end

  # Create ETS tables on startup
  # we are making it a :bag table so that we can have multiple values stored at the same key (but deduped)
  # public ensures that anyone can read and write to it
  # named_table ensures the tables have readable name
  # and we want concurrent access for performance. race conditions are probably fine for this kind of application
  @impl true
  def init(_) do
    ets_opts = [:bag, :public, :named_table, write_concurrency: true, read_concurrency: true]

    for table <- @ets_tables do
      :ets.new(table, ets_opts)
    end

    {:ok, []}
  end
end

# iex(1)> :ets.insert(:nostrex_ff_pubkeys, {:test, 1})
# true
# iex(2)> :ets.insert(:nostrex_ff_pubkeys, {:test, 2})
# true
# iex(3)> :ets.lookup(:nostrex_ff_pubkeys, :test)
