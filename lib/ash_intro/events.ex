defmodule AshIntro.Events do
  use Ash.Domain,
    otp_app: :ash_intro,
    extensions: [AshAi, AshPhoenix]

  tools do
    tool :get_events, AshIntro.Events.Event, :read do
      description """
      Use this tool to get information about events.
      Make sure to use %QUERY% pattern when searching
      for text queries, it uses ILIKE, both for event
      name and location.
      """

      load [:event_page_name]
    end
  end

  resources do
    resource AshIntro.Events.EventPage do
      define :list_event_pages,
        action: :read,
        default_options: [query: [sort: [inserted_at: :asc]]]

      define :get_event_page_by_id,
        action: :read,
        get_by: [:id]

      define :create_event_page, action: :create
      define :update_event_page, action: :update
      define :destroy_event_page, action: :destroy

      define :crawl, action: :crawl
    end

    resource AshIntro.Events.Event
  end
end
