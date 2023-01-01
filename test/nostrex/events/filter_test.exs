defmodule Nostrex.FilterTest do
  use Nostrex.DataCase
  alias Nostrex.Events.Filter

  @test_filters [
    [
      '{"ids":["aa","bb","cc"],"authors":["aa","bb","cc"],"kinds":[0,1,2,3],"since":1000,"until":1000,"limit":100,"#e":["aa","bb","cc"],"#p":["dd","ee","ff"],"#r":["00","11","22"]}',
      true
    ],
    ['{"#e": ["ekey_1", "ekey_2", "ekey_3"]}', true],
    [
      '{"authors":["3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", "04c915daefee38317fa734444acee390a8269fe5810b2241e5e6dd343dfbecc9", "12aa13a2fff8ff59188e3cb8846e3848c333b18931a1214a555f3a278136c82d", "35b23cd02d2d75e55cee38fdee26bc82f1d15d3c9580800b04b0da2edb7517ea", "e33fe65f1fde44c6dc17eeb38fdad0fceaf1cae8722084332ed1e32496291d42", "e88a691e98d9987c964521dff60025f60700378a4879180dcbbb4a5027850411", "d987084c48390a290f5d2a34603ae64f55137d9b4affced8c0eae030eb222a25", "8967f290cc7749fd3d232fb7110c05db746a31fce0635aeec4e111ad8bfc810d", "020f2d21ae09bf35fcdfb65decf1478b846f5f728ab30c5eaabcd6d081a81c3e", "cee66dcc9f50a352e51a9ac88adfcd3461bebb08f0eaf7bd01d2c66cd9b6c03e"]}',
      true
    ],
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
      params =
        f |> Jason.decode!(keys: :atoms) |> Map.put(:subscription_id, "subid#{:rand.uniform(99)}")

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
