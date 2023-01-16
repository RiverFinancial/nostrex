defmodule NostrexWeb.NostrSocket do
  # NOT USING Phoenix.Socket because it requires a proprietary wire protocol that is incompatible with Nostr
  # Implementing a custom module with the Phoenix.Socket.Transport behaviour instead
  require Logger

  alias Nostrex.Events
  alias Nostrex.Events.Filter
  alias Nostrex.FastFilter
  alias NostrexWeb.MessageParser
  alias Phoenix.PubSub

  @moduledoc """
    Module implementing core socket relay interface for clients
  """

  @behaviour Phoenix.Socket.Transport

  @impl true
  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl true
  def connect(state) do
    socket_rate_limit = Application.fetch_env!(:nostrex, :socket_rate_limit)

    Logger.info("Client connection attempt: #{inspect(state)}")

    ip_address = get_ip_from_state(state)

    case Hammer.check_rate("socket:#{ip_address}", 60_000, socket_rate_limit) do
      {:allow, _count} ->
        Logger.info("Connecting with state #{inspect(state)}")
        Telemetry.Metrics.counter("nostrex.socket.open")
        {:ok, state}

      {:deny, _limit} ->
        Logger.info("Socket rate limit exceeded #{inspect(state)}")
        {:error, state}
    end
  end

  @impl true
  def init(state) do
    Logger.info("Websocket init state: #{inspect(state)}")

    initial_state = %{
      subscriptions: %{},
      ip: get_ip_from_state(state)
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_in(frame, state)

  # Implement basic ping pong handler for easy health checking
  def handle_in({"ping", _opts}, state) do
    Logger.info("Ping endpoint hit")
    {:reply, :ok, {:text, "pong"}, state}
  end

  # Handles all Nostr [EVENT] messages. This endpoint is very DB write heavy
  # and is called by clients to publishing new Nostr events
  def handle_in({req = "[\"EVENT\"," <> _, _opts}, state) do
    Logger.info("Inbound EVENT message: #{req}")
    event_params = MessageParser.parse_and_sanity_check_event_message(req)

    Logger.info("Creating event with params #{inspect(event_params)}")

    event_rate_limit = Application.fetch_env!(:nostrex, :event_rate_limit)

    resp =
      case Hammer.check_rate("event:#{state.ip}", 60_000, event_rate_limit) do
        {:allow, _count} ->
          case Events.create_event(event_params) do
            {:ok, event} ->
              FastFilter.process_event(event)
              gen_notice("successfully created event #{event.id}")

            {:error, errors} ->
              Logger.error("failed to save event #{inspect(errors)}")
              gen_notice("error: unable to save event")
          end

        {:deny, _limit} ->
          Logger.error("rate limit exceeded for event message #{inspect(req)}")
          gen_notice("error: rate limit exceeded")
      end

    {:reply, :ok, {:text, resp}, state}
  end

  @doc """
  Handles all Nostr [REQ] messages. This endpoint is very DB read heavy
  and also grows the in-memory PubSub state. It's used by clients
  to query and subscribe to events based on a filter
  """
  def handle_in({req = "[\"REQ\"," <> _, _opts}, state) do
    Logger.info("Inbound REQ message: #{req}")

    {:ok, list} = Jason.decode(req, keys: :atoms)
    [_, subscription_id | filters] = list

    filter_rate_limit = Application.fetch_env!(:nostrex, :filter_rate_limit)

    # TODO, ensure subscription_id doesn't have colon since we use as separator in filter_id
    case Hammer.check_rate("filter:#{state.ip}", 60_000, filter_rate_limit) do
      {:allow, _count} ->
        new_state = handle_req_event(state, subscription_id, filters)
        resp = gen_notice("successfully created subscription #{subscription_id}")
        {:reply, :ok, {:text, resp}, new_state}

      {:deny, _limit} ->
        Logger.error("rate limit exceeded for REQ message #{inspect(req)}")
        resp = gen_notice("error: rate limit exceeded")
        {:reply, :ok, {:text, resp}, state}
    end
  end

  # Handles all Nostr [CLOSE] messages. This endpoint is very ETS read heavy
  # and also grows the in-memory PubSub state. This message includes a subscription
  # id, but we need to be sure we're only closing the subscription ids that belong to this
  # channel, otherwise we open ourselves up to somebody spamming in an attempt to close
  # subscriptions for other clients
  def handle_in({req = "[\"CLOSE\"," <> _, _opts}, state) do
    Logger.info("Inbound Close message #{req}")

    {:ok, list} = Jason.decode(req)

    # TODO, validate subscription ID
    subscription_id = Enum.at(list, 1)
    remove_subscription(state, subscription_id)
    close_msg = gen_notice("Closed subscription #{subscription_id}")

    {:reply, :ok, {:text, close_msg}, state}
  end

  # # This function is where we will process all *other* messages that get delivered to the
  # # process mailbox. This function isn't used in this handler.
  @impl true
  def handle_info(info, state)

  def handle_info({:events, events, subscription_id}, state) when is_list(events) do
    Logger.info("Sending events #{inspect(events)} to subscription #{subscription_id}")
    event_json = MessageParser.generate_event_list_response(events, subscription_id)
    {:push, {:text, event_json}, state}
  end

  # Process handler that should not be called, but implemented to catch any unexpected
  # messages and log them
  def handle_info(info, state) do
    msgs = Process.info(self(), :messages)

    Logger.error("""
    default websocket event handler (shouldn't be called)
    #{inspect(info)}
    #{inspect(state)}
    #{inspect(msgs)}
    """)

    {:ok, state}
  end

  # Gets called when the socket is killed. This is where we implement cleanup logic
  # for filtering
  @impl true
  def terminate(_, state) do
    ## Ensure any state gets cleaned up before terminating
    state.subscriptions
    |> Enum.each(fn {sub_id, _set} ->
      remove_subscription(state, sub_id)
    end)

    Telemetry.Metrics.counter("nostrex.socket.open")

    Logger.info("Websocket terminate called with state: #{inspect(state)}")
    :ok
  end

  # increments a counter on the state object
  # defp increment_state_counter(state, key) do
  #   put_in(state, [key], state[key] + 1)
  # end

  defp handle_req_event(state, _subscription_id, filters) when filters == [] do
    state
  end

  defp handle_req_event(state, subscription_id, unsanitized_filter_params) do
    # TODO move to safer place to only happen for future subscriptions, not all
    # register the subscriber
    PubSub.subscribe(Nostrex.PubSub, subscription_id)

    # TODO check subscription doesn't already exist
    state = put_in(state, [:subscriptions, subscription_id], MapSet.new())

    filters =
      unsanitized_filter_params
      |> Enum.map(fn params ->
        params
        |> Map.put(:subscription_id, subscription_id)
        |> Events.create_filter()
      end)

    # Iterate through filters, but use reduce to update state object throughout
    Enum.reduce(filters, state, fn filter, state ->
      # first get historical data for any filter
      query_and_return_historical_events(filter)

      # then subscribe to future events if relevant
      # it will return state object
      setup_future_subscription(filter, state, subscription_id)
    end)
  end

  defp query_and_return_historical_events(filter = %Filter{}) do
    Logger.info("Querying historical events for subscription: #{filter.subscription_id}")
    # query db for events and broadcast back to this subscribing socket
    Events.get_events_matching_filter_and_broadcast(filter)
  end

  defp setup_future_subscription(filter, state, subscription_id) do
    if filter.until == nil or !timestamp_before_now?(filter.until) do
      filter
      |> FastFilter.insert_filter()

      update_in(state, [:subscriptions, subscription_id], &MapSet.put(&1, filter))
    else
      state
    end
  end

  defp remove_subscription(state, subscription_id) do
    Logger.info("Cleanup subscription #{subscription_id} from ETS")

    filters = get_in(state, [:subscriptions, subscription_id])

    if filters != nil do
      Enum.each(filters, fn filter ->
        FastFilter.delete_filter(filter)
      end)
    end

    update_in(state.subscriptions, &Map.delete(&1, subscription_id))
  end

  # TODO: consider adding some larger buffer here
  defp timestamp_before_now?(unix_timestamp) do
    DateTime.compare(DateTime.from_unix!(unix_timestamp), DateTime.utc_now()) == :lt
  end

  defp gen_notice(message) do
    ~s(["NOTICE", "#{message}"])
  end

  # TODO make IP setting/header configurable since not all infra will be the same
  defp get_ip_from_state(state) do
    x_forwarded_for =
      state.connect_info.x_headers
      |> Enum.find(fn x -> elem(x, 0) == "x-forwarded-for" end)

    case x_forwarded_for do
      nil ->
        state.connect_info.peer_data.address |> :inet.ntoa() |> to_string()

      _ ->
        elem(x_forwarded_for, 1)
    end
  end
end
