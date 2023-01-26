defmodule Nostrex.EventsTest do
  use Nostrex.DataCase

  alias Nostrex.Events
  alias Nostrex.Events.Event
  alias Nostrex.FixtureFactory

  @valid_events [
    %Event{
      id: "bfe9a9f57c61d04493c74189dc6ffa73f54522d0bf470b6194dcf33c323eb3c0",
      pubkey: "f7b642493ed5a462c2faebb5d6cd208e42b8ea36f0b479f2aa2f5f5bf6f67aa7",
      created_at: 1673931680,
      kind: 1,
      tags: [],
      content: "running bitcoin",
      sig: "6815aaa87665e68a43639631d9dbac7c3f6b825ff14e6689a100eef2d307f54701ec6b28fa9ab9c9ea01215f07db4e507d8e06a0e01527035f0b0ae9e4c2779c"
    },
    %Event{
      # TODO(sachin): incorrect ID
      id: "035c202e0f98df0ca71ef0167a0d00bccc88cf290481a8c8f21be40e65f6da5f",
      pubkey: "b0448252cddc47798e5e726b5c6de25f3c486a01427d736915071f6d320abaab",
      created_at: 1673931868,
      kind: 1,
      tags: [
        ["p", "f7b642493ed5a462c2faebb5d6cd208e42b8ea36f0b479f2aa2f5f5bf6f67aa7", "random"],
        ["e", "bfe9a9f57c61d04493c74189dc6ffa73f54522d0bf470b6194dcf33c323eb3c0", "other"]
      ],
      content: "It might make sense just to get some in case it catches on.",
      # TODO(sachin): incorrect sig
      sig: "f0f6d65f6a2257b3af1a8e1760a697ed1dd2ad8839e3fb708e33555ad1d01206d7a68f9a944387c6505a7fd8cbfac29fc8151bf9109e62b5efbb1479893a8bca"
    },
  ]

  defp sample_event_params do
    map = %{
      id: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
      pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
      tags: [
        %{
          type: "e",
          field_1: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
          field_2: "test-relay",
          full_tag: [
            "e",
            "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
            "test-relay"
          ]
        },
        %{
          type: "p",
          field_1: "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
          field_2: "test-relay",
          full_tag: [
            "p",
            "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",
            "test.relay.com",
            "extra"
          ]
        }
      ],
      created_at: 1_672_531_200,
      kind: 1,
      content: "jet fuel can't melt steel beams",
      sig:
        "230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"
    }

    Map.put(map, :raw, Jason.encode!(map))
  end

  test "create new event and persist" do
    original_event_count = Repo.aggregate(Event, :count)
    assert original_event_count == 0

    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    # assert only one event created
    new_event_count = Repo.aggregate(Event, :count)
    assert new_event_count == 1

    # assert id persisted
    saved_event = Repo.one(Event)
    assert saved_event.id == event.id
  end

  test "ensure unique constraint functions and doesn't raise error" do
    event_params = sample_event_params()
    {:ok, _} = Events.create_event(event_params)

    # simply testing that this doesn't throw is sufficient
    {:error, _} = Events.create_event(event_params)
  end

  test "can create event without tags attribute" do
    event_params = sample_event_params()
    new_params = Map.delete(event_params, :tags)
    {:ok, _event} = Events.create_event(new_params)
  end

  test "tags get saved in order in db" do
    p_tags =
      Enum.map(1..100, fn i ->
        "#{i}"
      end)

    e_tags =
      Enum.map(101..200, fn i ->
        "#{i}"
      end)

    field_1_expectation = p_tags ++ e_tags

    # fixture factory generates list with p tags first
    # TODO: this is leaky and brittle
    event = FixtureFactory.create_event_no_validation(e: e_tags, p: p_tags)

    queried_event = Events.get_event_by_id!(event.id)

    tag_field_1_list = queried_event.tags |> Enum.map(fn t -> t.field_1 end)

    # test that lists are equal
    assert field_1_expectation == tag_field_1_list
  end

  test "ensure validation of proper field lengths and formatting" do
  end

  test "ensure valid created_at timestamp" do
  end

  test "ensure kind value is valid" do
  end

  describe "ensure signatures validation works" do
    test "valid signatures pass check" do
      for e <- @valid_events do
        assert Event.validate(e)
      end
    end

    test "invalid signatures fail check" do

    end
  end

  test "ensure invalid signature events don't get persisted" do
  end

  # TODO remove DB calls from these functions
  test "ensure event serialization happens correctly" do
    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    {:ok, serialized_event} = Event.serialize(event)

    assert serialized_event ==
             "[0,\"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d\",1672531200,1,[],\"jet fuel can't melt steel beams\"]"
  end

  # TODO: come back to this, may be able to delete
  # test "ensure event id generation is accurate" do
  #   event_params = sample_event_params()
  #   {:ok, event} = Events.create_event(event_params)

  #   assert event.id == Event.calculate_id(event)
  # end

  test "querying historical events from a filter" do
    time_now = DateTime.to_unix(DateTime.utc_now())
    time_future = time_now + 100
    time_past = time_now - 100

    # event identifier => event attributes
    test_events = [
      [pubkey: "akey_1", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
      [pubkey: "akey_2", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
      [pubkey: "akey_2", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
      [pubkey: "akey_3", p: [], e: ["ekey_3", "ekey_31"], kind: 1, created_at: time_now],
      [pubkey: "akey_4", p: [], e: [], kind: 1, created_at: time_future],
      [pubkey: "akey_5", p: [], e: [], kind: 1, created_at: time_future],
      [
        pubkey: "akey_6",
        p: ["pkey_61", "pkey_62"],
        e: ["ekey_61", "ekey_62"],
        kind: 1,
        created_at: time_future
      ]
    ]

    for event <- test_events do
      FixtureFactory.create_event_no_validation(event)
    end

    test_filter_params = [
      {[authors: ["akey_1"]], 1},
      {["#e": ["ekey_2"]], 0},
      # test multiple tag criteria
      {["#e": ["ekey_3", "ekey_31"]], 1},
      # test until functionality
      {["#e": ["ekey_3", "ekey_31"], until: time_now + 1], 1},
      # test until functionality
      {["#e": ["ekey_3", "ekey_31"], until: time_now + 1], 1},
      # test kind match functionality
      {[kinds: [1]], Enum.count(test_events)},
      # check since functionality
      {["#e": [], since: time_past], Enum.count(test_events)},
      # check since functionality
      {["#e": [], since: time_future + 10], 0},
      # check multiple tag conditions
      {["#p": ["pkey_61", "pkey_62"], "#e": ["ekey_61", "ekey_62"]], 1},
      # check kind no match
      {[kinds: [2, 3], "#p": ["pkey_61", "pkey_62"], "#e": ["ekey_61", "ekey_62"]], 0},
      # check kind no match, also check wrong key in a tag field
      {[
         kinds: [1, 3],
         authors: ["akey_1", "akey_4"],
         "#p": ["ekey_3", "pkey_61", "pkey_62"],
         "#e": ["ekey_199"]
       ], 3}
    ]

    for params <- test_filter_params do
      filter = FixtureFactory.create_filter(elem(params, 0))

      events = Events.get_events_matching_filter(filter)
      assert Enum.count(events) == elem(params, 1)
    end
  end
end
