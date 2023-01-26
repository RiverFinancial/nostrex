defmodule Nostrex.FixtureFactory do
  @moduledoc """
  Fixture Factory
  """

  alias Nostrex.Events
  alias Nostrex.Events.Filter

  import Ecto.Changeset

  def create_signed_event(opts \\ []) do
    # Event.sign will overwrite the random id and sig
    {:ok, event} =
      opts
      |> populate_default_event_params()
      |> Events.create_and_sign_event()
    event
  end

  def create_event_no_validation(opts \\ []) do
    {:ok, event} =
      opts
      |> populate_default_event_params()
      |> Events.create_event_no_validation()
    event
  end

  defp populate_default_event_params(opts \\ []) do
    defaults = %{
      id: rand_identifier(),
      pubkey: rand_identifier(),
      created_at: DateTime.to_unix(DateTime.utc_now()),
      kind: 1,
      content: "test string",
      sig: rand_identifier() <> rand_identifier(),
      p: [],
      e: []
    }

    params = Enum.into(opts, defaults)

    tags =
      Enum.map(params[:p], fn p ->
        %{
          type: "p",
          field_1: p,
          field_2: "test",
          full_tag: ["p", p, "test"]
        }
      end)

    tags =
      tags ++
        Enum.map(params[:e], fn e ->
          %{
            type: "e",
            field_1: e,
            field_2: "test",
            full_tag: ["e", e, "test"]
          }
        end)

    params = Map.put(params, :tags, tags)

    raw = Jason.encode!(params)

    Map.put(params, :raw, raw)
  end

  def create_filter(opts \\ []) do
    defaults = %{
      ids: [],
      authors: [],
      kinds: [],
      "#e": [],
      "#p": [],
      since: nil,
      until: nil,
      limit: nil,
      subscription_id: rand_identifier()
    }

    params = Enum.into(opts, defaults)

    %Filter{}
    |> Filter.changeset(params)
    |> apply_action!(:update)
  end

  def create_filter_from_string(str, sub_id \\ nil) do
    params =
      str
      |> Jason.decode!(keys: :atoms)
      |> Map.put(:subscription_id, sub_id || "subid#{:rand.uniform(99)}")

    %Filter{}
    |> Filter.changeset(params)
    |> apply_action!(:update)
  end

  defp rand_identifier do
    :crypto.hash(:sha256, Integer.to_string(:rand.uniform(99_999_999_999)))
    |> Base.encode16(case: :lower)
  end
end
