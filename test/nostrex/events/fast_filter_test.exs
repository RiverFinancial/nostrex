defmodule Nostrex.FastFilterTest do
  use Nostrex.DataCase

  alias Phoenix.PubSub
  alias Nostrex.Events
  alias Nostrex.Events.{Event}
  alias Nostrex.{FastFilter, FastFilterTableManager}
  require IEx

  alias Nostrex.FixtureFactory

  setup do
    # cleanup all ETS tables
    for table <- Nostrex.FastFilterTableManager.ets_tables() do
      :ets.delete_all_objects(table)
    end

    :ok
  end

  defp sample_event_params() do
    map = %{
      id: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
      pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
      # DateTime.utc_now(),
      tags: [
        %{
          type: "e",
          field_1: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
          field_2: "test-relay",
          full_tag: [
            "e",
            "c2b69351140f7f0002b050d9b2fcf4d1f2d5f4ade7a3b04ed24604672d326009",
            "test-relay"
          ]
        },
        %{
          type: "p",
          field_1: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
          field_2: "test-relay",
          full_tag: [
            "p",
            "1bb73351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
            "test.relay.com",
            "extra"
          ]
        }
      ],
      created_at: 1672531200,
      kind: 1,
      content: "jet fuel can't melt steel beams",
      sig:
        "230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"
    }
    Map.put(map, :raw, Jason.encode!(map))
  end

  test "test filter ets tables get created properly" do
    ff_tables_list = FastFilterTableManager.ets_tables()
    assert Enum.count(ff_tables_list) > 0

    for table <- ff_tables_list do
      assert :ets.info(table) != :undefined
    end
  end

  test "generating filter code used for part of filter identifier in lookup tables" do
    valid_filters = [
      [
        '{"ids":["aa","bb","cc"],"authors":["aa","bb","cc"],"kinds":[0,1,2,3],"since":1000,"until":1000,"limit":100,"#e":["aa","bb","cc"],"#p":["dd","ee","ff"],"#r":["00","11","22"]}',
        "ape"
      ],
      ['{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', "a"],
      [
        '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"], "#e": ["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}',
        "ae"
      ],
      ['{"ids":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', ""]
    ]

    for [f, i] <- valid_filters do
      id =
        FixtureFactory.create_filter_from_string(f)
        |> FastFilter.generate_filter_code()

      assert id == i
    end
  end

  test "test that filter can be added to ets" do
    valid_filters = [
      [
        '{"ids":["aa","bb","cc"],"authors":["dd","ee","ff"],"kinds":[0,1,2,3],"since":1000,"until":1000,"limit":100,"#e":["aa","bb","cc"],"#p":["dd","ee","ff"],"#r":["00","11","22"]}',
        "ape"
      ],
      ['{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', "a"],
      ['{"ids":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', ""],
      ['{"kinds":[1, 2, 3]}', ""]
    ]

    for [f, _] <- valid_filters do
      FixtureFactory.create_filter_from_string(f, "testsubscriptionid")
      |> FastFilter.insert_filter()
    end

    first_filter_pubkey_tuple = :ets.lookup(:nostrex_ff_pubkeys, "dd")
    first_filter_pubkey_value = elem(List.first(first_filter_pubkey_tuple), 1)
    assert Enum.count(first_filter_pubkey_tuple) == 1

    assert String.starts_with?(first_filter_pubkey_value, "ape:testsubscriptionid")

    second_filter_result =
      :ets.lookup(
        :nostrex_ff_pubkeys,
        "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
      )

    assert String.starts_with?(elem(List.first(second_filter_result), 1), "a:testsubscriptionid:")

    # assert String.starts_with?(elem(:ets.lookup(:nostrex_ff_pubkeys, "ee")[0], 1), "ape:testsubscriptionid:")
    # assert String.starts_with?(elem(:ets.lookup(:nostrex_ff_pubkeys, "ff")[0], 1), "ape:testsubscriptionid:")
  end

  # '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}'
  # '{#e":["aa","bb","cc"],"#p":["dd","ee","ff"]}'

  test "basic process_event" do
    # subscribe to subscription id

    # create basic filter and insert
    filter_string =
      '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}'

    filter = FixtureFactory.create_filter_from_string(filter_string)
    PubSub.subscribe(:nostrex_pubsub, filter.subscription_id)

    FastFilter.insert_filter(filter)

    # process event that should match filter and test that event is received

    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    FastFilter.process_event(event)

    assert_receive({:events, [%Event{}], _sub_id}, 100)
  end

  test "multiple subscriptions with multiple filters, some of which don't match an event" do
    filter_set_1 = [
      '{"authors":["akey_1"]}',
      '{"#e": ["ekey_1", "ekey_2", "ekey_3"]}',
      '{"#p": ["pkey_1", "pkey_2", "pkey_3"]}',
      '{"authors": ["akey_2"], "#p": ["pkey_3"]}',
      '{"authors":["akey_3"]}',
      '{"#e": ["ekey_4"], "#p": ["pkey_4"]}',
      '{"authors": ["akey_5"], "#e": ["ekey_5"], "#p": ["pkey_5"]}',
      '{"authors":["akey_6"], "#e": ["ekey_6"]}',
      '{"authors":["akey_7"], "#e": ["ekey_7"], "kinds": [1,2,3]}'
    ]

    # setup subscription
    sub_id = "123"
    PubSub.subscribe(:nostrex_pubsub, sub_id)

    for f <- filter_set_1 do
      filter = FixtureFactory.create_filter_from_string(f, sub_id)

      filter
      |> FastFilter.insert_filter()
    end

    test_events_1 = [
      {[pubkey: "akey_1", p: [], e: [], kind: 1], true},
      {[pubkey: "akey_2", p: [], e: [], kind: 1], false},
      {[pubkey: "akey_1", p: ["pkey_1"], e: [], kind: 1], true},
      {[pubkey: "akey_1", p: [], e: ["ekey_1"], kind: 1], true},
      # should also require pkey_4 to match
      {[pubkey: "akey_2", p: [], e: ["ekey_4"], kind: 1], false},
      {[pubkey: "akey_2", p: ["pkey_4"], e: ["ekey_4"], kind: 1], true},
      {[pubkey: "akey_4", p: ["pkey_4"], e: [], kind: 1], false},
      {[pubkey: "akey_4", p: ["pkey_4"], e: ["ekey_4"], kind: 1], true},
      {[pubkey: "akey_4", p: [], e: ["ekey_4"], kind: 1], false},
      {[pubkey: "akey_5", p: ["pkey_5"], e: [], kind: 1], false},
      {[pubkey: "akey_5", p: [], e: ["ekey_5"], kind: 1], false},
      {[pubkey: "akey_5", p: [], e: ["ekey_6"], kind: 1], false},
      {[pubkey: "akey_5", p: [], e: [], kind: 1], false},
      {[pubkey: "akey_5", p: ["pkey_5"], e: ["ekey_5"], kind: 1], true},
      {[pubkey: "akey_1", p: [], e: ["ekey_6"], kind: 1], true},
      {[pubkey: "akey_7", p: [], e: ["ekey_6"], kind: 1], false},
      {[pubkey: "akey_6", p: [], e: ["ekey_6"], kind: 1], true},
      {[pubkey: "akey_7", p: [], e: ["ekey_7"], kind: 1], true},
      {[pubkey: "akey_7", p: [], e: ["ekey_7"], kind: 7], false}
    ]

    for ev <- test_events_1 do
      event = FixtureFactory.create_event_no_validation(elem(ev, 0))

      event_id = event.id
      should_receive? = elem(ev, 1)

      FastFilter.process_event(event)

      if should_receive? do
        assert_receive({:events, [%Event{id: ^event_id}], ^sub_id}, 100)
      else
        refute_receive({:events, [%Event{id: ^event_id}], ^sub_id}, 100)
      end
    end
  end

  test "filter can be properly deleted" do
    filter_set = [
      '{"authors":["akey_1"]}',
      '{"#e": ["ekey_1", "ekey_2", "ekey_3"]}'
    ]

    filter_set_1 =
      filter_set
      |> Enum.map(fn f -> FixtureFactory.create_filter_from_string(f, "sub_id_1") end)

    filter_set_1 |> Enum.each(&FastFilter.insert_filter(&1))

    filter_set_2 =
      filter_set
      |> Enum.map(fn f -> FixtureFactory.create_filter_from_string(f, "sub_id_2") end)

    filter_set_2 |> Enum.each(&FastFilter.insert_filter(&1))

    # test that there are 6 etags filters (3 x 2 subscriptions)
    assert Enum.count(:ets.tab2list(:nostrex_ff_etags)) == 6

    # test that deleting the e filter for the first subscription only removes half of the entries in ets
    FastFilter.delete_filter(Enum.at(filter_set_1, 1))
    assert Enum.count(:ets.tab2list(:nostrex_ff_etags)) == 3

    # test that deleting the same filter doesn't raise
    FastFilter.delete_filter(Enum.at(filter_set_2, 1))

    FastFilter.delete_filter(Enum.at(filter_set_2, 0))
    assert Enum.count(:ets.tab2list(:nostrex_ff_pubkeys)) == 1
  end

  test "parsing filter_id" do
    res = FastFilter.parse_filter_id("ap:sdfsdfsd:23")
    assert res.code == "ap"
    assert res.subscription_id == "sdfsdfsd"
  end

  test "test that filter can be deleted" do
  end
end
