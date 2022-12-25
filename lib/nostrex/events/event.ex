defmodule Nostrex.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "events" do
    field :pubkey, :string
    field :created_at, :utc_datetime
    field :kind, :integer
    field :content, :string
    field :sig, :string
    timestamps()
  end

  @required_attrs ~w(id pubkey created_at kind content sig)a
  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> validate_length(:id, is: 64) # 64 character hex string for 32 bytes
    |> validate_length(:pubkey, is: 64)
    |> validate_length(:sig, is: 64*2)
  end
end
