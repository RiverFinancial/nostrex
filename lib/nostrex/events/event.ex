defmodule Nostrex.Events.Event do
  @moduledoc """
  Ecto schema for Nostr events
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Nostrex.Events.Tag
  alias Bitcoinex.Secp256k1.{Point, Signature, Schnorr, PrivateKey}

  @primary_key {:id, :string, autogenerate: false}
  # @primary_key false

  schema "events" do
    field :pubkey, :string
    field :created_at, :integer
    field :kind, :integer
    field :content, :string
    field :sig, :string
    field :raw, :string
    # raw event json
    # ensures tags get returned in order they are saved
    has_many :tags, Tag, preload_order: [asc: :id]
    timestamps()
  end

  @required_attrs ~w(id pubkey created_at kind content sig raw)a
  @doc false
  # TODO, validate raw length isn't insane
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_attrs)
    |> cast_assoc(:tags, with: {Tag, :event_changeset, [attrs[:created_at]]})
    |> validate_required(@required_attrs)
    # 64 character hex string for 32 bytes
    |> validate_length(:id, is: 64)
    |> validate_length(:pubkey, is: 64)
    |> validate_length(:sig, is: 64 * 2)
    # required to prevent throwing error on duplicate entry, suffix match required due to postgres
    # automatically adding partition name to index
    |> unique_constraint([:id, :created_at], name: :id_created_at_idx, match: :suffix)
  end

  # Only to be used by tests
  def test_only_changeset_no_validation(event, attrs) do
    event
    |> cast(attrs, @required_attrs)
    |> cast_assoc(:tags, with: {Tag, :event_changeset, [attrs[:created_at]]})
    |> validate_required(@required_attrs)
  end

  # @doc """
  # This method is for taking an untrusted JSON string that could have unapproved inputs
  # and converting it into a clean atom map to pass to Events.create_event

  # This also turns the tags list into a map for creating associated tags
  # """
  # TODO: don't throw error when non-valid keys sent
  # def json_string_to_map(event_str) do
  #   # key_whitelist = ["id", "pubkey", "created_at", "kind", "conetent", "sig", "tags"]
  #   {:ok, map} = Jason.decode(event_str, keys: :atoms!)

  #   Map.update(map, :tags, fn val ->
  #     if val == nil or val == [] do
  #       val
  #     else
  #       # convert lits

  #       val
  #     end
  #   end)
  # end

  # defp convert_tag_list_to_map_list(tags) do
  # end

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
      event.created_at,
      event.kind,
      event.tags,
      event.content
    ])
  end

  @doc """
  Calculates the event id given an %Event{} struct.
  Returns lowercase hex string
  """
  def calculate_id(event) do
    {:ok, serialized_event} = serialize(event)
    serialized_event
    |> Bitcoinex.Utils.sha256()
    |> Base.encode16(case: :lower)
  end

  def validate(%__MODULE__{pubkey: pubkey, id: id, sig: signature} = event) do
    # validate event ID
    if id != calculate_id(event) do
      {:error, "incorrect event id"}
    else
      # validate signature
      validate_signature(pubkey, id, signature)
    end
  end

  defp validate_signature(pubkey, event_id, signature) do
    {:ok, pk} = Point.lift_x(pubkey)
    {:ok, sig} = Signature.parse_signature(signature)

    z =
      event_id
      |> Base.decode16!(case: :lower)
      |> :binary.decode_unsigned()

    case {pk, sig} do
      {{:error, msg}, _} ->
        {:error, "failed to read event pubkey: #{msg}"}

      {_, {:error, msg}} ->
        {:error, "failed to read event signature: #{msg}"}

      {%Point{} = pk, %Signature{} = sig} ->
        Schnorr.verify_signature(pk, z, sig)
    end
  end

  def sign(%__MODULE__{} = event, %PrivateKey{} = sk) do
    id = calculate_id(event)
    z =
      id
      |> Base.decode16!(case: :lower)
      |> :binary.decode_unsigned()

    aux = get_rand_uint(32)

    {:ok, signature} = Schnorr.sign(sk, z, aux)
    sig = serialize_signature(signature)

    %__MODULE__{event | id: id, sig: sig}
  end

  defp get_rand_uint(len) do
    len
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
  end

  defp serialize_signature(%Signature{} = sig) do
    sig
    |> Signature.serialize_signature()
    |> Base.encode16(case: :lower)
  end
end
