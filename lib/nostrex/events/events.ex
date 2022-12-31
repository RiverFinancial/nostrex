defmodule Nostrex.Events do
  alias Nostrex.Repo
  alias Nostrex.Events.Event

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
end
