defmodule Nostrex.Events do
  alias Nostrex.Repo
  alias Nostrex.Events.{Event, Filter}
  import Ecto.Changeset
  import Ecto.Query

  def create_event(params) do
    %Event{}
    |> Event.changeset(params)
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

  def get_event_count() do
    Repo.aggregate(Event, :count)
  end

  # Only creating filter object in mem. No db calls
  def create_filter(params) do
    %Filter{}
    |> Filter.changeset(params)
    |> apply_action!(:update)
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
    filter
    |> filter_query()
    |> Repo.all()
  end

  defp filter_query(filter) do
    # TODO, change this default
    query_limit = filter.limit || 100

    Event
    |> join(:inner, [e], assoc(e, :tags), as: :tags)
    |> where(^filter_where(filter))
    |> limit(^query_limit)
  end

  # schema "events" do
  #   field :pubkey, :string
  #   field :created_at, :utc_datetime
  #   field :kind, :integer
  #   field :content, :string
  #   field :sig, :string
  #   has_many :tags, Tag
  #   timestamps()
  # end

  # See https://hexdocs.pm/ecto/dynamic-queries.html#dynamic-and-joins
  def filter_where(filter) do
    Enum.reduce(filter, dynamic(true), fn
      # keep going if no value
      {_, nil}, dynamic ->
        dynamic
      # ignore subscription id param
      {:subscription_id, _}, dynamic ->
        dynamic
      # handle limit elsewhere, not a "where" condition
      {:limit, _}, dynamic ->
        dynamic
      {:ids, list}, dynamic ->
        dynamic([e], ^dynamic and e.id in ^list)
      {:authors, list}, dynamic ->
        dynamic([e], ^dynamic and e.pubkey in ^list)
      {:kinds, list}, dynamic ->
        dynamic([e], ^dynamic and e.kind in ^list)
      {:"#e", list}, dynamic ->
        dynamic([tags: t], ^dynamic and t.type == "e" and t.field_1 in ^list)
      {:"#p", list}, dynamic ->
        dynamic([tags: t], ^dynamic and t.type == "p" and t.field_1 in ^list)
      {:since, timestamp}, dynamic -> # TODO: look at or equals for both time conditions
        dynamic([e], ^dynamic and e.created_at > ^timestamp)
      {:until, timestamp}, dynamic ->
        dynamic([e], ^dynamic and e.created_at < ^timestamp)
    end)
  end

  # TODO: DRY this code up, also exists in socket module
  defp timestamp_before_now?(unix_timestamp) do
    DateTime.compare(DateTime.from_unix!(unix_timestamp), DateTime.utc_now()) == :lt
  end
end
