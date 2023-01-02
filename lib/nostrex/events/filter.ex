defmodule Nostrex.Events.Filter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "filters" do
    field :ids, {:array, :string}
    field :authors, {:array, :string}
    field :kinds, {:array, :integer}
    field :"#e", {:array, :string}
    field :"#p", {:array, :string}
    field :since, :integer
    field :until, :integer
    field :limit, :integer
    field :subscription_id, :string
  end

  # defstruct [:ids, :authors, :kinds, :e, :p, :since, :until, :limit]

  @optional_attrs ~w(ids authors kinds #e #p since until limit subscription_id)a

  def changeset(filter, attrs) do
    filter
    |> cast(attrs, @optional_attrs)
    |> validate_required(:subscription_id)
    |> validate_one_field_not_empty()
  end

  defp validate_one_field_not_empty(changeset) do
    has_at_least_one_param? = Enum.reduce_while(changeset.changes, false, fn {k, v}, acc ->
      case {k, v} do
        {:subscription_id, _} ->
          {:cont, false}
        {_k, nil} ->
          {:cont, false}
        {_k, []} ->
          {:cont, false}
        {_, _} ->
          {:halt, true}
      end
    end)

    if has_at_least_one_param? do
      changeset
    else
      add_error(changeset, :ids, "Filter must have one field not empty")
    end
  end

  defp is_empty?([]) do
    true
  end

  defp is_empty?(%{}) do
    true
  end

  defp is_empty?("") do
    true
  end

  defp is_empty?(nil) do
    true
  end

  defp is_empty?(_) do
    false
  end
end
