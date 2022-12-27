defmodule Nostrex.FastFilterTest do
  use Nostrex.DataCase
  alias Nostrex.Events
  alias Nostrex.Events.{Filter, Event}
  alias Nostrex.{FastFilter, FastFilterTableManager}
  require IEx

  defp sample_event_params() do
    %{
      id: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
      pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
      # DateTime.utc_now(),
      created_at: DateTime.from_unix!(1_671_994_854),
      kind: 1,
      content: "jet fuel can't melt steel beams",
      sig:
        "230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"
    }
  end

  test "test filter ets tables get created properly" do
    ff_tables_list = FastFilterTableManager.ets_tables()
    assert Enum.count(ff_tables_list) > 0

    for table <- ff_tables_list do
      assert :ets.info(table) != :undefined
    end
  end

  test "generating filter ids used for fast lookups" do
    valid_filters = [
      ['{"ids":["aa","bb","cc"],"authors":["aa","bb","cc"],"kinds":[0,1,2,3],"since":1000,"until":1000,"limit":100,"#e":["aa","bb","cc"],"#p":["dd","ee","ff"],"#r":["00","11","22"]}', "ape"],
      ['{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', "a"],
      ['{"ids":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', ""]
    ]


    
    for [f, i] <- valid_filters do
      params = Jason.decode!(f, keys: :atoms)
      id = %Filter{}
        |> Filter.changeset(params)
        |> apply_action!(:update)
        |> FastFilter.generate_filter_id()
      assert id == i
    end
  end

  test "test that filter can be added" do
    
  end


  test "test that filter can be deleted" do
    
  end
end
