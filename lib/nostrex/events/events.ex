defmodule Nostrex.Events do
  @moduledoc """
  Context module for Nostr events
  """

  alias Nostrex.Repo
  alias Nostrex.Events.{Event, Filter}
  alias Bitcoinex.Secp256k1.PrivateKey
  import Ecto.Changeset
  import Ecto.Query
  alias Phoenix.PubSub
  require Logger

  def create_event(params) do
    %Event{}
    |> Event.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Only to be used for testing purposes. This makes it easy to test
  serialization, signature verification, and signing
  """
  def create_and_sign_event(params, %PrivateKey{} = sk) do
    %Event{}
    |> Event.test_only_changeset_no_validation( params)
    |> Event.sign(e, sk)
    |> Repo.insert()
  end

  @doc """
  Only to be used for testing purposes. This makes it easy to test
  filter logic with simple, human readable identifiers
  """
  def create_event_no_validation(params) do
    %Event{}
    |> Event.test_only_changeset_no_validation(params)
    |> Repo.insert()
  end

  def get_event_count do
    Repo.aggregate(Event, :count)
  end

  def get_event_by_id!(id) do
    Repo.get(Event, id) |> Repo.preload([:tags])
  end

  # Only creating filter object in mem. No db calls
  def create_filter(params) do
    %Filter{}
    |> Filter.changeset(params)
    |> apply_action!(:update)
  end

  def get_events_matching_filter_and_broadcast(%Filter{} = filter) do
    events = get_events_matching_filter(filter)
    Logger.info("Looking for past events in get_events_matching_filter_and_broadcast")
    Logger.info(inspect(filter))
    Logger.info(inspect(events))

    broadcast_events(events, filter.subscription_id)
  end

  defp broadcast_events([], _subscription_id), do: true

  defp broadcast_events(events, subscription_id) do
    Logger.info("Returning #{Enum.count(events)} events to subscriber #{subscription_id}")
    # TODO: look at chunking this up if the response sizes are too large
    PubSub.broadcast!(
      Nostrex.PubSub,
      subscription_id,
      {:events, events, subscription_id}
    )
  end

  def get_events_matching_filter(%Filter{} = filter) do
    cond do
      # return nil if filter since is in the future
      filter.since != nil and !timestamp_before_now?(filter.since) ->
        []

      filter.until != nil and timestamp_before_now?(filter.until) ->
        []

      filter.limit != nil and filter.limit == 0 ->
        []

      true ->
        query_historical_events(filter)
    end
  end

  defp query_historical_events(filter) do
    q = filter_query(filter)

    # NOTE: be sure to comment back below if uncommented for debugging
    # Inspect SQL generated
    # IO.inspect(
    #   Ecto.Adapters.SQL.to_sql(:all, Repo, q)
    # )

    Repo.all(q)
  end

  defp filter_query(filter) do
    # TODO, change this default
    query_limit = filter.limit || 100
    filter_map = Map.from_struct(filter)

    # if scalar conditionals add scalar where clause with and statements
    # if list conditionals add where clause with or statements

    # TODO see if this code is optimal
    # No need to preload tags since we are going to return raw event field to user
    Event
    |> distinct(true)
    |> join(:left, [e], t in assoc(e, :tags), as: :tags)
    |> where(^filter_by(:kinds, filter.kinds))
    |> where(^filter_by(:since, filter.since))
    |> where(^filter_by(:until, filter.until))
    |> where(^filter_where(filter_map))
    |> limit(^query_limit)
  end

  defp filter_by(_, nil), do: []
  defp filter_by(_, []), do: []

  defp filter_by(:kinds, kinds) do
    dynamic([e], e.kind in ^kinds)
  end

  defp filter_by(:since, since) do
    dynamic([e], e.created_at > ^since)
  end

  defp filter_by(:until, until) do
    dynamic([e], e.created_at < ^until)
  end

  # if all empty lists, return empty
  def filter_where(%{ids: [], authors: [], "#e": [], "#p": []}), do: []

  def filter_where(filter) do
    # where false + other conditions
    Enum.reduce(filter, dynamic(false), fn
      # keep going if no value
      {_, nil}, dynamic ->
        dynamic

      {_, []}, dynamic ->
        dynamic

      # ignore subscription id param
      {:subscription_id, _}, dynamic ->
        dynamic

      # handle limit elsewhere, not a "where" condition
      {:ids, list}, dynamic ->
        dynamic([e], ^dynamic or e.id in ^list)

      {:authors, list}, dynamic ->
        dynamic([e], ^dynamic or e.pubkey in ^list)

      {:"#e", list}, dynamic ->
        dynamic([tags: t], ^dynamic or (t.type == "e" and t.field_1 in ^list))

      {:"#p", list}, dynamic ->
        dynamic([tags: t], ^dynamic or (t.type == "p" and t.field_1 in ^list))

      # keep going if no value
      {_, _}, dynamic ->
        dynamic
    end)
  end

  # TODO: DRY this code up, also exists in socket module
  defp timestamp_before_now?(unix_timestamp) do
    DateTime.compare(DateTime.from_unix!(unix_timestamp), DateTime.utc_now()) == :lt
  end
end
