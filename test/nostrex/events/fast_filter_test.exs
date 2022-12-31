defmodule Nostrex.FastFilterTest do
  use Nostrex.DataCase

  alias Phoenix.PubSub
  alias Nostrex.Events
  alias Nostrex.Events.{Event, Filter}
  alias Nostrex.{FastFilter, FastFilterTableManager}
  require IEx

  defp sample_event_params() do
    %{
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
      params = Jason.decode!(f, keys: :atoms)

      id =
        %Filter{}
        |> Filter.changeset(params)
        |> apply_action!(:update)
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
      ['{"ids":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', ""]
    ]

    for [f, _] <- valid_filters do
      params = Jason.decode!(f, keys: :atoms)

      filter =
        %Filter{}
        |> Filter.changeset(params)
        |> apply_action!(:update)

      FastFilter.insert_filter(filter, "testsubscriptionid")
    end

    first_filter_pubkey_tuple = :ets.lookup(:nostrex_ff_pubkeys, "dd")
    first_filter_pubkey_value = elem(List.first(first_filter_pubkey_tuple), 1)
    assert Enum.count(first_filter_pubkey_tuple) == 1
    assert String.starts_with?(first_filter_pubkey_value, "ape:testsubscriptionid:")

    # second_filter_result = :ets.lookup(:nostrex_ff_pubkeys, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")

    # assert String.starts_with?(elem([0], 1), "ape:testsubscriptionid:")

    # assert String.starts_with?(elem(:ets.lookup(:nostrex_ff_pubkeys, "ee")[0], 1), "ape:testsubscriptionid:")
    # assert String.starts_with?(elem(:ets.lookup(:nostrex_ff_pubkeys, "ff")[0], 1), "ape:testsubscriptionid:")
  end

  # '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}'
  # '{#e":["aa","bb","cc"],"#p":["dd","ee","ff"]}'

  test "basic process_event" do
    # subscribe to subscription id
    sub_id = "req1234"
    PubSub.subscribe(:nostrex_pubsub, sub_id)

    # create basic filter and insert
    filter_string =
      '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}'

    filter = create_filter_from_string(filter_string)

    FastFilter.insert_filter(filter, sub_id)

    # process event that should match filter and test that event is received

    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    FastFilter.process_event(event)

    assert_receive({:event, %Event{}}, 100)
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
      '{"authors":["akey_6"], "#e": ["ekey_6"]}'
    ]

    # setup subscription
    sub_id = "123"
    PubSub.subscribe(:nostrex_pubsub, sub_id)

    for f <- filter_set_1 do
      filter = create_filter_from_string(f)

      filter
      |> FastFilter.insert_filter(sub_id)

      # IO.puts "FILTER CODE"
      # IO.puts FastFilter.generate_filter_code(filter)
      # IO.inspect filter
    end

    test_events_1 = [
      {[a: "akey_1", p: [], e: []], true},
      {[a: "akey_2", p: [], e: []], false},
      {[a: "akey_1", p: ["pkey_1"], e: []], true},
      {[a: "akey_1", p: [], e: ["ekey_1"]], true},
      # should also require pkey_4 to match
      {[a: "akey_2", p: [], e: ["ekey_4"]], false},
      {[a: "akey_2", p: ["pkey_4"], e: ["ekey_4"]], true},
      {[a: "akey_4", p: ["pkey_4"], e: []], false},
      {[a: "akey_4", p: ["pkey_4"], e: ["ekey_4"]], true},
      {[a: "akey_4", p: [], e: ["ekey_4"]], false},
      {[a: "akey_5", p: ["pkey_5"], e: []], false},
      {[a: "akey_5", p: [], e: ["ekey_5"]], false},
      {[a: "akey_5", p: [], e: ["ekey_6"]], false},
      {[a: "akey_5", p: [], e: []], false},
      {[a: "akey_5", p: ["pkey_5"], e: ["ekey_5"]], true},
      {[a: "akey_1", p: [], e: ["ekey_6"]], true},
      {[a: "akey_7", p: [], e: ["ekey_6"]], false},
      {[a: "akey_6", p: [], e: ["ekey_6"]], true}
    ]

    for ev <- test_events_1 do
      event = create_test_event(elem(ev, 0))

      event_id = event.id
      should_receive? = elem(ev, 1)

      FastFilter.process_event(event)

      if should_receive? do
        assert_receive({:event, %Event{id: ^event_id}}, 100)
      else
        refute_receive({:event, %Event{id: ^event_id}}, 100)
      end
    end
  end

  test "parsing filter_id" do
    res = FastFilter.parse_filter_id("ap:sdfsdfsd:123")
    assert res.code == "ap"
    assert res.subscription_id == "sdfsdfsd"
  end

  test "test that filter can be deleted" do
  end

  defp create_test_event(a: a, p: ps, e: es) do
    tags =
      Enum.map(ps, fn p ->
        %{
          type: "p",
          field_1: p,
          field_2: "test",
          full_tag: ["p", p, "test"]
        }
      end)

    tags =
      tags ++
        Enum.map(es, fn e ->
          %{
            type: "e",
            field_1: e,
            field_2: "test",
            full_tag: ["e", e, "test"]
          }
        end)

    rand_event_id =
      :crypto.hash(:sha256, Integer.to_string(:rand.uniform(99_999_999_999)))
      |> Base.encode16()
      |> String.downcase()

    params = %{
      id: rand_event_id,
      pubkey: a,
      created_at: DateTime.utc_now(),
      # TODO: test kind filters next
      kind: 2,
      content: "test content",
      # just reuse event id since we're not testing any validation here
      sig: rand_event_id,
      tags: tags
    }

    {:ok, event} = Events.create_event_no_validation(params)
    event
  end

  defp create_filter_from_string(str) do
    params = Jason.decode!(str, keys: :atoms)

    %Filter{}
    |> Filter.changeset(params)
    |> apply_action!(:update)
  end
end
