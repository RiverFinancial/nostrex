defmodule Nostrex.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false, options: "PARTITION BY RANGE (created_at)") do
      add :id, :string, null: false
      add :pubkey, :string, null: false
      add :created_at, :bigint, null: false
      add :kind, :integer, null: false
      add :content, :text, null: false
      add :sig, :string, null: false
      add :raw, :text, null: false
      timestamps()
    end

    create index(:events, :pubkey)
    create index(:events, :kind)

    # this is ok to do because an event with a given :id CANNOT have a different created at
    # since created_at is included in the event SHA digest
    create unique_index(:events, [:id, "created_at DESC"])

    create_partitions()
  end

  def create_partitions() do
    timestamp_list()
    |> Enum.with_index(fn date, index ->
      unless index == 0 do
        list = timestamp_list()
        start_date = Enum.at(list, index - 1)
        end_date = Enum.at(list, index)
        create_partition("events", DateTime.from_unix!(start_date), DateTime.from_unix!(end_date))
      end
    end)
  end

  def create_partition(table, start_timestamp, end_timestamp) do
    execute """
    CREATE TABLE #{table}_p#{start_timestamp.year}_#{start_timestamp.month}
    PARTITION OF #{table} FOR VALUES
    FROM ('#{DateTime.to_unix(start_timestamp)}')
    TO ('#{DateTime.to_unix(end_timestamp)}')
    """
  end

  defp timestamp_list() do
    # Starts Feb 1, 2023
    [
      1672531200,
      1675209600,
      1677628800,
      1680307200,
      1682899200,
      1685577600,
      1688169600,
      1690848000,
      1693526400,
      1696118400,
      1698796800,
      1701388800,
      1704067200,
      1706745600,
      1709251200,
      1711929600,
      1714521600,
      1717200000,
      1719792000,
      1722470400,
      1725148800,
      1727740800,
      1730419200,
      1733011200,
      1735689600,
      1738368000,
      1740787200,
      1743465600,
      1746057600,
      1748736000,
      1751328000,
      1754006400,
      1756684800,
      1759276800,
      1761955200,
      1764547200
    ]
  end
end
