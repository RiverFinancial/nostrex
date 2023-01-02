defmodule NostrexWeb.MessageParser do
  alias Nostrex.Events.Event

  @doc """
  parse and do some basic validation on event message and return
  params ready to be sent to Events.create_event/1
  """
  def parse_and_sanity_check_event_message(req) do
    # TODO: change this to not lead to dos vuln
    {:ok, list} = Jason.decode(req, keys: :atoms)
    event_params = Enum.at(list, 1)

    event_params
    |> Map.update(:tags, [], fn tags ->
      if tags == nil or tags == [] do
        []
      else
        # convert tag list to map list for embedded object creation

        tags
        |> Enum.map(fn tag ->
          list_to_tag_params(tag)
        end)
      end
    end)
  end

  def generate_event_list_response(events, subscription_id) do
    Enum.reduce(events, ~s'["EVENT","#{subscription_id}"', fn event, acc ->
      acc <> "," <> event_to_json(event)
    end) <> "]"
  end

  def event_to_json(event = %Event{}) do
    map = %{
      "id" => event.id,
      "pubkey" => event.pubkey,
      "created_at" => event.created_at,
      "kind" => event.kind,
      "content" => event.content,
      "sig" => event.sig
    }

    map =
      if event.tags do
        Map.put(map, "tags", Enum.map(event.tags, fn tag -> tag.full_tag end))
      else
        map
      end

    Jason.encode!(map)
  end

  defp list_to_tag_params(list) do
    [type, field_1, field_2 | _] = list

    %{
      type: type,
      field_1: field_1,
      field_2: field_2,
      full_tag: list
    }
  end
end
