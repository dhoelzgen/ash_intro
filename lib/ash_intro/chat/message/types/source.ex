defmodule AshIntro.Chat.Message.Types.Source do
  use Ash.Type.Enum, values: [:agent, :user]
end
