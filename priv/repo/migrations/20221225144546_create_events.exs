defmodule Nostrex.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :pubkey, :string, null: false
      add :created_at, :bigint, null: false
      add :kind, :integer, null: false
      add :content, :text, null: false
      add :sig, :string, null: false
      timestamps()
    end

    create index(:events, ["created_at DESC"])
    create index(:events, :pubkey)
    create index(:events, :kind)
    create unique_index(:events, :sig)
  end
end
