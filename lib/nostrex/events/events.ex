defmodule Nostrex.Events do
  alias Nostrex.Repo
  alias Nostrex.Events.{Event, Filter}
  import Ecto.Changeset

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
end
