defmodule Nostrex.Events do
	alias Nostrex.Repo
	alias Nostrex.Events.Event

	def create_event(params) do
		%Event{}
		|> Event.changeset(params)
		|> Repo.insert()
	end
end