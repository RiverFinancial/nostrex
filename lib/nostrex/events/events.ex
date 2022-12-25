defmodule Nostrex.Events do
	alias Nostrex.Repo
	alias Nostrex.Events.Event

	def create_event(params) do
		%Event{}
		|> Event.changeset(params)
		|> Repo.insert()
	end


	# TODO, move these to the Event struct as they are very much scoped purely for validation

	@doc """
	This is the serialization required to generate an event ID or sign an event.
	Takes an %Event{} struct and returns a JSON string to be signed.
	See https://github.com/nostr-protocol/nips/blob/master/01.md#events-and-signatures for further reference
	"""
	def serialize_event(%Event{} = event) do
		Jason.encode([
			0,
			event.pubkey,
			DateTime.to_unix(event.created_at, :second),
			event.kind,
			[], # TODO: add tag functionality next
			event.content
		])
	end

	@doc """
	Calculates the event id given an %Event{} struct.
	Returns lowercase hex string
	"""
	def calculate_event_id(%Event{} = event) do
		{:ok, serialized_event} = serialize_event(event)
		:crypto.hash(:sha256, serialized_event)
		|> Base.encode16(case: :lower)
	end

	# TODO
	defp validate_event(event) do
		# validate event ID
		# validate signature
	end

	# TODO
  defp validate_signature(pubkey, event_id, sig) do
    
  end
end