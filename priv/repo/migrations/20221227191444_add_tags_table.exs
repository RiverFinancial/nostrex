defmodule Nostrex.Repo.Migrations.AddTagsTable do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :event_id, references(:events, type: :string)
      add :type, :string
      add :field_1, :string
      add :field_2, :string
      add :full_tag, {:array, :string}

      timestamps()
    end

    create index(:tags, :event_id)
    create index(:tags, :field_1)
    create index(:tags, :field_2)
  end
end
