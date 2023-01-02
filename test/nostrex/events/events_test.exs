defmodule Nostrex.EventsTest do
  use Nostrex.DataCase
  alias Nostrex.FixtureFactory
  alias Nostrex.Events
  alias Nostrex.Events.Event

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
      created_at: 1_671_994_854,
      kind: 1,
      content: "jet fuel can't melt steel beams",
      sig:
        "230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"
    }
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

  test "ensure validation of proper field lengths and formatting" do
  end

  test "ensure valid created_at timestamp" do
  end

  test "ensure kind value is valid" do
  end

  test "ensure invalid signature events don't get persisted" do
  end

  # TODO remove DB calls from these functions
  test "ensure event serialization happens correctly" do
    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    {:ok, serialized_event} = Event.serialize(event)

    assert serialized_event ==
             "[0,\"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d\",1671994854,1,[],\"jet fuel can't melt steel beams\"]"
  end

  test "ensure event id generation is accurate" do
    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)

    assert event.id == Event.calculate_id(event)
  end

  test "querying historical events from a filter" do

    time_now = DateTime.to_unix(DateTime.utc_now())
    time_future = time_now + 100
    time_past = time_now - 100

    # event identifier => event attributes
    test_events =
      [
        [pubkey: "akey_1", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
        [pubkey: "akey_2", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
        [pubkey: "akey_2", p: [], e: ["ekey_1"], kind: 1, created_at: time_now],
      ]

    for event <- test_events do
      FixtureFactory.create_event_no_validation(event)
    end

    test_filter_params = [
      {[authors: ["akey_1"]], 1},
      {[authors: [], "#e": ["ekey_2"]], 0},
      {[authors: [], "#e": [], since: time_past], 3},
    ]

    for params <- test_filter_params do
      filter = FixtureFactory.create_filter(elem(params, 0))

      events = Events.get_events_matching_filter(filter)

      assert Enum.count(events) == elem(params, 1)
    end



    # for ev <- test_events_1 do
    #   event = create_test_event(elem(ev, 0))

    #   event_id = event.id
    #   should_receive? = elem(ev, 1)

      # FastFilter.process_event(event)

      # if should_receive? do
      #   assert_receive({:event, %Event{id: ^event_id}}, 100)
      # else
      #   refute_receive({:event, %Event{id: ^event_id}}, 100)
      # end
    # end
  end
end
