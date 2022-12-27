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
    # 64 character hex string for 32 bytes
    |> validate_length(:id, is: 64)
    |> validate_length(:pubkey, is: 64)
    |> validate_length(:sig, is: 64 * 2)
    # required to prevent throwing error on duplicate entry
    |> unique_constraint(:id, name: "events_pkey")
  end

  @doc """
  This method is for taking an untrusted JSON string that could have unapproved inputs
  and converting it into a clean atom map to pass to Events.create_event
  """
  # TODO: don't throw error when non-valid keys sent
  def json_string_to_map(event_str) do
    # key_whitelist = ["id", "pubkey", "created_at", "kind", "conetent", "sig", "tags"]
    {:ok, map} = Jason.decode(event_str, keys: :atoms!)
    map
  end

  # TODO, move these to the Event struct as they are very much scoped purely for validation

  @doc """
  This is the serialization required to generate an event ID or sign an event.
  Takes an %Event{} struct and returns a JSON string to be signed.
  See https://github.com/nostr-protocol/nips/blob/master/01.md#events-and-signatures for further reference
  """
  def serialize(event) do
    Jason.encode([
      0,
      event.pubkey,
      DateTime.to_unix(event.created_at, :second),
      event.kind,
      # TODO: add tag functionality next
      [],
      event.content
    ])
  end

  @doc """
  Calculates the event id given an %Event{} struct.
  Returns lowercase hex string
  """
  def calculate_id(event) do
    {:ok, serialized_event} = serialize(event)

    :crypto.hash(:sha256, serialized_event)
    |> Base.encode16(case: :lower)
  end

  # TODO
  defp validate(event) do
    # validate event ID
    # validate signature
  end

  # TODO
  defp validate_signature(pubkey, event_id, sig) do
  end
end