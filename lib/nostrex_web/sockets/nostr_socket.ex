defmodule NostrexWeb.NostrSocket do
  # NOT USING Phoenix.Socket because it requires a proprietary wire protocol that is incompatible with Nostr

  alias Nostrex.Events
  alias Nostrex.Events.Event
  alias Phoenix.PubSub
  alias Nostrex.FastFilter

  @moduledoc """
  Simple Websocket handler that echos back any data it receives
  """

  @behaviour :cowboy_websocket

  # entry point of the websocket socket. 
  # WARNING: this is where you would need to do any authentication
  #          and authorization. Since this handler is invoked BEFORE
  #          our Phoenix router, it will NOT follow your pipelines defined there.
  # 
  # WARNING: this function is NOT called in the same process context as the rest of the functions
  #          defined in this module. This is notably dissimilar to other gen_* behaviours.  
  # Phoenix.PubSub.broadcast(:nostrex_pubsub, "test", %{a: 1})       
  @impl :cowboy_websocket
  def init(req, opts) do
    IO.inspect(opts)
    # TODO: look at limiting max frame size here
    # NOTE: idle timeout default is 60s to save resources
    {:cowboy_websocket, req, opts}
  end

  # as long as `init/2` returned `{:cowboy_websocket, req, opts}`
  # this function will be called. You can begin sending packets at this point.
  # We'll look at how to do that in the `websocket_handle` function however.
  # This function is where you might want to  implement `Phoenix.Presence`, schedule an `after_join` message etc.
  @impl :cowboy_websocket
  def websocket_init(state) do
    IO.puts("INIT SERVER")

    initial_state = %{
      event_count: 0,
      req_count: 0,
      subscriptions: MapSet.new()
    }

    {[], state}
  end

  # `websocket_handle` is where data from a client will be received.
  # a `frame` will be delivered in one of a few shapes depending on what the client sent:
  # 
  #     :ping
  #     :pong
  #     {:text, data}
  #     {:binary, data}
  # 
  # Similarly, the return value of this function is similar:
  # 
  #     {[reply_frame1, reply_frame2, ....], state}
  # 
  # where `reply_frame` is the same format as what is delivered.
  @impl :cowboy_websocket
  def websocket_handle(frame, state)

  # Implement basic ping pong handler for easy health checking
  def websocket_handle({:text, "ping"}, state), do: {[{:text, "pong"}], state}

  # Handles all Nostr [EVENT] messages. This endpoint is very DB write heavy
  # and is called by clients to publishing new Nostr events
  def websocket_handle({:text, req = "[\"EVENT\"," <> _}, state) do
    IO.puts("EVENT endpoint hit")
    IO.inspect(state)

    # TODO: change this to not lead to dos vuln
    {:ok, list} = Jason.decode(req, keys: :atoms)
    event_params = Enum.at(list, 1)

    {:ok, raw_event} = Jason.encode(event_params)

    IO.puts("parsed")
    # the :atoms! option is important as it utilizes String.to_existing_atom
    # there would be a DoS vulnerability here otherwise
    # event_params = Event.json_string_to_map(event_str)
    resp =
      case Events.create_event(event_params) do
        {:ok, event} ->
          FastFilter.process_event(
            author_pubkey: event.pubkey,
            tags: event.tags,
            kind: event.kind,
            raw_event: raw_event
          )

          "successfully created event #{event.id}"

        _ ->
          "error: unable to save event"
      end

    {[{:text, resp}], state}
  end

  @doc """
  Handles all Nostr [REQ] messages. This endpoint is very DB read heavy
  and also grows the in-memory PubSub state. It's used by clients
  to query and subscribe to events based on a filter
  """
  def websocket_handle({:text, req = "[\"REQ\"," <> _}, state) do
    IO.puts("REQ endpoint hit")
    IO.inspect(state)

    {:ok, list} = Jason.decode(req, keys: :atoms)
    subscription_id = Enum.at(list, 1)
    filters = Enum.at(list, 2)

    # TODO, ensure subscription_id doesn't have colon since we use as separator in filter_id

    handle_req_event(subscription_id, filters)

    state =
      state
      |> increment_state_counter(:event_count)
      |> increment_state_counter(:req_count)
      |> add_subscription_to_state(subscription_id)

    IO.inspect(filters)

    {[{:text, "success"}], state}
  end

  @doc """
  Handles all Nostr [CLOSE] messages. This endpoint is very DB read heavy
  and also grows the in-memory PubSub state. This message includes a subscription
  id, but we need to be sure we're only closing the subscription ids that belong to this
  channel, otherwise we open ourselves up to somebody spamming in an attempt to close 
  subscriptions for other clients
  """
  def websocket_handle({:text, req = "[\"CLOSE\"," <> _}, state) do
    IO.puts("[CLOSE] endpoint hit")

    {:ok, list} = Jason.decode(req)

    # TODO, ensure subscription ID isn't too large
    subscription_id = Enum.at(list, 1)
    IO.puts(subscription_id)

    {[{:close, "success"}], state}
  end

  # # a message was delivered from a client. Here we handle it by just echoing it back
  # # to the client.
  # def websocket_handle({:text, message}, state) do
  # 	{[{:text, message}], state}
  # end

  # # This function is where we will process all *other* messages that get delivered to the
  # # process mailbox. This function isn't used in this handler.
  @impl :cowboy_websocket
  def websocket_info(info, state)

  def websocket_info(info, state) do
    IO.puts("INFO RECEIVED!!")
    IO.inspect(info)
    msgs = Process.info(self(), :messages)
    IO.puts("msgs")
    IO.inspect(msgs)
    {[], state}
  end

  # placeholder catch all
  def handle_info(_) do
    IO.puts("called!!! pubsub")
  end

  def terminate(_reason, _partial_req, state) do
    ## Ensure any state gets cleaned up before terminating
    IO.puts("TERMINATE CALLED")
    IO.inspect(state)
    :ok
  end

  # increments a counter on the state object
  defp increment_state_counter(state, key) do
    put_in(state, [key], state[key] + 1)
  end

  # adds a new subscription to the state object subscriptions set
  defp add_subscription_to_state(state, subscription) do
    new_subscriptions =
      state.subscriptions
      |> MapSet.put(subscription)

    put_in(state, [:subscriptions], new_subscriptions)
  end

  defp handle_req_event(subscription_id, filters) do
    # if until is empty or is after now
    if filters["until"] == nil or !timestamp_before_now?(filters["until"]) do
      # register the subscriber
      PubSub.subscribe(:nostrex_pubsub, "req:#{subscription_id}")

      FastFilter.insert_filter()

      # Create the ETS entries
      # create_subscription_ets_entries(filters)
    end
  end

  # defp create_subscription_ets_entries do
    
  # end

  # TODO: consider adding some larger buffer here
  defp timestamp_before_now?(unix_timestamp) do
    DateTime.compare(DateTime.from_unix(unix_timestamp), DateTime.now()) == :lt
  end
end
