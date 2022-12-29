defmodule NostrexWeb.MessageParser do
  @doc """
  parse and do some basic validation on event message and return
  params ready to be sent to Events.create_event/1
  """
  def parse_and_sanity_check_event_message(req) do
    # TODO: change this to not lead to dos vuln
    {:ok, list} = Jason.decode(req, keys: :atoms)
    event_params = Enum.at(list, 1)
    {:ok, raw_event} = Jason.encode(event_params)

    Map.update(event_params, :tags, nil, fn tags ->
      if tags == nil or tags == [] do
        tags
      else
        # convert tag list to map list for embedded object creation

        tags
        |> Enum.map(fn tag ->
          list_to_tag_params(tag)
        end)
      end
    end)
  end

  defp list_to_tag_params(list) do
    [type, field_1, field_2 | _] = list

    attrs = %{
      type: type,
      field_1: field_1,
      field_2: field_2,
      full_tag: list
    }
  end
end
