defmodule Nostrex.FastFilter do
  alias Nostrex.Events.{Event, Filter}

  @moduledoc """
  This module provies the tooling to utilize a KV store for Nostr-specific
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



  # Create ETS tables on startup
  # Gets called in Application.ex
  # def setup() do
  #   ets_opts = [:set, :public, write_concurrency: true, read_concurrency: true]
  #   for table <- @ets_tables do
  #     IO.puts "creating table"
  #     :ets.new(table, ets_opts)
  #   end
  # end

  def insert_filter(filter = %Filter{}) do
    filter_id = generate_filter_id(filter)
  end

  def delete_filter() do
  end

  def process_event(author_pubkey: pubkey, tags: tags, kind: kind, raw_event: raw_event) do
  end

  defp generate_filter_id(filter = %Filter{}) do
  end
end
