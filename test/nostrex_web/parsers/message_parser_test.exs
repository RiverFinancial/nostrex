defmodule NostrexWeb.MessageParserTest do
  use NostrexWeb.ConnCase
  alias NostrexWeb.MessageParser
  alias Nostrex.Events

  defp sample_event_params() do
    %{
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
            "test-relay",
            "test exended field",
            "test extended field 2"
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

  test "basic parsing logic" do
    tags_string =
      ~s("tags":[["e", "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009", "relay.com"], ["p", "75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009", "test.relay.com", "extra"]])

    event_req_string =
      ~s(["EVENT", {"content":"jet fuel can't melt steel beams","created_at":1672560642,"id":"75b79351140f7f0002b050d9b2fef4d1f2d5f4ade7a3b04ed24604672d326009",#{tags_string},"kind":1,"pubkey":"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d","sig":"230e9d8f0ddaf7eb70b5f7741ccfa37e87a455c9a469282e3464e2052d3192cd63a167e196e381ef9d7e69e9ea43af2443b839974dc85d8aaab9efe1d9296524"}])

    parsed_result = MessageParser.parse_and_sanity_check_event_message(event_req_string)

    assert Enum.count(parsed_result.tags) > 0
    assert [%{type: _} | _] = parsed_result.tags
  end

  test "event_to_json" do
    event_params = sample_event_params()
    {:ok, event} = Events.create_event(event_params)
    json = MessageParser.event_to_json(event)
    parsed_json = Jason.decode!(json, keys: :atoms)

    # Test tag ordering is maintained and that longer tags also work
    assert parsed_json[:id] == event.id
    assert Enum.count(Enum.at(parsed_json[:tags], 0)) == 5
  end
end
