defmodule Nostrex.FixtureFactory do
  alias Nostrex.Events
  alias Nostrex.Events.Filter

  import Ecto.Changeset

  def create_event_no_validation(a: a, p: ps, e: es, k: k) do
    tags =
      Enum.map(ps, fn p ->
        %{
          type: "p",
          field_1: p,
          field_2: "test",
          full_tag: ["p", p, "test"]
        }
      end)

    tags =
      tags ++
        Enum.map(es, fn e ->
          %{
            type: "e",
            field_1: e,
            field_2: "test",
            full_tag: ["e", e, "test"]
          }
        end)

    rand_event_id =
      :crypto.hash(:sha256, Integer.to_string(:rand.uniform(99_999_999_999)))
      |> Base.encode16()
      |> String.downcase()

    k = if is_nil(k), do: 2, else: k

    params = %{
      id: rand_event_id,
      pubkey: a,
      created_at: DateTime.utc_now(),
      # TODO: test kind filters next
      kind: k,
      content: "test content",
      # just reuse event id since we're not testing any validation here
      sig: rand_event_id,
      tags: tags
    }

    {:ok, event} = Events.create_event_no_validation(params)
    event
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
end
