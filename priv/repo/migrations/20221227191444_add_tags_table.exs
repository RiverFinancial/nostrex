defmodule Nostrex.Repo.Migrations.AddTagsTable do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false, options: "PARTITION BY RANGE (event_created_at)") do
      add :event_id, references(:events, type: :string, with: [event_created_at: :created_at]) # cannot be foreign key because of partitioned events table
      add :event_created_at, :integer # partition tags on same timestamp
      add :type, :string
      add :field_1, :string
      add :field_2, :string
      add :full_tag, {:array, :string}

      timestamps()
    end

    create index(:tags, :event_id)
    create index(:tags, :field_1)
    create index(:tags, :field_2)

    create_partitions()
  end

  def create_partitions() do
    timestamp_list()
    |> Enum.with_index(fn date, index ->
      unless index == 0 do
        list = timestamp_list()
        start_date = Enum.at(list, index - 1)
        end_date = Enum.at(list, index)
        create_partition("tags", DateTime.from_unix!(start_date), DateTime.from_unix!(end_date))
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
