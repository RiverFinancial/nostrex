defmodule Nostrex.FastFilter do
  alias Nostrex.Events.{Event, Filter}
  alias Phoenix.PubSub
  require Logger

  @moduledoc """
  This module provides the tooling and algorithm to utilize a KV store for Nostr-specific
  fast lookups to power efficent event broadcasting to subscribers. The current
  implementation is hardcoded to ETS, but this may change down the road. This tooling
  is only used for routing *future* events, not querying past events to return to a single
  subscriber

  The benefit of ETS is that it is built in, simple and fast. The downside is that
  it is not persistent across deploys, but based on our understanding of NIP-1 this
  shouldn't be an issue because filters should die when socket connections die and
  socket connections die on redeploys.

  The data model implemented here is a doubly-linked hashtable with the following sructure

  filter_ids_table
  	subscription_id -> Set of author_pubkeys, event_ids, filter_ids
  	subscriptions table is used for cleaning up other tables when sockets die

  authors_filter_table
  	author_pubkey -> [filter_ids]
  e_filters_table
  	event_id -> [filter_ids]
  p_filters_table
  	author_pubkey-> [filter_ids]

  When a new event comes in, the following logic is run:

  Assumptions:
  1. sockets own removing any filters that have expired
  2. sockets own filtering on kind types??

  filter_id format: type:kinds:subscription_id

  create 3 filter_set MapSet objects

  create a_filter_set
  create e_filter_set
  create p_filter_set

  create already_broadcast_sub_id MapSet object


  for the author pubkey
  	get filter ids from authors_filter_table
  	for each filter_id:

  		if filter fingerprint == 'a', then broadcast to filter's subscription and add sub_id to already_broadcast_sub_id if subscription_id not in already_broadcast_sub_id
  		else add to filter to filter_set

  for the referenced authors in the p tags
  	get filter_ids from p_filters_table for every pubkey referenced
  		for each filter_id
  			if filter_fingerprint == 'p'
  				if sub_id not in already_broadcast_sub_id
  					broadcast to filter subscription id and add sub_id to already_broadcast_sub_id
  			else
  				add fingerprint to filter_set if doesn't include an 'a' in the fingerprint
  for the referenced event ids in any e tag
  	get subscription ids pointed to by the e tags for every event referenced

  for every subscription in the set broadcast the event



  When a subscription needs to be deleted (called when socket dies), run the following logic:
  1. find all authors and events subscribed to by subscription
  2. remove subscription id from each of the ets tables

  """
  def insert_filter(filter = %Filter{}) do
    filter_id = generate_filter_id(filter)

    Logger.info(
      "Inserting filter with id #{filter_id} for subscription #{filter.subscription_id}"
    )

    # setup content identifier (author, e tag, ptag) -> filter_id tables
    ets_insert(:nostrex_ff_pubkeys, filter_id, filter.authors)
    ets_insert(:nostrex_ff_ptags, filter_id, filter."#p")
    ets_insert(:nostrex_ff_etags, filter_id, filter."#e")
    ets_insert_kinds(filter_id, filter.kinds)
  end

  defp ets_insert(table_name, filter_id, keys) when is_list(keys) do
    for key <- keys do
      :ets.insert(table_name, {key, filter_id})
    end
  end

  # :ets.insert() returns true or false as well so just imitating here
  defp ets_insert(_, _, _) do
    true
  end

  defp ets_insert_kinds(_filter_id, kinds) when is_nil(kinds) do
    true
  end

  defp ets_insert_kinds(filter_id, kinds) do
    for kind <- kinds do
      :ets.insert(:nostrex_ff_kinds, {filter_id, kind})
    end
  end

  defp ets_delete(table_name, filter_id, keys) when is_list(keys) do
    for key <- keys do
      # does not throw error if key or object doesn't exist
      :ets.delete_object(table_name, {key, filter_id})
    end
  end

  defp ets_delete(_, _, _) do
    true
  end

  def delete_filter(filter) do
    Logger.info("Deleting filters for sub_id: #{filter.subscription_id}")
    filter_id = generate_filter_id(filter)

    # TODO: improve efficiency by only deleting from necessary table
    ets_delete(:nostrex_ff_pubkeys, filter_id, filter.authors)
    ets_delete(:nostrex_ff_ptags, filter_id, filter."#p")
    ets_delete(:nostrex_ff_etags, filter_id, filter."#e")

    # delete kind entries
    :ets.delete(:nostrex_ff_kinds, filter_id)
  end

  def process_event(event = %Event{pubkey: pubkey, tags: tags, kind: _kind}) do
    # create base data structures for algo

    filter_logic_state = %{
      a_filter_set: MapSet.new(),
      p_filter_set: MapSet.new(),
      e_filter_set: MapSet.new(),
      already_broadcast_sub_ids: MapSet.new()
    }

    # lookup filters subcribed to author
    author_match_filters = ets_lookup(:nostrex_ff_pubkeys, pubkey)

    new_state =
      author_match_filters
      |> Enum.reduce(filter_logic_state, fn f, state ->
        %{code: code} = parse_filter_id(f)

        if code == "a" do
          broadcast_and_update_state(state, event, f)
        else
          Map.put(
            state,
            :a_filter_set,
            MapSet.put(state[:a_filter_set], f)
          )
        end
      end)

    # categorize tags by type
    p_tags = Enum.filter(tags, fn t -> t.type == "p" end)
    e_tags = Enum.filter(tags, fn t -> t.type == "e" end)

    new_state =
      p_tags
      |> Enum.reduce(new_state, fn t, state ->
        # lookup filters subscribed to p tags

        ets_lookup(:nostrex_ff_ptags, t.field_1)
        |> Enum.reduce(state, fn f, state ->
          %{code: code} = parse_filter_id(f)

          case code do
            "p" ->
              broadcast_and_update_state(state, event, f)

            # check if filter is type ap or ape and filter_set includes current filter, if so broacast
            "ap" ->
              if MapSet.member?(state[:a_filter_set], f) do
                broadcast_and_update_state(state, event, f)
              else
                Map.put(
                  state,
                  :p_filter_set,
                  MapSet.put(state[:p_filter_set], f)
                )
              end

            n when n in ["pe", "ape"] ->
              Map.put(
                state,
                :p_filter_set,
                MapSet.put(state[:p_filter_set], f)
              )
          end
        end)
      end)

    # returns new state after iterating through e_tags (should still work if list empty)
    e_tags
    |> Enum.reduce(new_state, fn t, state ->
      # lookup filters subscribed to p tags
      ets_lookup(:nostrex_ff_etags, t.field_1)
      |> Enum.reduce(state, fn f, state ->
        %{code: code} = parse_filter_id(f)

        case code do
          "e" ->
            broadcast_and_update_state(state, event, f)

          "ae" ->
            if MapSet.member?(state[:a_filter_set], f) do
              broadcast_and_update_state(state, event, f)
            else
              state
            end

          "pe" ->
            if MapSet.member?(state[:p_filter_set], f) do
              broadcast_and_update_state(state, event, f)
            else
              state
            end

          "ape" ->
            if MapSet.member?(state[:a_filter_set], f) and MapSet.member?(state[:p_filter_set], f) do
              broadcast_and_update_state(state, event, f)
            else
              # ignore filter, as there's no a match
              state
            end
        end
      end)
    end)
  end

  def generate_filter_id(filter) do
    code = generate_filter_code(filter)

    # https://www.erlang.org/doc/man/erlang.html#phash2-2
    "#{code}:#{filter.subscription_id}:#{:erlang.phash2(filter)}"
  end

  def parse_filter_id(filter_id) do
    [code, subscription_id, _] = String.split(filter_id, ":")

    %{
      code: code,
      subscription_id: subscription_id
    }
  end

  @doc """
  generates a fingerprint that includes non or all of the letters: a, p, e
  """
  def generate_filter_code(filter = %Filter{}) do
    ""
    |> append_if(filter.authors, "a")
    |> append_if(filter."#p", "p")
    |> append_if(filter."#e", "e")
  end

  defp append_if(string, condition, string2) do
    if condition, do: string <> string2, else: string
  end

  defp ets_lookup(table, value) do
    try do
      # lookup second value in tuple
      :ets.lookup_element(table, value, 2)
    rescue
      # catch ArgumentError if no result is found for given key
      ArgumentError -> []
    end
  end

  defp broadcast_and_update_state(state, event = %Event{}, filter_id) do
    %{subscription_id: subscription_id} = parse_filter_id(filter_id)

    Logger.info("Broadcasting event for filter ID #{filter_id}")
    broadcast_event(state[:already_broadcast_sub_ids], filter_id, subscription_id, event)

    Map.put(
      state,
      :already_broadcast_sub_ids,
      MapSet.put(state[:already_broadcast_sub_ids], subscription_id)
    )
  end

  defp broadcast_event(already_broadcast_sub_ids, filter_id, subscription_id, event) do
    # kind check
    kinds = ets_lookup(:nostrex_ff_kinds, filter_id)
    kind_match? = event.kind in kinds or kinds == []
    # only broadcast if not already broadcast to this subscription id
    unless MapSet.member?(already_broadcast_sub_ids, subscription_id) or !kind_match? do
      PubSub.broadcast(:nostrex_pubsub, subscription_id, {:events, [event], subscription_id})
    end
  end
end
