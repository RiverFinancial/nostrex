defmodule Nostrex.Repo.Migrations.AddTagsTable do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false, options: "PARTITION BY RANGE (event_created_at)") do
      add :id, :bigserial, null: false
      # cannot be foreign key because of partitioned events table
      add :event_id, references(:events, type: :string, with: [event_created_at: :created_at])
      # partition tags on same timestamp
      add :event_created_at, :integer
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
      1_672_531_200,
      1_675_209_600,
      1_677_628_800,
      1_680_307_200,
      1_682_899_200,
      1_685_577_600,
      1_688_169_600,
      1_690_848_000,
      1_693_526_400,
      1_696_118_400,
      1_698_796_800,
      1_701_388_800,
      1_704_067_200,
      1_706_745_600,
      1_709_251_200,
      1_711_929_600,
      1_714_521_600,
      1_717_200_000,
      1_719_792_000,
      1_722_470_400,
      1_725_148_800,
      1_727_740_800,
      1_730_419_200,
      1_733_011_200,
      1_735_689_600,
      1_738_368_000,
      1_740_787_200,
      1_743_465_600,
      1_746_057_600,
      1_748_736_000,
      1_751_328_000,
      1_754_006_400,
      1_756_684_800,
      1_759_276_800,
      1_761_955_200,
      1_764_547_200
    ]
  end
end
