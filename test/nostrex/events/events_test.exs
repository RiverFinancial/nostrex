defmodule Nostrex.EventsTest do
  use Nostrex.DataCase
  alias Nostrex.Events
  alias Nostrex.Events.Event

  test "create new event and persist" do
    original_event_count = Repo.aggregate(Event, :count)
    assert original_event_count == 0

    {:ok, event} = Events.create_event(%{
      id: "dc90c95f09947507c1044e8f48bcf6350aa6bff1507dd4acfc755b9239b5c962",
      pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
      created_at: DateTime.utc_now(),
      kind: 1,
      content: "jet fuel can't melt steel beams",
      sig: "230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"
    })

    # assert only one event created
    new_event_count = Repo.aggregate(Event, :count)
    assert new_event_count == 1

    # assert id persisted
    saved_event = Repo.one(Event)
    assert saved_event.id == event.id
  end
end
