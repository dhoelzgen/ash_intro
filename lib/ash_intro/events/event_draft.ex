defmodule AshIntro.Events.EventDraft do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string, allow_nil?: false, description: "The title of the event"
    field :description, :string, description: "A very brief description of the events"
    field :event_date, :string, description: "ISO-8601 UTC timestamp, e.g. 2025-08-25T09:00:00Z"

    field :event_location, :string,
      description: "The location of the event, can be Online / Zoom if applicable"
  end
end
