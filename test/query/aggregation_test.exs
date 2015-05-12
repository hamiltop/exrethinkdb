defmodule AggregationTest do
  use ExUnit.Case
  use TestConnection
  alias RethinkDB.Query.Aggregation, as: A

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  setup_all do
    TestConnection.connect
    :ok
  end

  test "group on key name" do
    query = [
        %{a: "hi", b: 1},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"}
      ]
      |> group("a")
    %Record{data: data} = query |> run
    assert data == %{
      "bye" => [
        %{"a" => "bye"}
      ],
      "hi" => [
        %{"a" => "hi", "b" => 1},
        %{"a" => "hi", "b" => [1,2,3]}
      ]
    }
  end

  test "group on function" do
    query = [
        %{a: "hi", b: 1},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello"}
      ]
      |> group(lambda fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end)
    %Record{data: data} = query |> run
    assert data == %{
      false: [
        %{"a" => "bye"},
      ],
      true: [
        %{"a" => "hi", "b" => 1},
        %{"a" => "hi", "b" => [1,2,3]},
        %{"a" => "hello"}
      ]
    }
  end

  test "group on multiple keys" do
    query = [
        %{a: "hi", b: 1, c: 2},
        %{a: "hi", b: 1, c: 3},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello", b: 1}
      ]
      |> group([lambda(fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end), "b"])
    %Record{data: data} = query |> run
    assert data == %{
      [false, nil] => [
        %{"a" => "bye"},
      ],
      [true, 1] => [
        %{"a" => "hi", "b" => 1, "c" => 2},
        %{"a" => "hi", "b" => 1, "c" => 3},
        %{"a" => "hello", "b" => 1},
      ],
      [true, [1,2,3]] => [
        %{"a" => "hi", "b" => [1,2,3]}
      ]
    }
  end

  test "ungroup" do
    query = [
        %{a: "hi", b: 1, c: 2},
        %{a: "hi", b: 1, c: 3},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello", b: 1}
      ]
      |> group([lambda(fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end), "b"])
      |> ungroup
    %Record{data: data} = query |> run
    assert data == [
      %{
        "group" => [false, nil],
        "reduction" => [
          %{"a" => "bye"},
        ]
      },
      %{
        "group" => [true, [1,2,3]],
        "reduction" => [
          %{"a" => "hi", "b" => [1,2,3]}
        ]
      },
      %{
        "group" => [true, 1],
        "reduction" => [
          %{"a" => "hi", "b" => 1, "c" => 2},
          %{"a" => "hi", "b" => 1, "c" => 3},
          %{"a" => "hello", "b" => 1},
        ]
      }
    ]
  end

  test "reduce" do
    query = [1,2,3,4] |> reduce(lambda fn(el, acc) ->
      el + acc
    end)
    %Record{data: data} = run query
    assert data == 10
  end

  test "count" do
    query = [1,2,3,4] |> count
    %Record{data: data} = run query
    assert data == 4
  end

  test "count with value" do
    query = [1,2,2,3,4] |> count 2
    %Record{data: data} = run query
    assert data == 2
  end

  test "count with predicate" do
    query = [1,2,2,3,4] |> count(lambda fn(x) ->
      rem(x, 2) == 0
    end)
    %Record{data: data} = run query
    assert data == 3
  end

  test "sum" do
    query = [1,2,3,4] |> sum
    %Record{data: data} = run query
    assert data == 10
  end

  test "sum with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> sum "a"
    %Record{data: data} = run query
    assert data == 3
  end

  test "sum with function" do
    query = [1,2,3,4] |> sum(lambda fn (x) ->
      if x == 1 do
        nil
      else
        x * 2
      end
    end)
    %Record{data: data} = run query
    assert data == 18
  end

  test "avg" do
    query = [1,2,3,4] |> avg
    %Record{data: data} = run query
    assert data == 2.5
  end

  test "avg with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> avg "a"
    %Record{data: data} = run query
    assert data == 1.5
  end

  test "avg with function" do
    query = [1,2,3,4] |> avg(lambda fn (x) ->
      if x == 1 do
        nil
      else
        x * 2
      end
    end)
    %Record{data: data} = run query
    assert data == 6
  end

  test "min" do
    query = [1,2,3,4] |> A.min
    %Record{data: data} = run query
    assert data == 1
  end

  test "min with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> A.min "b"
    %Record{data: data} = run query
    assert data == %{"b" => 3}
  end

  test "min with function" do
    query = [1,2,3,4] |> A.min(lambda fn (x) ->
      if x == 1 do
        100 # Note, there's a bug in rethinkdb (https://github.com/rethinkdb/rethinkdb/issues/4213)
            # which means we can't return null here
      else
        x * 2
      end
    end)
    %Record{data: data} = run query
    assert data == 2  
  end

  test "max" do
    query = [1,2,3,4] |> A.max
    %Record{data: data} = run query
    assert data == 4
  end

  test "max with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> A.max "b"
    %Record{data: data} = run query
    assert data == %{"b" => 4}
  end

  test "max with function" do
    query = [1,2,3,4] |> A.max(lambda fn (x) ->
      if x == 4 do
        nil
      else
        x * 2
      end
    end)
    %Record{data: data} = run query
    assert data == 3
  end

  test "distinct" do
    query = [1,2,3,3,4,4,5] |> distinct
    %Record{data: data} = run query
    assert data == [1,2,3,4,5]
  end

  test "contains" do
    query = [1,2,3,4] |> contains 4
    %Record{data: data} = run query
    assert data == true
  end

  test "contains multiple values" do
    query = [1,2,3,4] |> contains [4, 3]
    %Record{data: data} = run query
    assert data == true
  end

  test "contains with function" do
    query = [1,2,3,4] |> contains(lambda &(&1 == 3))
    %Record{data: data} = run query
    assert data == true
  end

  test "contains with multiple function" do
    query = [1,2,3,4] |> contains [lambda(&(&1 == 3)), lambda(&(&1 == 5))]
    %Record{data: data} = run query
    assert data == false
  end

  test "contains with multiple (mixed)" do
    query = [1,2,3,4] |> contains [lambda(&(&1 == 3)), 2]
    %Record{data: data} = run query
    assert data == true
  end
end
