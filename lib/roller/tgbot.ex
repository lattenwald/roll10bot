defmodule Roller.Tgbot do
  use GenServer
  require Logger

  def start_link(_) do
    Logger.info("starting")
    GenServer.start_link(
      __MODULE__,
      nil,
      name: __MODULE__
    )
  end

  @impl true
  def init(_) do
    send(self(), :init)
    {:ok, nil}
  end

  @impl true
  def handle_info(:init, nil) do
    Logger.info("starting get_updates() polling")
    {:ok, %{username: username}} = Nadia.get_me()
    poller = spawn_link(__MODULE__, :starter, [username])
    {:noreply, %{poller: poller, username: username}}
  end

  def starter(username, offset \\ 0) do
    case Nadia.get_updates(offset: offset) do
      {:ok, updates} ->
        next_offset =
          case List.last(updates) do
            nil -> offset
            upd -> upd.update_id + 1
          end

        for upd <- updates, do: process(upd, username)
        starter(username, next_offset)

      other ->
        Logger.warn("poller got #{inspect(other)}")
        starter(username, offset)
    end
  end

  defp process(upd = %{message: message = %{text: text}}, username) when text != nil do
    text = Regex.replace ~r/^(\/[^\s]+)@#{username}\b/i, text, "\\1"
    upd = %{upd | message: %{message | text: text}}
    process upd
  end
  defp process(upd, _), do: process upd

  ## commands
  defp process(%{message: %{text: "/id", chat: %{id: chat_id}, message_id: message_id}}) do
    Nadia.send_message(chat_id, "`#{chat_id}`", [reply_to_message_id: message_id, parse_mode: "Markdown"])
  end
  defp process(%{message: %{text: "/roll8" <> rest, chat: %{id: chat_id}, message_id: message_id}}) do
    process_roll_command(chat_id, message_id, rest, 8)
  end
  defp process(%{message: %{text: "/roll9" <> rest, chat: %{id: chat_id}, message_id: message_id}}) do
    process_roll_command(chat_id, message_id, rest, 9)
  end
  defp process(%{message: %{text: "/roll" <> rest, chat: %{id: chat_id}, message_id: message_id}}) do
    process_roll_command(chat_id, message_id, rest, 10)
  end
  defp process(%{message: %{text: "/plain", chat: %{id: chat_id}, message_id: message_id}}) do
    Nadia.send_message(chat_id, Roller.roll(), [reply_to_message_id: message_id, parse_mode: "Markdown"])
  end

  ## callback queries
  defp process(%{callback_query: %{data: "-" <> data, message: %{chat: %{id: chat_id}, message_id: message_id}}}) do
    rows = 10 .. 8 |> Enum.map(
      fn(again) ->
        [%Nadia.Model.InlineKeyboardButton{
          callback_data: "#{data}a#{again}",
          text: "#{again} again"
        }]
      end
    )
    inline_keyboard = %Nadia.Model.InlineKeyboardMarkup{inline_keyboard: rows}
    Nadia.edit_message_text(chat_id, message_id, nil, "Roll `#{data}d10`", [parse_mode: "Markdown", reply_markup: inline_keyboard])
  end
  defp process(%{callback_query: %{data: data, message: %{chat: %{id: chat_id}, message_id: message_id}}}) do
    with {num, again} <- parse_num_again(data) do
      text = Roller.roll(num, again)
      # Nadia.edit_message_reply_markup(chat_id, message_id, nil, [])
      Nadia.edit_message_text(chat_id, message_id, nil, text, [parse_mode: "Markdown"])
    else
      _ -> :ok
    end
  end

  ## inline queries
  defp process(%{inline_query: %{id: query_id, query: ""}}) do
    Nadia.answer_inline_query(query_id, plain_d10(), [cache_time: 0])
  end
  defp process(%{inline_query: %{id: query_id, query: query}}) do
    Nadia.answer_inline_query(query_id, suggestions(query), [cache_time: 0])
  end

  ## other
  defp process(upd) do
    IO.inspect(upd)
  end

  ## helpers
  defp process_roll_command(chat_id, message_id, str, default_again) do
    with " " <> str <- str,
         {num, again} <- parse_num_again(str, default_again) do
      Nadia.send_message(chat_id, Roller.roll(num, again), [reply_to_message_id: message_id, parse_mode: "Markdown"])
    else
      _ ->
        rows = [2, 5, 8] |> Enum.map(
          fn(start) ->
            start .. start+2 |> Enum.map(
              fn(num) ->
                %Nadia.Model.InlineKeyboardButton{
                  callback_data: "-#{num}",
                  text: "#{num}"
                }
              end
            )
          end
        )
        inline_keyboard = %Nadia.Model.InlineKeyboardMarkup{inline_keyboard: rows}
        Nadia.send_message(chat_id, "🎲", [reply_to_message_id: message_id, parse_mode: "Markdown", reply_markup: inline_keyboard])
    end
  end

  defp suggestions(num) when is_integer(num) do
      case num > 50 or num < 1 do
      true -> plain_d10()
      false ->
        [ inline_item(1, "roll #{num}d10", "10 again", Roller.roll(num, 10)),
          inline_item(2, "roll #{num}d10", "9 again", Roller.roll(num, 9)),
          inline_item(3, "roll #{num}d10", "8 again", Roller.roll(num, 8))
        ]
    end
  end

  defp suggestions(str) do
    case Integer.parse(str) do
      {num, ""} -> suggestions(num)
      _ -> plain_d10()
    end
  end

  defp inline_item(id, title, description, text) do
    %Nadia.Model.InlineQueryResult.Article{
      id: id, title: title, description: description,
      input_message_content: %Nadia.Model.InputMessageContent.Text{
        message_text: text,
        parse_mode: "Markdown"
      }
    }
  end

  def plain_d10(), do: [inline_item(1, "roll 1d10", "plain", Roller.roll())]

  defp parse_num_again(str, default_again \\ 10) do
    case Integer.parse(str) do
      {num, ""} when num <= 50 -> {num, default_again}
      {num, "a" <> str} ->
        case Integer.parse(str) do
          {again, ""} when again >= 7 -> {num, again}
          _ -> :error
        end
      _ -> :error
    end
  end

end
