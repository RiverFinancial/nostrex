defmodule Nostrex.Events.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  alias Nostrex.Events.Event

  @primary_key false
  schema "tags" do
    field :type, :string
    field :field_1, :string
    field :field_2, :string
    field :full_tag, {:array, :string}
    field :event_created_at, :integer
    belongs_to :event, Event, type: :string, references: :id

    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:type, :field_1, :field_2, :full_tag])
    |> validate_required([:type, :field_1, :field_2, :full_tag])
  end

  def event_changeset(tag, attrs, created_at) do
    tag
    |> cast(%{event_created_at:  created_at}, [:event_created_at])
    |> cast(attrs, [:type, :field_1, :field_2, :full_tag])
    |> validate_required([:event_created_at, :type, :field_1, :field_2, :full_tag])
  end
end
