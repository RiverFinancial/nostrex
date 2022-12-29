defmodule Nostrex.FilterTest do
  use Nostrex.DataCase
  alias Nostrex.Events.Filter

  @test_filters [
    [
      '{"ids":["aa","bb","cc"],"authors":["aa","bb","cc"],"kinds":[0,1,2,3],"since":1000,"until":1000,"limit":100,"#e":["aa","bb","cc"],"#p":["dd","ee","ff"],"#r":["00","11","22"]}',
      true
    ],
    ['{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', true],
    ['{"ids":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"]}', true],
    # although we may want to block such large sweeping reqs
    ['{"until": 2342342423}', true],
    ['{"ids":[123, 456]}', false],
    ['{"limit":[123]}', false],
    ['{"ids":[]}', false]
    # ['', false]
  ]

  test "create filter and perform basic validation" do
    for [f, res] <- @test_filters do
      params = Jason.decode!(f, keys: :atoms)

      {is_valid, _filter} =
        %Filter{}
        |> Filter.changeset(params)
        |> apply_action(:update)

      if is_valid == :ok do
        assert res
      else
        refute res
      end
    end
  end
end
