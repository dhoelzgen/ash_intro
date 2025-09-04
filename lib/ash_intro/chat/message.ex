defmodule AshIntro.Chat.Message do
  use Ash.Resource,
    otp_app: :ash_intro,
    domain: AshIntro.Chat,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "messages"
    repo AshIntro.Repo
  end

  oban do
    triggers do
      trigger :respond do
        actor_persister AshIntro.ActorPersistor
        action :respond
        queue :chat_responses
        lock_for_update? false
        scheduler_cron false
        worker_module_name AshIntro.Chat.Message.Workers.Respond
        scheduler_module_name AshIntro.Chat.Message.Schedulers.Respond
        where expr(needs_response)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:text]

      validate match(:text, ~r/\S/) do
        message "Message cannot be empty"
      end

      argument :conversation_id, :uuid do
        public? false
      end

      change AshIntro.Chat.Message.Changes.CreateConversationIfNotProvided
      change run_oban_trigger(:respond)
    end

    read :for_conversation do
      pagination keyset?: true, required?: false
      argument :conversation_id, :uuid, allow_nil?: false

      prepare build(default_sort: [inserted_at: :desc])
      filter expr(conversation_id == ^arg(:conversation_id))
    end

    update :respond do
      accept []
      require_atomic? false
      transaction? false
      change AshIntro.Chat.Message.Changes.Respond
    end

    create :upsert_response do
      upsert? true
      accept [:id, :response_to_id, :conversation_id]
      argument :complete, :boolean, default: false
      argument :text, :string, allow_nil?: false, constraints: [trim?: false, allow_empty?: true]
      argument :tool_calls, {:array, :map}
      argument :tool_results, {:array, :map}

      # if updating
      #   if complete, set the text to the provided text
      #   if streaming still, add the text to the provided text
      change atomic_update(
               :text,
               {:atomic,
                expr(
                  if ^arg(:complete) do
                    ^arg(:text)
                  else
                    ^atomic_ref(:text) <> ^arg(:text)
                  end
                )}
             )

      change atomic_update(
               :tool_calls,
               {:atomic,
                expr(
                  if not is_nil(^arg(:tool_calls)) do
                    fragment(
                      "? || ?",
                      ^atomic_ref(:tool_calls),
                      type(
                        ^arg(:tool_calls),
                        {:array, :map}
                      )
                    )
                  else
                    ^atomic_ref(:tool_calls)
                  end
                )}
             )

      change atomic_update(
               :tool_results,
               {:atomic,
                expr(
                  if not is_nil(^arg(:tool_results)) do
                    fragment(
                      "? || ?",
                      ^atomic_ref(:tool_results),
                      type(
                        ^arg(:tool_results),
                        {:array, :map}
                      )
                    )
                  else
                    ^atomic_ref(:tool_results)
                  end
                )}
             )

      # if creating, set the text attribute to the provided text
      change set_attribute(:text, arg(:text))
      change set_attribute(:complete, arg(:complete))
      change set_attribute(:source, :agent)
      change set_attribute(:tool_results, arg(:tool_results))
      change set_attribute(:tool_calls, arg(:tool_calls))

      # on update, only set complete to its new value
      upsert_fields [:complete]
    end
  end

  pub_sub do
    module AshIntroWeb.Endpoint
    prefix "chat"

    publish :create, ["messages", :conversation_id] do
      transform fn %{data: message} ->
        message
      end
    end

    publish :upsert_response, ["messages", :conversation_id] do
      transform fn %{data: message} ->
        message
      end
    end
  end

  attributes do
    timestamps()
    uuid_v7_primary_key :id, writable?: true

    attribute :text, :string do
      constraints allow_empty?: true, trim?: false
      public? true
      allow_nil? false
    end

    attribute :tool_calls, {:array, :map}
    attribute :tool_results, {:array, :map}

    attribute :source, AshIntro.Chat.Message.Types.Source do
      allow_nil? false
      public? true
      default :user
    end

    attribute :complete, :boolean do
      allow_nil? false
      default true
    end
  end

  relationships do
    belongs_to :conversation, AshIntro.Chat.Conversation do
      public? true
      allow_nil? false
    end

    belongs_to :response_to, __MODULE__ do
      public? true
    end

    has_one :response, __MODULE__ do
      public? true
      destination_attribute :response_to_id
    end
  end

  calculations do
    calculate :needs_response, :boolean do
      calculation expr(source == :user and not exists(response))
    end
  end
end
