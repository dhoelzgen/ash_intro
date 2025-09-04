defmodule AshIntro.Chat do
  use Ash.Domain,
    otp_app: :ash_intro,
    extensions: [AshPhoenix]

  resources do
    resource AshIntro.Chat.Conversation do
      define :create_conversation, action: :create
      define :get_conversation, action: :read, get_by: [:id]
    end

    resource AshIntro.Chat.Message do
      define :create_message, action: :create

      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]
    end
  end
end
