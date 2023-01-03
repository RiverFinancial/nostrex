defmodule NostrexWeb.NostrSocketTest do
  use NostrexWeb.ConnCase
  use ExUnit.Case
  alias Nostrex.FixtureFactory
  alias Phoenix.PubSub

  alias Nostrex.Events
  alias Nostrex.Events.Event
  alias NostrexWeb.NostrSocket

  setup do
    # TODO dry this up and move to shared place
    # cleanup all ETS tables
    for table <- Nostrex.FastFilterTableManager.ets_tables() do
      :ets.delete_all_objects(table)
    end

    :ok
  end

  test "ping pong" do
    state = %{
      event_count: 0,
      req_count: 0,
      subscriptions: %{}
    }

    res = NostrSocket.websocket_handle({:text, "ping"}, state)
    assert elem(res, 0) == [text: "pong"]
  end

  describe "EVENT message functionality" do
    test "Valid event message is properly stored" do
      state = %{
        event_count: 0,
        req_count: 0,
        subscriptions: %{}
      }

      req_msg =
        ~s(["EVENT", {"content":"jet fuel can't melt steel beams","created_at":1672531200,"id":"75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009","kind":1,"pubkey":"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d","sig":"230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"}])

      assert Nostrex.Events.get_event_count() == 0
      {[text: resp], state} = NostrSocket.websocket_handle({:text, req_msg}, state)

      assert resp =~ "success"

      # check that state is updated
      assert state.event_count == 1
      assert Nostrex.Events.get_event_count() == 1
    end
  end

  test "REQ message functionality and socket termination" do
    state = %{
      event_count: 0,
      req_count: 0,
      subscriptions: %{}
    }

    future_time = (DateTime.utc_now() |> DateTime.to_unix()) + 1000
    past_time = (DateTime.utc_now() |> DateTime.to_unix()) - 2000

    req_msg =
      ~s'["REQ", "1234", {"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"], "until": #{future_time}}, {"authors": ["auth2"], "until": #{past_time}}]'

    assert Enum.count(:ets.tab2list(:nostrex_ff_pubkeys)) == 0

    {[text: resp], new_state} = NostrSocket.websocket_handle({:text, req_msg}, state)

    assert resp =~ "success"

    # assert filter with until time in the past doesn't get added to fast filter
    assert Enum.count(:ets.tab2list(:nostrex_ff_pubkeys)) == 1

    refute Enum.empty?(new_state.subscriptions)

    # test termination happens properly and ETS gets cleand up

    assert :ok = NostrSocket.terminate(:reason, "dummy req", new_state)

    assert assert Enum.count(:ets.tab2list(:nostrex_ff_pubkeys)) == 0
  end

  test "REQ message for historical events" do
    state = %{
      event_count: 0,
      req_count: 0,
      subscriptions: %{}
    }

    time_now = DateTime.utc_now() |> DateTime.to_unix()

    event = FixtureFactory.create_event_no_validation(created_at: time_now - 100)
    event_id = event.id

    assert Events.get_event_count() == 1

    sub_id = "12345"
    req_msg = ~s'["REQ", "#{sub_id}", {"authors":["#{event.pubkey}"]}]'

    # test that it receives historical events
    PubSub.subscribe(:nostrex_pubsub, sub_id)
    refute_received({:events, _, _})

    {[text: resp], new_state} = NostrSocket.websocket_handle({:text, req_msg}, state)
    assert resp =~ "success"

    assert_received({:events, [%Event{id: ^event_id}], ^sub_id})

    # test that it receives a new event

    new_event_id = "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009"
    new_event_pubkey = event.pubkey

    new_event_message =
      ~s(["EVENT", {"content":"jet fuel can't melt steel beams","created_at":1672531200,"id":"#{new_event_id}","kind":1,"pubkey":"#{new_event_pubkey}","sig":"230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"}])

    {[text: _resp], _new_state} =
      NostrSocket.websocket_handle({:text, new_event_message}, new_state)

    assert Events.get_event_count() == 2
    assert_receive({:events, [%Event{id: ^new_event_id}], ^sub_id}, 100)
  end

  describe "CLOSE message functionality" do
  end

  test "termination happens properly" do
  end

  # defp get_valid_event_message do
  #   ~s(["EVENT", {"content":"jet fuel can't melt steel beams","created_at":"2022-12-25T19:00:54Z","id":"75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009","kind":1,"pubkey":"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d","sig":"230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"}])
  # end
end
