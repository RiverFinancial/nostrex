defmodule Nostrex.Events.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  alias Nostrex.Events.Event

  schema "tags" do
    field :type, :string
    field :field_1, :string
    field :field_2, :string
    field :full_tag, {:array, :string}
  	belongs_to :event, Event, type: :string

    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:type, :field_1, :field_2, :full_tag])
    |> validate_required([:type, :field_1, :field_2, :full_tag])
  end
end