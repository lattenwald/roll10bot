defmodule Roller do

  def roll do
    "plain `1d10` roll:\n *#{:rand.uniform(10)}*"
  end

  def roll(count, again) do
    results = roll(count, again, [])
    results_flat = List.flatten results

    summary = case Enum.count(results_flat, &(&1 >= 8)) do
      0 ->
        results_text = results_to_text(results, &(&1 == 1))
        case Enum.count(results_flat, &(&1 == 1)) do
          0 -> results_text
          failure ->
            "#{results_text}\n*#{failure}* #{msg(failure, "провал", "провала", "провалов")}"
        end
      success ->
        results_text = results_to_text(results, &(&1 >= 8))
        "#{results_text}\n*#{success}* #{msg(success, "успех", "успеха", "успехов")}"
    end
    "`#{count}d10` #{again} again\n#{summary}"
  end

  defp results_to_text(results, highlighter) do
    results |> Enum.map(fn (r) ->
      r |> Enum.map(&(if highlighter.(&1), do: "*#{&1}*", else: "#{&1}")) |> Enum.join(", ")
    end) |> Enum.reverse |> Enum.join("\n")
  end

  defp msg(num, a, b, c) do
    cond do
      num >= 20 -> msg(rem(num, 10), a, b, c)
      num == 0 -> c
      num == 1 -> a
      num < 5 -> b
      true -> c
    end
  end

  defp roll(0, _, acc), do: acc
  defp roll(count, again, acc) do
    results = 1..count |> Enum.map(fn(_) -> :rand.uniform(10) end)
    rerolls = Enum.count(results, &(&1 >= again))
    roll(rerolls, again, [results | acc])
  end
end
