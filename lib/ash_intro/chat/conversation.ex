defmodule AshIntro.Chat.Conversation do
  use Ash.Resource,
    otp_app: :ash_intro,
    domain: AshIntro.Chat,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "conversations"
    repo AshIntro.Repo
  end

  actions do
    default_accept []
    defaults [:create, :read, :destroy]
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    has_many :messages, AshIntro.Chat.Message do
      public? true
    end
  end
end
